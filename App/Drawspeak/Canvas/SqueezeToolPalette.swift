import CanvasKit
import SwiftUI

/// The tools shown near Apple Pencil Pro on squeeze. Choosing one closes it.
struct SqueezeToolPalette: View {
    @Bindable var controller: CanvasController

    var body: some View {
        HStack {
            CanvasToolControls(tool: $controller.tool)
            Divider()
            UndoRedoButtons(controller: controller)
        }
        .padding(.horizontal)
        .fixedSize()
        .presentationCompactAdaptation(.popover)
        .onChange(of: controller.tool) { controller.showsSqueezePalette = false }
    }
}
