import SwiftUI
import DrawspeakCore

public struct DraftsAndHistoryView: View {
    public let workspace: Workspace
    public let canvasId: UUID
    public let onResumeDraft: (Set<UUID>) -> Void
    @Environment(\.dismiss) private var dismiss

    public init(workspace: Workspace, canvasId: UUID, onResumeDraft: @escaping (Set<UUID>) -> Void) {
        self.workspace = workspace; self.canvasId = canvasId; self.onResumeDraft = onResumeDraft
    }
    public var body: some View {
        NavigationStack {
            List {
                Section("Drafts") {
                    if let drafts = workspace.canvas(canvasId)?.drafts, !drafts.isEmpty {
                        ForEach(drafts) { draft in
                            Button { onResumeDraft(workspace.resumeDraft(draft.id, canvasId: canvasId)) } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(draft.createdAt, format: .dateTime.month().day().hour().minute())
                                    Text("\(draft.items.count) comments · \(draft.thread?.displayName ?? "No recipient")").font(.subheadline).foregroundStyle(.secondary)
                                }.frame(minHeight: 44)
                            }
                            .swipeActions { Button("Delete", role: .destructive) { workspace.deleteDraft(draft.id, canvasId: canvasId) } }
                        }
                    } else { ContentUnavailableView("No Drafts", systemImage: "doc", description: Text("Save a feedback package to return to it later.")) }
                }
                Section("Sent / Outbox") {
                    if let entries = workspace.canvas(canvasId)?.outbox, !entries.isEmpty {
                        ForEach(entries) { entry in FeedbackHistoryRow(workspace: workspace, canvasId: canvasId, entry: entry) }
                    } else { ContentUnavailableView("No Delivery History", systemImage: "tray", description: Text("Packages appear here when you choose Send to Agent.")) }
                }
            }
            .navigationTitle("Drafts & History")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
            .refreshable { await workspace.refreshAgentStatus(canvasId: canvasId) }
        }
    }
}
