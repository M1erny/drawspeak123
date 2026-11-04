@testable import CanvasKit
import DrawspeakCore
import Foundation
import Testing

@MainActor
@Suite("Canvas presentation invalidation")
struct CanvasPresentationTests {
    @Test func presentationUsesVisibleNotesAndContinuousPinNumbers() throws {
        let source = makeWorkspace()
        let snapshot = try addScreen(source, id: "portrait", title: "iPad")
        var document = source.document
        let notes = [1, 3, 9].map { ordinal in
            Note(ordinal: ordinal, snapshotId: snapshot.id, shape: regionShape,
                 lastSentRevision: ordinal == 1 ? 1 : nil, createdAt: fixedDate, updatedAt: fixedDate)
        }
        document.canvases[0].notes = notes
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let ws = Workspace(document: document, blobs: source.blobs, store: LibraryStore(fileURL: root.appending(path: "library.json")))
        ws.showsSentNotes = false
        let presentation = CanvasPresentation()
        presentation.update(canvas: ws.currentCanvas, drag: nil, visibleNotes: ws.visibleNotes())
        #expect(presentation.marks.map(\.noteId) == [notes[1].id, notes[2].id])
        #expect(presentation.commentCounts[snapshot.id] == 2)
        #expect(presentation.marks.map { ws.displayNumber(for: $0.noteId) } == [1, 2])
        ws.showsSentNotes = true
        presentation.update(canvas: ws.currentCanvas, drag: nil, visibleNotes: ws.visibleNotes())
        #expect(presentation.marks.count == 3)
        #expect(ws.displayNumber(for: notes[2].id) == 3)
        ws.showsSentNotes = false
    }

    @Test func dragPreservesCountsAndMovesMarks() throws {
        let ws = makeWorkspace()
        let snapshot = try addScreen(ws, id: "now", title: "Checkout")
        let noteID = try #require(ws.addNote(snapshotId: snapshot.id, shape: regionShape, autoVoice: false))
        let canvas = try #require(ws.currentCanvas)
        let presentation = CanvasPresentation()
        presentation.update(canvas: canvas, drag: nil)
        let before = try #require(presentation.marks.first)
        #expect(presentation.commentCounts[snapshot.id] == 1)
        presentation.move(canvas: canvas, drag: ScreenDrag(screenId: snapshot.screenId, dx: 20, dy: 30))
        let after = try #require(presentation.marks.first)
        #expect(after.noteId == noteID)
        #expect(after.frame == before.frame.offsetBy(dx: 20, dy: 30))
        #expect(presentation.commentCounts[snapshot.id] == 1)
        presentation.update(canvas: nil, drag: nil)
        #expect(presentation.layout == nil)
        #expect(presentation.marks.isEmpty)
        #expect(presentation.commentCounts.isEmpty)
    }

    @Test func changingVersionsAndNotesInvalidatesPresentation() throws {
        let ws = makeWorkspace()
        let now = try addScreen(ws, id: "now", title: "Checkout")
        let first = try addProposal(ws, screenId: now.screenId, proposal: "A", id: "a1")
        let second = try addProposal(ws, screenId: now.screenId, proposal: "A", id: "a2")
        let firstNote = try #require(ws.addNote(snapshotId: first.id, shape: regionShape, autoVoice: false))
        let secondNote = try #require(ws.addNote(snapshotId: second.id, shape: regionShape, autoVoice: false))
        let presentation = CanvasPresentation()
        presentation.update(canvas: ws.currentCanvas, drag: nil)
        #expect(presentation.marks.map(\.noteId) == [secondNote])
        ws.selectVersion(first.id, lane: LaneKey(screenId: now.screenId, proposalId: "A"))
        presentation.update(canvas: ws.currentCanvas, drag: nil)
        #expect(presentation.marks.map(\.noteId) == [firstNote])
        #expect(presentation.commentCounts[first.id] == 1)
        #expect(presentation.commentCounts[second.id] == 1)
    }
}
