import SwiftUI
import DrawspeakCore

public struct NotesListView: View {
    private let workspace: Workspace
    private let onSelect: (UUID) -> Void

    public init(workspace: Workspace, onSelect: @escaping (UUID) -> Void) {
        self.workspace = workspace
        self.onSelect = onSelect
    }

    public var body: some View {
        if let canvas = workspace.currentCanvas, !canvas.notes.isEmpty {
            List {
                ForEach(canvas.snapshots) { snapshot in
                    let notes = canvas.notes.filter { $0.snapshotId == snapshot.id }.sorted { $0.ordinal < $1.ordinal }
                    if !notes.isEmpty {
                        Section {
                            ForEach(notes) { note in
                                Button { onSelect(note.id) } label: {
                                    NoteListRow(workspace: workspace, canvas: canvas, note: note)
                                }.buttonStyle(.plain)
                            }
                        } header: {
                            Text(NotesPresentation.sourceLabel(snapshot, in: canvas))
                            Text("^[\(notes.count) comment](inflect: true)")
                        }
                    }
                }
                let missing = canvas.notes.filter { note in !canvas.snapshots.contains { $0.id == note.snapshotId } }
                if !missing.isEmpty {
                    Section("Missing Source") {
                        ForEach(missing) { note in
                            Button { onSelect(note.id) } label: { NoteListRow(workspace: workspace, canvas: canvas, note: note) }
                                .buttonStyle(.plain)
                        }
                    }
                }
            }
        } else {
            ContentUnavailableView("No Comments Yet", systemImage: "text.bubble", description: Text("Mark a region on the canvas, or use Add Region, then say or type what should change."))
        }
    }
}

#Preview { NotesListView(workspace: NotesPreview.workspace(), onSelect: { _ in }) }
