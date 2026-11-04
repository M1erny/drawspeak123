import DrawspeakCore
import Foundation
import Testing

/// 1×1 PNG.
let tinyPNG = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==")!

/// The shape of the reply observed on thread 741ae2a6 ("Redesign App and Extension Flows"):
/// no bundle, only links to files the agent wrote on the Mac.
let linkedReply = """
Propozycje są gotowe do oceny. Pakietu Drawspeak nie wklejam w odpowiedź, bo jest za duży (szczegóły niżej).

## Porównanie kluczowych ekranów

![iPhone: prośby agentów](/Users/rafalw/Dev/apassy/output/ui-review-2026-11-04/screens/compare/compare-ios.png)

## Plansze

| Powierzchnia | Teraz | A | B |
|---|---|---|---|
| iPhone + Watch: konfiguracja | brak | [ios-setup](/Users/rafalw/Dev/apassy/output/ui-review-2026-11-04/prototypes/a/ios-setup.html) | [ios-setup](/Users/rafalw/Dev/apassy/output/ui-review-2026-11-04/prototypes/b/ios-setup.html) |
| Mac: sejf + AutoFill | [0.5.0](/Users/rafalw/Dev/apassy/output/ui-review-2026-11-04/baseline/mac-baseline.html) | [mac-vault](/Users/rafalw/Dev/apassy/output/ui-review-2026-11-04/prototypes/a/mac-vault.html) | [mac-vault](/Users/rafalw/Dev/apassy/output/ui-review-2026-11-04/prototypes/b/mac-vault.html) |
| Mac: prośby | [0.5.0](/Users/rafalw/Dev/apassy/output/ui-review-2026-11-04/baseline/mac-baseline.html) | x | y |

- Uzasadnienia są w [notes/](/Users/rafalw/Dev/apassy/output/ui-review-2026-11-04/notes).
- Wszystko razem: [README](/Users/rafalw/Dev/apassy/output/ui-review-2026-11-04/README.md) i [review-manifest.json](/Users/rafalw/Dev/apassy/output/ui-review-2026-11-04/review-manifest.json).
- iOS: 880 KB, [ios-bundle.txt](/Users/rafalw/Dev/apassy/output/ui-review-2026-11-04/bundles/ios-bundle.txt);
- Bare path: /Users/rafalw/Dev/apassy/output/ui-review-2026-11-04/screens/compare/compare-mac.png.
- Not a local file: [site](https://example.com/page.html), traversal [x](/Users/rafalw/Dev/apassy/../secrets/a.html).

W repo nic się nie zmieniło. Wszystko jest w `output/ui-review-2026-11-04/` (110 MB, poza gitem).
"""

private func html(_ title: String) -> Data {
    Data("<!doctype html><html><head><meta name=\"viewport\" content=\"width=1440\"><title>\(title)</title></head><body>\(title)</body></html>".utf8)
}

@Suite("Workspace file paths")
struct WorkspaceFilePathTests {
    @Test func validatesAndResolvesInsideTheRoot() {
        let root = "/Users/me/Dev/apassy"
        #expect(WorkspaceFilePath.relative("/Users/me/Dev/apassy/output/a.html", root: root) == "output/a.html")
        #expect(WorkspaceFilePath.relative("/Users/me/Dev/apassy/output/a.html", root: root + "/") == "output/a.html")
        #expect(WorkspaceFilePath.relative("output/a.html", root: root) == "output/a.html")
        #expect(WorkspaceFilePath.relative("/Users/me/Dev/apassy-other/a.html", root: root) == nil)
        #expect(WorkspaceFilePath.relative("/Users/me/Dev/apassy", root: root) == nil)
        #expect(WorkspaceFilePath.relative("/Users/me/Dev/apassy/../drawspeak/a.html", root: root) == nil)
        for unsafe in ["../a.html", "a/../../b.html", "~/a.html", "a\\b.html", "file:///a.html", "a//b.html", "./a.html", ""] {
            #expect(!WorkspaceFilePath.isAcceptable(unsafe), "\(unsafe)")
        }
        #expect(WorkspaceFilePath.sibling("prototypes/a/x.html", of: "output/r/review-manifest.json") == "output/r/prototypes/a/x.html")
        #expect(WorkspaceFilePath.sibling("x.html", of: "review-manifest.json") == "x.html")
        #expect(WorkspaceFilePath.sibling("../x.html", of: "output/review-manifest.json") == nil)
        #expect(WorkspaceFilePath.sibling("/etc/x.html", of: "output/review-manifest.json") == nil)
    }
}

