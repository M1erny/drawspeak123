@testable import CanvasKit
import CoreGraphics
import DrawspeakCore
import Foundation
import Testing

@MainActor
@Suite("Component selection, target and labels")
struct ComponentTests {
    let frame = CGRect(x: 0, y: 56, width: 420, height: 912)

    func element(_ label: String, bounds: NRect = NRect(x: 0.1, y: 0.1, width: 0.5, height: 0.2)) -> DOMElementInfo {
        DOMElementInfo(label: label, tagName: "div", locator: DOMLocator(strategy: .id, value: label), bounds: bounds)
    }

    func selection(_ layers: [[DOMElementInfo]], snapshotId: String = "snap") -> ComponentSelection {
        ComponentSelection(slotId: "slot", snapshotId: snapshotId, frame: frame, layers: layers, method: .touch)
    }

    // MARK: ComponentSelection

    @Test func selectionWalksParentsAndChildren() {
        let (a, b, c, d, e) = (element("a"), element("b"), element("c"), element("d"), element("e"))
        var sel = selection([[a, b, c], [d, e]])
        #expect(sel.element == a)
        #expect(sel.canSelectParent)
        #expect(!sel.canSelectChild)

        sel.selectParent()
        sel.selectParent()
        #expect(sel.element == c)
        #expect(!sel.canSelectParent)

        sel.selectParent()
        #expect(sel.element == c)
        #expect(sel.depth == 2)

        sel.selectChild()
        #expect(sel.element == b)

        sel.select(layer: 1)
        #expect(sel.depth == 0)
        #expect(sel.element == d)

        sel.select(depth: 99)
        #expect(sel.element == e)
        sel.select(depth: -5)
        #expect(sel.element == d)
    }

    @Test func emptyLayersAreDropped() {
        let a = element("a")
        let sel = selection([[], [a]])
        #expect(sel.chain == [a])
        #expect(sel.element == a)
        #expect(selection([]).isEmpty)
    }

    // MARK: ComponentTargetBuilder

    @Test func targetCarriesEverySelectionField() throws {
        let ws = makeWorkspace()
        let now = try addScreen(ws, id: "now", title: "Checkout")
        let html = try addHTMLProposal(ws, screenId: now.screenId, proposal: "A", id: "h1")
        let (a, b, c) = (element("a"), element("b"), element("c"))
        var sel = selection([[a, b, c]], snapshotId: html.id)
        sel.select(depth: 1)
        sel.method = .pencilPressure
        sel.pressure = 0.6

        let target = try #require(ComponentTargetBuilder.target(for: sel, snapshot: html, renderHash: "abc"))
        #expect(target.snapshotId == html.id)
        #expect(target.sourceHash == html.html!.sha256)
        #expect(target.renderHash == "abc")
        #expect(target.renderPolicy == .staticNoScript)
        #expect(target.viewport == html.viewport)
        #expect(target.locator == b.locator)
        #expect(target.label == b.label)
        #expect(target.tagName == b.tagName)
        #expect(target.ancestry == sel.chain)
        #expect(target.selectedDepth == 1)
        #expect(target.layer == 0)
        #expect(target.selectionMethod == .pencilPressure)
        #expect(target.pressure == 0.6)
        // clamped() recomputes width/height from edges, so allow rounding error.
        #expect(abs(target.bounds.x - b.bounds.x) < 1e-12)
        #expect(abs(target.bounds.y - b.bounds.y) < 1e-12)
        #expect(abs(target.bounds.width - b.bounds.width) < 1e-12)
        #expect(abs(target.bounds.height - b.bounds.height) < 1e-12)
    }

    @Test func targetIsNilForImageSnapshot() throws {
        let ws = makeWorkspace()
        let image = try addScreen(ws, id: "now", title: "Checkout")
        let sel = selection([[element("a")]], snapshotId: image.id)
        #expect(ComponentTargetBuilder.target(for: sel, snapshot: image, renderHash: "abc") == nil)
    }

