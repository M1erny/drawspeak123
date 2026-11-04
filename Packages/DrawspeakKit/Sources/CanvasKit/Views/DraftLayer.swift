#if canImport(UIKit)
import DrawspeakCore
import SwiftUI

/// Live preview of the stroke being drawn. It is the only view that observes
/// the draft, so touch moves do not re-render the rest of the canvas.
struct DraftLayer: View {
    let draft: InkDraft
    let camera: CanvasCamera

    var body: some View {
        let zoom = CGFloat(camera.zoom)
        let lineWidth = Theme.markLineWidth / zoom
        let points = draft.points
        ZStack(alignment: .topLeading) {
            switch draft.kind {
            case .region:
                MarkGeometry.polyline(points)
                    .annotationStroke(width: lineWidth, halo: 2.5 / zoom)
                let bounds = Path(StrokeClassifier.boundingRect(of: points))
                bounds.stroke(Theme.annotationHalo, style: StrokeStyle(lineWidth: lineWidth / 2 + 2.5 / zoom, dash: [6 / zoom, 4 / zoom]))
                bounds
                    .stroke(Theme.annotation.opacity(0.5), style: StrokeStyle(lineWidth: lineWidth / 2, dash: [6 / zoom, 4 / zoom]))
            case .arrow:
                if let first = points.first, let last = points.last {
                    MarkGeometry.arrow(from: first, to: last, headLength: 14 / zoom)
                        .annotationStroke(width: lineWidth, halo: 2.5 / zoom)
                }
            case .pen:
                MarkGeometry.polyline(points)
                    .annotationStroke(width: lineWidth, halo: 2.5 / zoom)
            case nil:
                EmptyView()
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
#endif
