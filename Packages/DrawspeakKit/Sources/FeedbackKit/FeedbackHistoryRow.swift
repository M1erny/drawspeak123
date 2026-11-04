import SwiftUI
import DrawspeakCore

struct FeedbackHistoryRow: View {
    let workspace: Workspace
    let canvasId: UUID
    let entry: OutboxEntry
    @State private var busy = false
    @State private var notice: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(String(entry.id.suffix(12))).font(.headline).textSelection(.enabled)
            Text("\(entry.items.count) comments · \(entry.thread.displayName)").font(.subheadline)
            Text(entry.state.feedbackLabel).font(.caption.bold()).padding(6).background(.quaternary, in: .capsule)
            if let receipt = entry.receipt { Text(receipt.acknowledgedAt, format: .dateTime.month().day().hour().minute()).font(.caption) }
            if let status = entry.agentStatus { Text("Agent: \(status)").font(.subheadline) }
            switch entry.state {
            case .deliveryUnknown:
                Button("Check Thread") { Task { await check() } }.disabled(busy).frame(minHeight: 44)
            case .readyToSend:
                Text("If a previous delivery was uncertain, sending again might duplicate it if the thread check was wrong.").font(.caption)
                Button("Send") { Task { await send() } }.disabled(busy).frame(minHeight: 44)
            case .failed(let reason):
                Text(reason).foregroundStyle(.red)
                Button("Try Again") { Task { await send() } }.disabled(busy).frame(minHeight: 44)
            case .uploading(let done, let total): ProgressView(value: Double(done), total: Double(max(total, 1)))
            case .sending: ProgressView("Sending…")
            case .sent: EmptyView()
            }
            if busy { ProgressView() }
            if let notice { Text(notice).font(.subheadline).foregroundStyle(.red) }
        }.padding(.vertical, 6)
    }
    private func check() async {
        guard !busy else { return }
        busy = true
        defer { busy = false }
        let result = await workspace.reconcile(batchId: entry.id, canvasId: canvasId)
        notice = result == .notFound ? "No message found. A resend may duplicate delivery if the thread check was wrong." : result == .unavailable ? "Could not check the thread. Reconnect and try again." : nil
        await workspace.saveNow()
    }
    private func send() async {
        guard !busy else { return }
        busy = true; notice = nil
        defer { busy = false }
        do {
            if !workspace.hasStagedPayload(batchId: entry.id) {
                guard var canvas = workspace.canvas(canvasId), entry.items.allSatisfy({ item in canvas.notes.contains { $0.id == item.noteId } }),
                      entry.items.allSatisfy({ item in canvas.snapshots.contains { $0.id == item.snapshotId && workspace.isSourceAvailable($0) } }) else {
                    notice = "Open the draft again to rebuild"; return
                }
                // Restore frozen revisions into a value copy, never into the live workspace.
                canvas.notes = entry.items.map { item in
                    Note(id: item.noteId, ordinal: item.ordinal, snapshotId: item.snapshotId, shape: item.shape,
                         domTarget: item.domTarget, text: item.text, textSource: .typed, revision: item.revision,
                         lastSentRevision: entry.isRepeat ? item.revision : nil, createdAt: entry.createdAt, updatedAt: entry.createdAt)
                }
                let package = FeedbackPackageBuilder.build(canvas: canvas, noteIds: Set(entry.items.map(\.noteId)), thread: entry.thread, batchId: entry.id, now: entry.createdAt)
                let attachments = try await FeedbackPayloadBuilder.attachments(for: package, blobs: workspace.blobs)
                workspace.stagePayload(batchId: entry.id, text: FeedbackPackageBuilder.messageText(for: package), attachments: attachments)
            }
            await workspace.deliver(batchId: entry.id, canvasId: canvasId)
            await workspace.saveNow()
            notice = workspace.lastSaveError
        } catch { notice = error.localizedDescription }
    }
}
