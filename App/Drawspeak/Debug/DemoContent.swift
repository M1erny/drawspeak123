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
        let renderer = ImageRenderer(content: view)
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
