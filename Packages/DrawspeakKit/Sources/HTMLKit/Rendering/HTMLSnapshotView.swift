#if canImport(UIKit)
import DrawspeakCore
import SwiftUI
import WebKit

/// Renders one HTML version at viewport width and its captured content height
/// in an isolated, offline web view. Scale it with `scaleEffect` to fit
/// the canvas; the web view itself never zooms or bounces.
public struct HTMLSnapshotView: UIViewRepresentable {
    /// Tallest document shown as one full-height live web view. A taller web
    /// view scaled down on the canvas would rasterize tens of megapixels (and
    /// exceed GPU texture limits), so such cards show their capture image.
    public static let maximumFullHeightCSS = 2_048.0

    let html: Data
    let policy: RenderPolicy
    let viewport: Viewport
    let contentHeightCSS: Double?
    let inspector: DOMInspector?
    let allowsInteraction: Bool
    let allowsScrolling: Bool
    let isRendered: Bool
    let onLoad: (() -> Void)?

    public init(
        html: Data,
        policy: RenderPolicy,
        viewport: Viewport,
        contentHeightCSS: Double? = nil,
        inspector: DOMInspector? = nil,
        allowsInteraction: Bool = false,
        allowsScrolling: Bool = false,
        isRendered: Bool = true,
        onLoad: (() -> Void)? = nil
    ) {
        self.html = html
        self.policy = policy
        self.viewport = viewport
        self.contentHeightCSS = contentHeightCSS
        self.inspector = inspector
        self.allowsInteraction = allowsInteraction
        self.allowsScrolling = allowsScrolling
        self.isRendered = isRendered
        self.onLoad = onLoad
    }

    private var renderingViewport: Viewport {
        var result = viewport
        if let contentHeightCSS, contentHeightCSS.isFinite, contentHeightCSS > 0 {
            result.height = Int(min(HTMLCaptureSize.maximumHeightCSS, ceil(contentHeightCSS)))
        }
        return result
    }

    public func makeCoordinator() -> HTMLSnapshotCoordinator {
        HTMLSnapshotCoordinator(viewport: renderingViewport)
    }

    public func makeUIView(context: Context) -> WKWebView {
        context.coordinator.session.webView
    }

    public func updateUIView(_ webView: WKWebView, context: Context) {
        let session = context.coordinator.session
        session.onLoad = onLoad
        webView.isUserInteractionEnabled = allowsInteraction
        webView.scrollView.isScrollEnabled = allowsScrolling
        webView.scrollView.showsVerticalScrollIndicator = allowsScrolling
        // A hidden web view keeps its DOM for inspection but paints nothing.
        webView.isHidden = !isRendered
        session.load(html: html, policy: policy, viewport: renderingViewport)
        session.attach(inspector)
    }

    public func sizeThatFits(_ proposal: ProposedViewSize, uiView: WKWebView, context: Context) -> CGSize? {
        HTMLWebViewFactory.size(of: renderingViewport)
    }

    public static func dismantleUIView(_ webView: WKWebView, coordinator: HTMLSnapshotCoordinator) {
        coordinator.session.tearDown()
    }
}
#endif
