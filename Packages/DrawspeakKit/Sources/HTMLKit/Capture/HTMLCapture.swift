#if canImport(UIKit)
import DrawspeakCore
import UIKit
import WebKit

/// Renders an HTML version offscreen into a PNG reference image.
public enum HTMLCapture {
    public static let timeout = Duration.seconds(15)

    /// Loads at viewport width, then captures the full document height (up to
    /// 8000 CSS pixels), reducing raster scale when needed to stay within 40 MP.
    /// Tall pages are captured in slices of at most 4096 px and stitched.
    /// Throws `HTMLKitError.captureTimedOut` after 15 seconds.
    public static func capture(html: Data, policy: RenderPolicy, viewport: Viewport) async throws -> HTMLCaptureResult {
        let session = HTMLWebViewSession(viewport: viewport)
        let inspector = DOMInspector()
        session.attach(inspector)
        let host = HTMLOffscreenHost(webView: session.webView, viewport: viewport)
        defer {
            session.tearDown()
            host.remove()
        }
        return try await HTMLDeadline.run(timeout, timeoutError: .captureTimedOut) {
            session.load(html: html, policy: policy, viewport: viewport)
            try await session.waitUntilLoaded()
            try await inspector.settle()
            let content = try await inspector.contentSize()
            let size = HTMLCaptureSize(viewport: viewport, contentHeightCSS: content.height)
            host.resize(to: CGSize(width: size.widthCSS, height: size.heightCSS))
            try await inspector.settle()
            let image = try await stitchedSnapshot(of: session.webView, size: size)
            let renderHash = try await inspector.renderHash()
            return try encode(image, size: size, renderHash: renderHash)
        }
    }

    /// Snapshots the page slice by slice (`HTMLCaptureSize.tiles`) and draws
    /// each slice into one opaque sRGB bitmap of exactly the target pixel size
    /// as it arrives, so at most one slice is held besides the bitmap.
    private static func stitchedSnapshot(of webView: WKWebView, size: HTMLCaptureSize) async throws -> CGImage {
        let displayScale = webView.traitCollection.displayScale > 0 ? webView.traitCollection.displayScale : 1
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                  data: nil, width: size.pixelWidth, height: size.pixelHeight, bitsPerComponent: 8, bytesPerRow: 0,
                  space: colorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
              ) else { throw HTMLKitError.snapshotFailed }
        // Transparent page backgrounds read as white, never as black.
        context.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: size.pixelWidth, height: size.pixelHeight))
        context.interpolationQuality = .high
        for tile in size.tiles() {
            let configuration = WKSnapshotConfiguration()
            configuration.rect = CGRect(x: 0, y: tile.minYCSS, width: size.widthCSS, height: tile.heightCSS)
            configuration.afterScreenUpdates = true
            configuration.snapshotWidth = NSNumber(value: Double(size.pixelWidth) / displayScale)
            let slice: CGImage?
            do {
                slice = try await webView.takeSnapshot(configuration: configuration).cgImage
            } catch {
                throw HTMLKitError.snapshotFailed
            }
            guard let slice else { throw HTMLKitError.snapshotFailed }
            // Core Graphics is bottom-left; tiles are listed top-down.
            let y = size.pixelHeight - tile.pixelMinY - tile.pixelHeight
            context.draw(slice, in: CGRect(x: 0, y: y, width: size.pixelWidth, height: tile.pixelHeight))
        }
        guard let image = context.makeImage() else { throw HTMLKitError.snapshotFailed }
        return image
    }

    private static func encode(_ cgImage: CGImage, size: HTMLCaptureSize, renderHash: String) throws -> HTMLCaptureResult {
        guard let png = UIImage(cgImage: cgImage).pngData() else { throw HTMLKitError.snapshotFailed }
        return HTMLCaptureResult(pngData: png, pixelWidth: cgImage.width, pixelHeight: cgImage.height, renderHash: renderHash, contentHeightCSS: size.heightCSS)
    }
}
#endif
