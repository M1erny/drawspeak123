import DrawspeakCore
import Foundation

/// The subset of the Scribe v2 response the app stores.
nonisolated struct ElevenLabsResponse: Decodable {
    var text: String
    var languageCode: String?
    var languageProbability: Double?

    private enum CodingKeys: String, CodingKey {
        case text
        case languageCode = "language_code"
        case languageProbability = "language_probability"
    }

    /// Decodes a 2xx body. Empty text is a valid result (silence).
    static func transcript(
        from data: Data,
        requestedLanguage: String?,
        receivedAt: Date
    ) throws(TranscriptionFailure) -> Transcript {
        let response: ElevenLabsResponse
        do {
            response = try JSONDecoder().decode(ElevenLabsResponse.self, from: data)
        } catch {
            throw TranscriptionFailure(code: .invalidResponse, requestMayHaveBeenProcessed: true)
        }
        if let probability = response.languageProbability, !(0...1).contains(probability) {
            throw TranscriptionFailure(code: .invalidResponse, requestMayHaveBeenProcessed: true)
        }
        let detected = response.languageCode.flatMap { $0.isEmpty ? nil : $0 }
        return Transcript(
            text: response.text,
            requestedLanguage: requestedLanguage,
            detectedLanguage: detected,
            languageProbability: response.languageProbability,
            provider: "elevenlabs",
            modelId: ElevenLabsTranscriber.modelId,
            receivedAt: receivedAt
        )
    }
}
