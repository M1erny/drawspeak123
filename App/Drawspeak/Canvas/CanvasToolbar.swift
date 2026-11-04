import CanvasKit
import DrawspeakCore
import FeedbackKit
import SwiftUI

/// Title menu leading, tools and Undo/Redo in the center, Add, Comments and Send trailing.
struct CanvasToolbar: ToolbarContent {
    let workspace: Workspace
    @Bindable var controller: CanvasController
    let isRegularWidth: Bool

    var body: some ToolbarContent {
        ToolbarTitleMenu {
            CanvasTitleMenu(controller: controller)
        }

        ToolbarItemGroup(placement: .secondaryAction) {
            CanvasToolControls(tool: $controller.tool)
        }
        ToolbarSpacer(.fixed, placement: .secondaryAction)
        ToolbarItemGroup(placement: .secondaryAction) {
            UndoRedoButtons(controller: controller)
        }

        ToolbarItemGroup(placement: .primaryAction) {
            CanvasAddMenu(controller: controller)
            Toggle("Comments", systemImage: "text.bubble", isOn: $controller.showsInspector)
                .keyboardShortcut("l", modifiers: [.command, .shift])
        }
        ToolbarSpacer(.fixed, placement: .primaryAction)
        ToolbarItem(placement: .primaryAction) {
            SendFeedbackButton(workspace: workspace, action: openFeedback)
                .popover(isPresented: $controller.showsFeedback) {
                    FeedbackPopover(workspace: workspace, controller: controller, isRegularWidth: isRegularWidth)
                }
        }
    }

    private func openFeedback() {
        controller.openFeedback()
    }
}
