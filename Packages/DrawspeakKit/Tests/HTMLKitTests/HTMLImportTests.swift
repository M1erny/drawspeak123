import DrawspeakCore
import Foundation
import Testing
@testable import HTMLKit

struct HTMLImportTests {
    private func inspect(_ html: String) -> HTMLImportInfo {
        HTMLImport.inspect(Data(html.utf8))
    }

    @Test func readsTheTitle() {
        let info = inspect("<html><head><TITLE lang=en>\n  Checkout &amp; Pay\n</TITLE></head><body></body></html>")
        #expect(info.title == "Checkout & Pay")
    }

    @Test func missingOrEmptyTitleIsNil() {
        #expect(inspect("<html><body>Hi</body></html>").title == nil)
        #expect(inspect("<title>   </title>").title == nil)
    }

    @Test func detectsScripts() {
        #expect(inspect("<body><SCRIPT src=app.js></SCRIPT></body>").containsScripts)
        #expect(inspect("<body><script type=\"module\">run()</script></body>").containsScripts)
        #expect(inspect("<button onclick=\"pay()\">Pay</button>").containsScripts)
        #expect(!inspect("<body><p>A description of scripts and onboarding.</p></body>").containsScripts)
        #expect(!inspect("<body><noscript>off</noscript><p class=\"script\">x</p></body>").containsScripts)
    }

    @Test func defaultsToTheDefaultHTMLViewport() {
        #expect(inspect("<html><body></body></html>").suggestedViewport == .defaultHTML)
        let deviceWidth = "<meta name=\"viewport\" content=\"width=device-width,initial-scale=1\">"
        #expect(inspect(deviceWidth).suggestedViewport == .defaultHTML)
    }

    @Test func readsTheMetaViewportWidth() {
        let viewport = inspect("<head><meta name=\"viewport\" content=\"width=330, initial-scale=1\"></head>").suggestedViewport
        #expect(viewport == Viewport(width: 330, height: Viewport.defaultHTML.height, deviceScaleFactor: 2))
        let reversed = inspect("<meta content='initial-scale=1,width=414' name='viewport'>").suggestedViewport
        #expect(reversed.width == 414)
        let other = inspect("<meta name=\"description\" content=\"width=500\">").suggestedViewport
        #expect(other == .defaultHTML)
    }

    @Test func reviewViewportOnHtmlOrBodyWins() {
        let onHTML = inspect("<html data-review-viewport=\"330x480\"><head><meta name=viewport content=\"width=390\"></head></html>")
        #expect(onHTML.suggestedViewport == Viewport(width: 330, height: 480, deviceScaleFactor: 2))
        let onBody = inspect("<html><body class=\"x\" data-review-viewport='1024 × 768'></body></html>")
        #expect(onBody.suggestedViewport == Viewport(width: 1024, height: 768, deviceScaleFactor: 2))
    }

    @Test func ignoresImplausibleSizes() {
        #expect(inspect("<html data-review-viewport=\"10x10\"></html>").suggestedViewport == .defaultHTML)
        #expect(inspect("<meta name=viewport content=\"width=99999\">").suggestedViewport == .defaultHTML)
        #expect(inspect("<div data-review-viewport=\"330x480\"></div>").suggestedViewport == .defaultHTML)
    }

    static let fixture = URL(filePath: #filePath)
        .deletingLastPathComponent()
        .appending(path: "../../../../prototype/fixtures/stacked-components.html")
        .standardized

    @Test(.enabled(if: FileManager.default.fileExists(atPath: HTMLImportTests.fixture.path(percentEncoded: false))))
    func readsTheStackedFixture() throws {
        let info = HTMLImport.inspect(try Data(contentsOf: Self.fixture))
        #expect(info.title == "Stacked component fixture")
        #expect(!info.containsScripts)
        #expect(info.suggestedViewport == .defaultHTML)
    }
}
