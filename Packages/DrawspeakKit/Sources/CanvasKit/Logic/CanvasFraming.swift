import CoreGraphics
import DrawspeakCore
import SwiftUI

/// Pure camera math. A camera maps world to screen as
/// `screen = offset + world × zoom`; `offset` is the screen position of the
/// world origin.
nonisolated public enum CanvasFraming {
    /// Screen margin around framed content, in points.
    public static let margin: CGFloat = 48
    /// Screen height reserved above a card for its lane header and screen title.
    public static let headerChrome: CGFloat = 96
    /// Fit All never enlarges content beyond 100 %.
    public static let fitAllMaxZoom = 1.0
    public static let snapshotMaxZoom = 2.0
    public static let noteMaxZoom = 3.0

    public static func clampZoom(_ zoom: Double) -> Double {
        guard zoom.isFinite else { return 1 }
        return min(max(zoom, CameraState.minZoom), CameraState.maxZoom)
    }

    public static func worldToScreen(_ point: CGPoint, camera: CameraState) -> CGPoint {
        CGPoint(x: camera.offsetX + point.x * camera.zoom, y: camera.offsetY + point.y * camera.zoom)
    }

    public static func screenToWorld(_ point: CGPoint, camera: CameraState) -> CGPoint {
        let zoom = camera.zoom > 0 ? camera.zoom : 1
        return CGPoint(x: (point.x - camera.offsetX) / zoom, y: (point.y - camera.offsetY) / zoom)
    }

    public static func worldToScreen(_ rect: CGRect, camera: CameraState) -> CGRect {
        CGRect(origin: worldToScreen(rect.origin, camera: camera), size: CGSize(width: rect.width * camera.zoom, height: rect.height * camera.zoom))
    }

    public static func screenToWorld(_ rect: CGRect, camera: CameraState) -> CGRect {
        let zoom = camera.zoom > 0 ? camera.zoom : 1
        return CGRect(origin: screenToWorld(rect.origin, camera: camera), size: CGSize(width: rect.width / zoom, height: rect.height / zoom))
    }

    /// Scales the camera by `factor`, keeping the world point under the screen
    /// `point` in place. The result is clamped to the camera's zoom range.
    public static func zoomed(_ camera: CameraState, by factor: Double, around point: CGPoint) -> CameraState {
        guard factor.isFinite, factor > 0, camera.zoom > 0 else { return camera }
        let zoom = clampZoom(camera.zoom * factor)
        let ratio = zoom / camera.zoom
        return CameraState(
            offsetX: point.x - (point.x - camera.offsetX) * ratio,
            offsetY: point.y - (point.y - camera.offsetY) * ratio,
            zoom: zoom
        )
    }

    /// Every screen and lane visible with margins; never above 100 %.
    public static func fitAll(canvas: ReviewCanvas, viewSize: CGSize, insets: EdgeInsets) -> CameraState {
        guard let bounds = CanvasWorldLayout(canvas: canvas).contentBounds else { return CameraState() }
        return fit(bounds, viewSize: viewSize, insets: insets, maxZoom: fitAllMaxZoom)
    }

    /// Centers a snapshot card, or a normalized rect within it, at a readable
    /// zoom. Returns `nil` when the snapshot is not on the canvas.
    public static func frame(snapshotId: String, rect: NRect?, in canvas: ReviewCanvas, viewSize: CGSize, insets: EdgeInsets) -> CameraState? {
        guard let card = CanvasWorldLayout(canvas: canvas).frame(forSnapshot: snapshotId) else { return nil }
        let cardCamera = fit(card, viewSize: viewSize, insets: insets, maxZoom: snapshotMaxZoom)
        guard let rect, rect.isValid else { return cardCamera }
        let target = SnapshotSpace.worldRect(rect.clamped(), in: card)
        let padding = max(target.width, target.height) * 0.5 + 24
        let noteCamera = fit(target.insetBy(dx: -padding, dy: -padding), viewSize: viewSize, insets: insets, maxZoom: noteMaxZoom)
        return noteCamera.zoom > cardCamera.zoom ? noteCamera : cardCamera
    }

    /// The screen rect content may occupy: the view minus insets, the header
    /// chrome above cards and the margin.
    static func availableRect(viewSize: CGSize, insets: EdgeInsets) -> CGRect {
        let base = CGRect(
            x: insets.leading,
            y: insets.top + headerChrome,
            width: viewSize.width - insets.leading - insets.trailing,
            height: viewSize.height - insets.top - insets.bottom - headerChrome
        )
        let inset = min(margin, max(base.width, 0) * 0.1, max(base.height, 0) * 0.1)
        let rect = base.insetBy(dx: inset, dy: inset)
        guard rect.width > 1, rect.height > 1 else {
            return CGRect(x: 0, y: 0, width: max(viewSize.width, 1), height: max(viewSize.height, 1))
        }
        return rect
    }

    /// A camera that shows `rect` centered in the available area.
    static func fit(_ rect: CGRect, viewSize: CGSize, insets: EdgeInsets, maxZoom: Double) -> CameraState {
        let available = availableRect(viewSize: viewSize, insets: insets)
        var zoom = maxZoom
        if rect.width > 0 { zoom = min(zoom, available.width / rect.width) }
        if rect.height > 0 { zoom = min(zoom, available.height / rect.height) }
        zoom = clampZoom(zoom)
        return CameraState(
            offsetX: available.midX - rect.midX * zoom,
            offsetY: available.midY - rect.midY * zoom,
            zoom: zoom
        )
    }
}
