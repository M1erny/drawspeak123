import DrawspeakCore
import Foundation
import Testing

@MainActor
@Suite("FeedbackScope (AC-07, AC-08)")
struct FeedbackScopeTests {
    @Test func readyContainsExactlyTheTextNotesAndMarkOnlyIsPending() throws {
        let ws = makeWorkspace()
        try addImage(ws, id: "s1")
        try addImage(ws, id: "s2")
        try addImage(ws, id: "s3")
        let n1 = addTextNote(ws, snapshotId: "s1", text: "Make the button bigger")
        let n2 = addTextNote(ws, snapshotId: "s2", text: "Wrong color")
        let n3 = addTextNote(ws, snapshotId: "s3", text: "", shape: arrowShape)

        let scope = try #require(ws.feedbackScope())
        #expect(Set(scope.ready.map(\.id)) == [n1, n2])
        #expect(scope.ready.count == 2)
        #expect(scope.pending.map(\.id) == [n3])
        #expect(scope.unavailable.isEmpty)
        #expect(scope.sent.isEmpty)
        #expect(scope.count == 2)
    }

    @Test func noteWithEmptyTextIsPending() throws {
        let ws = makeWorkspace()
        try addImage(ws, id: "s1")
        let empty = addTextNote(ws, snapshotId: "s1", text: "")
        let whitespace = addTextNote(ws, snapshotId: "s1", text: "   \n ")

        let scope = try #require(ws.feedbackScope())
        #expect(scope.ready.isEmpty)
        #expect(Set(scope.pending.map(\.id)) == [empty, whitespace])
    }

    @Test func noteWithDeletedSnapshotBlobIsUnavailableWithReason() throws {
        let ws = makeWorkspace()
        let snapshot = try addImage(ws, id: "s1")
        let ok = try { _ = try addImage(ws, id: "s2"); return addTextNote(ws, snapshotId: "s2", text: "fine") }()
        let broken = addTextNote(ws, snapshotId: "s1", text: "has text")
        let blob = try #require(snapshot.sourceBlob)
        try FileManager.default.removeItem(at: ws.blobs.url(for: blob))

        let scope = try #require(ws.feedbackScope())
        #expect(scope.ready.map(\.id) == [ok])
        #expect(scope.unavailable.count == 1)
        #expect(scope.unavailable.first?.note.id == broken)
        #expect(scope.unavailable.first?.reason.isEmpty == false)
        // Unavailable notes still count toward the Feedback (N) badge.
        #expect(scope.count == 2)
    }

    @Test func sentNoteIsSentThenReadyAgainAfterEdit() async throws {
        let ws = makeWorkspace()
        ws.threads = FakeThreadService()
        try addImage(ws, id: "s1")
        let id = addTextNote(ws, snapshotId: "s1", text: "first")

        let result = await sendNotes(ws, noteIds: [id])
        #expect(result.entry?.state == .sent)
        var scope = try #require(ws.feedbackScope())
        #expect(scope.sent.map(\.id) == [id])
        #expect(scope.ready.isEmpty)
        let note = try #require(ws.note(id))
        #expect(note.lastSentRevision == note.revision)

        ws.updateNoteText(id, text: "first, but edited")
        scope = try #require(ws.feedbackScope())
        #expect(scope.ready.map(\.id) == [id])
        #expect(scope.sent.isEmpty)
    }
}
