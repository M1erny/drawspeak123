#if DEBUG
import DrawspeakCore
import Foundation
import SwiftUI

/// Sample content for simulator checks (launch argument -DrawspeakSeedDemo).
@MainActor
enum DemoContent {
    /// Imports a host file given by DRAWSPEAK_IMPORT_FILE as a new screen (simulator checks).
    static func importFromEnvironment(into workspace: Workspace) {
        guard let path = ProcessInfo.processInfo.environment["DRAWSPEAK_IMPORT_FILE"],
              let data = FileManager.default.contents(atPath: path),
              let size = ImportCoordinator.pixelSize(of: data) else { return }
        _ = try? workspace.importArtifact(
            data: data, kind: .image, contentType: "image/png", fileName: (path as NSString).lastPathComponent,
            pixelSize: size, target: .newScreen(title: "Imported")
        )
    }

    /// Four canvases with threads and a current canvas with three Photo screens, for the
    /// canvas list and Add to Canvas screenshots (launch argument -DrawspeakSeedCanvases).
    static func seedCanvasList(into workspace: Workspace) {
        guard workspace.canvases.count == 1, workspace.currentCanvas?.screens.isEmpty ?? false,
              let host = URL(string: "http://localhost:3773"), let canvasId = workspace.currentCanvasId else { return }
        func binding(_ id: String, _ title: String, _ project: String) -> ThreadBinding {
            ThreadBinding(hostURL: host, threadId: id, threadTitle: title, projectId: project, projectTitle: project)
        }
        workspace.renameCanvas(canvasId, title: "Review 3")
        _ = workspace.bindThread(binding("t-e2e", "Drawspeak E2E new thread test", "Drawspeak"), to: canvasId)
        _ = workspace.createCanvas(title: "Review 5", thread: binding("t-apassy", "Redesign App and Extension", "apassy"))
        _ = workspace.createCanvas(title: "Review 3", thread: binding("t-build", "Build Drawspeak App for TestFlight", "Drawspeak"))
        let hocket = workspace.createCanvas(title: "Review 4", thread: binding("t-hocket", "Unspecified Test Request", "hocket"))
        _ = hocket
        // The last Review 3 is the working canvas, with three Photo screens.
        guard let working = workspace.canvases.first(where: { $0.thread?.threadId == "t-build" }) else { return }
        workspace.selectCanvas(working.id)
        for index in 1...3 {
            guard let data = png(title: "Photo \(index)", accent: .gray, button: "Pay"),
                  let snapshot = try? workspace.importArtifact(
                    data: data, kind: .image, contentType: "image/png", fileName: "photo-\(index).png",
                    pixelSize: (780, 1688), target: .newScreen(title: "Photo \(index)")) else { continue }
            if index == 1, let proposal = png(title: "Photo 1", accent: .blue, button: "Pay") {
                _ = try? workspace.importArtifact(
                    data: proposal, kind: .image, contentType: "image/png", fileName: "photo-1a.png",
                    pixelSize: (780, 1688), target: .proposal(screenId: snapshot.screenId, proposalId: "a"))
            }
        }
        workspace.focusedNoteId = nil
    }

    /// A photo waiting for its place on the canvas (`-DrawspeakOpen importTarget`).
    static func pendingPhoto(canvasId: UUID) -> PendingImport? {
        guard let data = png(title: "Photo", accent: .teal, button: "Pay") else { return nil }
        return PendingImport(canvasId: canvasId, fileName: "Photo.jpg", suggestedTitle: "Photo", kind: .image,
                             contentType: "image/png", data: data, pixelSize: (780, 1688), viewport: nil,
                             capture: nil, containsScripts: false)
    }

    static func seed(into workspace: Workspace) {
        guard workspace.currentCanvas?.screens.isEmpty ?? false else { return }
        guard let now = png(title: "Checkout", accent: .gray, button: "Pay"),
              let proposal = png(title: "Checkout", accent: .blue, button: "Pay 129 zł") else { return }
        guard let base = try? workspace.importArtifact(
            data: now, kind: .image, contentType: "image/png", fileName: "checkout-now.png",
            pixelSize: (780, 1688), target: .newScreen(title: "Checkout")
        ) else { return }
        _ = try? workspace.importArtifact(
            data: proposal, kind: .image, contentType: "image/png", fileName: "checkout-a1.png",
            pixelSize: (780, 1688), target: .proposal(screenId: base.screenId, proposalId: "a"),
            changeSummary: "Total shown on the pay button."
        )
        let html = Data(sampleHTML.utf8)
        _ = try? workspace.importArtifact(
            data: html, kind: .html, contentType: "text/html", fileName: "checkout-b1.html",
            pixelSize: (780, 1688), viewport: Viewport(width: 390, height: 844, deviceScaleFactor: 2),
            target: .proposal(screenId: base.screenId, proposalId: "b"), renderPolicy: .staticNoScript
        )
        workspace.addNote(snapshotId: base.id, shape: .region(NRect(x: 0.06, y: 0.875, width: 0.88, height: 0.095)), autoVoice: false)
        if let id = workspace.currentCanvas?.notes.last?.id {
            workspace.updateNoteText(id, text: "The pay button should show the total.")
        }
        workspace.focusedNoteId = nil
    }

