import DrawspeakCore
import Foundation
import Testing

@MainActor
@Suite("Workspace notes")
struct WorkspaceNotesTests {
    @Test func ordinalsIncreaseAndAreNeverReused() throws {
        let ws = makeWorkspace()
        try addImage(ws, id: "s1")
        let n1 = addTextNote(ws, snapshotId: "s1", text: "one")
        let n2 = addTextNote(ws, snapshotId: "s1", text: "two")
        let n3 = addTextNote(ws, snapshotId: "s1", text: "three")
        #expect([n1, n2, n3].compactMap { ws.note($0)?.ordinal } == [1, 2, 3])

        ws.deleteNote(n2)
        let n4 = addTextNote(ws, snapshotId: "s1", text: "four")
        #expect(ws.note(n4)?.ordinal == 4)
        #expect(ws.currentCanvas?.notes.map(\.ordinal) == [1, 3, 4])
    }

    @Test func undoAfterDeleteRestoresSameIdOrdinalAndText() throws {
        let ws = makeWorkspace()
        try addImage(ws, id: "s1")
        let id = addTextNote(ws, snapshotId: "s1", text: "keep me")
        let original = try #require(ws.note(id))
        let undo = UndoManager()
        undo.groupsByEvent = false
        ws.undoManager = undo

        undo.beginUndoGrouping()
        ws.deleteNote(id)
        undo.endUndoGrouping()
        #expect(ws.note(id) == nil)

        #expect(undo.canUndo)
        undo.undo()
        let restored = try #require(ws.note(id))
        #expect(restored.id == original.id)
        #expect(restored.ordinal == original.ordinal)
        #expect(restored.text == "keep me")
        #expect(restored == original)
    }

    @Test func textEditsBumpRevisionAndSetTypedSource() throws {
        let ws = makeWorkspace()
        try addImage(ws, id: "s1")
        let id = addTextNote(ws, snapshotId: "s1", text: "")
        let r0 = try #require(ws.note(id)).revision
        ws.updateNoteText(id, text: "hello")
        let note = try #require(ws.note(id))
        #expect(note.revision == r0 + 1)
        #expect(note.textSource == .typed)
        ws.updateNoteText(id, text: "hello")
        #expect(ws.note(id)?.revision == r0 + 1)
        // Clearing is an edit too: it stays typed so a late transcript cannot refill it.
        ws.updateNoteText(id, text: "")
        #expect(ws.note(id)?.textSource == .typed)
        #expect(ws.note(id)?.revision == r0 + 2)
    }
}
