import Foundation

/// A comment anchored to one immutable snapshot.
public struct Note: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    /// Stable number on the canvas; never derived from an array index.
    public var ordinal: Int
    public var snapshotId: String
    public var shape: AnnotationShape
    public var domTarget: DOMTarget?
    public var text: String
    public var textSource: TextSource
    /// Increments on every text change; sending records the sent revision.
    public var revision: Int
    public var lastSentRevision: Int?
    public var recordings: [Recording]
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        ordinal: Int,
        snapshotId: String,
        shape: AnnotationShape,
        domTarget: DOMTarget? = nil,
        text: String = "",
        textSource: TextSource = .none,
        revision: Int = 1,
        lastSentRevision: Int? = nil,
        recordings: [Recording] = [],
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.ordinal = ordinal
        self.snapshotId = snapshotId
        self.shape = shape
        self.domTarget = domTarget
        self.text = text
        self.textSource = textSource
        self.revision = revision
        self.lastSentRevision = lastSentRevision
        self.recordings = recordings
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public var trimmedText: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }
    public var hasText: Bool { !trimmedText.isEmpty }
    public var isSentAtCurrentRevision: Bool { lastSentRevision == revision }
    public var activeRecording: Recording? { recordings.last(where: { $0.state.isInFlight }) }
    public var isRecording: Bool { recordings.contains { $0.state == .recording } }
    public var isTranscribing: Bool { recordings.contains { $0.state == .transcribing } }
}
