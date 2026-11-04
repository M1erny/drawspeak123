@preconcurrency import AVFoundation
import DrawspeakCore
import Foundation
import Observation

/// Captures the microphone with `AVAudioEngine`: the original audio goes to one local
/// AAC/.m4a file per recording, and 16 kHz PCM streams to ElevenLabs realtime
/// transcription at the same time. Audio is saved locally before any result.
@Observable
public final class AudioRecorder: VoiceCapturing {
    public private(set) var isRecording = false
    /// 0...1, refreshed about 15 times a second while recording.
    public private(set) var level: Double = 0
    public private(set) var elapsed: TimeInterval = 0
    /// Called after an audio interruption or route loss stopped capture. The partial file is kept:
    /// the owner decides between `stop()` (keep) and `discard()`.
    @ObservationIgnored public var onInterruption: (() -> Void)?

    private struct Capture {
        let scope: RecordingScope
        let fileURL: URL
        let sink: CaptureSink
        let transcriber: RealtimeTranscriber?
        let events: Task<Void, Never>?
        var halted = false
    }

    @ObservationIgnored private let engine = AVAudioEngine()
    @ObservationIgnored private let keyStore: ElevenLabsKeyStore
    @ObservationIgnored private let makeTransport: @Sendable (URLRequest) -> any RealtimeTransport
    @ObservationIgnored private var isPrepared = false
    @ObservationIgnored private var capture: Capture?
    @ObservationIgnored private var meterTask: Task<Void, Never>?
    @ObservationIgnored private var interruptionTasks: [Task<Void, Never>] = []

    static let minimumDuration: TimeInterval = 0.1
    private static let meterInterval = Duration.milliseconds(66)
    /// About 21 ms at 48 kHz: the first chunk is ready quickly.
    private static let tapBufferSize: AVAudioFrameCount = 1_024

    /// Uses the built-in ElevenLabs key for live transcription.
    public convenience init(keyStore: ElevenLabsKeyStore = .init()) {
        self.init(keyStore: keyStore) { URLSessionRealtimeTransport(request: $0) }
    }

    init(keyStore: ElevenLabsKeyStore, makeTransport: @escaping @Sendable (URLRequest) -> any RealtimeTransport) {
        self.keyStore = keyStore
        self.makeTransport = makeTransport
    }

    public var hasPermission: Bool { AVAudioApplication.shared.recordPermission == .granted }

    public func requestPermission() async -> Bool {
        let granted = hasPermission ? true : await AVAudioApplication.requestRecordPermission()
        if granted { prepare() }
        return granted
    }

    /// Sets the audio category and prepares the engine so `start` only activates the
    /// session and starts the engine. Call at launch when permission was already granted.
    /// Does not activate the session, so other audio keeps playing.
    public func prepare() {
        guard !isPrepared, hasPermission else { return }
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setCategory(
            .playAndRecord, mode: .spokenAudio, options: [.allowBluetoothHFP, .defaultToSpeaker]
        )
        #endif
        _ = engine.inputNode
        engine.prepare()
        isPrepared = true
    }

    public func start(scope: RecordingScope, language: String?, onEvent: @escaping @MainActor (LiveTranscriptEvent) -> Void) throws {
        guard capture == nil else { throw AudioRecorderError.alreadyRecording }
        prepare()

        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        do {
            if session.category != .playAndRecord {
                try session.setCategory(.playAndRecord, mode: .spokenAudio, options: [.allowBluetoothHFP, .defaultToSpeaker])
            }
            try session.setActive(true)
        } catch {
            throw AudioRecorderError.sessionUnavailable
        }
        #endif

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        let directory = FileManager.default.temporaryDirectory.appending(path: "Recordings", directoryHint: .isDirectory)
        let url = directory.appending(path: "\(scope.recordingId.uuidString).m4a", directoryHint: .notDirectory)
        let (audio, audioContinuation) = AsyncStream.makeStream(of: AudioChunk.self, bufferingPolicy: .unbounded)
        let sink: CaptureSink
        do {
            guard format.sampleRate > 0, format.channelCount > 0, let converter = PCMConverter(from: format) else {
                throw AudioRecorderError.recorderUnavailable
            }
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let file = try AVAudioFile(
                forWriting: url,
                settings: [
                    AVFormatIDKey: kAudioFormatMPEG4AAC,
                    AVSampleRateKey: format.sampleRate,
                    AVNumberOfChannelsKey: format.channelCount,
                    AVEncoderBitRateKey: 64_000,
                ],
                commonFormat: format.commonFormat,
                interleaved: format.isInterleaved
            )
            sink = CaptureSink(file: file, converter: converter, sampleRate: format.sampleRate, audio: audioContinuation)
            try input.installAudioTap(onBus: 0, bufferSize: Self.tapBufferSize, format: format, tapProvider: sink.makeTapProvider())
            do {
                try engine.start()
            } catch {
                input.removeTap(onBus: 0)
                sink.cancel()
                throw AudioRecorderError.recorderUnavailable
            }
        } catch {
            audioContinuation.finish()
            deactivateSession()
            try? FileManager.default.removeItem(at: url)
            throw AudioRecorderError.recorderUnavailable
        }

        let (transcriber, events) = startLiveTranscription(audio: audio, language: language, onEvent: onEvent)
        capture = Capture(scope: scope, fileURL: url, sink: sink, transcriber: transcriber, events: events)
        elapsed = 0
        level = 0
        isRecording = true
        startMetering()
        observeInterruptions()
    }

