import DrawspeakCore
import SwiftUI

/// Shown on a canvas without screens.
struct EmptyCanvasView: View {
    let controller: CanvasController

    var body: some View {
        ContentUnavailableView {
            Label("No Screens", systemImage: "rectangle.on.rectangle.angled")
        } actions: {
            // Pulling from the canvas's thread is the usual start; importing is the fallback.
            if controller.hasThread {
                Button("Pull from Thread", systemImage: "arrow.down.circle", action: controller.pull)
                    .buttonStyle(.bordered)
                    .disabled(controller.isPulling)
            }
            if controller.hasThread {
                Button("Import…", systemImage: "square.and.arrow.down", action: controller.requestImport)
            } else {
                Button("Import…", systemImage: "square.and.arrow.down", action: controller.requestImport)
                    .buttonStyle(.bordered)
            }
        }
    }
}
