import CoreGraphics

/// Keeps the measured, screen-space bubble inside the usable canvas.
nonisolated enum RecordingBubblePlacement {
    static func origin(pin: CGPoint, bubble: CGSize, bounds: CGRect) -> CGPoint {
        let gap = 26.0
        let right = pin.x + gap
        let x = right + bubble.width <= bounds.maxX ? right : pin.x - gap - bubble.width
        return CGPoint(
            x: min(max(x, bounds.minX), max(bounds.minX, bounds.maxX - bubble.width)),
            y: min(max(pin.y - bubble.height / 2, bounds.minY), max(bounds.minY, bounds.maxY - bubble.height))
        )
    }
}
