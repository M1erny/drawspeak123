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
                    .stroke(Theme.annotation, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
                Path(StrokeClassifier.boundingRect(of: points))
                    .stroke(Theme.annotation.opacity(0.5), style: StrokeStyle(lineWidth: lineWidth / 2, dash: [6 / zoom, 4 / zoom]))
            case .arrow:
                if let first = points.first, let last = points.last {
                    MarkGeometry.arrow(from: first, to: last, headLength: 14 / zoom)
                        .stroke(Theme.annotation, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
                }
            case .pen:
                MarkGeometry.polyline(points)
                    .stroke(Theme.annotation, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
            case nil:
                EmptyView()
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
#endif
