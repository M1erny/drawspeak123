import Foundation

/// What the refiner knows about the comment besides its words.
public struct RefineContext: Sendable, Hashable {
    public var screenTitle: String
    public var versionLabel: String
    public var markKind: String
    /// Label of the selected HTML component, if any.
    public var componentLabel: String?
    /// "pol", "eng" or nil when unknown.
    public var language: String?

    public init(screenTitle: String, versionLabel: String, markKind: String, componentLabel: String?, language: String?) {
        self.screenTitle = screenTitle
        self.versionLabel = versionLabel
        self.markKind = markKind
        self.componentLabel = componentLabel
        self.language = language
    }
}

public struct RefineFailure: Error, Hashable, Sendable {
    public enum Code: String, Sendable {
        case notConfigured = "not_configured"
        case auth
        case rateLimited = "rate_limited"
        case refused
        case network
        case upstream
        case invalidResponse = "invalid_response"
    }

    public var code: Code

    public init(code: Code) {
        self.code = code
    }
}

/// Turns a spoken transcript and a crop of the marked region into a concise,
/// technical comment. Implemented in RefineKit (Claude Sonnet).
public protocol TranscriptRefining: Sendable {
    var isConfigured: Bool { get }
    /// - Parameters:
    ///   - transcript: the raw spoken text.
    ///   - regionPNG: the marked region with some context and the mark drawn, or nil.
    func refine(transcript: String, regionPNG: Data?, context: RefineContext) async throws(RefineFailure) -> String
}
