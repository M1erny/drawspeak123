import Foundation

/// One explicit revision of Now for a screen. The latest revision is Now.
public struct BaselineRevision: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var screenId: String
    public var snapshotId: String
    /// Set when a proposal iteration was promoted.
    public var promotedFromSnapshotId: String?
    public var createdAt: Date

    public init(id: UUID = UUID(), screenId: String, snapshotId: String, promotedFromSnapshotId: String?, createdAt: Date) {
        self.id = id
        self.screenId = screenId
        self.snapshotId = snapshotId
        self.promotedFromSnapshotId = promotedFromSnapshotId
        self.createdAt = createdAt
    }
}
