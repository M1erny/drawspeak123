import SwiftUI
import DrawspeakCore

@available(*, deprecated, message: "Use CommentsInspector")
public struct NoteInspector: View {
    private let workspace: Workspace
    private let noteId: UUID
    private let onShowSource: (UUID) -> Void
    private let onClose: () -> Void
    public init(workspace: Workspace, noteId: UUID, onShowSource: @escaping (UUID) -> Void, onClose: @escaping () -> Void) {
        self.workspace = workspace
        self.noteId = noteId
        self.onShowSource = onShowSource
        self.onClose = onClose
    }
    public var body: some View {
        CommentsInspector(workspace: workspace, onShowSource: onShowSource, onAddRegion: {})
            .task(id: noteId) { workspace.focusedNoteId = workspace.note(noteId)?.id }
            .onChange(of: workspace.focusedNoteId) { _, id in
                if id == nil { onClose() }
            }
    }
}
