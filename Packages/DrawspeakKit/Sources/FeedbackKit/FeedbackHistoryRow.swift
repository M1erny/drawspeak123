import SwiftUI
import DrawspeakCore

struct FeedbackHistoryRow: View {
    let workspace: Workspace
    let canvasId: UUID
    let entry: OutboxEntry
    @State private var busy = false
    @State private var notice: String?
    var body: some View {
        VStack(alignment: .leading, spacing: FeedbackLayout.spacing) {
            Text(entry.thread.displayName).font(.headline)
            Text(entry.createdAt, format: .relative(presentation: .named)).font(.subheadline)
            Text("^[\(entry.items.count) comment](inflect: true)", bundle: .module).font(.subheadline)
            Text(entry.state.feedbackLabel).font(.caption.bold()).padding(FeedbackLayout.rowPadding).background(.quaternary, in: .capsule)
            if let status = entry.agentStatus { Text("Agent: \(status)", bundle: .module).font(.subheadline) }
            switch entry.state {
            case .deliveryUnknown:
                Button(action: startCheck) { Text("Check Thread", bundle: .module) }.disabled(busy).frame(minHeight: Theme.minTarget)
            case .readyToSend:
                Text(String(localized: "May send twice.", bundle: .module)).font(.caption)
                Button(action: startSend) { Text("Send", bundle: .module) }.disabled(busy).frame(minHeight: Theme.minTarget)
            case .failed(let reason):
                Text(reason).foregroundStyle(.secondary)
                Button(action: startSend) { Text("Try Again", bundle: .module) }.disabled(busy).frame(minHeight: Theme.minTarget)
            case .uploading(let done, let total): ProgressView(value: Double(done), total: Double(max(total, 1)))
            case .sending: ProgressView()
            case .sent: EmptyView()
            }
            if busy { ProgressView() }
            if let notice { Text(notice).font(.subheadline).foregroundStyle(.secondary) }
        }.padding(.vertical, FeedbackLayout.rowPadding)
    }
    private func startCheck() { Task { await check() } }
    private func startSend() { Task { await send() } }
    private func check() async {
        guard !busy else { return }
        busy = true
        defer { busy = false }
        let result = await workspace.reconcile(batchId: entry.id, canvasId: canvasId)
        notice = result == .notFound ? String(localized: "Not found in thread. Sending again may duplicate it.", bundle: .module) : result == .unavailable ? String(localized: "Can't reach thread.", bundle: .module) : nil
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
                    notice = String(localized: "Open draft to resend", bundle: .module); return
                }
                // Restore frozen revisions into a value copy, never into the live workspace.
                canvas.notes = entry.items.map { item in
                    Note(id: item.noteId, ordinal: item.ordinal, snapshotId: item.snapshotId, shape: item.shape,
                         domTarget: item.domTarget, text: item.text, textSource: .typed, revision: item.revision,
                         lastSentRevision: entry.isRepeat ? item.revision : nil, createdAt: entry.createdAt, updatedAt: entry.createdAt)
                }
                let numbers = Dictionary(uniqueKeysWithValues: entry.items.map { ($0.noteId, $0.displayNumber ?? $0.ordinal) })
                let package = FeedbackPackageBuilder.build(canvas: canvas, noteIds: Set(entry.items.map(\.noteId)), thread: entry.thread,
                    batchId: entry.id, now: entry.createdAt, displayNumbers: numbers, directive: entry.directive)
                let attachments = try await FeedbackPayloadBuilder.attachments(for: package, blobs: workspace.blobs, style: FeedbackPreviewModel.storedAnnotationStyle)
                workspace.stagePayload(batchId: entry.id, text: FeedbackPackageBuilder.messageText(for: package), attachments: attachments)
            }
            await workspace.deliver(batchId: entry.id, canvasId: canvasId)
            await workspace.saveNow()
            notice = workspace.lastSaveError
        } catch { notice = error.localizedDescription }
    }
}
