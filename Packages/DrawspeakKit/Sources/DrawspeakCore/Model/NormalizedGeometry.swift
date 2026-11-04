import Foundation

/// A point in the normalized coordinate space of one snapshot: (0,0) is the
/// top-left corner of the captured image, (1,1) the bottom-right corner.
/// Camera pan and zoom never change these values.
public struct NPoint: Codable, Hashable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    public func clamped() -> NPoint {
        NPoint(x: min(max(x, 0), 1), y: min(max(y, 0), 1))
    }
}

/// A rectangle in normalized snapshot space.
public struct NRect: Codable, Hashable, Sendable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    public static let zero = NRect(x: 0, y: 0, width: 0, height: 0)

    public init(bounding points: [NPoint]) {
        guard let first = points.first else {
            self = .zero
            return
        }
        var minX = first.x, maxX = first.x, minY = first.y, maxY = first.y
        for point in points.dropFirst() {
            minX = min(minX, point.x)
            maxX = max(maxX, point.x)
            minY = min(minY, point.y)
            maxY = max(maxY, point.y)
        }
        self.init(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    public var midX: Double { x + width / 2 }
    public var midY: Double { y + height / 2 }
    public var maxX: Double { x + width }
    public var maxY: Double { y + height }
    public var area: Double { max(width, 0) * max(height, 0) }

    /// A rectangle is valid when it is finite, non-empty and overlaps the snapshot.
    public var isValid: Bool {
        [x, y, width, height].allSatisfy(\.isFinite) && width > 0 && height > 0
            && maxX > 0 && maxY > 0 && x < 1 && y < 1
    }

    public func clamped() -> NRect {
        let minX = min(max(x, 0), 1)
        let minY = min(max(y, 0), 1)
        let maxX = min(max(self.maxX, 0), 1)
        let maxY = min(max(self.maxY, 0), 1)
        return NRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}
