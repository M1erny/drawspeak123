import SwiftUI
import DrawspeakCore

struct NoteTextEditor: View {
    let workspace: Workspace
    let note: Note
    @State private var text: String
    @FocusState private var isFocused: Bool

    init(workspace: Workspace, note: Note) {
        self.workspace = workspace
        self.note = note
        _text = State(initialValue: note.text)
    }

    var body: some View {
        VStack(alignment: .leading) {
            TextField(text: $text, axis: .vertical) { Text("Comment", bundle: .module) }
                .lineLimit(3...10)
                .focused($isFocused)
            if let error = workspace.lastSaveError {
                Text(error).font(.caption).foregroundStyle(.secondary)
            }
        }
        .onChange(of: text) { _, value in
            if value != workspace.note(note.id)?.text { workspace.updateNoteText(note.id, text: value) }
        }
        .onChange(of: note.text) { _, value in
            if !isFocused { text = value }
        }
        .onChange(of: isFocused) { _, focused in
            if !focused { text = workspace.note(note.id)?.text ?? text }
        }
        .onChange(of: workspace.voiceIssue) { _, issue in
            if issue != nil && !note.hasText { isFocused = true }
        }
    }
}
