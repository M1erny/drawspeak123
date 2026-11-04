@testable import CanvasKit
import CoreGraphics
import DrawspeakCore
import Foundation
import SwiftUI
import Testing

@MainActor
@Suite("CanvasFraming")
struct CanvasFramingTests {
    let viewSize = CGSize(width: 1366, height: 1024)
    let insets = EdgeInsets(top: 80, leading: 20, bottom: 100, trailing: 20)

    @Test func worldScreenRoundTrip() {
        let camera = CameraState(offsetX: 100, offsetY: 50, zoom: 2)
        let screen = CanvasFraming.worldToScreen(CGPoint(x: 10, y: 20), camera: camera)
        #expect(screen == CGPoint(x: 120, y: 90))
        #expect(CanvasFraming.screenToWorld(screen, camera: camera) == CGPoint(x: 10, y: 20))
    }

    @Test func rectConversionRoundTrip() {
        let camera = CameraState(offsetX: 100, offsetY: 50, zoom: 2)
        let rect = CGRect(x: 10, y: 20, width: 30, height: 40)
        let screen = CanvasFraming.worldToScreen(rect, camera: camera)
        #expect(screen == CGRect(x: 120, y: 90, width: 60, height: 80))
        #expect(CanvasFraming.screenToWorld(screen, camera: camera) == rect)
    }

    @Test func zoomKeepsAnchorFixed() {
        let camera = CameraState(offsetX: 0, offsetY: 0, zoom: 1)
        let anchor = CGPoint(x: 100, y: 100)
        let zoomed = CanvasFraming.zoomed(camera, by: 2, around: anchor)
        #expect(zoomed.zoom == 2)
        let before = CanvasFraming.screenToWorld(anchor, camera: camera)
        let after = CanvasFraming.screenToWorld(anchor, camera: zoomed)
        #expect(approx(before, after))
    }

    @Test func zoomClampsToMaximum() {
        let camera = CameraState(offsetX: 30, offsetY: -40, zoom: 5)
        let anchor = CGPoint(x: 250, y: 125)
        let zoomed = CanvasFraming.zoomed(camera, by: 10, around: anchor)
        #expect(zoomed.zoom == 6.0)
        #expect(approx(CanvasFraming.screenToWorld(anchor, camera: camera), CanvasFraming.screenToWorld(anchor, camera: zoomed), tolerance: 1e-9))
    }

    @Test func zoomClampsToMinimum() {
        let camera = CameraState(offsetX: 30, offsetY: -40, zoom: 0.2)
        let anchor = CGPoint(x: 250, y: 125)
        let zoomed = CanvasFraming.zoomed(camera, by: 0.1, around: anchor)
        #expect(zoomed.zoom == 0.1)
        #expect(approx(CanvasFraming.screenToWorld(anchor, camera: camera), CanvasFraming.screenToWorld(anchor, camera: zoomed), tolerance: 1e-9))
    }

    @Test(arguments: [0.0, -1.0, Double.nan, Double.infinity])
    func invalidZoomFactorLeavesCameraUnchanged(factor: Double) {
        let camera = CameraState(offsetX: 12, offsetY: 34, zoom: 1.5)
        #expect(CanvasFraming.zoomed(camera, by: factor, around: CGPoint(x: 50, y: 60)) == camera)
    }

    @Test func fitAllShowsEveryCardInsideAvailableRect() throws {
        let fixture = try TwoScreenFixture()
        let canvas = fixture.canvas
        let camera = CanvasFraming.fitAll(canvas: canvas, viewSize: viewSize, insets: insets)
        let available = CanvasFraming.availableRect(viewSize: viewSize, insets: insets).insetBy(dx: -0.5, dy: -0.5)
        let slots = CanvasWorldLayout(canvas: canvas).slots
        #expect(slots.count == 4)
        for slot in slots {
            let screenFrame = CanvasFraming.worldToScreen(slot.frame, camera: camera)
            #expect(available.contains(screenFrame), "slot \(slot.id) at \(screenFrame) escapes \(available)")
        }
        #expect(camera.zoom <= 1)
    }

