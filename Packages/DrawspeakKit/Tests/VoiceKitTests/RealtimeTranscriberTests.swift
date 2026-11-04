import DrawspeakCore
import Foundation
import Synchronization
import Testing
@testable import VoiceKit

/// A scripted WebSocket: records sent frames; `reply` decides the server's answers.
final class FakeRealtimeTransport: RealtimeTransport, Sendable {
    private let state = Mutex<(sent: [String], inbox: [String], closed: Bool)>(([], [], false))
    let reply: @Sendable (String) -> [String]
    let sendFails: Bool

    init(sendFails: Bool = false, reply: @escaping @Sendable (String) -> [String] = { _ in [] }) {
        self.sendFails = sendFails
        self.reply = reply
    }

    var sent: [String] { state.withLock { $0.sent } }
    var isClosed: Bool { state.withLock { $0.closed } }

    func push(_ frames: [String]) { state.withLock { $0.inbox += frames } }

    func send(_ text: String) async throws {
        if sendFails { throw URLError(.notConnectedToInternet) }
        let closed = state.withLock { state in
            if !state.closed { state.sent.append(text) }
            return state.closed
        }
        if closed { throw URLError(.cancelled) }
        push(reply(text))
    }

    func receive() async throws -> String? {
        while true {
            let next: String?? = state.withLock { state in
                if !state.inbox.isEmpty { return .some(state.inbox.removeFirst()) }
                return state.closed ? .none : .some(nil)
            }
            switch next {
            case .none: throw URLError(.cancelled)
            case .some(.some(let frame)): return frame
            case .some(.none): try await Task.sleep(for: .milliseconds(2))
            }
        }
    }

    func close() { state.withLock { $0.closed = true } }
}

private struct SentChunk: Decodable {
    let message_type: String
    let audio_base_64: String
    let commit: Bool
    let sample_rate: Int
}

private func decode(_ frame: String) throws -> SentChunk {
    try JSONDecoder().decode(SentChunk.self, from: Data(frame.utf8))
}

private func collect(_ events: AsyncStream<LiveTranscriptEvent>) async -> [LiveTranscriptEvent] {
    var result: [LiveTranscriptEvent] = []
    for await event in events { result.append(event) }
    return result
}

struct RealtimeMessageTests {
    @Test func audioChunkFrameMatchesTheProtocol() throws {
        let pcm = Data([0x01, 0x00, 0xff, 0x7f])
        let frame = RealtimeClientMessage.audioChunk(pcm, commit: false)
        let chunk = try decode(frame)
        #expect(chunk.message_type == "input_audio_chunk")
        #expect(Data(base64Encoded: chunk.audio_base_64) == pcm)
        #expect(chunk.commit == false)
        #expect(chunk.sample_rate == 16_000)
        #expect(try decode(RealtimeClientMessage.audioChunk(pcm, commit: true)).commit)
        #expect(frame == #"{"audio_base_64":"AQD/fw==","commit":false,"message_type":"input_audio_chunk","sample_rate":16000}"#)
    }

    @Test func parsesServerMessages() {
        #expect(RealtimeServerMessage.parse(#"{"message_type":"session_started","session_id":"s1","config":{}}"#) == .sessionStarted)
        #expect(RealtimeServerMessage.parse(#"{"message_type":"partial_transcript","text":"Ten przy"}"#) == .partial("Ten przy"))
        #expect(RealtimeServerMessage.parse(#"{"message_type":"committed_transcript","text":"Ten przycisk."}"#) == .committed("Ten przycisk."))
        #expect(RealtimeServerMessage.parse(#"{"message_type":"committed_transcript_with_timestamps","text":"x","words":[]}"#) == .ignored)
        #expect(RealtimeServerMessage.parse(#"{"message_type":"warning","warning":"slow"}"#) == .ignored)
        #expect(RealtimeServerMessage.parse(#"{"message_type":"something_new"}"#) == .ignored)
        #expect(RealtimeServerMessage.parse("not json") == nil)
        #expect(RealtimeServerMessage.parse(#"{"text":"no type"}"#) == nil)
    }

    @Test(arguments: [
        "error", "auth_error", "quota_exceeded", "rate_limited", "input_error", "chunk_size_exceeded",
        "insufficient_audio_activity", "session_time_limit_exceeded", "transcriber_error", "invalid_request",
    ])
    func errorTypesCarryOnlyTheirType(type: String) {
        #expect(RealtimeServerMessage.parse(#"{"message_type":"\#(type)","error":"secret detail"}"#) == .error(type: type))
    }

