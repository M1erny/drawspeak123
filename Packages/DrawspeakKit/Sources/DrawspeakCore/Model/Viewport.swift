import Foundation

public struct Viewport: Codable, Hashable, Sendable {
    public var width: Int
    public var height: Int
    public var deviceScaleFactor: Double

    public init(width: Int, height: Int, deviceScaleFactor: Double = 1) {
        self.width = width
        self.height = height
        self.deviceScaleFactor = deviceScaleFactor
    }

    public static let defaultHTML = Viewport(width: 390, height: 844, deviceScaleFactor: 2)

    /// Accepted CSS viewport width and height, in points.
    public static let dimensionRange = 1...4096
    /// Accepted device scale factor.
    public static let scaleRange = 0.5...4.0
    /// Maximum rendered pixels (width × height × scale²): 40 MP.
    public static let maxPixelCount = 40_000_000.0

    /// Rendered pixel count, computed in floating point so it cannot overflow.
    public var pixelCount: Double {
        Double(width) * deviceScaleFactor * Double(height) * deviceScaleFactor
    }

    /// True when rendering this viewport is safe: bounded, finite dimensions,
    /// scale and total pixel count. Check before any numeric conversion or allocation.
    public var isWithinCaptureLimits: Bool {
        Self.dimensionRange.contains(width)
            && Self.dimensionRange.contains(height)
            && deviceScaleFactor.isFinite
            && Self.scaleRange.contains(deviceScaleFactor)
            && pixelCount.isFinite
            && pixelCount <= Self.maxPixelCount
    }
}
