import SwiftUI
import DrawspeakCore

struct RootView: View {
    let model: AppModel

    @AppStorage("drawspeak.markLineWidth") private var lineWidth = Double(AnnotationStyle.standard.lineWidth)
    @AppStorage("drawspeak.pinSize") private var pinSize = Double(AnnotationStyle.standard.pinSize)

    var body: some View {
        content.environment(\.annotationStyle, AnnotationStyle(lineWidth: lineWidth, pinSize: pinSize))
    }

    @ViewBuilder private var content: some View {
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
