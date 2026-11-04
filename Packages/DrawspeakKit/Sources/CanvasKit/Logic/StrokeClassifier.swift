import CoreGraphics
import DrawspeakCore

/// Turns a finished stroke into a mark, or nothing when it shows no intent.
/// Points are in world space; thresholds are in screen points, so the same
/// gesture means the same thing at every zoom.
nonisolated enum StrokeClassifier {
    /// Marks whose screen bounding box fits in this square are taps or slips.
    static let minimumMarkSize: CGFloat = 24
    /// A dragged region needs at least this much on its shorter side.
    static let minimumRegionSide: CGFloat = 8
    static let minimumArrowLength: CGFloat = 32
    /// A loop is closed when its end is within this fraction of the path
    /// length, or within `closeDistance`, of its start.
    static let closeFraction: CGFloat = 0.12
    static let closeDistance: CGFloat = 30
    /// Stored freehand points are at least this far apart on screen.
    static let sampleSpacing: CGFloat = 2

    /// - Parameters:
    ///   - points: The stroke in world space, in drawing order.
    ///   - zoom: Screen points per world unit while drawing.
    ///   - frame: World frame of the snapshot the stroke started on.
    static func shape(for points: [CGPoint], kind: MarkKind, zoom: Double, in frame: CGRect) -> AnnotationShape? {
        guard points.count >= 2, zoom > 0, zoom.isFinite, let first = points.first, let last = points.last else { return nil }
        let scale = CGFloat(zoom)
        let bounds = boundingRect(of: points)
        let screenWidth = bounds.width * scale
        let screenHeight = bounds.height * scale
        let fitsInTapBox = screenWidth < minimumMarkSize && screenHeight < minimumMarkSize

        let shape: AnnotationShape
        switch kind {
        case .arrow:
            guard distance(first, last) * scale >= minimumArrowLength else { return nil }
            shape = .arrow(from: SnapshotSpace.normalized(first, in: frame), to: SnapshotSpace.normalized(last, in: frame))
        case .pen:
            guard !fitsInTapBox else { return nil }
            let samples = simplified(points, spacing: sampleSpacing / scale)
            shape = .stroke(samples.map { SnapshotSpace.normalized($0, in: frame) })
        case .region:
            guard !fitsInTapBox else { return nil }
            if isClosedLoop(points, scale: scale) {
                let samples = simplified(points, spacing: sampleSpacing / scale)
                shape = .lasso(samples.map { SnapshotSpace.normalized($0, in: frame) })
            } else {
                guard min(screenWidth, screenHeight) >= minimumRegionSide else { return nil }
                let corners = [CGPoint(x: bounds.minX, y: bounds.minY), CGPoint(x: bounds.maxX, y: bounds.maxY)]
                shape = .region(NRect(bounding: corners.map { SnapshotSpace.normalized($0, in: frame) }))
            }
        }
        return shape.isValid ? shape : nil
    }

    /// True when the stroke ends near where it started, relative to its length.
    static func isClosedLoop(_ points: [CGPoint], scale: CGFloat) -> Bool {
        guard points.count >= 3, let first = points.first, let last = points.last else { return false }
        let length = pathLength(points) * scale
        guard length > 0 else { return false }
        let gap = distance(first, last) * scale
        return gap <= closeFraction * length || gap <= closeDistance
    }

    static func pathLength(_ points: [CGPoint]) -> CGFloat {
        zip(points, points.dropFirst()).reduce(0) { $0 + distance($1.0, $1.1) }
    }

    static func boundingRect(of points: [CGPoint]) -> CGRect {
        guard let first = points.first else { return .null }
        var minX = first.x, maxX = first.x, minY = first.y, maxY = first.y
        for point in points.dropFirst() {
            minX = min(minX, point.x)
            maxX = max(maxX, point.x)
            minY = min(minY, point.y)
            maxY = max(maxY, point.y)
        }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    /// Drops points closer than `spacing` to the last kept one; keeps the end point.
    static func simplified(_ points: [CGPoint], spacing: CGFloat) -> [CGPoint] {
        guard var kept = points.first.map({ [$0] }) else { return [] }
        for point in points.dropFirst() where distance(point, kept[kept.count - 1]) >= spacing {
            kept.append(point)
        }
        if let last = points.last, kept.last != last {
            kept.append(last)
        }
        return kept
    }

    static func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        hypot(b.x - a.x, b.y - a.y)
    }
}
