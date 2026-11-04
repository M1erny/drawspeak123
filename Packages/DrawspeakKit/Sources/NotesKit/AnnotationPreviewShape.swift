import SwiftUI
import DrawspeakCore

struct AnnotationPreviewShape: Shape {
    let annotation: AnnotationShape
    var crop = NRect(x: 0, y: 0, width: 1, height: 1)

    nonisolated func path(in rect: CGRect) -> Path {
        func point(_ p: NPoint) -> CGPoint { CGPoint(x: rect.minX + (p.x - crop.x) / crop.width * rect.width, y: rect.minY + (p.y - crop.y) / crop.height * rect.height) }
        func box(_ r: NRect) -> CGRect { CGRect(x: rect.minX + (r.x - crop.x) / crop.width * rect.width, y: rect.minY + (r.y - crop.y) / crop.height * rect.height, width: r.width / crop.width * rect.width, height: r.height / crop.height * rect.height) }
        var path = Path()
        switch annotation {
        case .region(let r), .component(let r): path.addRect(box(r))
        case .ellipse(let r): path.addEllipse(in: box(r))
        case .stroke(let points), .lasso(let points):
            if let first = points.first {
                path.move(to: point(first))
                for p in points.dropFirst() { path.addLine(to: point(p)) }
                if case .lasso = annotation { path.closeSubpath() }
            }
        case .arrow(let from, let to):
            let a = point(from), b = point(to)
            path.move(to: a); path.addLine(to: b)
            let angle = atan2(b.y - a.y, b.x - a.x)
            for offset in [-0.5, 0.5] {
                path.move(to: b)
                path.addLine(to: CGPoint(x: b.x - 12 * cos(angle + offset), y: b.y - 12 * sin(angle + offset)))
            }
        }
        return path
    }
}

#Preview {
    AnnotationPreviewShape(annotation: .region(NRect(x: 0.2, y: 0.2, width: 0.5, height: 0.4)))
        .stroke(Theme.annotation, lineWidth: 3).frame(width: 240, height: 180)
}