    @Test func targetIsNilForZeroWidthElement() throws {
        let ws = makeWorkspace()
        let now = try addScreen(ws, id: "now", title: "Checkout")
        let html = try addHTMLProposal(ws, screenId: now.screenId, proposal: "A", id: "h1")
        let flat = element("flat", bounds: NRect(x: 0.1, y: 0.1, width: 0, height: 0.2))
        let sel = selection([[flat]], snapshotId: html.id)
        #expect(ComponentTargetBuilder.target(for: sel, snapshot: html, renderHash: "abc") == nil)
    }

    @Test func targetIsNilForOtherSnapshotOrEmptySelection() throws {
        let ws = makeWorkspace()
        let now = try addScreen(ws, id: "now", title: "Checkout")
        let html = try addHTMLProposal(ws, screenId: now.screenId, proposal: "A", id: "h1")
        #expect(ComponentTargetBuilder.target(for: selection([[element("a")]], snapshotId: "other"), snapshot: html, renderHash: "x") == nil)
        #expect(ComponentTargetBuilder.target(for: selection([], snapshotId: html.id), snapshot: html, renderHash: "x") == nil)
    }

    // MARK: CanvasLabels

    @Test func componentChipText() {
        #expect(CanvasLabels.componentChip(label: "Pay Button", depth: 1, chainCount: 5) == "Pay Button · parent 1 of 4")
        #expect(CanvasLabels.componentChip(label: "Pay Button", depth: 0, chainCount: 5) == "Pay Button · element, 4 parents")
        #expect(CanvasLabels.componentChip(label: "Pay Button", depth: 0, chainCount: 2) == "Pay Button · element, 1 parent")
        #expect(CanvasLabels.componentChip(label: "Pay Button", depth: 0, chainCount: 1) == "Pay Button")
    }

    @Test func pinLabels() {
        let region = AnnotationShape.region(NRect(x: 0.1, y: 0.1, width: 0.2, height: 0.2))
        #expect(CanvasLabels.pin(ordinal: 3, text: "", shape: region) == "Comment 3: Region, no text yet")
        #expect(CanvasLabels.pin(ordinal: 3, text: "   \n ", shape: region) == "Comment 3: Region, no text yet")
        #expect(CanvasLabels.pin(ordinal: 3, text: "The pay button looks disabled", shape: region) == "Comment 3: The pay button looks disabled")
        let long = "one two three four five six seven eight nine ten"
        #expect(CanvasLabels.pin(ordinal: 3, text: long, shape: region) == "Comment 3: one two three four five six seven eight…")
    }

    @Test func cardLabel() throws {
        let ws = makeWorkspace()
        let now = try addScreen(ws, id: "now", title: "Checkout")
        try addProposal(ws, screenId: now.screenId, proposal: "A", id: "a1")
        try addProposal(ws, screenId: now.screenId, proposal: "A", id: "a2")
        let canvas = ws.currentCanvas!
        let lanes = CanvasLayout.lanes(in: canvas, screen: canvas.screens[0])
        let lane = try #require(lanes.first { $0.key.proposalId == "A" })
        #expect(CanvasLabels.card(lane: lane, screenTitle: "Checkout", commentCount: 3) == "Proposal A, Iteration 2, Checkout screen, 3 comments")
        #expect(CanvasLabels.card(lane: lane, screenTitle: "Checkout", commentCount: 1) == "Proposal A, Iteration 2, Checkout screen, 1 comment")
        let nowLane = try #require(lanes.first { $0.key.isNow })
        #expect(CanvasLabels.card(lane: nowLane, screenTitle: "Checkout", commentCount: 0) == "Now, Revision 1, Checkout screen, 0 comments")
    }

    // MARK: ImageCache.bucket

    @Test func imageBuckets() {
        #expect(ImageCache.bucket(worldWidth: 420, zoom: 1, displayScale: 2) == 1024)
        #expect(ImageCache.bucket(worldWidth: 420, zoom: 0.1, displayScale: 2) == 512)
        #expect(ImageCache.bucket(worldWidth: 420, zoom: 6, displayScale: 2) == 4096)
    }
}
