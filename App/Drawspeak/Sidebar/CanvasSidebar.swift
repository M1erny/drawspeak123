import DrawspeakCore
import SwiftUI

/// All review canvases. Each canvas belongs to one thread.
struct CanvasSidebar: View {
    let workspace: Workspace
    @State private var selection: UUID?
    @State private var renaming: ReviewCanvas?

    var body: some View {
        List(selection: $selection) {
            ForEach(workspace.canvases) { canvas in
                CanvasSidebarRow(workspace: workspace, canvas: canvas, onRename: rename)
            }
        }
        .tint(Theme.actionFill)
        .navigationTitle("Canvases")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("New Canvas", systemImage: "plus", action: createCanvas)
            }
        }
        .modifier(RenameCanvasAlert(workspace: workspace, canvas: $renaming))
        .onChange(of: workspace.currentCanvasId, initial: true) { _, id in selection = id }
        .onChange(of: selection, selectionChanged)
    }

    private func rename(_ canvas: ReviewCanvas) {
        renaming = canvas
    }

    private func selectionChanged(_ old: UUID?, _ new: UUID?) {
        guard let new else { return }
        workspace.selectCanvas(new)
    }

    private func createCanvas() {
        workspace.createCanvas(title: CanvasNaming.nextTitle(in: workspace), thread: nil)
    }
}
