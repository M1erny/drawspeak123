import DrawspeakCore
import FeedbackKit
import NotesKit
import SwiftUI

/// The content of the one sheet the canvas presents.
struct CanvasSheetContent: View {
    let sheet: CanvasSheet
    let model: AppModel
    let workspace: Workspace
    let controller: CanvasController

    var body: some View {
        switch sheet {
        case .settings:
            SettingsView(model: model)
        case .history:
            if let canvasId = workspace.currentCanvasId {
                DraftsAndHistoryView(workspace: workspace, canvasId: canvasId, onResumeDraft: controller.resumeDraft)
                    .frame(idealHeight: ShellMetrics.historyHeight)
                    .presentationSizing(.form.fitted(horizontal: false, vertical: true))
            }
        case .addRegion(let snapshotId):
            AddRegionSheet(workspace: workspace, initialSnapshotId: snapshotId, onDone: dismiss)
        case .threadPicker(let returnSelection):
            ThreadBindingSheet(workspace: workspace, connection: model.connection) {
                controller.threadBound(returnSelection: returnSelection)
            }
        case .importTarget(let pending):
            ImportTargetSheet(workspace: workspace, pending: pending) { target in
                dismiss()
                controller.finishImport(pending, target: target)
            }
        }
    }

    private func dismiss() {
        controller.sheet = nil
    }
}
