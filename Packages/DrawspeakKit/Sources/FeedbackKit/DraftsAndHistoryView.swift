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
                if let resumeNotice, restoredSelection != nil {
                    Section {
                        Text(resumeNotice).font(.footnote)
                        Button(action: reviewRestored) { Text("Review", bundle: .module) }
                    }
                }
                if let drafts = workspace.canvas(canvasId)?.drafts, !drafts.isEmpty {
                    Section {
                        ForEach(drafts) { draft in
                            FeedbackDraftRow(workspace: workspace, canvasId: canvasId, draft: draft, onResume: resume)
                        }
                    } header: { Text("Drafts", bundle: .module) }
                }
                if let entries = workspace.canvas(canvasId)?.outbox, !entries.isEmpty {
                    Section {
                        ForEach(entries) { entry in FeedbackHistoryRow(workspace: workspace, canvasId: canvasId, entry: entry) }
                    } header: { Text("Sent", bundle: .module) }
                }
            }
            .overlay {
                if (workspace.canvas(canvasId)?.drafts.isEmpty ?? true) && (workspace.canvas(canvasId)?.outbox.isEmpty ?? true) {
                    ContentUnavailableView {
                        Label { Text("No Feedback Sent", bundle: .module) } icon: { Image(systemName: "paperplane") }
                    }
                }
            }
            .navigationTitle(Text("History", bundle: .module))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(role: .close, action: close) } }
            .presentationDragIndicator(.hidden)
            .refreshable { await workspace.refreshAgentStatus(canvasId: canvasId) }
        }.tint(.primary).presentationSizing(.form)
    }
    private func close() { dismiss() }
    private func reviewRestored() { if let restoredSelection { onResumeDraft(restoredSelection) } }
    private func resume(_ draftId: UUID) {
        let result = workspace.resumeDraft(draftId, canvasId: canvasId)
        var notices: [String] = []
        if result.copiedCount > 0 {
            notices.append(String(localized: "Some comments changed since this draft.", bundle: .module))
        }
        if result.recipientChanged {
            notices.append(String(localized: "Thread changed.", bundle: .module))
        }
        if notices.isEmpty {
            onResumeDraft(result.noteIds)
        } else {
            restoredSelection = result.noteIds
            resumeNotice = notices.joined(separator: " ")
        }
    }

}
