import SwiftUI
import DrawspeakCore

struct CommentInspectorRow: View {
    let workspace: Workspace
    let note: Note
    let onShowSource: (UUID) -> Void
    let onDelete: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var starting = false
    private var selected: Bool { workspace.focusedNoteId == note.id }
    private var recording: Bool { workspace.activeRecording?.noteId == note.id }
    private var canRecord: Bool { !starting && workspace.activeRecording == nil }
    private var canDelete: Bool { !starting && !note.isRecording && !recording }

    var body: some View {
        VStack(alignment: .leading, spacing: NotesMetrics.sectionSpacing) {
            HStack {
                header
                if selected {
                    Button(action: toggleRecording) {
                        Label {
                            if recording { Text("Stop", bundle: .module) }
                            else { Text("Record Again", bundle: .module) }
                        } icon: {
                            Image(systemName: recording ? "stop.fill" : "mic")
                                // HIG: “Aim for brevity and precision in feedback animations.”
                                .symbolEffect(.pulse, options: .nonRepeating, value: recording)
                                .symbolEffectsRemoved(reduceMotion)
                        }
                    }
                    .labelStyle(.iconOnly)
                    .frame(minWidth: Theme.minTarget, minHeight: Theme.minTarget)
                    .disabled(!recording && !canRecord)
                    Button(role: .destructive, action: delete) {
                        Label { Text("Delete", bundle: .module) } icon: { Image(systemName: "trash") }
                    }
                    .labelStyle(.iconOnly)
                    .frame(minWidth: Theme.minTarget, minHeight: Theme.minTarget)
                    .disabled(!canDelete)
                }
                CommentMoreMenu(workspace: workspace, note: note)
            }
            if selected {
                CommentEditorContent(workspace: workspace, note: note)
                    .transition(reduceMotion ? .identity : .opacity)
            }
        }
        // Automatic List button styling can activate Record when More is tapped.
        // Keep each control independent; selection gestures live only on the header.
        .buttonStyle(.borderless)
        .animation(reduceMotion ? nil : .snappy(duration: 0.22), value: selected)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive, action: delete) {
                Label { Text("Delete", bundle: .module) } icon: { Image(systemName: "trash") }
            }
            .disabled(!canDelete)
        }
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            Button(action: record) {
                Label { Text("Record Again", bundle: .module) } icon: { Image(systemName: "mic") }
            }
            .disabled(!canRecord)
        }
        .accessibilityAction(named: Text("Show on Canvas", bundle: .module), showSource)
        .accessibilityActions {
            if canRecord {
                Button(action: record) { Text("Record Again", bundle: .module) }
            }
            if canDelete {
                Button(role: .destructive, action: delete) { Text("Delete", bundle: .module) }
            }
        }
    }

    private var header: some View {
        HStack {
            if let number = workspace.displayNumber(for: note.id) {
                PinBadge(number: number, isActive: selected)
            }
            if !selected {
                if note.hasText {
                    Text(String(note.trimmedText.split(separator: "\n").first ?? "")).lineLimit(1)
                } else {
                    Text("No comment", bundle: .module).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
            CommentStatusSymbol(note: note)
        }
        .frame(minHeight: Theme.minTarget)
        .contentShape(.rect)
        .onTapGesture(count: 2, perform: showSource)
        // Select immediately while the double-tap recognizer waits for its second tap.
        .simultaneousGesture(TapGesture(count: 1).onEnded { select() })
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : [.isButton])
        .accessibilityAction(.default, select)
    }

    private func select() { workspace.focusedNoteId = note.id }
    private func showSource() { select(); onShowSource(note.id) }
    private func toggleRecording() {
        if recording { workspace.stopRecording() }
        else { record() }
    }
    private func record() {
        guard canRecord else { return }
        select()
        starting = true
        Task {
            await workspace.startRecording(noteId: note.id)
            starting = false
        }
    }
    private func delete() {
        guard canDelete else { return }
        withAnimation(reduceMotion ? nil : .snappy(duration: 0.22)) {
            workspace.deleteNote(note.id)
            onDelete()
        }
    }
}
