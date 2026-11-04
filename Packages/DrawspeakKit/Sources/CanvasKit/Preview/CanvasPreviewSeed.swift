#if DEBUG && canImport(UIKit)
import DrawspeakCore
import SwiftUI

/// An in-memory workspace for previews: two screens, Now with Proposal A
/// (two iterations) and Proposal B (HTML), and a few notes.
enum CanvasPreviewSeed {
    static let checkoutHTML = """
    <!doctype html><html><head><style>
    body{margin:0;font:15px -apple-system,sans-serif;color:#24374c}
    header{padding:22px 24px;border-bottom:1px solid #e5eaf0;font-weight:700}
    main{padding:24px} h1{font-size:28px;margin:0 0 8px}
    .card{background:#f1f4f8;border-radius:12px;padding:16px;margin:16px 0}
    button{width:100%;height:56px;border:0;border-radius:14px;background:#173f39;color:#fff;font-size:18px}
    </style></head><body>
    <header data-review-id="brand">north / studio</header>
    <main data-review-id="checkout">
    <h1 data-review-id="title">Checkout</h1><p>One last step. Make it yours.</p>
    <section class="card" data-review-id="summary"><strong>Everyday tote</strong><p>Slate · $48.00</p></section>
    <section class="card" data-review-id="delivery">Free delivery · arrives Nov 8–10</section>
    <button data-review-id="pay-action"><span data-review-id="pay-label">Pay $48</span></button>
    </main></body></html>
    """

    static func makeWorkspace() -> Workspace {
        let root = FileManager.default.temporaryDirectory.appending(path: "canvas-preview-\(UUID().uuidString)")
        let project = Project(name: "Preview", createdAt: .now)
        let canvas = ReviewCanvas(projectId: project.id, title: "Checkout review", createdAt: .now, updatedAt: .now)
        let workspace = Workspace(
            document: LibraryDocument(projects: [project], canvases: [canvas], lastCanvasId: canvas.id),
            blobs: BlobStore(root: root.appending(path: "blobs")),
            store: LibraryStore(fileURL: root.appending(path: "library.json"))
        )
        workspace.autoVoiceEnabled = { false }
        do {
            try seed(workspace)
        } catch {
            assertionFailure("Preview seed failed: \(error)")
        }
        if let current = workspace.currentCanvas {
            let camera = CanvasFraming.fitAll(canvas: current, viewSize: CGSize(width: 1366, height: 1024), insets: EdgeInsets())
            workspace.updateCamera(camera, canvasId: current.id)
        }
        return workspace
    }

    private static func seed(_ workspace: Workspace) throws {
        let checkoutNow = try image(workspace, MockScreenArt(title: "Your bag", subtitle: "2 items in your order", accent: .gray), target: .newScreen(title: "Checkout"))
        let screenId = checkoutNow.screenId
        _ = try image(workspace, MockScreenArt(title: "Checkout", subtitle: "Shipping calculated at payment", accent: .blue), target: .proposal(screenId: screenId, proposalId: "A"))
        let a2 = try image(workspace, MockScreenArt(title: "Checkout", subtitle: "Shipping included · no extra fees", accent: .indigo), target: .proposal(screenId: screenId, proposalId: "A"))
        let capture = MockScreenArt(title: "Checkout", subtitle: "One last step. Make it yours.", accent: .teal).pngData()
        let b1 = try workspace.importArtifact(
            data: Data(checkoutHTML.utf8),
            kind: .html,
            contentType: "text/html",
            fileName: "checkout-b.html",
            pixelSize: (width: 390, height: 844),
            viewport: Viewport(width: 390, height: 844),
            target: .proposal(screenId: screenId, proposalId: "B"),
            captureImage: capture.map { (data: $0, contentType: "image/png") }
        )
        let cartNow = try image(workspace, MockScreenArt(title: "Cart", subtitle: "Review your items", accent: .gray), target: .newScreen(title: "Cart"))
        _ = try image(workspace, MockScreenArt(title: "Cart", subtitle: "Saved for later moved up", accent: .orange), target: .proposal(screenId: cartNow.screenId, proposalId: "A"))

        note(workspace, checkoutNow.id, .region(NRect(x: 0.06, y: 0.86, width: 0.88, height: 0.09)), "The pay button looks disabled on the current screen.")
        note(workspace, a2.id, .arrow(from: NPoint(x: 0.8, y: 0.12), to: NPoint(x: 0.55, y: 0.2)), "Shipping copy is much clearer here.")
        note(workspace, a2.id, .lasso(lassoPoints(center: NPoint(x: 0.5, y: 0.35), radius: 0.12)), "")
        note(workspace, b1.id, .stroke([NPoint(x: 0.1, y: 0.3), NPoint(x: 0.3, y: 0.32), NPoint(x: 0.5, y: 0.29)]), "Underline this headline.")
        workspace.focusedNoteId = nil
    }

    private static func image(_ workspace: Workspace, _ art: MockScreenArt, target: Workspace.ImportTarget) throws -> Snapshot {
        try workspace.importArtifact(
            data: art.pngData() ?? Data(),
            kind: .image,
            contentType: "image/png",
            fileName: "\(art.title).png",
            pixelSize: (width: 390, height: 844),
            target: target
        )
    }

    private static func note(_ workspace: Workspace, _ snapshotId: String, _ shape: AnnotationShape, _ text: String) {
        guard let id = workspace.addNote(snapshotId: snapshotId, shape: shape, autoVoice: false), !text.isEmpty else { return }
        workspace.updateNoteText(id, text: text)
    }

    private static func lassoPoints(center: NPoint, radius: Double) -> [NPoint] {
        (0..<24).map { step in
            let angle = Double(step) / 24 * 2 * .pi
            return NPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius * 0.46)
        }
    }
}
#endif
