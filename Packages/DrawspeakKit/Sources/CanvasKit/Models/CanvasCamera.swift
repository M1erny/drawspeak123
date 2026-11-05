import CoreGraphics
import DrawspeakCore
import Observation

/// The live camera. Offset and zoom are separate stored properties so views
/// that only need the zoom (constant-width strokes) skip pan frames.
@Observable
final class CanvasCamera {
    /// Screen position of the world origin.
    var offset: CGPoint = .zero
    var zoom: Double = 1
    /// Size of the canvas view, in points.
    var viewSize: CGSize = .zero
    /// True while a gesture or a coast moves the canvas; scroll indicators show then.
    var isScrolling = false
    /// The camera when the last gesture ended. Culling and image resolution
    /// follow it, so they do not churn during a gesture.
    private(set) var settled = CameraState()

    var state: CameraState {
        CameraState(offsetX: offset.x, offsetY: offset.y, zoom: zoom)
    }

    /// Visible world rect of the settled camera, grown by one view size so
    /// nearby cards are ready before they scroll in.
    var settledVisibleWorld: CGRect {
        let screen = CGRect(origin: .zero, size: viewSize).insetBy(dx: -viewSize.width, dy: -viewSize.height)
        return CanvasFraming.screenToWorld(screen, camera: settled)
    }

    func apply(_ camera: CameraState) {
        let next = CGPoint(x: camera.offsetX, y: camera.offsetY)
        if offset != next { offset = next }
        if zoom != camera.zoom { zoom = camera.zoom }
    }

    func settle() {
        if settled != state { settled = state }
    }
}
