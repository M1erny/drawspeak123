#if canImport(WebKit)
import DrawspeakCore
import Foundation
import Observation
import WebKit

/// Reads the DOM of the HTML snapshot an `HTMLSnapshotView` is showing.
/// All JavaScript runs in the isolated "drawspeak-probe" content world, so it
/// works with page scripts disabled and page scripts cannot observe it.
@Observable
public final class DOMInspector {
    /// True once the attached web view finished loading its document.
    public private(set) var isReady = false
    /// Viewport of the attached document; probe bounds are normalized by it.
    public private(set) var viewport: Viewport?

    @ObservationIgnored private weak var webView: WKWebView?

    public init() {}

    /// Elements under a normalized point: the hit-to-root chain of the topmost
    /// element first, then the chains of elements underneath it.
    public func probe(at point: NPoint) async throws -> DOMProbeResult {
        let (webView, viewport) = try readyTarget()
        let point = point.clamped()
        let arguments: [String: Any] = [
            "x": point.x,
            "y": point.y,
            "width": Double(viewport.width),
            "height": Double(viewport.height),
        ]
        let value = try await webView.callAsyncJavaScript(
            DOMProbeScript.probeBody,
            arguments: arguments,
            in: nil,
            contentWorld: DOMProbeScript.world
        )
        guard let json = value as? String else { throw HTMLKitError.invalidProbeResponse }
        do {
            return try JSONDecoder().decode(DOMProbeResult.self, from: Data(json.utf8))
        } catch {
            throw HTMLKitError.invalidProbeResponse
        }
    }

    /// SHA-256 hex of `document.documentElement.outerHTML` as rendered now,
    /// without the probe's own viewport tag.
    public func renderHash() async throws -> String {
        let (webView, _) = try readyTarget()
        let value = try await webView.callAsyncJavaScript(
            DOMProbeScript.serializedDocumentBody,
            in: nil,
            contentWorld: DOMProbeScript.world
        )
        guard let html = value as? String else { throw HTMLKitError.invalidProbeResponse }
        return BlobStore.sha256Hex(Data(html.utf8))
    }

    /// Waits for web fonts and one rendered frame (bounded in the probe).
    func settle() async throws {
        let (webView, _) = try readyTarget()
        _ = try await webView.callAsyncJavaScript(DOMProbeScript.settleBody, in: nil, contentWorld: DOMProbeScript.world)
    }

    func attach(_ webView: WKWebView, viewport: Viewport, isReady: Bool) {
        self.webView = webView
        self.viewport = viewport
        self.isReady = isReady
    }

    func markReady(for webView: WKWebView) {
        guard webView === self.webView else { return }
        isReady = true
    }

    func detach(from webView: WKWebView) {
        guard webView === self.webView else { return }
        self.webView = nil
        viewport = nil
        isReady = false
    }

    private func readyTarget() throws -> (WKWebView, Viewport) {
        guard isReady, let webView, let viewport else { throw HTMLKitError.inspectorNotReady }
        return (webView, viewport)
    }
}
#endif
