import SwiftUI

/// The toolbar `+` menu. Progress of a file or pull shows in the canvas status,
/// not here: swapping this label's icon for a ProgressView inside the toolbar
/// glass group left the item blank and unusable after the import ended.
struct CanvasAddMenu: View {
    let controller: CanvasController

    var body: some View {
        Menu {
            Button("Choose File…", systemImage: "square.and.arrow.down", action: controller.requestImport)
                .keyboardShortcut("i", modifiers: .command)
                .disabled(controller.isImportingFile)
            Button("Photo Library…", systemImage: "photo.on.rectangle", action: controller.requestPhotoLibrary)
                .disabled(controller.isImportingFile)
        } label: {
            Label("Add", systemImage: "plus")
        }
        .accessibilityValue(controller.isBusy ? Text("In Progress") : Text(verbatim: ""))
    }
}
