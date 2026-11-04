import DrawspeakCore
import Foundation
import Testing

@MainActor
@Suite("Drafts (AC-10)")
struct DraftTests {
    @Test func saveDraftNeverMarksSentOrQueues() throws {
        let ws = makeWorkspace()
        try addImage(ws, id: "s1")
        let a = addTextNote(ws, snapshotId: "s1", text: "a")
        let b = addTextNote(ws, snapshotId: "s1", text: "b")
        let canvasId = try #require(ws.currentCanvasId)

        let draft = try #require(ws.saveDraft(noteIds: [a, b], canvasId: canvasId))

        let canvas = try #require(ws.currentCanvas)
        #expect(canvas.notes.allSatisfy { $0.lastSentRevision == nil })
        #expect(canvas.outbox.isEmpty)
        #expect(canvas.drafts.map(\.id) == [draft.id])
        #expect(draft.items.map(\.noteId) == [a, b])
    }

    @Test func resumeAfterEditKeepsNewerTextAndSameNoteId() throws {
        let ws = makeWorkspace()
        try addImage(ws, id: "s1")
        let id = addTextNote(ws, snapshotId: "s1", text: "draft text")
        let canvasId = try #require(ws.currentCanvasId)
        let draft = try #require(ws.saveDraft(noteIds: [id], canvasId: canvasId))

        ws.updateNoteText(id, text: "newer text")
        let resumed = ws.resumeDraft(draft.id, canvasId: canvasId)

        #expect(resumed == [id])
        #expect(ws.note(id)?.text == "newer text")
        #expect(ws.currentCanvas?.notes.count == 1)
    }

    @Test func resumeAfterDeleteCreatesCopyWithNewOrdinalAndDraftText() throws {
        let ws = makeWorkspace()
        try addImage(ws, id: "s1")
        let id = addTextNote(ws, snapshotId: "s1", text: "draft text")
        let canvasId = try #require(ws.currentCanvasId)
        let draft = try #require(ws.saveDraft(noteIds: [id], canvasId: canvasId))
        let originalOrdinal = try #require(ws.note(id)).ordinal

        ws.deleteNote(id)
        let resumed = ws.resumeDraft(draft.id, canvasId: canvasId)

        let copyId = try #require(resumed.first)
        #expect(resumed.count == 1)
        #expect(copyId != id)
        let copy = try #require(ws.note(copyId))
        #expect(copy.text == "draft text")
        #expect(copy.ordinal != originalOrdinal)
        #expect(copy.ordinal == originalOrdinal + 1)
        #expect(copy.snapshotId == "s1")
    }
}
