import SwiftUI
import DrawspeakCore

struct FeedbackDraftRow: View {
    let workspace: Workspace
    let canvasId: UUID
    let draft: SavedDraft
    let onResume: (UUID) -> Void
    var body: some View {
        Button(action: resume) {
            VStack(alignment: .leading, spacing: FeedbackLayout.rowPadding) {
                Text(draft.thread?.displayName ?? String(localized: "No Thread", bundle: .module)).font(.headline)
                Text(draft.createdAt, format: .relative(presentation: .named)).font(.subheadline)
                Text("^[\(draft.items.count) comment](inflect: true)", bundle: .module).foregroundStyle(.secondary)
                Text("Draft", bundle: .module).font(.caption.bold())
                    .padding(FeedbackLayout.rowPadding).background(.quaternary, in: .capsule)
            }.frame(minHeight: Theme.minTarget)
        }
        .swipeActions { Button(role: .destructive, action: delete) { Text("Delete", bundle: .module) } }
    }
    private func resume() { onResume(draft.id) }
    private func delete() { workspace.deleteDraft(draft.id, canvasId: canvasId) }
}
