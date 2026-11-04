import Foundation

/// One frozen note revision inside a batch or draft.
public struct BatchItem: Codable, Hashable, Sendable {
    public var noteId: UUID
    public var ordinal: Int
    public var revision: Int
    public var snapshotId: String
    public var text: String
    public var shape: AnnotationShape
    public var domTarget: DOMTarget?

    public init(noteId: UUID, ordinal: Int, revision: Int, snapshotId: String, text: String, shape: AnnotationShape, domTarget: DOMTarget?) {
        self.noteId = noteId
        self.ordinal = ordinal
        self.revision = revision
        self.snapshotId = snapshotId
        self.text = text
        self.shape = shape
        self.domTarget = domTarget
    }

    public init(note: Note) {
        self.init(
            noteId: note.id,
            ordinal: note.ordinal,
            revision: note.revision,
            snapshotId: note.snapshotId,
            text: note.trimmedText,
            shape: note.shape,
            domTarget: note.domTarget
        )
    }
}