    @Test func fitAllOnEmptyCanvasIsDefaultCamera() {
        let canvas = makeWorkspace().currentCanvas!
        #expect(CanvasFraming.fitAll(canvas: canvas, viewSize: viewSize, insets: insets) == CameraState())
    }

    @Test func frameMissingSnapshotIsNil() throws {
        let fixture = try TwoScreenFixture()
        #expect(CanvasFraming.frame(snapshotId: "missing", rect: nil, in: fixture.canvas, viewSize: viewSize, insets: insets) == nil)
    }

    @Test func frameSnapshotCentersCard() throws {
        let fixture = try TwoScreenFixture()
        let canvas = fixture.canvas
        let card = try #require(CanvasWorldLayout(canvas: canvas).frame(forSnapshot: fixture.proposalA.id))
        let camera = try #require(CanvasFraming.frame(snapshotId: fixture.proposalA.id, rect: nil, in: canvas, viewSize: viewSize, insets: insets))
        let available = CanvasFraming.availableRect(viewSize: viewSize, insets: insets)
        let center = CanvasFraming.worldToScreen(CGPoint(x: card.midX, y: card.midY), camera: camera)
        #expect(approx(center, CGPoint(x: available.midX, y: available.midY), tolerance: 0.5))
        #expect(camera.zoom <= 2)
    }

    @Test func frameRectZoomsInAndCentersRect() throws {
        let fixture = try TwoScreenFixture()
        let canvas = fixture.canvas
        let card = try #require(CanvasWorldLayout(canvas: canvas).frame(forSnapshot: fixture.proposalA.id))
        let cardCamera = try #require(CanvasFraming.frame(snapshotId: fixture.proposalA.id, rect: nil, in: canvas, viewSize: viewSize, insets: insets))
        let rect = NRect(x: 0.4, y: 0.4, width: 0.1, height: 0.05)
        let camera = try #require(CanvasFraming.frame(snapshotId: fixture.proposalA.id, rect: rect, in: canvas, viewSize: viewSize, insets: insets))
        #expect(camera.zoom > cardCamera.zoom)

        let target = SnapshotSpace.worldRect(rect, in: card)
        let available = CanvasFraming.availableRect(viewSize: viewSize, insets: insets)
        let center = CanvasFraming.worldToScreen(CGPoint(x: target.midX, y: target.midY), camera: camera)
        #expect(approx(center, CGPoint(x: available.midX, y: available.midY), tolerance: 0.5))
    }

    @Test func markScreenRectUsesSelectedVersionAndCamera() throws {
        let fixture = try TwoScreenFixture()
        let noteId = try #require(fixture.ws.addNote(snapshotId: fixture.proposalA.id, shape: regionShape, autoVoice: false))
        let camera = CameraState(offsetX: 37, offsetY: -19, zoom: 1.5)
        let card = try #require(CanvasWorldLayout(canvas: fixture.canvas).slots.first { $0.snapshot?.id == fixture.proposalA.id }?.frame)
        let rect = try #require(CanvasFraming.markScreenRect(noteId: noteId, in: fixture.canvas, camera: camera))
        #expect(abs(rect.minX - (37 + (card.minX + card.width * 0.1) * 1.5)) < 0.0001)
        #expect(abs(rect.minY - (-19 + (card.minY + card.height * 0.1) * 1.5)) < 0.0001)
        #expect(abs(rect.width - card.width * 0.3 * 1.5) < 0.0001)
        #expect(abs(rect.height - card.height * 0.2 * 1.5) < 0.0001)
        #expect(CanvasFraming.markScreenRect(noteId: UUID(), in: fixture.canvas, camera: camera) == nil)
        _ = try addProposal(fixture.ws, screenId: fixture.s1, proposal: "A", id: "newer-a")
        #expect(CanvasFraming.markScreenRect(noteId: noteId, in: fixture.canvas, camera: camera) == nil)
    }

    @Test func clampZoomHandlesNonFinite() {
        #expect(CanvasFraming.clampZoom(.nan) == 1)
        #expect(CanvasFraming.clampZoom(100) == 6)
        #expect(CanvasFraming.clampZoom(0.001) == 0.1)
    }
}
