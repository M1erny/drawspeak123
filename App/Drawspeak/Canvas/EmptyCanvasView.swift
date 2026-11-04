import DrawspeakCore
import SwiftUI

/// Shown on a canvas without screens.
struct EmptyCanvasView: View {
    let controller: CanvasController

    var body: some View {
        ContentUnavailableView {
            Label("No Screens", systemImage: "rectangle.on.rectangle.angled")
        } actions: {
            Button("Import Image or HTML…", systemImage: "square.and.arrow.down", action: controller.requestImport)
                .buttonStyle(.bordered)
            if controller.hasThread {
                Button("Pull Versions", systemImage: "arrow.down.circle", action: controller.pull)
                    .disabled(controller.isPulling)
            }
        }
    }
}
