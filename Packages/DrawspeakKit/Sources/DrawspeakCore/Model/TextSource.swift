import Foundation

/// Where the current comment text came from.
public enum TextSource: String, Codable, Hashable, Sendable {
    case none
    /// Filled from a finished transcript and not edited since.
    case transcript
    /// Typed or edited by the person.
    case typed
}
