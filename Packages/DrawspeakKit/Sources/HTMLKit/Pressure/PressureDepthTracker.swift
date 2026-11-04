import CoreGraphics
import Foundation

/// Maps Pencil force to a depth on a hit-to-root chain: 0 is the hit element,
/// `levels - 1` the root. Thresholds are evenly spaced over 0...1 and a
/// hysteresis band keeps jitter around a threshold from flipping the depth.
/// Release commits the last depth that was held for `stableInterval`, so the
/// falling force while lifting the Pencil does not snap back to the top element.
nonisolated public struct PressureDepthTracker: Sendable, Hashable {
    public let levels: Int
    public let band: Double
    public let stableInterval: TimeInterval

    /// Live depth after the latest update, for the preview outline.
    public private(set) var depth = 0
    /// The last depth held for at least `stableInterval`.
    public private(set) var stableDepth = 0
    /// Latest accepted normalized force.
    public private(set) var force: Double = 0

    private var depthSince: TimeInterval?

    public init(levels: Int, band: Double = 0.04, stableInterval: TimeInterval = 0.12) {
        self.levels = max(1, levels)
        self.band = max(0, band)
        self.stableInterval = max(0, stableInterval)
    }

    /// Threshold between depth `level - 1` and `level`, for `level` in `1..<levels`.
    public func threshold(for level: Int) -> Double {
        Double(level) / Double(levels)
    }

    /// Feeds one normalized force sample (0...1) and returns the live depth.
    /// Non-finite samples are ignored.
    @discardableResult
    public mutating func update(force rawForce: Double, at time: TimeInterval) -> Int {
        guard rawForce.isFinite, time.isFinite else { return depth }
        let force = min(max(rawForce, 0), 1)
        self.force = force

        let since = depthSince ?? time
        if time - since >= stableInterval {
            stableDepth = depth
        }

        var next = depth
        while next < levels - 1, force > threshold(for: next + 1) + band / 2 {
            next += 1
        }
        while next > 0, force < threshold(for: next) - band / 2 {
            next -= 1
        }

        if next != depth || depthSince == nil {
            depth = next
            depthSince = time
        }
        if stableInterval == 0 {
            stableDepth = depth
        }
        return depth
    }

    /// The depth to confirm when the Pencil lifts.
    public func commit() -> Int {
        stableDepth
    }

    /// Selects a depth explicitly (chain button, keyboard); it counts as stable at once.
    public mutating func select(depth newDepth: Int, at time: TimeInterval) {
        let clamped = min(max(newDepth, 0), levels - 1)
        depth = clamped
        stableDepth = clamped
        depthSince = time
    }

    /// Normalizes `UITouch.force` by `maximumPossibleForce`; 0 when the maximum is unknown.
    public static func normalizedForce(force: CGFloat, maximumPossibleForce: CGFloat) -> Double {
        let maximum = Double(maximumPossibleForce)
        let value = Double(force)
        guard maximum > 0, maximum.isFinite, value.isFinite else { return 0 }
        return min(max(value / maximum, 0), 1)
    }
}
