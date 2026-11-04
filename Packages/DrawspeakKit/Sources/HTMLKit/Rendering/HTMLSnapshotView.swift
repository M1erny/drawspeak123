#if canImport(UIKit)
import DrawspeakCore
import SwiftUI
import WebKit

/// Renders one HTML version at exactly `viewport.width × viewport.height` CSS
/// pixels in an isolated, offline web view. Scale it with `scaleEffect` to fit
/// the canvas; the web view itself never zooms or bounces.
public struct HTMLSnapshotView: UIViewRepresentable {
    let html: Data
    let policy: RenderPolicy
    let viewport: Viewport
    let inspector: DOMInspector?
    let allowsInteraction: Bool
    let onLoad: (() -> Void)?

    public init(
        html: Data,
        policy: RenderPolicy,
        viewport: Viewport,
        inspector: DOMInspector? = nil,
        allowsInteraction: Bool = false,
        onLoad: (() -> Void)? = nil
    ) {
        self.html = html
        self.policy = policy
        self.viewport = viewport
        self.inspector = inspector
        self.allowsInteraction = allowsInteraction
        self.onLoad = onLoad
    }

    public func makeCoordinator() -> HTMLSnapshotCoordinator {
        HTMLSnapshotCoordinator(viewport: viewport)
    }

    public func makeUIView(context: Context) -> WKWebView {
        context.coordinator.session.webView
    }

    public func updateUIView(_ webView: WKWebView, context: Context) {
        let session = context.coordinator.session
        session.onLoad = onLoad
        webView.isUserInteractionEnabled = allowsInteraction
        webView.scrollView.isScrollEnabled = allowsInteraction
        session.load(html: html, policy: policy, viewport: viewport)
        session.attach(inspector)
    }

    public func sizeThatFits(_ proposal: ProposedViewSize, uiView: WKWebView, context: Context) -> CGSize? {
        HTMLWebViewFactory.size(of: viewport)
    }

    public static func dismantleUIView(_ webView: WKWebView, coordinator: HTMLSnapshotCoordinator) {
        coordinator.session.tearDown()
    }
}
#endif
