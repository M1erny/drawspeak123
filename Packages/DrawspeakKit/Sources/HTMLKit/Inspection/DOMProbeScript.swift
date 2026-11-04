#if canImport(WebKit)
import DrawspeakCore
import Foundation
import WebKit

/// The probe source and the function bodies run in the isolated probe world.
enum DOMProbeScript {
    static let worldName = "drawspeak-probe"

    /// Page scripts run in `.page`; this world shares the DOM but not JavaScript globals,
    /// and it keeps running when page JavaScript is disabled.
    static var world: WKContentWorld { .world(name: worldName) }

    static let source: String = {
        guard let url = Bundle.module.url(forResource: "dom-probe", withExtension: "js"),
              let text = try? String(contentsOf: url, encoding: .utf8)
        else { fatalError("HTMLKit resource dom-probe.js is missing from the bundle.") }
        return text
    }()

    /// Every body defines the probe first, so a call works even if the user script did not run.
    static var probeBody: String { body("return globalThis.__drawspeakProbe.probe(x, y, width, height);") }
    static var serializedDocumentBody: String { body("return globalThis.__drawspeakProbe.serializedDocument();") }
    static var settleBody: String { body("return await globalThis.__drawspeakProbe.settle();") }

    /// Installed per load: defines the probe and pins the layout width to the viewport.
    static func userScript(viewport: Viewport) -> WKUserScript {
        WKUserScript(
            source: body("globalThis.__drawspeakProbe.installViewport(\(viewport.width));"),
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true,
            in: world
        )
    }

    private static func body(_ statement: String) -> String {
        source + "\n" + statement
    }
}
#endif
