import CanvasKit
import DrawspeakCore
import FeedbackKit
import SwiftUI

/// Title menu leading; Add, tools and Undo/Redo in the center (everything that changes the
/// canvas); Comments and Send trailing. With the inspector open, its Filter, Select and More
/// form their own group between the canvas items and the Comments toggle.
struct CanvasToolbar: ToolbarContent {
    let workspace: Workspace
    @Bindable var controller: CanvasController
    let isRegularWidth: Bool

    var body: some ToolbarContent {
        ToolbarTitleMenu {
            CanvasTitleMenu(controller: controller)
        }

        ToolbarItem(placement: .secondaryAction) {
            CanvasAddMenu(controller: controller)
        }
        ToolbarSpacer(.fixed, placement: .secondaryAction)
        ToolbarItemGroup(placement: .secondaryAction) {
            CanvasToolControls(tool: $controller.tool)
        }
        ToolbarSpacer(.fixed, placement: .secondaryAction)
        ToolbarItemGroup(placement: .secondaryAction) {
            UndoRedoButtons(controller: controller)
        }

        ToolbarSpacer(.fixed, placement: .primaryAction)
        ToolbarItem(placement: .primaryAction) {
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
