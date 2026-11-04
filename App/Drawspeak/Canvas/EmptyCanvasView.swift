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
            Button("Choose File…", systemImage: "square.and.arrow.down", action: controller.requestImport)
                .disabled(controller.isImportingFile)
            Button("Photo Library…", systemImage: "photo.on.rectangle", action: controller.requestPhotoLibrary)
                .disabled(controller.isImportingFile)
        }
    }
}