    public func stop() -> CapturedAudio? {
        guard var capture else { return nil }
        let wrote = halt(&capture)
        self.capture = nil
        level = 0
        let duration = capture.sink.meters.elapsed
        elapsed = duration

        let size = (try? capture.fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        guard wrote, size > 0, duration >= Self.minimumDuration else {
            try? FileManager.default.removeItem(at: capture.fileURL)
            if let transcriber = capture.transcriber { Task { await transcriber.cancel() } }
            return nil
        }
        return CapturedAudio(scope: capture.scope, fileURL: capture.fileURL, contentType: "audio/mp4", duration: duration)
    }

    public func discard() {
        guard var capture else { return }
        capture.sink.cancel()
        _ = halt(&capture)
        if let transcriber = capture.transcriber { Task { await transcriber.cancel() } }
        capture.events?.cancel()
        try? FileManager.default.removeItem(at: capture.fileURL)
        self.capture = nil
        level = 0
        elapsed = 0
    }

    /// Maps average power in dB (-160...0) to 0...1, treating -50 dB and below as silence.
    nonisolated static func normalizedLevel(averagePower: Float) -> Double {
        let floor: Float = -50
        guard averagePower.isFinite else { return 0 }
        return Double(max(0, min(1, (averagePower - floor) / -floor)))
    }

    // MARK: Private

    /// Connects the live session; chunks captured meanwhile wait in `audio`.
    private func startLiveTranscription(
        audio: AsyncStream<AudioChunk>,
        language: String?,
        onEvent: @escaping @MainActor (LiveTranscriptEvent) -> Void
    ) -> (RealtimeTranscriber?, Task<Void, Never>?) {
        guard let key = keyStore.key(), let request = RealtimeTranscriber.request(key: key, language: language) else {
            // Delivered after `start` returns, never synchronously.
            Task { onEvent(.failed(code: TranscriptionFailure.Code.notConfigured.rawValue)) }
            Task { for await _ in audio {} }
            return (nil, nil)
        }
        let transcriber = RealtimeTranscriber(transport: makeTransport(request))
        Task { await transcriber.run(audio: audio) }
        let events = Task {
            for await event in transcriber.events {
                guard !Task.isCancelled else { return }
                onEvent(event)
            }
        }
        return (transcriber, events)
    }

    /// Stops the engine and closes the file (sending the final chunk), keeps the
    /// capture, and releases the audio session. Returns false when the file write failed.
    private func halt(_ capture: inout Capture) -> Bool {
        meterTask?.cancel()
        meterTask = nil
        interruptionTasks.forEach { $0.cancel() }
        interruptionTasks = []
        if !capture.halted {
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
            deactivateSession()
            capture.halted = true
        }
        isRecording = false
        return capture.sink.finish()
    }

    private func startMetering() {
        meterTask = Task { [weak self] in
            while !Task.isCancelled {
                self?.sampleMeters()
                try? await Task.sleep(for: Self.meterInterval)
            }
        }
    }

    private func sampleMeters() {
        guard let capture, !capture.halted else { return }
        let meters = capture.sink.meters
        level = meters.level
        elapsed = meters.elapsed
    }

    private func interrupt() {
        guard var capture, !capture.halted else { return }
        _ = halt(&capture)
        self.capture = capture
        level = 0
        onInterruption?()
    }

    private func deactivateSession() {
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        #endif
    }

    private func observeInterruptions() {
        var tasks = [
            // A route or format change stops the engine; treat it like an interruption.
            Task { [weak self, engine] in
                for await _ in NotificationCenter.default.notifications(named: .AVAudioEngineConfigurationChange, object: engine) {
                    self?.interrupt()
                }
            },
        ]
        #if os(iOS)
        tasks += [
            // iOS 27 replaced interruptionNotification: the system deactivating the session ends capture.
            // Our own deactivation happens after these tasks are cancelled, so it never lands here.
            Task { [weak self] in
                for await _ in NotificationCenter.default.notifications(named: AVAudioSession.didBecomeInactiveNotification) {
                    self?.interrupt()
                }
            },
            Task { [weak self] in
                for await notification in NotificationCenter.default.notifications(named: AVAudioSession.routeChangeNotification) {
                    let rawReason = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
                    let previous = notification.userInfo?[AVAudioSessionRouteChangePreviousRouteKey] as? AVAudioSessionRouteDescription
                    let lostInput = previous.map { !$0.inputs.isEmpty } ?? false
                    if rawReason.flatMap(AVAudioSession.RouteChangeReason.init(rawValue:)) == .oldDeviceUnavailable, lostInput {
                        self?.interrupt()
                    }
                }
            },
        ]
        #endif
        interruptionTasks = tasks
    }
}
