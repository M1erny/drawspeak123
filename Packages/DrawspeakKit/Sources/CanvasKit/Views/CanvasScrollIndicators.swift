#if canImport(UIKit)
import SwiftUI

/// Scroll indicators for the canvas, shown while it moves (HIG, Scroll views: "all indicators
/// provide visual feedback about the scrolling action"). They show where the visible part sits
/// among the cards and fade out shortly after the canvas comes to rest.
struct CanvasScrollIndicators: View {
    let camera: CanvasCamera
    let contentBounds: CGRect?

    private let thickness: CGFloat = 3
    private let inset: CGFloat = 6
    private let minimumLength: CGFloat = 36

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let viewport = CGRect(
                x: -camera.offset.x / camera.zoom, y: -camera.offset.y / camera.zoom,
                width: size.width / camera.zoom, height: size.height / camera.zoom
            )
            let extent = contentBounds.map { $0.union(viewport) } ?? viewport
            ZStack(alignment: .topLeading) {
                if let thumb = thumb(viewport.minY - extent.minY, of: extent.height, visible: viewport.height, track: size.height) {
                    Capsule()
                        .fill(.foreground.opacity(0.35))
                        .frame(width: thickness, height: thumb.length)
                        .offset(x: size.width - inset - thickness, y: inset + thumb.position)
                }
                if let thumb = thumb(viewport.minX - extent.minX, of: extent.width, visible: viewport.width, track: size.width) {
                    Capsule()
                        .fill(.foreground.opacity(0.35))
                        .frame(width: thumb.length, height: thickness)
                        .offset(x: inset + thumb.position, y: size.height - inset - thickness)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .opacity(camera.isScrolling ? 1 : 0)
        .animation(camera.isScrolling ? .easeOut(duration: 0.1) : .easeOut(duration: 0.3).delay(0.7), value: camera.isScrolling)
    }

    /// Length and position of a thumb on a track, or nil when everything is visible.
    private func thumb(_ origin: CGFloat, of extent: CGFloat, visible: CGFloat, track: CGFloat) -> (length: CGFloat, position: CGFloat)? {
        let available = track - 2 * inset
        guard extent > 0, available > minimumLength, visible / extent < 0.995 else { return nil }
        let length = max(minimumLength, available * visible / extent)
        let position = min(max(available * origin / extent, 0), available - length)
        return (length, position)
    }
}
#endif
