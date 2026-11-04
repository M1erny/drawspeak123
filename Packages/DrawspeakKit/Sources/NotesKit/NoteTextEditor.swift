import SwiftUI
import DrawspeakCore

struct NoteTextEditor: View {
    let workspace: Workspace
    let note: Note
    @State private var text = ""
    @State private var isSaving = false
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text("Say or type what should change")
                        .foregroundStyle(Theme.secondaryInk).padding(.horizontal, 5).padding(.vertical, 8)
                        .allowsHitTesting(false).accessibilityHidden(true)
                }
                TextEditor(text: $text)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 120)
                    .focused($isFocused)
                    .accessibilityLabel("Comment text")
                    .accessibilityHint("Say or type what should change. Changes save automatically.")
            }
            Text(workspace.lastSaveError ?? (isSaving ? "Saving…" : "Saved"))
                .font(.caption).foregroundStyle(Theme.secondaryInk)
        }
        .onAppear { text = note.text }
        .task(id: note.text) {
            isSaving = true
            do { try await Task.sleep(for: .milliseconds(300)) } catch { return }
            await workspace.saveNow()
            if !Task.isCancelled { isSaving = false }
        }
        .onChange(of: workspace.voiceIssue, initial: true) { old, issue in
            if (issue != nil || old != nil) && !note.hasText { isFocused = true }
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
    }
}

#Preview {
    let workspace = NotesPreview.workspace()
    NoteTextEditor(workspace: workspace, note: workspace.currentCanvas!.notes[0])
}
