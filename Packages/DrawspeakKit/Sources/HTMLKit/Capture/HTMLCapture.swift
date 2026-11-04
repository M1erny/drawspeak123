#if canImport(UIKit)
import DrawspeakCore
import UIKit
import WebKit

/// Renders an HTML version offscreen into a PNG reference image.
public enum HTMLCapture {
    public static let timeout = Duration.seconds(15)

    /// Loads the document in an isolated, offline web view of viewport size, waits
    /// for load, fonts and one frame, and snapshots it at `viewport.deviceScaleFactor`.
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
            let image = try await snapshot(of: session.webView, viewport: viewport)
            let renderHash = try await inspector.renderHash()
            return try encode(image, viewport: viewport, renderHash: renderHash)
        }
    }

    static func pixelSize(of viewport: Viewport) -> (width: Int, height: Int) {
        let scale = viewport.deviceScaleFactor.isFinite && viewport.deviceScaleFactor > 0 ? viewport.deviceScaleFactor : 1
        return (
            max(1, Int((Double(viewport.width) * scale).rounded())),
            max(1, Int((Double(viewport.height) * scale).rounded()))
        )
    }

    private static func snapshot(of webView: WKWebView, viewport: Viewport) async throws -> UIImage {
        let configuration = WKSnapshotConfiguration()
        configuration.rect = CGRect(origin: .zero, size: HTMLWebViewFactory.size(of: viewport))
        configuration.afterScreenUpdates = true
        let displayScale = webView.traitCollection.displayScale > 0 ? webView.traitCollection.displayScale : 1
        configuration.snapshotWidth = NSNumber(value: Double(pixelSize(of: viewport).width) / displayScale)
        do {
            return try await webView.takeSnapshot(configuration: configuration)
        } catch {
            throw HTMLKitError.snapshotFailed
        }
    }

    /// Encodes at exactly the viewport's pixel size, redrawing only when WebKit
    /// returned another scale.
    private static func encode(_ image: UIImage, viewport: Viewport, renderHash: String) throws -> HTMLCaptureResult {
        let target = pixelSize(of: viewport)
        var cgImage = image.cgImage
        if cgImage?.width != target.width || cgImage?.height != target.height {
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            format.opaque = true
            format.preferredRange = .standard
            let size = CGSize(width: target.width, height: target.height)
            let renderer = UIGraphicsImageRenderer(size: size, format: format)
            cgImage = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }.cgImage
        }
        guard let cgImage, let png = UIImage(cgImage: cgImage).pngData() else { throw HTMLKitError.snapshotFailed }
        return HTMLCaptureResult(pngData: png, pixelWidth: cgImage.width, pixelHeight: cgImage.height, renderHash: renderHash)
    }
}
#endif
