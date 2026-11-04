import SwiftUI
import DrawspeakCore

struct CommentInspectorRow: View {
    let workspace: Workspace
    let note: Note
    let onShowSource: (UUID) -> Void
    private var selected: Bool { workspace.focusedNoteId == note.id }

    var body: some View {
        VStack(alignment: .leading, spacing: NotesMetrics.sectionSpacing) {
            HStack {
                Button(action: select) {
                    HStack {
                        if let number = workspace.displayNumber(for: note.id) {
                            PinBadge(number: number, isActive: selected)
                        }
                        if selected {
                            // The editor below shows the full text.
                            EmptyView()
                        } else if note.hasText {
                            Text(String(note.trimmedText.split(separator: "\n").first ?? "")).lineLimit(1)
                        } else {
                            Text("No comment", bundle: .module).foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                        CommentStatusSymbol(note: note)
                    }
                    .frame(minHeight: Theme.minTarget)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? [.isSelected] : [])
                CommentMoreMenu(workspace: workspace, note: note, onShowSource: onShowSource)
            }
            if selected {
                CommentEditorContent(workspace: workspace, note: note)
            }
        }
    }

    private func select() { workspace.focusedNoteId = note.id }
}
