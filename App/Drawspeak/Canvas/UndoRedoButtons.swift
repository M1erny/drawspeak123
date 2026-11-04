import SwiftUI

struct UndoRedoButtons: View {
    let controller: CanvasController

    var body: some View {
        Button("Undo", systemImage: "arrow.uturn.backward", action: controller.undo)
            .keyboardShortcut("z", modifiers: .command)
            .disabled(!controller.canUndo)
        Button("Redo", systemImage: "arrow.uturn.forward", action: controller.redo)
            .keyboardShortcut("z", modifiers: [.command, .shift])
            .disabled(!controller.canRedo)
    }
}
