import Foundation

/// The per-canvas camera. `offset` is the screen position of world origin.
public struct CameraState: Codable, Hashable, Sendable {
    public var offsetX: Double
    public var offsetY: Double
    public var zoom: Double

    public init(offsetX: Double = 40, offsetY: Double = 120, zoom: Double = 0.6) {
        self.offsetX = offsetX
        self.offsetY = offsetY
        self.zoom = zoom
    }

    public static let minZoom = 0.1
    public static let maxZoom = 6.0
}
