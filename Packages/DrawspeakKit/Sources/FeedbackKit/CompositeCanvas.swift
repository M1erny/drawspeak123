import SwiftUI
import DrawspeakCore

struct CompositeCanvas: View {
    let image: CGImage
    let items: [BatchItem]
    let style: AnnotationStyle

    var body: some View {
        Canvas { context, size in
            context.draw(Image(decorative: image, scale: 1), in: CGRect(origin: .zero, size: size))
            let scale = max(size.width, size.height) / 1000
            let width = style.lineWidth * scale
            for item in items {
                let path = mark(item.shape, size: size, width: width)
                context.stroke(path, with: .color(Theme.annotationHalo), style: StrokeStyle(lineWidth: style.haloWidth * scale, lineCap: .round, lineJoin: .round))
                context.stroke(path, with: .color(Theme.annotation), style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
                let bounds = item.shape.bounds.clamped()
                let radius = style.pinSize * scale / 2
                let x = min(max(CGFloat(bounds.x) * size.width, radius + width), size.width - radius - width)
                let y = min(max(CGFloat(bounds.y) * size.height, radius + width), size.height - radius - width)
                let pin = Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2))
                let ring = AnnotationStyle.pinRingWidth * scale
                context.fill(Path(ellipseIn: CGRect(x: x - radius - ring, y: y - radius - ring, width: (radius + ring) * 2, height: (radius + ring) * 2)),
                             with: .color(Theme.annotationHalo))
                context.fill(pin, with: .color(Theme.annotation))
                context.draw(Text(item.displayNumber ?? item.ordinal, format: .number).font(.system(size: style.pinFontSize * scale, weight: .bold, design: .monospaced)).foregroundStyle(.white), at: CGPoint(x: x, y: y))
            }
        }
    }

    private func mark(_ shape: AnnotationShape, size: CGSize, width: CGFloat) -> Path {
        func point(_ p: NPoint) -> CGPoint { CGPoint(x: p.x * size.width, y: p.y * size.height) }
        func rect(_ r: NRect) -> CGRect { CGRect(x: r.x * size.width, y: r.y * size.height, width: r.width * size.width, height: r.height * size.height) }
        var path = Path()
        switch shape {
        case .region(let r), .component(let r): path.addRect(rect(r))
        case .ellipse(let r): path.addEllipse(in: rect(r))
        case .lasso(let points), .stroke(let points):
            if let first = points.first {
                path.move(to: point(first))
                for p in points.dropFirst() { path.addLine(to: point(p)) }
                if case .lasso = shape { path.closeSubpath() }
            }
        case .arrow(let from, let to):
            let start = point(from), end = point(to)
            path.move(to: start); path.addLine(to: end)
            let angle = atan2(end.y - start.y, end.x - start.x)
            for offset in [-CGFloat.pi / 6, CGFloat.pi / 6] {
                path.move(to: end)
                path.addLine(to: CGPoint(x: end.x - cos(angle + offset) * width * 7, y: end.y - sin(angle + offset) * width * 7))
            }
        }
        return path
    }
}
