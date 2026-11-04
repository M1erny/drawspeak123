import Foundation

/// Continuous comment numbers for the person. `Note.ordinal` stays the stable
/// internal id; the shown number is the 1-based position among visible notes.
public enum NoteNumbering {
    /// A note is visible unless its current revision was sent and sent notes are hidden.
    public static func isVisible(_ note: Note, showsSentNotes: Bool) -> Bool {
        showsSentNotes || !note.isSentAtCurrentRevision
    }

    /// Visible notes of the canvas, ordered by `ordinal`. Notes in `including` are
    /// treated as visible (for example the ones chosen for sending).
    public static func visibleNotes(in canvas: ReviewCanvas, showsSentNotes: Bool, including: Set<UUID> = []) -> [Note] {
        canvas.notes
            .filter { isVisible($0, showsSentNotes: showsSentNotes) || including.contains($0.id) }
            .sorted { $0.ordinal < $1.ordinal }
    }

    /// Note id → shown number (1-based) for every visible note.
    public static func displayNumbers(in canvas: ReviewCanvas, showsSentNotes: Bool, including: Set<UUID> = []) -> [UUID: Int] {
        let visible = visibleNotes(in: canvas, showsSentNotes: showsSentNotes, including: including)
        return Dictionary(uniqueKeysWithValues: visible.enumerated().map { ($1.id, $0 + 1) })
    }
}
