import Foundation

public enum FeedbackLimitError: LocalizedError {
    case tooManySnapshots(max: Int)
    case tooManyAttachments(count: Int, snapshotsToRemove: Int)
    case missingHTML(String)
    case textTooLong
    case missingImage(String)
    case renderingFailed

    public var errorDescription: String? {
        switch self {
        case .tooManySnapshots(let max): "Select comments on at most \(max) snapshots. Deselect comments to send the rest."
        case .tooManyAttachments(let count, let snapshotsToRemove):
            "This package needs \(count) attachments; the limit is 8 per message. Deselect all comments on at least \(snapshotsToRemove) snapshots (HTML snapshots use 2 attachments each)."
        case .missingHTML(let id): "Exact HTML source is missing for snapshot \(id). Restore the source or deselect its comments."
        case .textTooLong: "The message exceeds 120,000 characters. Deselect comments to shorten it."
        case .missingImage(let id): "Capture image is missing or unreadable for snapshot \(id)."
        case .renderingFailed: "The annotated image could not be rendered within the 10 MiB limit."
        }
    }
}
