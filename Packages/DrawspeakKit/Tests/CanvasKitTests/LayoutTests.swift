@testable import CanvasKit
import CoreGraphics
import DrawspeakCore
import Foundation
import Testing

@MainActor
@Suite("CanvasWorldLayout and PlacedMark")
struct LayoutTests {
    @Test func portraitScreenshotCardMatchesIntrinsicAspect() throws {
        let ws = makeWorkspace()
        let snapshot = try ws.importArtifact(data: Data("portrait".utf8), kind: .image,
            contentType: "image/png", fileName: "portrait.png", pixelSize: (width: 1653, height: 2400),
            target: .newScreen(title: "iPad"), snapshotId: "portrait")
        let canvas = try #require(ws.currentCanvas)
        let layout = CanvasWorldLayout(canvas: canvas)
        let frame = try #require(layout.frame(forSnapshot: snapshot.id))
        #expect(frame.width == 420)
        #expect(abs(frame.height - 420 * 2400 / 1653) < 1e-9)
        #expect(abs(frame.width / frame.height - 1653.0 / 2400) < 1e-9)
        let bottomRight = SnapshotSpace.world(NPoint(x: 1, y: 1), in: frame)
        #expect(bottomRight == CGPoint(x: frame.maxX, y: frame.maxY))
        #expect(layout.contentBounds == frame)
    }

    @Test func slotsAreLaidOutLeftToRight() throws {
        let ws = makeWorkspace()
        let now = try addScreen(ws, id: "now", title: "Checkout")
        try addProposal(ws, screenId: now.screenId, proposal: "A", id: "a")
        try addProposal(ws, screenId: now.screenId, proposal: "B", id: "b")
        let canvas = ws.currentCanvas!
        let origin = canvas.screens[0].origin
        let layout = CanvasWorldLayout(canvas: canvas)
        let slots = layout.slots
        #expect(slots.count == 3)
        let originX = CGFloat(origin.x), originY = CGFloat(origin.y)
        for (index, expectedX) in [CGFloat(0), 484, 968].enumerated() {
            #expect(slots[index].frame.minX == originX + expectedX)
            #expect(slots[index].frame.minY == originY + 56)
            #expect(slots[index].frame.width == CGFloat(420))
            #expect(slots[index].frame.height == CGFloat(840))
        }
        for slot in slots {
            let inside = CGPoint(x: slot.frame.midX, y: slot.frame.midY)
            #expect(layout.slot(at: inside)?.id == slot.id)
        }
        let gap = CGPoint(x: slots[0].frame.maxX + 32, y: slots[0].frame.midY)
        #expect(layout.slot(at: gap) == nil)
    }

    @Test func dragMovesOnlyThatScreen() throws {
        let fixture = try TwoScreenFixture()
        let canvas = fixture.canvas
        let base = CanvasWorldLayout(canvas: canvas)
        let dragged = CanvasWorldLayout(canvas: canvas, drag: ScreenDrag(screenId: fixture.s1, dx: 10, dy: 20))
        #expect(base.slots.count == dragged.slots.count)
        var movedCount = 0
        for (before, after) in zip(base.slots, dragged.slots) {
            if before.screen.id == fixture.s1 {
                #expect(after.frame == before.frame.offsetBy(dx: 10, dy: 20))
                movedCount += 1
            } else {
                #expect(after.frame == before.frame)
            }
        }
        #expect(movedCount == 3)
    }

    @Test func marksFollowSelectedVersion() throws {
        let ws = makeWorkspace()
        let now = try addScreen(ws, id: "now", title: "Checkout")
        let a1 = try addProposal(ws, screenId: now.screenId, proposal: "A", id: "a1")
        let a2 = try addProposal(ws, screenId: now.screenId, proposal: "A", id: "a2")
        let noteOnA2 = try #require(ws.addNote(snapshotId: a2.id, shape: regionShape, autoVoice: false))
        let noteOnA1 = try #require(ws.addNote(snapshotId: a1.id, shape: regionShape, autoVoice: false))

        func placedNoteIds() -> Set<UUID> {
            let canvas = ws.currentCanvas!
            return Set(PlacedMark.marks(in: CanvasWorldLayout(canvas: canvas), notes: canvas.notes).map(\.noteId))
        }
        #expect(placedNoteIds() == [noteOnA2])

        ws.selectVersion(a1.id, lane: LaneKey(screenId: now.screenId, proposalId: "A"))
        #expect(placedNoteIds() == [noteOnA1])
    }

