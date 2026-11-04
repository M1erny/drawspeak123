import SwiftUI
import DrawspeakCore

/// Isolated synthetic data. No account, network service, or user library is opened.
enum FeedbackPreviewFixtures {
    static func workspace() async -> Workspace {
        let root = FileManager.default.temporaryDirectory.appending(path: "Drawspeak-feedback-preview-\(UUID())")
        let blobs = BlobStore(root: root.appending(path: "blobs"))
        let store = LibraryStore(fileURL: root.appending(path: "library.json"))
        let now = Date.now
        let thread = ThreadBinding(hostURL: URL(string: "https://preview.example.test")!, threadId: "fixture-thread", threadTitle: "iPad review", projectId: nil, projectTitle: "Drawspeak")
        let workspace = Workspace(document: LibraryDocument(), blobs: blobs, store: store)
        _ = workspace.createCanvas(title: "Checkout review", thread: thread)
        let renderer = ImageRenderer(content: FeedbackFixtureImage().frame(width: 640, height: 480))
        renderer.scale = 1
        if let image = renderer.cgImage {
            if let data = try? await FeedbackImageWorker.encode(image),
               let snapshot = try? workspace.importArtifact(data: data, kind: .image, contentType: "image/png", fileName: "Checkout.png", pixelSize: (640, 480), target: .newScreen(title: "Checkout")) {
                for (index, text) in ["Give the primary action more space.", "Explain when payment is collected.", "Keep the summary visible."].enumerated() {
                    if let id = workspace.addNote(snapshotId: snapshot.id, shape: .region(NRect(x: 0.1, y: 0.15 + Double(index) * 0.22, width: 0.7, height: 0.15)), autoVoice: false) { workspace.updateNoteText(id, text: text) }
                }
            }
        }
        // Seed persisted history before initializing Workspace, which applies restart recovery.
        var document = workspace.document
        if var canvas = document.canvases.first {
            let items = canvas.notes.map(BatchItem.init(note:))
            canvas.drafts = [SavedDraft(createdAt: now, thread: thread, items: items)]
            canvas.outbox = [
                OutboxEntry(id: "fixture-ready", createdAt: now, thread: thread, items: items, isRepeat: false, state: .readyToSend),
                OutboxEntry(id: "fixture-unknown", createdAt: now, thread: thread, items: items, isRepeat: false, state: .deliveryUnknown),
                OutboxEntry(id: "fixture-failed", createdAt: now, thread: thread, items: items, isRepeat: false, state: .failed(reason: "Preview connection unavailable")),
                OutboxEntry(id: "fixture-sent", createdAt: now, thread: thread, items: items, isRepeat: false, state: .sent,
                            receipt: DeliveryReceipt(threadId: thread.threadId, messageId: "fixture-message", acknowledgedAt: now, attachmentCount: 2, confirmation: .response), agentStatus: "Idle")
            ]
            document.canvases = [canvas]
        }
        return Workspace(document: document, blobs: blobs, store: store)
    }
}

#Preview("Feedback button") {
    @Previewable @State var workspace: Workspace?
    Group {
        if let workspace { SendFeedbackButton(workspace: workspace, action: {}) }
        else { ProgressView() }
    }.task { workspace = await FeedbackPreviewFixtures.workspace() }
}
#Preview("Feedback package") {
    @Previewable @State var workspace: Workspace?
    Group {
        if let workspace, let id = workspace.currentCanvasId {
            FeedbackPreviewSheet(workspace: workspace, canvasId: id, onClose: {})
        } else { ProgressView() }
    }.task { workspace = await FeedbackPreviewFixtures.workspace() }
}
#Preview("Drafts and delivery history") {
    @Previewable @State var workspace: Workspace?
    Group {
        if let workspace, let id = workspace.currentCanvasId {
            DraftsAndHistoryView(workspace: workspace, canvasId: id, onResumeDraft: { _ in })
        } else { ProgressView() }
    }.task { workspace = await FeedbackPreviewFixtures.workspace() }
}
