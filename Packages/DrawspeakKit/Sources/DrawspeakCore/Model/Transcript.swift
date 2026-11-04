import Foundation

/// The raw provider result for one recording, kept separate from the comment text.
public struct Transcript: Codable, Hashable, Sendable {
    public var text: String
    public var requestedLanguage: String?
    public var detectedLanguage: String?
    public var languageProbability: Double?
    public var provider: String
    public var modelId: String
    public var receivedAt: Date

    public init(
        text: String,
        requestedLanguage: String?,
        detectedLanguage: String?,
        languageProbability: Double?,
        provider: String,
        modelId: String,
        receivedAt: Date
    ) {
        self.text = text
        self.requestedLanguage = requestedLanguage
        self.detectedLanguage = detectedLanguage
        self.languageProbability = languageProbability
        self.provider = provider
        self.modelId = modelId
        self.receivedAt = receivedAt
    }
}
