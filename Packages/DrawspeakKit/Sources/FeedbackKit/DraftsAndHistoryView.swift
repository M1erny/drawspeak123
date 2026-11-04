import SwiftUI
import DrawspeakCore

public struct DraftsAndHistoryView: View {
    public let workspace: Workspace
    public let canvasId: UUID
    public let onResumeDraft: (Set<UUID>) -> Void
    @State private var resumeNotice: String?
    @State private var restoredSelection: Set<UUID>?
    @Environment(\.dismiss) private var dismiss

    public init(workspace: Workspace, canvasId: UUID, onResumeDraft: @escaping (Set<UUID>) -> Void) {
        self.workspace = workspace; self.canvasId = canvasId; self.onResumeDraft = onResumeDraft
    }
    public var body: some View {
        NavigationStack {
            List {
                if let resumeNotice, let restoredSelection {
                    Section {
                        Text(resumeNotice).font(.footnote)
                        Button("Review Restored Draft") { onResumeDraft(restoredSelection) }
                            .tint(Theme.action)
                    }
                }
                if (workspace.canvas(canvasId)?.drafts.isEmpty ?? true) && (workspace.canvas(canvasId)?.outbox.isEmpty ?? true) {
                    ContentUnavailableView("No Drafts or Sent Feedback", systemImage: "tray",
                        description: Text("Save a feedback package as a draft or send it to an agent to see it here."))
                }
                if let drafts = workspace.canvas(canvasId)?.drafts, !drafts.isEmpty {
                    Section("Drafts") {
                        ForEach(drafts) { draft in
                            Button { resume(draft.id) } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(draft.createdAt, format: .dateTime.month().day().hour().minute())
                                    Text("^[\(draft.items.count) comment](inflect: true) · \(draft.thread?.displayName ?? "No recipient")").font(.subheadline).foregroundStyle(.secondary)
                                }.frame(minHeight: 44)
                            }
                            .swipeActions { Button("Delete", role: .destructive) { workspace.deleteDraft(draft.id, canvasId: canvasId) } }
                        }
                    }
                }
                if let entries = workspace.canvas(canvasId)?.outbox, !entries.isEmpty {
                    Section("Sent") {
                        ForEach(entries) { entry in FeedbackHistoryRow(workspace: workspace, canvasId: canvasId, entry: entry) }
                    }
                }
            }
            .navigationTitle("Drafts & History")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(role: .close) { dismiss() } } }
            .presentationDragIndicator(.hidden)
            .refreshable { await workspace.refreshAgentStatus(canvasId: canvasId) }
        }
    }
    private func resume(_ draftId: UUID) {
        let result = workspace.resumeDraft(draftId, canvasId: canvasId)
        var notices: [String] = []
        if result.copiedCount > 0 {
            let noun = result.copiedCount == 1 ? "comment changed" : "comments changed"
            notices.append("\(result.copiedCount) \(noun) since the draft; the draft's text was restored as new comments.")
        }
        if result.recipientChanged {
            notices.append("The recipient has changed since this draft was saved. Review the current recipient before sending.")
        }
        if notices.isEmpty {
            onResumeDraft(result.noteIds)
        } else {
            restoredSelection = result.noteIds
            resumeNotice = notices.joined(separator: " ")
        }
    }

}
