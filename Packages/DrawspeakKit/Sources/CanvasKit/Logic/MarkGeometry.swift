import CoreGraphics
import DrawspeakCore
import SwiftUI

/// World-space paths for annotation shapes on a card.
nonisolated enum MarkGeometry {
    /// Arrowhead wing angle from the shaft.
    static let headAngle: CGFloat = .pi / 6.5

    /// - Parameter headLength: Arrowhead wing length in world units.
    static func path(for shape: AnnotationShape, in frame: CGRect, headLength: CGFloat) -> Path {
        switch shape {
        case .region(let rect), .component(let rect):
            let world = SnapshotSpace.worldRect(rect, in: frame)
            let radius = min(world.width, world.height, headLength) * 0.3
            return Path(roundedRect: world, cornerRadius: radius)
        case .ellipse(let rect):
            return Path(ellipseIn: SnapshotSpace.worldRect(rect, in: frame))
        case .lasso(let points):
            var path = polyline(points.map { SnapshotSpace.world($0, in: frame) })
            path.closeSubpath()
            return path
        case .stroke(let points):
            return polyline(points.map { SnapshotSpace.world($0, in: frame) })
        case .arrow(let from, let to):
            return arrow(from: SnapshotSpace.world(from, in: frame), to: SnapshotSpace.world(to, in: frame), headLength: headLength)
        }
    }

    static func polyline(_ points: [CGPoint]) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        for point in points.dropFirst() { path.addLine(to: point) }
        return path
    }

    static func arrow(from start: CGPoint, to end: CGPoint, headLength: CGFloat) -> Path {
        var path = Path()
        path.move(to: start)
        path.addLine(to: end)
        let angle = atan2(end.y - start.y, end.x - start.x)
        let length = min(headLength, hypot(end.x - start.x, end.y - start.y) * 0.5)
        for side in [-1.0, 1.0] {
            let wing = angle + .pi + CGFloat(side) * headAngle
            path.move(to: end)
            path.addLine(to: CGPoint(x: end.x + cos(wing) * length, y: end.y + sin(wing) * length))
        }
        return path
    }
}
