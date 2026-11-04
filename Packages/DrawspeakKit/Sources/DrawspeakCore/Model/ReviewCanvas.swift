import Foundation

/// A review canvas: one T3 thread, its own camera, versions, notes, drafts and outbox.
public struct ReviewCanvas: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var projectId: UUID
    public var title: String
    public var thread: ThreadBinding?
    public var camera: CameraState
    public var screens: [Screen]
    public var snapshots: [Snapshot]
    public var baselineRevisions: [BaselineRevision]
    /// Selected iteration snapshot id per proposal lane (`LaneKey.description`).
    public var laneSelections: [String: String]
    public var notes: [Note]
    public var nextOrdinal: Int
    public var drafts: [SavedDraft]
    public var outbox: [OutboxEntry]
    /// Message ids already imported by Pull, to keep pulls idempotent.
    public var pulledMessageIds: [String]
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        projectId: UUID,
        title: String,
        thread: ThreadBinding? = nil,
        camera: CameraState = CameraState(),
        screens: [Screen] = [],
        snapshots: [Snapshot] = [],
        baselineRevisions: [BaselineRevision] = [],
        laneSelections: [String: String] = [:],
        notes: [Note] = [],
        nextOrdinal: Int = 1,
        drafts: [SavedDraft] = [],
        outbox: [OutboxEntry] = [],
        pulledMessageIds: [String] = [],
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.projectId = projectId
        self.title = title
        self.thread = thread
        self.camera = camera
        self.screens = screens
        self.snapshots = snapshots
        self.baselineRevisions = baselineRevisions
        self.laneSelections = laneSelections
        self.notes = notes
        self.nextOrdinal = nextOrdinal
        self.drafts = drafts
        self.outbox = outbox
        self.pulledMessageIds = pulledMessageIds
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
