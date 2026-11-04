import SwiftUI

/// The canvas title menu: rename, thread, pull, history and settings.
struct CanvasTitleMenu: View {
    let controller: CanvasController

    var body: some View {
        RenameButton()
        Button("Choose Thread…", systemImage: "link", action: controller.chooseThread)
        Button("Pull Versions", systemImage: "arrow.down.circle", action: controller.pull)
            .disabled(!controller.hasThread || controller.isPulling)
        Divider()
        Button("Drafts and Sent", systemImage: "clock.arrow.circlepath", action: controller.showHistory)
        Button("Settings", systemImage: "gearshape", action: controller.showSettings)
            .keyboardShortcut(",", modifiers: .command)
    }
}
