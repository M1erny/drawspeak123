import AVFoundation
import DrawspeakCore
import Foundation
import Testing
@testable import VoiceKit

/// Opt-in live check of Scribe v2 Realtime. Runs only when DRAWSPEAK_LIVE_ELEVENLABS_KEY
/// and DRAWSPEAK_LIVE_AUDIO (an .m4a or .wav file) are set; never prints the key.
@Suite struct LiveRealtimeTests {
    static var key: String? { ProcessInfo.processInfo.environment["DRAWSPEAK_LIVE_ELEVENLABS_KEY"].flatMap { $0.isEmpty ? nil : $0 } }
    static var audioPath: String? { ProcessInfo.processInfo.environment["DRAWSPEAK_LIVE_AUDIO"].flatMap { $0.isEmpty ? nil : $0 } }

    /// Decodes the file and converts it to 16 kHz mono Int16 PCM.
    static func pcm(fromFileAt path: String) throws -> Data {
        let file = try AVAudioFile(forReading: URL(filePath: path))
        let converter = try #require(PCMConverter(from: file.processingFormat))
        var pcm = Data()
        while file.framePosition < file.length {
            let buffer = try #require(AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: 4_096))
            try file.read(into: buffer)
            if buffer.frameLength == 0 { break }
            pcm.append(converter.convert(buffer))
        }
        return pcm
    }

    @Test(.enabled(if: key != nil && audioPath != nil), .timeLimit(.minutes(2)))
    func streamsPolishSpeechAndCommitsText() async throws {
        let path = try #require(Self.audioPath)
        let pcm = try Self.pcm(fromFileAt: path)
        #expect(pcm.count > 3_200)
        let key = try #require(Self.key)
        let request = try #require(RealtimeTranscriber.request(key: key, language: nil))
        let transcriber = RealtimeTranscriber(transport: URLSessionRealtimeTransport(request: request))
        let (audio, input) = AsyncStream.makeStream(of: AudioChunk.self)
        let feeder = Task {
            var chunker = PCMChunker()
            // 100 ms of audio every 25 ms: four times real time.
            for chunk in chunker.append(pcm) {
                input.yield(AudioChunk(data: chunk, isLast: false))
                try? await Task.sleep(for: .milliseconds(25))
            }
            let rest = chunker.flush()
            input.yield(AudioChunk(data: rest.isEmpty ? Data(count: 320) : rest, isLast: true))
            input.finish()
        }
        var committed: [String] = []
        var partials = 0
        var terminal: LiveTranscriptEvent?
        async let run: Void = transcriber.run(audio: audio)
        for await event in transcriber.events {
            switch event {
            case .partial: partials += 1
            case .committed(let text): committed.append(text)
            case .finished, .failed: terminal = event
            }
        }
        await run
        await feeder.value
        print("LIVE realtime partials=\(partials) committed=\(committed.joined(separator: " | ")) terminal=\(String(describing: terminal))")
        #expect(committed.joined(separator: " ").lowercased().contains("przycisk"))
        guard case .finished(let text) = terminal else {
            Issue.record("Expected finished, got \(String(describing: terminal))")
            return
        }
        #expect(text.lowercased().contains("przycisk"))
    }
}
