import Foundation

/// A PNG rendering of one HTML snapshot version.
nonisolated public struct HTMLCaptureResult: Sendable, Hashable {
    public var pngData: Data
    public var pixelWidth: Int
    public var pixelHeight: Int
    /// SHA-256 hex of the rendered `document.documentElement.outerHTML`.
    public var renderHash: String

    public init(pngData: Data, pixelWidth: Int, pixelHeight: Int, renderHash: String) {
        self.pngData = pngData
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.renderHash = renderHash
    }
}
