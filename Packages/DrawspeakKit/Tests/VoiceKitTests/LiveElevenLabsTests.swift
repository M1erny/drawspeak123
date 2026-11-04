import DrawspeakCore
import Foundation
import Testing
@testable import VoiceKit

/// Opt-in live check against ElevenLabs. Runs only when both
/// DRAWSPEAK_LIVE_ELEVENLABS_KEY and DRAWSPEAK_LIVE_AUDIO are set; never prints the key.
@Suite struct LiveElevenLabsTests {
    static var key: String? { ProcessInfo.processInfo.environment["DRAWSPEAK_LIVE_ELEVENLABS_KEY"].flatMap { $0.isEmpty ? nil : $0 } }
    static var audioPath: String? { ProcessInfo.processInfo.environment["DRAWSPEAK_LIVE_AUDIO"] }

    @Test(.enabled(if: key != nil && audioPath != nil))
    func transcribesPolishSpeech() async throws {
        let audio = try Data(contentsOf: URL(fileURLWithPath: try #require(Self.audioPath)))
        let transcriber = ElevenLabsTranscriber(keyStore: ElevenLabsKeyStore(fixedKey: Self.key))
        let transcript = try await transcriber.transcribe(audio: audio, contentType: "audio/mp4", language: nil)
        print("LIVE detected=\(transcript.detectedLanguage ?? "nil") text=\(transcript.text)")
        #expect(transcript.text.lowercased().contains("przycisk"))
        #expect(transcript.modelId == "scribe_v2")
    }
}
