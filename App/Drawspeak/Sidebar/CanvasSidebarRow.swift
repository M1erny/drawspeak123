import DrawspeakCore
import SwiftUI

/// A canvas row with Rename and Delete; the delete confirmation is anchored here.
struct CanvasSidebarRow: View {
    let workspace: Workspace
    let canvas: ReviewCanvas
    let onRename: (ReviewCanvas) -> Void
    @State private var pendingDelete: ReviewCanvas?

    var body: some View {
        CanvasRow(canvas: canvas)
            .tag(canvas.id)
            .swipeActions {
                Button("Delete", systemImage: "trash", role: .destructive, action: requestDelete)
                Button("Rename", systemImage: "pencil", action: rename)
            }
            .contextMenu {
                Button("Rename", systemImage: "pencil", action: rename)
                Button("Delete", systemImage: "trash", role: .destructive, action: requestDelete)
            }
            .confirmationDialog("Delete \(canvas.title)?", item: $pendingDelete, titleVisibility: .visible) { canvas in
                Button("Delete Canvas", role: .destructive) { delete(canvas) }
            } message: { _ in
                Text("Sent feedback stays in the thread.")
            }
    }

    private func rename() {
        onRename(canvas)
    }

    private func requestDelete() {
        pendingDelete = canvas
    }

    private func delete(_ canvas: ReviewCanvas) {
        workspace.deleteCanvas(canvas.id)
    }
}
