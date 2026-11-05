import Foundation

public nonisolated enum FeedbackLimitError: LocalizedError {
    /// Internal: a multi-message package reached the single-message builder.
    case needsSplit
    case missingHTML(String)
    case textTooLong
    case missingImage(String)
    case renderingFailed

    public var errorDescription: String? {
        switch self {
        case .needsSplit: String(localized: "Couldn't split the feedback into messages.", bundle: .module)
        case .missingHTML: String(localized: "HTML missing.", bundle: .module)
        case .textTooLong: String(localized: "A comment is too long to send. Shorten it and try again.", bundle: .module)
        case .missingImage: String(localized: "Image missing", bundle: .module)
        case .renderingFailed: String(localized: "Couldn't render image.", bundle: .module)
        }
    }
}
