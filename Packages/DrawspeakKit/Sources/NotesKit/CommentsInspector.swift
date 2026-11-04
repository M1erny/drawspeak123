import SwiftUI
import DrawspeakCore

public struct CommentsInspector: View {
    private let workspace: Workspace
    private let onShowSource: (UUID) -> Void
    private let onAddRegion: () -> Void
    @State private var groups: [CommentGroup] = []

    public init(workspace: Workspace, onShowSource: @escaping (UUID) -> Void, onAddRegion: @escaping () -> Void) {
        self.workspace = workspace
        self.onShowSource = onShowSource
        self.onAddRegion = onAddRegion
    }

    public var body: some View {
        ScrollViewReader { scroll in
            List {
                ForEach(groups) { group in
                    Section {
                        ForEach(group.notes) { note in
                            CommentInspectorRow(workspace: workspace, note: note, onShowSource: onShowSource)
                                .id(note.id)
                        }
                    } header: { Text(group.title) }
                }
            }
            .listStyle(.insetGrouped)
            .overlay {
                if workspace.currentCanvas?.notes.isEmpty != false {
                    ContentUnavailableView {
                        Label { Text("No Comments", bundle: .module) } icon: { Image(systemName: "text.bubble") }
                    } description: { Text("Draw on a screen to add one.", bundle: .module) }
                }
            }
            .onChange(of: workspace.currentCanvas, initial: true) { _, canvas in
                groups = CommentGroup.make(canvas)
                if let id = workspace.focusedNoteId, canvas?.notes.contains(where: { $0.id == id }) != true {
                    workspace.focusedNoteId = nil
                }
            }
            .task(id: workspace.focusedNoteId) {
                // Let the selected row expand before positioning it.
                await Task.yield()
                guard !Task.isCancelled, let id = workspace.focusedNoteId else { return }
                scroll.scrollTo(id, anchor: .center)
            }
        }
        .navigationTitle(Text("Comments", bundle: .module))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: onAddRegion) {
                    Label { Text("Add Region", bundle: .module) } icon: { Image(systemName: "plus") }
                }
            }
        }
        .tint(.primary)
    }
}

#Preview { NavigationStack { CommentsInspector(workspace: NotesPreview.workspace(), onShowSource: { _ in }, onAddRegion: {}) } }
