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
}
