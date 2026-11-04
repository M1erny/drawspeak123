#if canImport(UIKit)
import DrawspeakCore
import UIKit
import WebKit

/// Hosts a capture web view in a window behind the app's own windows, so
/// WebKit renders frames and snapshots while nothing becomes visible or
/// interactive. Without a connected scene the web view stays windowless.
final class HTMLOffscreenHost {
    private let webView: WKWebView
    private var window: UIWindow?

    init(webView: WKWebView, viewport: Viewport) {
        self.webView = webView
        let frame = CGRect(origin: .zero, size: HTMLWebViewFactory.size(of: viewport))
        webView.frame = frame

        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        guard let scene = scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first else { return }
        let window = UIWindow(windowScene: scene)
        window.frame = frame
        window.windowLevel = UIWindow.Level(rawValue: UIWindow.Level.normal.rawValue - 1)
        window.backgroundColor = .clear
        window.isUserInteractionEnabled = false
        window.accessibilityElementsHidden = true
        let controller = UIViewController()
        controller.view.frame = frame
        controller.view.addSubview(webView)
        window.rootViewController = controller
        window.isHidden = false
        self.window = window
    }

    func remove() {
        webView.removeFromSuperview()
        window?.isHidden = true
        window?.rootViewController = nil
        window = nil
    }
}
#endif
