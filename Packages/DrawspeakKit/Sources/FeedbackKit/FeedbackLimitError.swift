import Foundation

public nonisolated enum FeedbackLimitError: LocalizedError {
    case tooManySnapshots(max: Int)
    case tooManyAttachments(count: Int, snapshotsToRemove: Int)
    case missingHTML(String)
    case textTooLong
    case missingImage(String)
    case renderingFailed

    public var errorDescription: String? {
        switch self {
        case .tooManySnapshots(let max): String(AttributedString(localized: "Select comments on up to ^[\(max) screen](inflect: true).", bundle: .module).characters)
        case .tooManyAttachments(let count, let remove):
            String(AttributedString(localized: "Too many attachments (\(count) of 8). Deselect comments on ^[\(remove) screen](inflect: true).", bundle: .module).characters)
        case .missingHTML: String(localized: "HTML missing.", bundle: .module)
        case .textTooLong: String(localized: "Message too long. Deselect some comments.", bundle: .module)
        case .missingImage: String(localized: "Image missing", bundle: .module)
        case .renderingFailed: String(localized: "Couldn't render image.", bundle: .module)
        }
    }
}
