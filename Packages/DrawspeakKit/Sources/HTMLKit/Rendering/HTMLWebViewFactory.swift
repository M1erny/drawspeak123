#if canImport(WebKit)
import DrawspeakCore
import Foundation
import WebKit

/// Builds isolated web views: no persistent data, no windows, no page JavaScript
/// until a navigation explicitly allows it, and no native bridge for page scripts.
enum HTMLWebViewFactory {
    static func size(of viewport: Viewport) -> CGSize {
        CGSize(width: Double(max(viewport.width, 1)), height: Double(max(viewport.height, 1)))
    }

    static func makeWebView(viewport: Viewport, userContentController: WKUserContentController) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.userContentController = userContentController
        configuration.defaultWebpagePreferences.allowsContentJavaScript = false
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
        configuration.preferences.isElementFullscreenEnabled = false
        configuration.mediaTypesRequiringUserActionForPlayback = .all
        #if canImport(UIKit)
        configuration.defaultWebpagePreferences.preferredContentMode = .mobile
        configuration.dataDetectorTypes = []
        configuration.allowsAirPlayForMediaPlayback = false
        configuration.allowsPictureInPictureMediaPlayback = false
        #endif

        let webView = WKWebView(frame: CGRect(origin: .zero, size: size(of: viewport)), configuration: configuration)
        webView.allowsBackForwardNavigationGestures = false
        webView.allowsLinkPreview = false
        #if canImport(UIKit)
        let scrollView = webView.scrollView
        scrollView.bounces = false
        scrollView.bouncesZoom = false
        scrollView.minimumZoomScale = 1
        scrollView.maximumZoomScale = 1
        scrollView.pinchGestureRecognizer?.isEnabled = false
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        #endif
        return webView
    }
}
#endif
