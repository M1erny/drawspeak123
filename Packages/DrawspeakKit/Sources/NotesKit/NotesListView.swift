import SwiftUI
import DrawspeakCore

@available(*, deprecated, message: "Use CommentsInspector")
public struct NotesListView: View {
    private let workspace: Workspace
    private let onSelect: (UUID) -> Void
    public init(workspace: Workspace, onSelect: @escaping (UUID) -> Void) {
        self.workspace = workspace
        self.onSelect = onSelect
    }
    public var body: some View {
        CommentsInspector(workspace: workspace, onShowSource: onSelect, onAddRegion: {})
            .onChange(of: workspace.focusedNoteId) { _, id in
                if let id { onSelect(id) }
            }
    }
}
