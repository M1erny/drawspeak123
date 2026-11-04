import Foundation

public enum FeedbackLimitError: LocalizedError {
    case tooManySnapshots(max: Int)
    case textTooLong
    case missingImage(String)
    case renderingFailed

    public var errorDescription: String? {
        switch self {
        case .tooManySnapshots(let max): "Select comments on at most \(max) snapshots. Deselect comments to send the rest."
        case .textTooLong: "The message exceeds 120,000 characters. Deselect comments to shorten it."
        case .missingImage(let id): "Capture image is missing or unreadable for snapshot \(id)."
        case .renderingFailed: "The annotated image could not be rendered within the 10 MiB limit."
        }
    }
}
