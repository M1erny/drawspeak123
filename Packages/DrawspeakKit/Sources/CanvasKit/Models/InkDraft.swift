import CoreGraphics
import Observation

/// The stroke being drawn. Only the draft overlay observes it, so the rest of
/// the canvas does not re-render on every touch move.
@Observable
final class InkDraft {
    /// World-space points in drawing order.
    private(set) var points: [CGPoint] = []
    private(set) var kind: MarkKind?
    @ObservationIgnored private(set) var snapshotId: String?
    @ObservationIgnored private(set) var frame: CGRect = .zero

    var isActive: Bool { kind != nil }

    func begin(kind: MarkKind, snapshotId: String, frame: CGRect, at point: CGPoint) {
        self.snapshotId = snapshotId
        self.frame = frame
        self.kind = kind
        points = [point]
    }

    /// Adds a point when it is at least `minimumDistance` (world units) from the last one.
    func append(_ point: CGPoint, minimumDistance: CGFloat) {
        guard isActive else { return }
        if let last = points.last, hypot(point.x - last.x, point.y - last.y) < minimumDistance { return }
        points.append(point)
    }

    func clear() {
        guard isActive || !points.isEmpty else { return }
        kind = nil
        snapshotId = nil
        points = []
    }
}
