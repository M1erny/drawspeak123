import DrawspeakCore
import FeedbackKit
import SwiftUI

/// The feedback preview: a popover from Send, a sheet in compact width.
struct FeedbackPopover: View {
    let workspace: Workspace
    let controller: CanvasController
    /// Read where the popover is anchored; inside a popover the size class is compact.
    let isRegularWidth: Bool
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        if let canvasId = workspace.currentCanvasId {
            FeedbackPreviewSheet(
                workspace: workspace,
                canvasId: canvasId,
                initialSelection: controller.feedbackSelection,
                onChooseThread: controller.chooseThreadForFeedback,
                onClose: controller.closeFeedback
            )
            .frame(
                width: isRegularWidth ? ShellMetrics.feedbackPopoverSize.width : nil,
                height: isRegularWidth ? (dynamicTypeSize.isAccessibilitySize ? ShellMetrics.feedbackPopoverLargeTextHeight : ShellMetrics.feedbackPopoverSize.height) : nil
            )
            .presentationCompactAdaptation(.sheet)
        }
    }
}
