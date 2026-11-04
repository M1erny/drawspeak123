import CoreGraphics
import DrawspeakCore

/// Conversions between canvas world space and the normalized space of one
/// snapshot card, whose world frame spans (0,0)...(1,1).
nonisolated enum SnapshotSpace {
    /// The normalized position of a world point, clamped to the snapshot.
    static func normalized(_ point: CGPoint, in frame: CGRect) -> NPoint {
        guard frame.width > 0, frame.height > 0 else { return NPoint(x: 0, y: 0) }
        return NPoint(
            x: Double((point.x - frame.minX) / frame.width),
            y: Double((point.y - frame.minY) / frame.height)
        ).clamped()
    }

    static func world(_ point: NPoint, in frame: CGRect) -> CGPoint {
        CGPoint(x: frame.minX + point.x * frame.width, y: frame.minY + point.y * frame.height)
    }

    static func worldRect(_ rect: NRect, in frame: CGRect) -> CGRect {
        CGRect(
            x: frame.minX + rect.x * frame.width,
            y: frame.minY + rect.y * frame.height,
            width: rect.width * frame.width,
            height: rect.height * frame.height
        )
    }
}