@MainActor
@Suite("Pull from workspace files")
struct WorkspacePullTests {
    @Test func pointerBlockNamesTheManifest() {
        let canvas = ReviewCanvas(projectId: UUID(), title: "R", createdAt: fixedDate, updatedAt: fixedDate)
        let fenced = "Boards are on the Mac.\n\n```drawspeak-bundle path=\"output/ui-review/review-manifest.json\"\n```\n"
        #expect(PulledBundleReader.read(fenced, canvas: canvas).remote == .manifest(path: "output/ui-review/review-manifest.json"))
        #expect(PulledBundleReader.read(fenced, canvas: canvas).diagnosis == nil)
        let inline = "Done: `drawspeak-bundle path=\"/Users/me/Dev/app/output/r/review-manifest.json\"`"
        #expect(PulledBundleReader.read(inline, canvas: canvas).remote == .manifest(path: "/Users/me/Dev/app/output/r/review-manifest.json"))
        let unsafe = PulledBundleReader.read("```drawspeak-bundle path=\"../x/review-manifest.json\"\n```", canvas: canvas)
        #expect(unsafe.remote == nil)
        #expect(unsafe.issues.contains { $0.message.contains("unsafe") })
    }

    @Test func linkedFilesInTheObservedReplyShape() {
        let files = PulledBundleReader.linkedFiles(in: linkedReply)
        let base = "/Users/rafalw/Dev/apassy/output/ui-review-2026-11-04/"
        #expect(files.map(\.path) == [
            "screens/compare/compare-ios.png", "prototypes/a/ios-setup.html", "prototypes/b/ios-setup.html",
            "baseline/mac-baseline.html", "prototypes/a/mac-vault.html", "prototypes/b/mac-vault.html",
            "screens/compare/compare-mac.png",
        ].map { base + $0 })
        #expect(files.map(\.kind) == [.image, .html, .html, .html, .html, .html, .image])
        let canvas = ReviewCanvas(projectId: UUID(), title: "R", createdAt: fixedDate, updatedAt: fixedDate)
        #expect(PulledBundleReader.read(linkedReply, canvas: canvas).remote == nil, "tolerant mode is opt-in")
        #expect(PulledBundleReader.read(linkedReply, canvas: canvas, linkedFiles: true).remote == .files(files))
    }

    @Test func linkedFilesImportAsProposalsBaselinesAndImages() async throws {
        let ws = makeWorkspace()
        let canvasId = try #require(ws.currentCanvasId)
        let base = "/Users/rafalw/Dev/apassy/output/ui-review-2026-11-04/"
        var files: [String: Data] = [:]
        for path in ["prototypes/a/ios-setup.html", "prototypes/b/ios-setup.html", "baseline/mac-baseline.html", "prototypes/a/mac-vault.html", "prototypes/b/mac-vault.html"] {
            files[base + path] = html(path)
        }
        files[base + "screens/compare/compare-ios.png"] = tinyPNG
        files[base + "screens/compare/compare-mac.png"] = tinyPNG + Data([0])
        let log = CallLog()
        let older = ThreadMessage(id: "m0", role: "assistant", text: "Earlier: [draft](/Users/rafalw/Dev/apassy/output/old/draft.html)", createdAt: fixedDate, attachments: [])
        let latest = ThreadMessage(id: "m1", role: "assistant", text: linkedReply, createdAt: fixedDate, attachments: [])
        ws.threads = FakeThreadService(messages: [older, latest], log: log, workspaceFiles: files)

        let report = await ws.pull(canvasId: canvasId, captureHTML: { _, _, _ in (tinyPNG, 1, 1) })

        #expect(report.importedSnapshots == 7, "\(report.issues)")
        #expect(!log.calls.contains { $0.contains("old/draft.html") }, "linked files only from the latest reply")
        let canvas = try #require(ws.currentCanvas)
        let setup = canvas.snapshots.filter { $0.screenId == "ios-setup" }
        #expect(Set(setup.compactMap(\.proposalId)) == ["a", "b"])
        #expect(setup.allSatisfy { $0.role == .proposal && $0.kind == .html && $0.iteration == 1 })
        #expect(canvas.screens.first { $0.id == "ios-setup" }?.title == "ios-setup")
        let baseline = try #require(canvas.snapshots.first { $0.screenId == "mac-baseline" })
        #expect(baseline.role == .baseline)
        let images = canvas.snapshots.filter { $0.kind == .image }
        #expect(images.count == 2)
        #expect(images.allSatisfy { $0.role == .proposal && $0.widthPx == 1 && $0.heightPx == 1 })
        #expect(canvas.pulledMessageIds == ["m1"])

        let again = await ws.pull(canvasId: canvasId, captureHTML: { _, _, _ in (tinyPNG, 1, 1) })
        #expect(again.importedSnapshots == 0)
    }

    @Test func pointerManifestDownloadsItsFilesRelativeToTheManifest() async throws {
        let ws = makeWorkspace()
        let canvasId = try #require(ws.currentCanvasId)
        let page = html("Checkout")
        let manifest: [String: Any] = ["schemaVersion": 1, "reviewId": "r", "threadId": "thread-1", "status": "ready_for_review", "snapshots": [
            ["snapshotId": "checkout-a-001", "screenId": "checkout", "screenTitle": "Checkout", "role": "proposal", "proposalId": "a", "iteration": 1,
             "artifactKind": "html", "htmlPath": "prototypes/a/index.html", "htmlSha256": BlobStore.sha256Hex(page),
             "viewport": ["width": 390, "height": 844, "deviceScaleFactor": 2], "renderPolicy": "static-no-script"],
            ["snapshotId": "checkout-b-001", "screenId": "checkout", "role": "proposal", "proposalId": "b", "iteration": 1,
             "artifactKind": "image", "imagePath": "screens/checkout-b.png", "sha256": BlobStore.sha256Hex(tinyPNG)],
        ]]
        let log = CallLog()
        ws.threads = FakeThreadService(
            messages: [ThreadMessage(id: "m1", role: "assistant", text: "Ready.\n```drawspeak-bundle path=\"output/r/review-manifest.json\"\n```", createdAt: fixedDate, attachments: [])],
            log: log,
            workspaceFiles: [
                "output/r/review-manifest.json": try JSONSerialization.data(withJSONObject: manifest),
                "output/r/prototypes/a/index.html": page,
                "output/r/screens/checkout-b.png": tinyPNG,
            ]
        )

        let report = await ws.pull(canvasId: canvasId, captureHTML: { _, _, _ in (tinyPNG, 1, 1) })

        #expect(report.importedSnapshots == 2, "\(report.issues)")
        #expect(report.issues.isEmpty)
        #expect(log.calls.filter { $0.hasPrefix("download:") } == ["download:output/r/review-manifest.json", "download:output/r/prototypes/a/index.html", "download:output/r/screens/checkout-b.png"])
        let canvas = try #require(ws.currentCanvas)
        #expect(canvas.snapshots.first { $0.id == "checkout-a-001" }?.kind == .html)
        #expect(canvas.snapshots.first { $0.id == "checkout-b-001" }?.kind == .image)
        #expect(canvas.pulledMessageIds == ["m1"])
    }

    @Test func unavailableFilesStopAfterOneAttemptAndStayRetryable() async throws {
        let ws = makeWorkspace()
        let canvasId = try #require(ws.currentCanvasId)
        let log = CallLog()
        ws.threads = FakeThreadService(
            messages: [ThreadMessage(id: "m1", role: "assistant", text: linkedReply, createdAt: fixedDate, attachments: [])],
            log: log, workspaceUnavailable: WorkspaceFileUnavailable("Pair again")
        )
        let report = await ws.pull(canvasId: canvasId, captureHTML: { _, _, _ in (tinyPNG, 1, 1) })
        #expect(report.importedSnapshots == 0)
        #expect(report.issues == ["Pair again"])
        #expect(log.calls.filter { $0.hasPrefix("download:") }.count == 1)
        #expect(ws.currentCanvas?.pulledMessageIds.isEmpty == true)
    }

    @Test func missingFileKeepsTheReplyRetryable() async throws {
        let ws = makeWorkspace()
        let canvasId = try #require(ws.currentCanvasId)
        let text = "[a](/w/prototypes/a/home.html) [b](/w/prototypes/b/home.html)"
        ws.threads = FakeThreadService(messages: [ThreadMessage(id: "m1", role: "assistant", text: text, createdAt: fixedDate, attachments: [])],
                                       workspaceFiles: ["/w/prototypes/a/home.html": html("Home")])
        let report = await ws.pull(canvasId: canvasId, captureHTML: { _, _, _ in (tinyPNG, 1, 1) })
        #expect(report.importedSnapshots == 1)
        #expect(report.issues.contains { $0.hasPrefix("/w/prototypes/b/home.html:") })
        #expect(ws.currentCanvas?.pulledMessageIds.isEmpty == true)
    }

    @Test func boardWidthComesFromBodyCSSWithoutAViewportMeta() {
        let canvas = ReviewCanvas(projectId: UUID(), title: "R", createdAt: fixedDate, updatedAt: fixedDate)
        let board = Data("<!doctype html><html><head><style>*{box-sizing:border-box}\nbody{margin:0;width:1440px;max-width:none}</style></head><body></body></html>".utf8)
        let bundle = PulledBundleReader.read(linked: [LinkedFile(path: "/w/prototypes/b/ios-setup.html", kind: .html)], files: ["/w/prototypes/b/ios-setup.html": board], canvas: canvas)
        #expect(bundle.entries.first?.viewport == Viewport(width: 1440, height: 844, deviceScaleFactor: 2))
        #expect(bundle.entries.first?.proposalId == "b")
    }

    @Test func replyWithoutVersionsGivesTheReason() async throws {
        let ws = makeWorkspace()
        let canvasId = try #require(ws.currentCanvasId)
        ws.threads = FakeThreadService(messages: [ThreadMessage(id: "m1", role: "assistant", text: "The Drawspeak bundle is too large to paste.", createdAt: fixedDate, attachments: [])])
        let report = await ws.pull(canvasId: canvasId, captureHTML: { _, _, _ in (tinyPNG, 1, 1) })
        #expect(report.importedSnapshots == 0)
        #expect(report.noVersionsReason == "The reply mentions a review bundle but contains no HTML block")
    }
}
