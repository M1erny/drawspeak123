import SwiftUI
import DrawspeakCore

/// Passive content lets List own taps and multi-selection while editing.
struct CommentSelectionRow: View {
    let workspace: Workspace
    let note: Note

    var body: some View {
        HStack {
            if let number = workspace.displayNumber(for: note.id) {
                PinBadge(number: number, isActive: false)
            }
            if note.hasText {
                Text(verbatim: String(note.trimmedText.split(separator: "\n").first ?? "")).lineLimit(2)
            } else {
                Text("No comment", bundle: .module).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            CommentStatusSymbol(note: note)
        }
        .frame(minHeight: Theme.minTarget)
        .contentShape(.rect)
    }
}
