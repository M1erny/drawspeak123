import SwiftUI

/// The toolbar `+` menu. Shows progress while a file or pull is in flight.
struct CanvasAddMenu: View {
    let controller: CanvasController

    var body: some View {
        Menu {
            Button("Import Image or HTML…", systemImage: "square.and.arrow.down", action: controller.requestImport)
                .keyboardShortcut("i", modifiers: .command)
            Button("Add Region…", systemImage: "rectangle.dashed", action: controller.addRegion)
        } label: {
            Label {
                Text("Add")
            } icon: {
                if controller.isBusy {
                    ProgressView()
                } else {
                    Image(systemName: "plus")
                }
            }
        }
        .accessibilityValue(controller.isBusy ? Text("In Progress") : Text(verbatim: ""))
    }
}
