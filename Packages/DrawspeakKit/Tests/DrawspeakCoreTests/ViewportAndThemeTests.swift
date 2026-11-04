import DrawspeakCore
import Foundation
import SwiftUI
import Testing

@MainActor
@Suite("Viewport bounds (F12) and theme colors")
struct ViewportAndThemeTests {
    private func manifest(viewport: [String: Any], widthPx: Int = 390, heightPx: Int = 844) throws -> ReviewManifest {
        let bytes = Data("img".utf8)
        let entry: [String: Any] = [
            "snapshotId": "v", "screenId": "s", "role": "baseline", "iteration": 0, "imagePath": "v.png",
            "sha256": BlobStore.sha256Hex(bytes), "widthPx": widthPx, "heightPx": heightPx, "viewport": viewport,
        ]
        let dict: [String: Any] = ["schemaVersion": 1, "reviewId": "r", "status": "ready_for_review", "snapshots": [entry]]
        return try ReviewManifest.decode(JSONSerialization.data(withJSONObject: dict))
    }

    private func validate(_ m: ReviewManifest) -> (valid: [ReviewManifest.Entry], issues: [ManifestIssue]) {
        let canvas = ReviewCanvas(projectId: UUID(), title: "C", createdAt: fixedDate, updatedAt: fixedDate)
        return ManifestValidator.validate(m, files: ["v.png": Data("img".utf8)], canvas: canvas)
    }

    struct ViewportCase: Sendable, CustomStringConvertible {
        var width: Int
        var height: Int
        var scale: Double
        var description: String { "\(width)x\(height)@\(scale)" }
    }

    @Test(arguments: [
        ViewportCase(width: 390, height: 844, scale: 1e308),
        ViewportCase(width: 0, height: 844, scale: 2),
        ViewportCase(width: 5000, height: 844, scale: 1),
        ViewportCase(width: 390, height: 844, scale: 0.1),
        ViewportCase(width: 4096, height: 4096, scale: 2),
    ])
    func outOfRangeViewportIsRejected(_ viewport: ViewportCase) throws {
        let result = validate(try manifest(viewport: ["width": viewport.width, "height": viewport.height, "deviceScaleFactor": viewport.scale]))
        #expect(result.valid.isEmpty)
        #expect(result.issues.first?.snapshotId == "v")
    }

    @Test func boundedViewportIsAccepted() throws {
        let result = validate(try manifest(viewport: ["width": 390, "height": 844, "deviceScaleFactor": 3]))
        #expect(result.valid.count == 1)
        #expect(validate(try manifest(viewport: ["width": 390, "height": 844, "deviceScaleFactor": 1], widthPx: 100_000, heightPx: 100_000)).valid.isEmpty)
    }

    @Test func viewportLimitsHandleNonFiniteScale() {
        #expect(!Viewport(width: 390, height: 844, deviceScaleFactor: .nan).isWithinCaptureLimits)
        #expect(!Viewport(width: 390, height: 844, deviceScaleFactor: .infinity).isWithinCaptureLimits)
        #expect(Viewport.defaultHTML.isWithinCaptureLimits)
    }

    @Test func importRejectsAnUnboundedViewport() throws {
        let ws = makeWorkspace()
        #expect(throws: Workspace.ImportError.invalidViewport) {
            try ws.importArtifact(
                data: Data("<p>x</p>".utf8), kind: .html, contentType: "text/html", fileName: "x.html",
                pixelSize: (width: 390, height: 844), viewport: Viewport(width: 390, height: 844, deviceScaleFactor: 1e308),
                target: .newScreen(title: "X")
            )
        }
        #expect(ws.currentCanvas?.snapshots.isEmpty == true)
    }

    @Test func annotationAndActionFillAreFixedInBothAppearances() {
        var light = EnvironmentValues()
        light.colorScheme = .light
        var dark = EnvironmentValues()
        dark.colorScheme = .dark
        #expect(Theme.annotation.resolve(in: light) == Theme.annotation.resolve(in: dark))
        #expect(Theme.annotation.resolve(in: light) == Color(hex: 0xBD3048).resolve(in: light))
        #expect(Theme.actionFill.resolve(in: dark) == Color(hex: 0x1758BD).resolve(in: light))
        #expect(Theme.annotationHalo.resolve(in: dark) == Color.white.resolve(in: dark))
    }
}
