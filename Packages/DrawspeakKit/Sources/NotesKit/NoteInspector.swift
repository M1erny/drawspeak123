import SwiftUI
import DrawspeakCore

public struct NoteInspector: View {
    private let workspace: Workspace
    private let noteId: UUID
    private let onShowSource: (UUID) -> Void
    private let onClose: () -> Void
    @State private var availableHeight: CGFloat?

    public init(workspace: Workspace, noteId: UUID, onShowSource: @escaping (UUID) -> Void, onClose: @escaping () -> Void) {
        self.workspace = workspace
        self.noteId = noteId
        self.onShowSource = onShowSource
        self.onClose = onClose
    }

    public var body: some View {
        GeometryReader { geometry in
            ScrollViewReader { scroll in
                ScrollView {
                    if let note = workspace.note(noteId), let canvas = workspace.currentCanvas {
                        NoteInspectorContent(workspace: workspace, note: note, canvas: canvas, onShowSource: onShowSource, onClose: onClose)
                            .id(note.id)
                    } else {
                        ContentUnavailableView("Comment Unavailable", systemImage: "text.bubble", description: Text("This comment may have been deleted."))
                        Button("Close", systemImage: "xmark", action: onClose).frame(minHeight: Theme.minTarget)
                    }
                }
                .onChange(of: workspace.voiceIssue) { old, issue in
                    if (issue != nil || old != nil), workspace.note(noteId)?.hasText == false {
                        scroll.scrollTo("comment-editor", anchor: .top)
                    }
                }
            }
            .frame(maxHeight: availableHeight ?? geometry.size.height)
            .paletteBackground()
            .clipShape(.rect(cornerRadius: Theme.paletteCornerRadius))
        }
        .frame(maxWidth: 360)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { availableHeight = $0 }
    }
}

#Preview {
    let workspace = NotesPreview.workspace()
    NoteInspector(workspace: workspace, noteId: workspace.currentCanvas!.notes[0].id, onShowSource: { _ in }, onClose: {})
}
