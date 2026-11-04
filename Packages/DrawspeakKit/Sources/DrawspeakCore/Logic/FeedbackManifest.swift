import Foundation

/// The JSON manifest attached to every feedback message (Drawspeak contract v1).
public struct FeedbackManifest: Codable, Hashable, Sendable {
    public struct Item: Codable, Hashable, Sendable {
        public var number: Int
        public var noteId: String
        public var revision: Int
        public var text: String
        public var shape: AnnotationShape
        public var domTarget: DOMTarget?
    }

    public struct SnapshotEntry: Codable, Hashable, Sendable {
        public var snapshotId: String
        public var screenId: String
        public var screenTitle: String
        public var role: SnapshotRole
        public var proposalId: String?
        public var iteration: Int
        public var parentSnapshotId: String?
        public var artifactKind: ArtifactKind
        public var sourceSha256: String?
        public var imageSha256: String?
        public var renderPolicy: RenderPolicy?
        public var viewport: Viewport
        public var widthPx: Int
        public var heightPx: Int
        public var compositeFileName: String
        public var notes: [Item]
    }

    public var schema: String
    public var batchId: String
    public var canvasTitle: String
    public var threadId: String
    public var createdAt: Date
    public var isRepeat: Bool
    public var coordinateSpace: String
    public var snapshots: [SnapshotEntry]

    public init(package: FeedbackPackage) {
        schema = "drawspeak.feedback.v1"
        batchId = package.batchId
        canvasTitle = package.canvasTitle
        threadId = package.thread.threadId
        createdAt = package.createdAt
        isRepeat = package.isRepeat
        coordinateSpace = "normalized snapshot space: (0,0) top-left, (1,1) bottom-right"
        snapshots = package.groups.map { group in
            SnapshotEntry(
                snapshotId: group.snapshot.id,
                screenId: group.snapshot.screenId,
                screenTitle: group.screenTitle,
                role: group.snapshot.role,
                proposalId: group.snapshot.proposalId,
                iteration: group.snapshot.iteration,
                parentSnapshotId: group.snapshot.parentSnapshotId,
                artifactKind: group.snapshot.kind,
                sourceSha256: group.snapshot.sourceBlob?.sha256,
                imageSha256: group.snapshot.image?.sha256,
                renderPolicy: group.snapshot.renderPolicy,
                viewport: group.snapshot.viewport,
                widthPx: group.snapshot.widthPx,
                heightPx: group.snapshot.heightPx,
                compositeFileName: group.compositeFileName,
                notes: group.items.map {
                    Item(number: $0.ordinal, noteId: $0.noteId.uuidString, revision: $0.revision, text: $0.text, shape: $0.shape, domTarget: $0.domTarget)
                }
            )
        }
    }

    public func jsonData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(self)
    }
}
