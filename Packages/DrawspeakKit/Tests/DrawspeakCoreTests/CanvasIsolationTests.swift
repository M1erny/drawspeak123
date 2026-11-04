import DrawspeakCore
import Foundation
import Testing

@MainActor
@Suite("Canvas isolation (AC-01)")
struct CanvasIsolationTests {
    @Test func notesOnOneCanvasNeverAppearInAnotherCanvasScope() throws {
        let ws = makeWorkspace()
        let a = ws.createCanvas(title: "A", thread: testThread)
        try addImage(ws, id: "a-shot", canvasId: a.id)
        let noteA1 = addTextNote(ws, snapshotId: "a-shot", text: "A one")
        let noteA2 = addTextNote(ws, snapshotId: "a-shot", text: "A two")

        let b = ws.createCanvas(title: "B", thread: testThread)
        #expect(ws.currentCanvasId == b.id)
        try addImage(ws, id: "b-shot", canvasId: b.id)
        let noteB = addTextNote(ws, snapshotId: "b-shot", text: "B one")

        let scopeA = try #require(ws.feedbackScope(canvasId: a.id))
        let scopeB = try #require(ws.feedbackScope(canvasId: b.id))
        #expect(Set(scopeA.ready.map(\.id)) == [noteA1, noteA2])
        #expect(scopeB.ready.map(\.id) == [noteB])
        #expect(!scopeB.ready.contains { $0.id == noteA1 || $0.id == noteA2 })
        #expect(!scopeA.ready.contains { $0.id == noteB })
        #expect(ws.note(noteA1, canvasId: b.id) == nil)
    }

    @Test func addNoteRejectsSnapshotFromAnotherCanvas() throws {
        let ws = makeWorkspace()
        let a = ws.createCanvas(title: "A", thread: testThread)
        try addImage(ws, id: "a-shot", canvasId: a.id)
        _ = ws.createCanvas(title: "B", thread: testThread)
        #expect(ws.addNote(snapshotId: "a-shot", shape: regionShape, autoVoice: false) == nil)
    }

    @Test func selectCanvasKeepsEachCanvasCamera() throws {
        let ws = makeWorkspace()
        let a = ws.createCanvas(title: "A", thread: testThread)
        let b = ws.createCanvas(title: "B", thread: testThread)
        let camA = CameraState(offsetX: 10, offsetY: 20, zoom: 1.5)
        let camB = CameraState(offsetX: -300, offsetY: 55, zoom: 0.25)
        ws.updateCamera(camA, canvasId: a.id)
        ws.updateCamera(camB, canvasId: b.id)

        ws.selectCanvas(a.id)
        #expect(ws.currentCanvasId == a.id)
        #expect(ws.currentCanvas?.camera == camA)
        ws.selectCanvas(b.id)
        #expect(ws.currentCanvas?.camera == camB)
        ws.selectCanvas(a.id)
        #expect(ws.currentCanvas?.camera == camA)
        #expect(ws.canvas(b.id)?.camera == camB)
    }
}
