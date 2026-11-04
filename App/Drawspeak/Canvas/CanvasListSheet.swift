import DrawspeakCore
import SwiftUI
import T3Kit

/// All review canvases. Each canvas belongs to one thread.
struct CanvasListSheet: View {
    let workspace: Workspace
    let connection: T3Connection
    @Environment(\.dismiss) private var dismiss
    @State private var renaming: ReviewCanvas?
    @State private var newTitle = ""
    @State private var pendingDelete: ReviewCanvas?

    var body: some View {
        NavigationStack {
            List {
                ForEach(workspace.canvases) { canvas in
                    Button {
                        workspace.selectCanvas(canvas.id)
                        dismiss()
                    } label: {
                        CanvasRow(canvas: canvas, isCurrent: canvas.id == workspace.currentCanvasId)
                    }
                    .foregroundStyle(Theme.ink)
                    .swipeActions {
                        Button("Delete", systemImage: "trash", role: .destructive) { pendingDelete = canvas }
                        Button("Rename", systemImage: "pencil") {
                            newTitle = canvas.title
                            renaming = canvas
                        }
                    }
                    .contextMenu {
                        Button("Rename", systemImage: "pencil") {
                            newTitle = canvas.title
                            renaming = canvas
                        }
                        Button("Delete", systemImage: "trash", role: .destructive) { pendingDelete = canvas }
                    }
                }
            }
            .navigationTitle("Canvases")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("New Canvas", systemImage: "plus") {
                        workspace.createCanvas(title: "Review \(workspace.canvases.count + 1)", thread: nil)
                        dismiss()
                    }
                }
            }
            .alert("Rename Canvas", isPresented: renameBinding) {
                TextField("Title", text: $newTitle)
                Button("Rename") {
                    if let renaming, !newTitle.trimmingCharacters(in: .whitespaces).isEmpty {
                        workspace.renameCanvas(renaming.id, title: newTitle)
                    }
                }
                Button("Cancel", role: .cancel) {}
            }
            .confirmationDialog(
                "Delete \(pendingDelete?.title ?? "")?",
                isPresented: deleteBinding,
                titleVisibility: .visible
            ) {
                Button("Delete Canvas", role: .destructive) {
                    if let pendingDelete { workspace.deleteCanvas(pendingDelete.id) }
                }
            } message: {
                Text("Its versions, comments and drafts are removed from this iPad. Messages already sent stay in the T3 thread.")
            }
        }
    }

    private var renameBinding: Binding<Bool> {
        Binding { renaming != nil } set: { if !$0 { renaming = nil } }
    }

    private var deleteBinding: Binding<Bool> {
        Binding { pendingDelete != nil } set: { if !$0 { pendingDelete = nil } }
    }
}
