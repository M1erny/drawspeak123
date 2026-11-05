import DrawspeakCore
import Foundation
import Testing

@MainActor
@Suite("Draft resume (F05, UX F06)")
struct DraftResumeTests {
    @Test func unchangedNoteIsReusedAndRecipientChangeIsReported() throws {
        let ws = makeWorkspace()
        try addImage(ws, id: "s1")
        let id = addTextNote(ws, snapshotId: "s1", text: "same text")
        let canvasId = try #require(ws.currentCanvasId)
        let draft = try #require(ws.saveDraft(noteIds: [id], canvasId: canvasId))

        var other = testThread
        other.threadId = "thread-2"
        #expect(ws.bindThread(other, to: canvasId))
        let resumed = ws.resumeDraft(draft.id, canvasId: canvasId)

        #expect(resumed.noteIds == [id])
        #expect(resumed.copiedCount == 0)
        #expect(resumed.recipientChanged)
        #expect(ws.currentCanvas?.notes.count == 1)
    }

    @Test func editedThenRevertedTextIsStillCopiedBecauseTheRevisionMoved() throws {
        let ws = makeWorkspace()
        try addImage(ws, id: "s1")
        let id = addTextNote(ws, snapshotId: "s1", text: "draft")
        let canvasId = try #require(ws.currentCanvasId)
        let draft = try #require(ws.saveDraft(noteIds: [id], canvasId: canvasId))
        ws.updateNoteText(id, text: "other")
        ws.updateNoteText(id, text: "draft")

        let resumed = ws.resumeDraft(draft.id, canvasId: canvasId)

        #expect(resumed.copiedCount == 1)
        #expect(!resumed.noteIds.contains(id))
    }

    @Test func draftKeepsTheAgentDirectiveAndResumeHandsItOverOnce() throws {
        let ws = makeWorkspace()
        try addImage(ws, id: "s1")
        let id = addTextNote(ws, snapshotId: "s1", text: "draft")
        let canvasId = try #require(ws.currentCanvasId)
        let directive = AgentDirective(mode: .replyOnly, variantCount: 3, note: "only answer")
        let draft = try #require(ws.saveDraft(noteIds: [id], canvasId: canvasId, directive: directive))
        #expect(draft.directive == directive)
        let back = try JSONDecoder().decode(SavedDraft.self, from: JSONEncoder().encode(draft))
        #expect(back.directive == directive)

        _ = ws.resumeDraft(draft.id, canvasId: canvasId)
        #expect(ws.resumedDirective == directive)
    }
}
