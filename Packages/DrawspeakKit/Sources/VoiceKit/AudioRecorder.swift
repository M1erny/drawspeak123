import AVFoundation
import DrawspeakCore
import Foundation
import Observation

/// Records one local AAC/.m4a file per recording. Transcription is separate and starts only after `stop()`.
@Observable
public final class AudioRecorder: VoiceCapturing {
    public private(set) var isRecording = false
    /// 0...1, refreshed about 15 times a second while recording.
    public private(set) var level: Double = 0
    public private(set) var elapsed: TimeInterval = 0
    /// Called after an audio interruption or route loss stopped capture. The partial file is kept:
    /// the owner decides between `stop()` (keep) and `discard()`.
    @ObservationIgnored public var onInterruption: (() -> Void)?

    @ObservationIgnored private var recorder: AVAudioRecorder?
    @ObservationIgnored private var scope: RecordingScope?
    @ObservationIgnored private var fileURL: URL?
    @ObservationIgnored private var meterTask: Task<Void, Never>?
    @ObservationIgnored private var interruptionTasks: [Task<Void, Never>] = []

    static let minimumDuration: TimeInterval = 0.1
    private static let meterInterval = Duration.milliseconds(66)

    public init() {}

    public func requestPermission() async -> Bool {
        if AVAudioApplication.shared.recordPermission == .granted { return true }
        return await AVAudioApplication.requestRecordPermission()
    }

    public func start(scope: RecordingScope) throws {
        guard recorder == nil else { throw AudioRecorderError.alreadyRecording }

        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .spokenAudio, options: [.allowBluetoothHFP, .defaultToSpeaker])
            try session.setActive(true)
        } catch {
            throw AudioRecorderError.sessionUnavailable
        }
        #endif

        let directory = FileManager.default.temporaryDirectory.appending(path: "Recordings", directoryHint: .isDirectory)
        let url = directory.appending(path: "\(scope.recordingId.uuidString).m4a", directoryHint: .notDirectory)
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44_100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: 64_000,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
        ]
        let newRecorder: AVAudioRecorder
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            newRecorder = try AVAudioRecorder(url: url, settings: settings)
            newRecorder.isMeteringEnabled = true
            guard newRecorder.record() else { throw AudioRecorderError.recorderUnavailable }
        } catch {
            deactivateSession()
            try? FileManager.default.removeItem(at: url)
            throw AudioRecorderError.recorderUnavailable
        }

        recorder = newRecorder
        self.scope = scope
        fileURL = url
        elapsed = 0
        level = 0
        isRecording = true
        startMetering()
        observeInterruptions()
    }

    public func stop() -> CapturedAudio? {
        guard let scope, let fileURL else { return nil }
        halt()
        let duration = elapsed
        self.scope = nil
        self.fileURL = nil
        recorder = nil
        level = 0

        let size = (try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        guard size > 0, duration >= Self.minimumDuration else {
            try? FileManager.default.removeItem(at: fileURL)
            return nil
        }
        return CapturedAudio(scope: scope, fileURL: fileURL, contentType: "audio/mp4", duration: duration)
    }

    public func discard() {
        halt()
        if let fileURL { try? FileManager.default.removeItem(at: fileURL) }
        scope = nil
        fileURL = nil
        recorder = nil
        level = 0
        elapsed = 0
    }

    /// Maps average power in dB (-160...0) to 0...1, treating -50 dB and below as silence.
    static func normalizedLevel(averagePower: Float) -> Double {
        let floor: Float = -50
        guard averagePower.isFinite else { return 0 }
        return Double(max(0, min(1, (averagePower - floor) / -floor)))
    }

    // MARK: Private

    /// Stops the recorder, keeps the file and the final `elapsed`, and releases the audio session.
    private func halt() {
        meterTask?.cancel()
        meterTask = nil
        interruptionTasks.forEach { $0.cancel() }
        interruptionTasks = []
        if let recorder, recorder.isRecording {
            elapsed = recorder.currentTime
            recorder.stop()
            deactivateSession()
        }
        isRecording = false
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
        guard let recorder, recorder.isRecording else { return }
        recorder.updateMeters()
        level = Self.normalizedLevel(averagePower: recorder.averagePower(forChannel: 0))
        elapsed = recorder.currentTime
    }

    private func interrupt() {
        guard isRecording else { return }
        halt()
        level = 0
        onInterruption?()
    }

    private func deactivateSession() {
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        #endif
    }

    private func observeInterruptions() {
        #if os(iOS)
        interruptionTasks = [
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
    }
}
