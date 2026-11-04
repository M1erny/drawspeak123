#if canImport(UIKit)
import DrawspeakCore
import SwiftUI

/// Outline of the component being selected (solid) or hovered (dashed), with
/// a constant on-screen stroke width.
struct ComponentOutlineLayer: View {
    let pick: ComponentPick
    let camera: CanvasCamera

    @Environment(\.annotationStyle) private var annotationStyle
    var body: some View {
        let zoom = CGFloat(camera.zoom)
        let lineWidth = annotationStyle.lineWidth / zoom
        ZStack(alignment: .topLeading) {
            if let selection = pick.selection, let element = selection.element {
                let rect = SnapshotSpace.worldRect(element.bounds.clamped(), in: selection.frame)
                Path(rect)
                    .fill(Theme.componentOutline.opacity(0.1))
                Path(rect)
                    .stroke(Theme.componentOutline, lineWidth: lineWidth)
            } else if let hover = pick.hover {
                Path(SnapshotSpace.worldRect(hover.element.bounds.clamped(), in: hover.frame))
                    .stroke(Theme.componentOutline.opacity(0.8), style: StrokeStyle(lineWidth: lineWidth, dash: [5 / zoom, 3 / zoom]))
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
#endif
