@testable import CanvasKit
import CoreGraphics
import DrawspeakCore
import Testing

@MainActor
@Suite("Prototype annotation isolation")
struct CanvasInteractionTests {
    @Test func commitFeedbackTracksArrowAndPenButIgnoresCancellation() throws {
        for tool in [CanvasTool.arrow, .pen] {
            let ws = makeWorkspace()
            let snapshot = try addScreen(ws, id: "screen", title: "Review")
            let layout = CanvasWorldLayout(canvas: try #require(ws.currentCanvas))
            let frame = try #require(layout.frame(forSnapshot: snapshot.id))
            let input = CanvasInteraction()
            input.workspace = ws
            input.tool = tool
            let start = CGPoint(x: frame.midX, y: frame.midY)
            let end = CGPoint(x: start.x + 80, y: start.y + 80)
            #expect(input.markBegan(at: start, kind: .pencil, force: nil, time: 0))
            input.markCancelled()
            #expect(input.commitFeedback.noteId == nil)
            #expect(input.markBegan(at: start, kind: .pencil, force: nil, time: 1))
            input.markMoved(to: end, force: nil, time: 2)
            input.markEnded(at: end)
            let note = try #require(ws.currentCanvas?.notes.first)
            #expect(input.commitFeedback.noteId == note.id)
        }
    }

    @Test func tryingOneCardBlocksItsMarksAndLeavesOtherCardsAvailable() throws {
        let fixture = try TwoScreenFixture()
        let html = try addHTMLProposal(fixture.ws, screenId: fixture.s1, proposal: "A", id: "prototype")
        let layout = CanvasWorldLayout(canvas: fixture.canvas)
        let prototype = try #require(layout.slots.first { $0.snapshot?.id == html.id })
        let other = try #require(layout.slots.first { $0.snapshot?.id == fixture.proposalB.id })
        let input = CanvasInteraction()
        input.workspace = fixture.ws
        input.tool = .region
        input.loadCamera(CameraState(offsetX: 31, offsetY: -17, zoom: 0.75))
        input.interactingSnapshotId = html.id
        let point = CanvasFraming.worldToScreen(CGPoint(x: prototype.frame.midX, y: prototype.frame.midY), camera: input.camera.state)
        let otherPoint = CanvasFraming.worldToScreen(CGPoint(x: other.frame.midX, y: other.frame.midY), camera: input.camera.state)
        #expect(input.isInteracting(at: point))
        #expect(!input.markBegan(at: point, kind: .pencil, force: nil, time: 0))
        #expect(!input.isInteracting(at: otherPoint))
        #expect(input.markBegan(at: otherPoint, kind: .pencil, force: nil, time: 0))
        input.cancelMarking()
        input.interactingSnapshotId = nil
        #expect(!input.isInteracting(at: point))
        #expect(input.markBegan(at: point, kind: .pencil, force: nil, time: 0))
        input.cancelMarking()
    }
}
