#if canImport(UIKit)
import DrawspeakCore
import SwiftUI

struct LegacyToolPaletteContent: View {
    @Binding var tool: CanvasTool
    let canUndo: Bool
    let canRedo: Bool
    let onUndo: () -> Void
    let onRedo: () -> Void
    var body: some View {
        CanvasToolControls(tool: $tool)
        PaletteIconButton(title: String(localized: "Undo", bundle: .module), systemImage: "arrow.uturn.backward", isEnabled: canUndo, action: onUndo)
            .keyboardShortcut("z", modifiers: .command)
        PaletteIconButton(title: String(localized: "Redo", bundle: .module), systemImage: "arrow.uturn.forward", isEnabled: canRedo, action: onRedo)
            .keyboardShortcut("z", modifiers: [.command, .shift])
    }
}
#endif
