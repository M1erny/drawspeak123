import DrawspeakCore
import SwiftUI

/// Canvases in a sidebar that starts hidden; the current canvas fills the
/// detail and Comments sit in an inspector inside it (see `CanvasDetail`).
struct MainSplitView: View {
    let model: AppModel
    let workspace: Workspace
    @State private var controller: CanvasController
    @State private var columnVisibility: NavigationSplitViewVisibility = .detailOnly
    @State private var compactColumn: NavigationSplitViewColumn = .detail

    init(model: AppModel, workspace: Workspace) {
        self.model = model
        self.workspace = workspace
        _controller = State(initialValue: CanvasController(workspace: workspace))
    }

    var body: some View {
        @Bindable var controller = controller
        NavigationSplitView(columnVisibility: $columnVisibility, preferredCompactColumn: $compactColumn) {
            CanvasSidebar(workspace: workspace)
        } detail: {
            if workspace.currentCanvas != nil {
                CanvasDetail(model: model, workspace: workspace, controller: controller)
            } else {
                NoCanvasView(workspace: workspace)
            }
        }
        .onAppear(perform: applyDebugLaunch)
    }

    private func applyDebugLaunch() {
        #if DEBUG
        if DebugLaunch.requestedState == .canvases {
            columnVisibility = .all
            compactColumn = .sidebar
        }
        #endif
    }
}