    @Test func regionAnchorIsTopLeftOfBounds() throws {
        let ws = makeWorkspace()
        let now = try addScreen(ws, id: "now", title: "Checkout")
        let a = try addProposal(ws, screenId: now.screenId, proposal: "A", id: "a")
        _ = try #require(ws.addNote(snapshotId: a.id, shape: .region(NRect(x: 0.5, y: 0.25, width: 0.2, height: 0.1)), autoVoice: false))
        let canvas = ws.currentCanvas!
        let mark = try #require(PlacedMark.marks(in: CanvasWorldLayout(canvas: canvas), notes: canvas.notes).first)
        #expect(approx(mark.anchor, CGPoint(x: mark.frame.minX + 210, y: mark.frame.minY + 210)))
    }

    @Test func arrowAndStrokePinsAnchorToTheirStart() {
        let frame = CGRect(x: 40, y: 80, width: 400, height: 800)
        let start = NPoint(x: 0.8, y: 0.7)
        let end = NPoint(x: 0.1, y: 0.2)
        for shape in [AnnotationShape.arrow(from: start, to: end), .stroke([start, end])] {
            let mark = PlacedMark(slotId: "slot", noteId: UUID(), ordinal: 1,
                                  shape: shape, frame: frame, pinLabel: "1")
            #expect(approx(mark.anchor, SnapshotSpace.world(start, in: frame)))
            #expect(!approx(mark.anchor, SnapshotSpace.world(end, in: frame)))
        }
    }

    @Test func frameForNonSelectedVersionUsesItsLane() throws {
        let ws = makeWorkspace()
        let now = try addScreen(ws, id: "now", title: "Checkout")
        let a1 = try addProposal(ws, screenId: now.screenId, proposal: "A", id: "a1")
        _ = try addProposal(ws, screenId: now.screenId, proposal: "A", id: "a2")
        let canvas = ws.currentCanvas!
        let layout = CanvasWorldLayout(canvas: canvas)
        let frame = try #require(layout.frame(forSnapshot: a1.id))
        #expect(frame.minX == CGFloat(canvas.screens[0].origin.x) + 484)
        #expect(layout.frame(forSnapshot: "missing") == nil)
    }

