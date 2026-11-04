import SwiftUI
import DrawspeakCore

struct CompositeCanvas: View {
    let image: CGImage
    let items: [BatchItem]
    private let red = Color(red: 189 / 255, green: 48 / 255, blue: 72 / 255)

    var body: some View {
        Canvas { context, size in
            context.draw(Image(decorative: image, scale: 1), in: CGRect(origin: .zero, size: size))
            let width = max(size.width, size.height) * 0.003
            for item in items {
                let path = mark(item.shape, size: size, width: width)
                context.stroke(path, with: .color(.white), style: StrokeStyle(lineWidth: width * 2, lineCap: .round, lineJoin: .round))
                context.stroke(path, with: .color(red), style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
                let bounds = item.shape.bounds.clamped()
                let radius = width * 4.5
                let x = min(max(CGFloat(bounds.x) * size.width, radius + width), size.width - radius - width)
                let y = min(max(CGFloat(bounds.y) * size.height, radius + width), size.height - radius - width)
                let pin = Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2))
                context.fill(pin, with: .color(red))
                context.stroke(pin, with: .color(.white), lineWidth: width)
                context.draw(Text(item.ordinal, format: .number).font(.system(size: radius, weight: .bold)).foregroundStyle(.white), at: CGPoint(x: x, y: y))
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