    @Test func requestCarriesModelFormatVadLanguageAndKeyHeader() throws {
        let request = try #require(RealtimeTranscriber.request(key: "test-key", language: "pl-PL"))
        let url = try #require(request.url)
        let items = Dictionary(uniqueKeysWithValues: (URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []).map { ($0.name, $0.value ?? "") })
        #expect(url.scheme == "wss")
        #expect(url.host() == "api.elevenlabs.io")
        #expect(url.path() == "/v1/speech-to-text/realtime")
        #expect(items == ["model_id": "scribe_v2_realtime", "audio_format": "pcm_16000", "commit_strategy": "vad", "language_code": "pol"])
        #expect(request.value(forHTTPHeaderField: "xi-api-key") == "test-key")
        #expect(!url.absoluteString.contains("test-key"))

        let automatic = try #require(RealtimeTranscriber.request(key: "k", language: nil)?.url?.absoluteString)
        #expect(!automatic.contains("language_code"))
        #expect(RealtimeTranscriber.request(key: "bad\r\nkey", language: nil) == nil)
    }
}

struct RealtimeTranscriberTests {
    @Test func streamsBufferedChunksThenCommitsAndFinishes() async throws {
        let transport = FakeRealtimeTransport { frame in
            guard let chunk = try? decode(frame) else { return [] }
            if chunk.commit {
                return [#"{"message_type":"partial_transcript","text":"zmień kolor"}"#,
                        #"{"message_type":"committed_transcript","text":"Zmień kolor."}"#]
            }
            return []
        }
        transport.push([#"{"message_type":"session_started","session_id":"s","config":{}}"#,
                        #"{"message_type":"partial_transcript","text":"Ten"}"#,
                        #"{"message_type":"committed_transcript","text":"Ten przycisk."}"#])
        let transcriber = RealtimeTranscriber(transport: transport)
        // Chunks captured before the socket is used are buffered, not dropped.
        let (audio, input) = AsyncStream.makeStream(of: AudioChunk.self)
        for index in 0..<3 { input.yield(AudioChunk(data: Data(repeating: UInt8(index), count: 3_200), isLast: false)) }
        input.yield(AudioChunk(data: Data(count: 400), isLast: true))
        input.finish()

        async let events = collect(transcriber.events)
        await transcriber.run(audio: audio)
        let received = await events

        let sent = try transport.sent.map(decode)
        #expect(sent.map(\.commit) == [false, false, false, true])
        #expect(sent.map { Data(base64Encoded: $0.audio_base_64)?.count } == [3_200, 3_200, 3_200, 400])
        #expect(received.first == .partial("Ten"))
        #expect(received.contains(.committed("Ten przycisk.")))
        #expect(received.last == .finished("Ten przycisk. Zmień kolor."))
        #expect(received.filter { if case .finished = $0 { true } else { false } }.count == 1)
        #expect(transport.isClosed)
    }

    @Test func finishWaitsAtMostTheTimeoutForTheFinalCommit() async {
        let transport = FakeRealtimeTransport()
        let transcriber = RealtimeTranscriber(transport: transport, finalCommitTimeout: .milliseconds(150))
        let (audio, input) = AsyncStream.makeStream(of: AudioChunk.self)
        input.yield(AudioChunk(data: Data(count: 320), isLast: true))
        input.finish()
        async let events = collect(transcriber.events)
        let start = ContinuousClock.now
        await transcriber.run(audio: audio)
        #expect(ContinuousClock.now - start < .seconds(1))
        #expect(await events == [.finished("")])
    }

    @Test func serverErrorFailsOnceWithItsTypeAndCloses() async {
        let transport = FakeRealtimeTransport()
        transport.push([#"{"message_type":"auth_error","error":"Invalid key abc"}"#])
        let transcriber = RealtimeTranscriber(transport: transport)
        let (audio, input) = AsyncStream.makeStream(of: AudioChunk.self)
        async let events = collect(transcriber.events)
        async let run: Void = transcriber.run(audio: audio)
        let received = await events
        // Audio keeps draining after the failure; the final chunk is not sent.
        input.yield(AudioChunk(data: Data(count: 3_200), isLast: false))
        input.yield(AudioChunk(data: Data(count: 10), isLast: true))
        input.finish()
        await run
        #expect(received == [.failed(code: "auth_error")])
        #expect(transport.isClosed)
        #expect(!transport.sent.contains { (try? decode($0))?.commit == true })
    }

    @Test func sendFailureIsANetworkFailure() async {
        let transcriber = RealtimeTranscriber(transport: FakeRealtimeTransport(sendFails: true))
        let (audio, input) = AsyncStream.makeStream(of: AudioChunk.self)
        input.yield(AudioChunk(data: Data(count: 3_200), isLast: false))
        input.finish()
        async let events = collect(transcriber.events)
        await transcriber.run(audio: audio)
        #expect(await events == [.failed(code: "network")])
    }

    @Test func endingWithoutALastChunkCancelsSilently() async {
        let transport = FakeRealtimeTransport()
        let transcriber = RealtimeTranscriber(transport: transport)
        let (audio, input) = AsyncStream.makeStream(of: AudioChunk.self)
        input.yield(AudioChunk(data: Data(count: 3_200), isLast: false))
        input.finish()
        async let events = collect(transcriber.events)
        await transcriber.run(audio: audio)
        #expect(await events.isEmpty)
        #expect(transport.isClosed)
    }
}
