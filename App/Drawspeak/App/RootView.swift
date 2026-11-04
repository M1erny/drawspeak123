import SwiftUI

struct RootView: View {
    let model: AppModel

    var body: some View {
        if let workspace = model.workspace {
            MainSplitView(model: model, workspace: workspace)
        } else if let error = model.loadError {
            LibraryRecoveryView(error: error, fileURL: model.unreadableLibrary, model: model)
        } else {
            ProgressView()
                .controlSize(.large)
                .accessibilityLabel("Opening Drawspeak")
        }
    }
}
