import DrawspeakCore
import Foundation

/// A piece of 16 kHz mono Int16 PCM for the live session. The last one carries the final commit.
nonisolated struct AudioChunk: Sendable {
    var data: Data
    var isLast: Bool
}

/// ElevenLabs Scribe v2 Realtime over one WebSocket per recording.
///
/// Audio is consumed from an `AsyncStream`, so chunks captured while the socket
/// connects are buffered and sent in order. Never reconnects or retries (paid).
actor RealtimeTranscriber {
    static let defaultEndpoint = URL(string: "wss://api.elevenlabs.io/v1/speech-to-text/realtime")!
    static let modelId = Transcript.liveModelId
    static let finalCommitTimeout = Duration.seconds(3)

    /// Partial and committed text, then exactly one `finished` or `failed`, unless cancelled.
    nonisolated let events: AsyncStream<LiveTranscriptEvent>
    private let continuation: AsyncStream<LiveTranscriptEvent>.Continuation
    private let transport: any RealtimeTransport
    private let finalCommitTimeout: Duration
    private var segments: [String] = []
    private var ended = false
    private var awaitingFinalCommit = false
    private var finalCommitReceived = false
    private var receiveTask: Task<Void, Never>?

    init(transport: any RealtimeTransport, finalCommitTimeout: Duration = RealtimeTranscriber.finalCommitTimeout) {
        self.transport = transport
        self.finalCommitTimeout = finalCommitTimeout
        (events, continuation) = AsyncStream.makeStream(bufferingPolicy: .unbounded)
    }

    /// The handshake request. Nil when the key cannot be a header value.
    /// `language` is normalized to "pol"/"eng"; anything else means automatic detection.
    nonisolated static func request(key: String, language: String?, endpoint: URL = defaultEndpoint) -> URLRequest? {
        guard !key.isEmpty, key.utf8.allSatisfy({ (0x20...0x7e).contains($0) }),
              var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false) else { return nil }
        var items = [
            URLQueryItem(name: "model_id", value: modelId),
            URLQueryItem(name: "audio_format", value: "pcm_16000"),
            URLQueryItem(name: "commit_strategy", value: "vad"),
        ]
        if let code = language.flatMap(ElevenLabsLanguage.code(for:)) {
            items.append(URLQueryItem(name: "language_code", value: code))
        }
        components.queryItems = items
        guard let url = components.url else { return nil }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
        request.setValue(key, forHTTPHeaderField: "xi-api-key")
        request.httpShouldHandleCookies = false
        return request
    }

    /// Streams `audio` until its last chunk, then waits for the final commit and closes.
    /// When the stream ends without a last chunk (discard), closes without a terminal event.
    func run(audio: AsyncStream<AudioChunk>) async {
        receiveTask = Task { await self.receiveLoop() }
        var sentLast = false
        for await chunk in audio {
            // After a failure keep draining so the capture side never piles up audio.
            guard !ended else { continue }
            if chunk.isLast { awaitingFinalCommit = true }
            do {
                try await transport.send(RealtimeClientMessage.audioChunk(chunk.data, commit: chunk.isLast))
            } catch {
                fail("network")
                continue
            }
            if chunk.isLast {
                sentLast = true
                break
            }
        }
        guard !ended else { return }
        guard sentLast else {
            cancel()
            return
        }
        let clock = ContinuousClock()
        let deadline = clock.now + finalCommitTimeout
        while !ended, !finalCommitReceived, clock.now < deadline {
            try? await Task.sleep(for: .milliseconds(20))
        }
        guard !ended else { return }
        ended = true
        close()
        continuation.yield(.finished(segments.joined(separator: " ")))
        continuation.finish()
    }

    /// Closes the socket; no further events.
    func cancel() {
        guard !ended else { return }
        ended = true
        close()
        continuation.finish()
    }

    private func receiveLoop() async {
        while !ended {
            let frame: String?
            do {
                frame = try await transport.receive()
            } catch {
                fail("network")
                return
            }
            guard let frame, let message = RealtimeServerMessage.parse(frame) else { continue }
            handle(message)
        }
    }

    func handle(_ message: RealtimeServerMessage) {
        guard !ended else { return }
        switch message {
        case .sessionStarted, .ignored:
            break
        case .partial(let text):
            continuation.yield(.partial(text))
        case .committed(let text):
            let segment = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !segment.isEmpty {
                segments.append(segment)
                continuation.yield(.committed(segment))
            }
            if awaitingFinalCommit { finalCommitReceived = true }
        case .error(let type):
            fail(type)
        }
    }

    private func fail(_ code: String) {
        guard !ended else { return }
        ended = true
        close()
        continuation.yield(.failed(code: code))
        continuation.finish()
    }

    private func close() {
        transport.close()
        receiveTask?.cancel()
    }
}