    /// Twelve screens with sixteen comments: more than one T3 message carries (launch
    /// argument -DrawspeakSeedLarge), for screenshots of a split send.
    static func seedLargeReview(into workspace: Workspace) {
        guard workspace.currentCanvas?.screens.isEmpty ?? false else { return }
        let titles = ["Welcome", "Sign In", "Vault", "Search", "Item Detail", "Edit Item", "Share Sheet",
                      "Requests", "Answer Request", "Settings", "Lock", "Extension"]
        let comments = [
            "Make the primary button full width and pin it to the bottom.",
            "The secondary text is too light; use the standard secondary label color.",
            "Group these rows into one inset section with a header.",
            "Replace the custom back arrow with the system back button.",
        ]
        let accents: [Color] = [.blue, .indigo, .teal, .orange]
        for (index, title) in titles.enumerated() {
            guard let data = png(title: title, accent: accents[index % accents.count], button: "Continue"),
                  let snapshot = try? workspace.importArtifact(
                    data: data, kind: .image, contentType: "image/png", fileName: "screen-\(index + 1).png",
                    pixelSize: (780, 1688), target: .newScreen(title: "iPhone · \(title)")
                  ) else { continue }
            let count = index % 3 == 0 ? 2 : 1
            for offset in 0..<count {
                let y = 0.2 + Double(offset) * 0.35
                guard let id = workspace.addNote(snapshotId: snapshot.id, shape: .region(NRect(x: 0.08, y: y, width: 0.84, height: 0.12)),
                                                 autoVoice: false) else { continue }
                workspace.updateNoteText(id, text: comments[(index + offset) % comments.count])
            }
        }
        workspace.focusedNoteId = nil
    }

    private static func png(title: String, accent: Color, button: String) -> Data? {
        let view = VStack(spacing: 24) {
            Text(title).font(.largeTitle.bold())
            ForEach(0..<4) { index in
                RoundedRectangle(cornerRadius: 12).fill(.gray.opacity(0.15)).frame(height: 80)
                    .overlay { Text(verbatim: "Item \(index + 1)").font(.title3) }
            }
            Spacer()
            RoundedRectangle(cornerRadius: 16).fill(accent).frame(height: 64)
                .overlay { Text(button).font(.title2.bold()).foregroundStyle(.white) }
        }
        .padding(32)
        .frame(width: 390, height: 844)
        .background(.white)
        let renderer = ImageRenderer(content: view.environment(\.colorScheme, .light))
        renderer.scale = 2
        guard let image = renderer.uiImage else { return nil }
        return image.pngData()
    }

    static let sampleHTML = """
    <!doctype html><html data-review-viewport="390x844"><head><title>Checkout B</title>
    <style>body{font:17px -apple-system;margin:0;padding:24px;background:#fff}
    .card{border-radius:12px;background:#f1f3f6;padding:16px;margin:12px 0}
    .pay{position:fixed;left:24px;right:24px;bottom:32px;padding:18px;border-radius:16px;background:#1758bd;color:#fff;text-align:center;font-weight:700}
    .badge{position:fixed;right:32px;bottom:92px;background:#bd3048;color:#fff;border-radius:10px;padding:4px 10px;font-size:13px}</style></head>
    <body data-review-id="checkout"><h1 data-review-id="title">Checkout</h1>
    <section data-review-id="items"><div class="card" data-review-id="item-1">Wireless keyboard · 99 zł</div><div class="card" data-review-id="item-2">USB-C cable · 30 zł</div></section>
    <div class="card" data-review-id="summary"><span data-review-id="total-label">Total</span> <strong data-review-id="total">129 zł</strong></div>
    <div class="pay" data-review-id="pay-action"><span data-review-id="pay-label">Pay 129 zł</span></div>
    <div class="badge" data-review-id="promo-badge">−10% today</div></body></html>
    """
}
#endif
