import DrawspeakCore
import Foundation
import Testing

@Suite struct TextBundleParserTests {
    @Test func extractsManifestAndFiles() {
        let text = """
        Here are two proposals.
        ````drawspeak-manifest
        {"schemaVersion": 1}
        ````
        ````drawspeak-file path="prototypes/a/index.html"
        <!doctype html>
        <p>```inline```</p>
        ````
        ````drawspeak-file path="../escape.html"
        bad
        ````
        """
        let bundle = TextBundleParser.parse(text)
        #expect(bundle.manifest == Data("{\"schemaVersion\": 1}".utf8))
        #expect(bundle.files["prototypes/a/index.html"] == Data("<!doctype html>\n<p>```inline```</p>".utf8))
        #expect(bundle.files["../escape.html"] == nil)
    }

    @Test func unclosedFenceIsIgnored() {
        let bundle = TextBundleParser.parse("````drawspeak-manifest\n{}")
        #expect(bundle.manifest == nil)
    }

    @Test @MainActor func htmlEntryWithoutImageValidates() throws {
        let html = Data("<html><body data-review-id=\"root\"></body></html>".utf8)
        let manifestJSON = """
        {"schemaVersion":1,"reviewId":"r","status":"ready_for_review","snapshots":[{"snapshotId":"a-1","screenId":"s","role":"proposal","proposalId":"a","iteration":1,"artifactKind":"html","htmlPath":"a.html","htmlSha256":"\(BlobStore.sha256Hex(html))","widthPx":390,"heightPx":844,"viewport":{"width":390,"height":844,"deviceScaleFactor":2}}]}
        """
        let manifest = try ReviewManifest.decode(Data(manifestJSON.utf8))
        let canvas = ReviewCanvas(projectId: UUID(), title: "t", createdAt: .now, updatedAt: .now)
        let result = ManifestValidator.validate(manifest, files: ["a.html": html], canvas: canvas)
        #expect(result.valid.count == 1)
        #expect(result.issues.isEmpty)
    }
}