    @Test func contentBoundsUnionsAllCards() throws {
        let fixture = try TwoScreenFixture()
        let layout = CanvasWorldLayout(canvas: fixture.canvas)
        let bounds = try #require(layout.contentBounds)
        for slot in layout.slots { #expect(bounds.contains(slot.frame)) }
        #expect(CanvasWorldLayout(canvas: makeWorkspace().currentCanvas!).contentBounds == nil)
    }

    // MARK: Row stacking

    /// Bottom of a row's cards and top of the next row's cards never meet.
    private func expectRowsDoNotOverlap(_ layout: CanvasWorldLayout) {
        for (index, row) in layout.rows.enumerated() {
            for other in layout.rows[(index + 1)...] {
                for a in row.slots { for b in other.slots { #expect(!a.frame.intersects(b.frame)) } }
            }
        }
    }

    @Test func tallSnapshotPushesTheNextScreenBelowIt() throws {
        let ws = makeWorkspace()
        let first = try addScreen(ws, id: "s1-now", title: "Setup")
        let second = try addScreen(ws, id: "s2-now", title: "Vault")
        // The board's height is known only after the second row was placed.
        _ = try ws.importArtifact(
            data: Data("<html><body>tall</body></html>".utf8), kind: .html, contentType: "text/html",
            fileName: "tall.html", pixelSize: (width: 2683, height: 14907),
            viewport: Viewport(width: 1440, height: 844, deviceScaleFactor: 2),
            target: .proposal(screenId: first.screenId, proposalId: "A"), snapshotId: "tall"
        )
        let canvas = try #require(ws.currentCanvas)
        let layout = CanvasWorldLayout(canvas: canvas)
        let tall = try #require(layout.frame(forSnapshot: "tall"))
        #expect(abs(tall.height - 420 * 14907 / 2683) < 1e-9)
        let next = try #require(layout.rows.first { $0.id == second.screenId })
        let nextTop = try #require(next.slots.map(\.frame.minY).min())
        #expect(nextTop >= tall.maxY + CGFloat(CanvasLayout.rowSpacing + CanvasLayout.headerHeight) - 1e-9)
        #expect(next.baseOrigin.y > canvas.screens[1].origin.y)
        expectRowsDoNotOverlap(layout)
        let bounds = try #require(layout.contentBounds)
        #expect(bounds.contains(tall) && bounds.maxY >= nextTop)
        // A new screen lands below the stacked rows, not below the stored origins.
        #expect(CanvasLayout.nextScreenOrigin(in: canvas).y >= Double(next.slots.map(\.frame.maxY).max() ?? 0))
    }

    @Test func rowMovedAboveAnotherTakesItsPlace() throws {
        var canvas = try TwoScreenFixture().canvas
        canvas.screens[1].origin = WorldPoint(x: 0, y: -2_000)
        let layout = CanvasWorldLayout(canvas: canvas)
        #expect(layout.rows[1].baseOrigin == WorldPoint(x: 0, y: -2_000))
        let movedBottom = try #require(layout.rows[1].slots.map(\.frame.maxY).max())
        let firstTop = try #require(layout.rows[0].slots.map(\.frame.minY).min())
        #expect(firstTop >= movedBottom + CGFloat(CanvasLayout.rowSpacing + CanvasLayout.headerHeight) - 1e-9)
        expectRowsDoNotOverlap(layout)
    }

    @Test func rowMovedBesideAnotherKeepsItsHeight() throws {
        var canvas = try TwoScreenFixture().canvas
        canvas.screens[1].origin = WorldPoint(x: 5_000, y: 0)
        let layout = CanvasWorldLayout(canvas: canvas)
        #expect(layout.rows[1].baseOrigin == WorldPoint(x: 5_000, y: 0))
    }

    // MARK: Now lane

    @Test func proposalOnlyScreenStartsWithItsFirstProposal() throws {
        let fixture = try TwoScreenFixture()
        var canvas = fixture.canvas
        canvas.baselineRevisions.removeAll { $0.screenId == fixture.s1 }
        canvas.snapshots.removeAll { $0.id == "s1-now" }
        let layout = CanvasWorldLayout(canvas: canvas)
        let row = try #require(layout.rows.first { $0.id == fixture.s1 })
        #expect(row.slots.map(\.lane.key.proposalId) == ["A", "B"])
        #expect(row.slots[0].laneIndex == 0)
        #expect(row.slots[0].frame.minX == CGFloat(row.baseOrigin.x))
        #expect(layout.frame(forSnapshot: fixture.proposalA.id)?.minX == CGFloat(row.baseOrigin.x))

        // Promote to Now brings the Now lane back in front.
        canvas.baselineRevisions.append(BaselineRevision(screenId: fixture.s1, snapshotId: fixture.proposalA.id, promotedFromSnapshotId: fixture.proposalA.id, createdAt: fixedDate))
        let promoted = try #require(CanvasWorldLayout(canvas: canvas).rows.first { $0.id == fixture.s1 })
        #expect(promoted.slots.map(\.lane.key.proposalId) == [nil, "A", "B"])
        #expect(promoted.slots[0].snapshot?.id == fixture.proposalA.id)
    }

    @Test func screenWithoutVersionsKeepsItsNowPlaceholder() throws {
        let fixture = try TwoScreenFixture()
        var canvas = fixture.canvas
        canvas.baselineRevisions.removeAll { $0.screenId == fixture.s2 }
        canvas.snapshots.removeAll { $0.screenId == fixture.s2 }
        let row = try #require(CanvasWorldLayout(canvas: canvas).rows.first { $0.id == fixture.s2 })
        #expect(row.slots.count == 1)
        #expect(row.slots[0].lane.key.isNow && row.slots[0].snapshot == nil)
    }

    // MARK: Screen chrome

    @Test func chromeThatWouldCoverTheRowAboveIsLeftOut() throws {
        let layout = CanvasWorldLayout(canvas: try TwoScreenFixture().canvas)
        let clearances = RowChrome.clearances(rows: layout.rows)
        #expect(clearances[layout.rows[0].id] == .infinity)
        let gap = try #require(clearances[layout.rows[1].id])
        #expect(abs(gap - CGFloat(CanvasLayout.rowSpacing + CanvasLayout.headerHeight)) < 1e-9)

        let line: CGFloat = 46
        let full = RowChrome(clearance: gap, zoom: 1, line: line)
        #expect(full.showsHeaders && full.showsTitle && full.titleLines == 2)
        let titleOnly = RowChrome(clearance: gap, zoom: 0.2, line: line)
        #expect(!titleOnly.showsHeaders && titleOnly.showsTitle && titleOnly.titleLines == 1)
        let none = RowChrome(clearance: gap, zoom: 0.1, line: line)
        #expect(!none.showsHeaders && !none.showsTitle)
        let top = RowChrome(clearance: .infinity, zoom: 0.01, line: line)
        #expect(top.showsHeaders && top.showsTitle)
    }
}
