import Foundation

/// One immutable captured version of a logical screen. Bytes under a snapshot
/// id are never replaced; a new source, state or viewport is a new snapshot.
public struct Snapshot: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var screenId: String
    public var role: SnapshotRole
    /// `nil` for baseline snapshots.
    public var proposalId: String?
    /// 0 for baseline, 1... for proposal iterations.
    public var iteration: Int
    public var parentSnapshotId: String?
    public var kind: ArtifactKind
    /// The capture image. HTML snapshots get one after their first render.
    public var image: BlobRef?
    public var html: BlobRef?
    public var renderPolicy: RenderPolicy?
    public var stateId: String?
    public var widthPx: Int
    public var heightPx: Int
    public var viewport: Viewport
    public var capturedAt: Date
    public var changeSummary: String?
    public var addressedNoteIds: [String]
    public var origin: SnapshotOrigin
    public var title: String

    public init(
        id: String,
        screenId: String,
        role: SnapshotRole,
        proposalId: String?,
        iteration: Int,
        parentSnapshotId: String?,
        kind: ArtifactKind,
        image: BlobRef?,
        html: BlobRef?,
        renderPolicy: RenderPolicy?,
        stateId: String?,
        widthPx: Int,
        heightPx: Int,
        viewport: Viewport,
        capturedAt: Date,
        changeSummary: String?,
        addressedNoteIds: [String],
        origin: SnapshotOrigin,
        title: String
    ) {
        self.id = id
        self.screenId = screenId
        self.role = role
        self.proposalId = proposalId
        self.iteration = iteration
        self.parentSnapshotId = parentSnapshotId
        self.kind = kind
        self.image = image
        self.html = html
        self.renderPolicy = renderPolicy
        self.stateId = stateId
        self.widthPx = widthPx
        self.heightPx = heightPx
        self.viewport = viewport
        self.capturedAt = capturedAt
        self.changeSummary = changeSummary
        self.addressedNoteIds = addressedNoteIds
        self.origin = origin
        self.title = title
    }

    /// Width divided by height of the captured content.
    public var aspectRatio: Double {
        guard widthPx > 0, heightPx > 0 else { return 1 }
        return Double(widthPx) / Double(heightPx)
    }

    /// The bytes that define this version: the HTML source for HTML, the image otherwise.
    public var sourceBlob: BlobRef? { kind == .html ? html : image }

    /// HTML imported without a capture image. It cannot be sent until a
    /// capture is attached (`Workspace.attachCapture`).
    public var needsCapture: Bool { kind == .html && image == nil }

    public var versionLabel: String {
        switch role {
        case .baseline: "Now"
        case .proposal: "Iteration \(iteration)"
        }
    }
}
