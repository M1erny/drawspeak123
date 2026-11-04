import DrawspeakCore
import Foundation
import Testing

@Suite struct PulledBundleTests {
    private let html = "<!doctype html><html><head><title>Checkout</title></head><body>Pay</body></html>"
    private func canvas() -> ReviewCanvas {
        ReviewCanvas(projectId: UUID(), title: "Review", screens: [Screen(id: "checkout", title: "Checkout", origin: WorldPoint(x: 0, y: 0))], createdAt: .now, updatedAt: .now)
    }
    private func reply(_ rows: String, blocks: String, schema: Int = 1) -> String {
        "~~~JSON DRAWSPEAK-MANIFEST\n{\"schemaVersion\":\(schema),\"snapshots\":[\(rows)]}\n~~~\n" + blocks
    }
    @Test func strictVariantsAndDefaults() {
        for attr in ["path='a.html'", "path=\"a.html\"", "path=a.html"] {
            let result = PulledBundleReader.read(reply("{\"screenId\":\"checkout\",\"htmlPath\":\"a.html\"}", blocks: "```DRAWSPEAK-FILE \(attr)\n\(html)\n```"), canvas: canvas())
            #expect(result.issues.isEmpty)
            #expect(result.entries.count == 1)
            #expect(result.entries.first?.html == Data(html.utf8))
            #expect(result.entries.first?.iteration == 1)
            #expect(result.entries.first?.widthPx == 780)
            #expect(result.entries.first?.heightPx == 1688)
            #expect(result.entries.first?.role == .proposal)
            #expect(result.entries.first?.snapshotId == "checkout-a-\(BlobStore.sha256Hex(Data(html.utf8)).prefix(10))")
        }
    }
    @Test func manifestHTMLByHintAndOrder() {
        let text = reply("{\"htmlPath\":\"a.html\"},{\"htmlPath\":\"b.html\"}", blocks: "```html\n<!-- path: b.html -->\(html)\n```\n```html\n<html data-review-path='a.html'></html>\n```")
        let result = PulledBundleReader.read(text, canvas: canvas())
        #expect(result.entries.count == 2)
        #expect(String(data: result.entries[0].html, encoding: .utf8)?.contains("data-review-path") == true)
        let ordered = PulledBundleReader.read(reply("{\"htmlPath\":\"a.html\"}", blocks: "```html\n\(html)\n```"), canvas: canvas())
        #expect(ordered.entries.count == 1)
    }
    @Test func sloppyAgentReplyAndHints() {
        let text = "Here is the updated checkout. I moved the total above the button.\n```html\n\(html)\n```\nLet me know what you think."
        let result = PulledBundleReader.read(text, canvas: canvas())
        #expect(result.entries.first?.screenId == "checkout")
        #expect(result.entries.first?.proposalId == "a")
        #expect(result.diagnosis == nil)
        let hinted = PulledBundleReader.read("```html\n<html data-review-screen='Checkout' data-review-proposal='c' data-review-viewport='1024x768@1'></html>\n```", canvas: canvas())
        #expect(hinted.entries.first?.proposalId == "c")
        #expect(hinted.entries.first?.viewport == Viewport(width: 1024, height: 768))
    }
    @Test func hashMismatchIsNonBlocking() {
        let result = PulledBundleReader.read(reply("{\"htmlPath\":\"a.html\",\"htmlSha256\":\"wrong\"}", blocks: "````drawspeak-file path=a.html\n\(html)\n````"), canvas: canvas())
        #expect(result.entries.count == 1)
        #expect(result.issues.contains { $0.message.contains("hash differs, imported the text as received") })
    }
    @Test func rejectsTraversalSchemaOversizeAndFragments() {
        let unsafe = PulledBundleReader.read(reply("{\"htmlPath\":\"../a.html\"}", blocks: "```html\n\(html)\n```"), canvas: canvas())
        #expect(unsafe.entries.isEmpty)
        #expect(!unsafe.issues.isEmpty)
        #expect(PulledBundleReader.read(reply("{}", blocks: "```html\n\(html)\n```", schema: 2), canvas: canvas()).entries.isEmpty)
        #expect(PulledBundleReader.read("```drawspeak-file path=../x\n\(html)\n```", canvas: canvas()).entries.isEmpty)
        #expect(PulledBundleReader.read("```html\n<div>fragment</div>\n```", canvas: canvas()).entries.isEmpty)
        let huge = "<html>" + String(repeating: "a", count: 2 * 1024 * 1024) + "</html>"
        #expect(PulledBundleReader.read("```html\n\(huge)\n```", canvas: canvas()).entries.isEmpty)
    }
    @Test func limitsAndNoContentDiagnosis() {
        let many = (0..<14).map { "```html\n<html>\($0)</html>\n```" }.joined(separator: "\n")
        #expect(PulledBundleReader.read(many, canvas: canvas()).entries.count == 12)
        #expect(PulledBundleReader.read("Drawspeak manifest is ready in my local files.", canvas: canvas()).diagnosis?.contains("no HTML block") == true)
        #expect(PulledBundleReader.read("Hello", canvas: canvas()).diagnosis == nil)
        var empty = canvas(); empty.screens = []
        let result = PulledBundleReader.read("```html\n\(html)\n```", canvas: empty)
        #expect(result.entries.first?.screenTitle == "From Thread")
    }
    @Test func nextIterationAndViewportMeta() {
        let text = reply("{\"proposalId\":\"a\",\"iteration\":3},{\"proposalId\":\"a\"}", blocks: "```html\n\(html)\n```\n```html\n<html><meta content='width=800,height=600' name='viewport'></html>\n```")
        let result = PulledBundleReader.read(text, canvas: canvas())
        #expect(result.entries.map(\.iteration) == [3, 4])
        #expect(result.entries.last?.viewport.width == 800)
    }
    @Test func parentChainsAreSortedAndCyclesRejected() {
        let blocks = "```html\n<html>child</html>\n```\n```html\n<html>parent</html>\n```"
        let rows = "{\"snapshotId\":\"child\",\"proposalId\":\"a\",\"parentSnapshotId\":\"parent\"},{\"snapshotId\":\"parent\",\"proposalId\":\"a\"}"
        let sorted = PulledBundleReader.read(reply(rows, blocks: blocks), canvas: canvas())
        #expect(sorted.entries.map(\.snapshotId) == ["parent", "child"])
        let cyclicRows = rows.replacingOccurrences(of: "\"snapshotId\":\"parent\",", with: "\"snapshotId\":\"parent\",\"parentSnapshotId\":\"child\",")
        let cyclic = PulledBundleReader.read(reply(cyclicRows, blocks: blocks), canvas: canvas())
        #expect(cyclic.entries.isEmpty)
        #expect(cyclic.issues.contains { $0.message.contains("cycle") })
    }
    @Test func nextFreeProposalAndTrailingNewlineBytes() {
        var target = canvas()
        target.screens[0].proposalOrder = ["a", "b"]
        let result = PulledBundleReader.read("~~~html\n<html></html>\n\n~~~", canvas: target)
        #expect(result.entries.first?.proposalId == "c")
        #expect(result.entries.first?.html == Data("<html></html>\n".utf8))
        let infoAfter = PulledBundleReader.read(reply("{}", blocks: "```html\n<html></html>\n```").replacingOccurrences(of: "JSON DRAWSPEAK-MANIFEST", with: "drawspeak-manifest json"), canvas: target)
        #expect(infoAfter.entries.count == 1)
    }

    @Test func titleHintCanMatchAfterUnrecognizedScreenHint() {
        var target = canvas()
        target.screens.insert(Screen(id: "other", title: "Other", origin: WorldPoint(x: 0, y: 0)), at: 0)
        let result = PulledBundleReader.read("```html\n<html data-review-screen='unknown'><title>Checkout</title><meta name=viewport width=800 height=600></html>\n```", canvas: target)
        #expect(result.entries.first?.screenId == "checkout")
        #expect(result.entries.first?.viewport.width == 800)
        #expect(result.entries.first?.viewport.height == 600)
    }

}
