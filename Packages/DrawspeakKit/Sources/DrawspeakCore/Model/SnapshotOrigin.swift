import Foundation

public enum SnapshotOrigin: Codable, Hashable, Sendable {
    case manualImport(fileName: String)
    case t3Pull(messageId: String?, manifestReviewId: String?)
    case sample
}
