#if canImport(WebKit)
import DrawspeakCore
import Foundation
import WebKit

/// Owns one isolated web view and loads one HTML version at a time.
/// Only the initial document navigation is allowed; every later navigation,
/// window, and network load is refused.
final class HTMLWebViewSession: NSObject, WKNavigationDelegate, WKUIDelegate {
    let webView: WKWebView
    var onLoad: (() -> Void)?
    private(set) var isLoaded = false
    private(set) var viewport: Viewport

    private let userContentController = WKUserContentController()
    private weak var inspector: DOMInspector?
    private var html: Data?
    private var policy = RenderPolicy.staticNoScript
    private var initialNavigation: WKNavigation?
    private var awaitsInitialNavigation = false
    private var rulesInstalled = false
    private var loadError: HTMLKitError?
    private var loadTask: Task<Void, Never>?
    private var loadWaiters: [CheckedContinuation<Void, any Error>] = []

    init(viewport: Viewport) {
        self.viewport = viewport
        webView = HTMLWebViewFactory.makeWebView(viewport: viewport, userContentController: userContentController)
        super.init()
        webView.navigationDelegate = self
        webView.uiDelegate = self
    }

    func attach(_ inspector: DOMInspector?) {
        guard inspector !== self.inspector else { return }
        self.inspector?.detach(from: webView)
        self.inspector = inspector
        inspector?.attach(webView, viewport: viewport, isReady: isLoaded)
    }

    /// Starts loading when the document, policy or viewport differ from the current ones.
    func load(html: Data, policy: RenderPolicy, viewport: Viewport) {
        guard html != self.html || policy != self.policy || viewport != self.viewport else { return }
        self.html = html
        self.policy = policy
        self.viewport = viewport
        isLoaded = false
        loadError = nil
        initialNavigation = nil
        awaitsInitialNavigation = false
        inspector?.attach(webView, viewport: viewport, isReady: false)
        webView.stopLoading()

        loadTask?.cancel()
        loadTask = Task { [weak self] in
            let rules: WKContentRuleList
            do {
                rules = try await HTMLContentRules.compiled()
            } catch {
                self?.failLoad(.contentRulesUnavailable)
                return
            }
            guard let self, !Task.isCancelled else { return }
            start(html: html, rules: rules)
        }
    }

    /// Returns once the current document has loaded.
    func waitUntilLoaded() async throws {
        if isLoaded { return }
        if let loadError { throw loadError }
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                loadWaiters.append(continuation)
            }
        } onCancel: {
            Task { @MainActor [weak self] in
                self?.resumeWaiters(throwing: CancellationError())
            }
        }
    }

    func tearDown() {
        loadTask?.cancel()
        loadTask = nil
        webView.stopLoading()
        inspector?.detach(from: webView)
        inspector = nil
        onLoad = nil
        resumeWaiters(throwing: CancellationError())
    }

    private func start(html: Data, rules: WKContentRuleList) {
        if !rulesInstalled {
            userContentController.add(rules)
            rulesInstalled = true
        }
        userContentController.removeAllUserScripts()
        userContentController.addUserScript(DOMProbeScript.userScript(viewport: viewport))
        awaitsInitialNavigation = true
        initialNavigation = webView.loadHTMLString(String(decoding: html, as: UTF8.self), baseURL: nil)
    }

    private func failLoad(_ error: HTMLKitError) {
        isLoaded = false
        loadError = error
        resumeWaiters(throwing: error)
    }

    private func resumeWaiters(throwing error: (any Error)?) {
        let waiters = loadWaiters
        loadWaiters.removeAll()
        for waiter in waiters {
            if let error {
                waiter.resume(throwing: error)
            } else {
                waiter.resume()
            }
        }
    }

    // MARK: WKNavigationDelegate

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        preferences: WKWebpagePreferences
    ) async -> (WKNavigationActionPolicy, WKWebpagePreferences) {
        let scheme = navigationAction.request.url?.scheme?.lowercased() ?? "about"
        let isInitialDocument = awaitsInitialNavigation
            && navigationAction.targetFrame?.isMainFrame == true
            && scheme == "about"
        guard isInitialDocument else { return (.cancel, preferences) }
        awaitsInitialNavigation = false
        preferences.allowsContentJavaScript = policy == .isolatedScripted
        #if canImport(UIKit)
        preferences.preferredContentMode = .mobile
        #endif
        return (.allow, preferences)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard navigation === initialNavigation else { return }
        isLoaded = true
        inspector?.markReady(for: webView)
        resumeWaiters(throwing: nil)
        onLoad?()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: any Error) {
        guard navigation === initialNavigation else { return }
        failLoad(.loadFailed(error.localizedDescription))
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: any Error) {
        guard navigation === initialNavigation else { return }
        failLoad(.loadFailed(error.localizedDescription))
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        inspector?.attach(webView, viewport: viewport, isReady: false)
        failLoad(.webContentTerminated)
        guard let html else { return }
        self.html = nil
        load(html: html, policy: policy, viewport: viewport)
    }

    // MARK: WKUIDelegate

    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        nil
    }

    #if canImport(UIKit)
    func webView(
        _ webView: WKWebView,
        contextMenuConfigurationFor elementInfo: WKContextMenuElementInfo
    ) async -> UIContextMenuConfiguration? {
        nil
    }
    #endif
}
#endif
