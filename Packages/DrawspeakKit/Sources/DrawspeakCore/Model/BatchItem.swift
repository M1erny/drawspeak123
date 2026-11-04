import Foundation

/// One frozen note revision inside a batch or draft.
public struct BatchItem: Codable, Hashable, Sendable {
    public var noteId: UUID
    /// Stable internal number of the note.
    public var ordinal: Int
    /// The number shown to the person when the package was built (1-based among
    /// visible notes). Nil for items stored before this existed; use `number`.
    public var displayNumber: Int?
    public var revision: Int
    public var snapshotId: String
    public var text: String
    public var shape: AnnotationShape
    public var domTarget: DOMTarget?

    public init(
        noteId: UUID, ordinal: Int, displayNumber: Int? = nil, revision: Int, snapshotId: String, text: String,
        shape: AnnotationShape, domTarget: DOMTarget?
    ) {
        self.noteId = noteId
        self.ordinal = ordinal
        self.displayNumber = displayNumber
        self.revision = revision
        self.snapshotId = snapshotId
        self.text = text
        self.shape = shape
        self.domTarget = domTarget
    }

    /// The comment number in messages and manifests.
    public var number: Int { displayNumber ?? ordinal }

    public init(note: Note) {
        self.init(note: note, displayNumber: nil)
    }

    public init(note: Note, displayNumber: Int?) {
        self.init(
            noteId: note.id,
            ordinal: note.ordinal,
            displayNumber: displayNumber,
            revision: note.revision,
            snapshotId: note.snapshotId,
            text: note.trimmedText,
            shape: note.shape,
            domTarget: note.domTarget
        )
    }
}
