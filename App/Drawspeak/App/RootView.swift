import SwiftUI

struct RootView: View {
    let model: AppModel

    var body: some View {
        if let workspace = model.workspace {
            CanvasScreen(model: model, workspace: workspace)
        } else if let error = model.loadError {
            ContentUnavailableView(error, systemImage: "externaldrive.badge.exclamationmark")
        } else {
            ProgressView()
                .controlSize(.large)
                .accessibilityLabel("Opening Drawspeak")
        }
    }
}
