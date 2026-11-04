import DrawspeakCore
import Foundation
import Testing
@testable import HTMLKit

struct DOMProbeResultTests {
    /// The probe returns this JSON shape; it must decode into Core types.
    @Test func decodesProbeJSON() throws {
        let json = """
        {"layers":[[
          {"label":"Pay Label","tagName":"span","locator":{"strategy":"data-review-id","value":"pay-label"},
           "bounds":{"x":0.1,"y":0.5,"width":0.2,"height":0.1}},
          {"label":"<body>","tagName":"body","locator":{"strategy":"css-path","value":"body"},
           "bounds":{"x":0,"y":0,"width":1,"height":1}}
        ],[
          {"label":"main","tagName":"main","locator":{"strategy":"id","value":"main"},
           "bounds":{"x":0,"y":0,"width":1,"height":0.5}}
        ]]}
        """
        let result = try JSONDecoder().decode(DOMProbeResult.self, from: Data(json.utf8))
        #expect(result.layers.count == 2)
        #expect(result.layers[0].first?.locator == DOMLocator(strategy: .dataReviewId, value: "pay-label"))
        #expect(result.layers[0].last?.locator.strategy == .cssPath)
        #expect(result.layers[1].first?.locator.displayText == "#main")
        #expect(!result.isEmpty)
        #expect(DOMProbeResult(layers: []).isEmpty)
    }

    #if canImport(WebKit)
    @MainActor
    @Test func probeScriptIsBundled() {
        let source = DOMProbeScript.source
        #expect(source.contains("elementsFromPoint"))
        #expect(DOMProbeScript.probeBody.hasSuffix("return globalThis.__drawspeakProbe.probe(x, y, width, height);"))
        #expect(DOMProbeScript.worldName == "drawspeak-probe")
    }
    #endif
}
