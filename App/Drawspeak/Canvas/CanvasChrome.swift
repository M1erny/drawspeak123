import CanvasKit
import DrawspeakCore
import FeedbackKit
import SwiftUI
import T3Kit

/// Floating palettes around the canvas: canvas/thread (top leading), actions and
/// Feedback (top trailing), tools (bottom center) and zoom (bottom leading).
struct CanvasChrome: View {
    struct Actions {
        var showCanvases: () -> Void
        var pickThread: () -> Void
        var importFile: () -> Void
        var pull: () -> Void
        var showNotes: () -> Void
        var showHistory: () -> Void
        var showSettings: () -> Void
        var addRegion: () -> Void
        var openFeedback: () -> Void
        var undo: () -> Void
        var redo: () -> Void
        var zoomIn: () -> Void
        var zoomOut: () -> Void
        var fitAll: () -> Void
    }

    let workspace: Workspace
    let connection: T3Connection
    @Binding var tool: CanvasTool
    let isPulling: Bool
    let canUndo: Bool
    let canRedo: Bool
    let actions: Actions

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                CanvasTitlePalette(workspace: workspace, connection: connection, onShowCanvases: actions.showCanvases, onPickThread: actions.pickThread)
                Spacer(minLength: 12)
                CanvasActionsPalette(
                    hasThread: workspace.currentCanvas?.thread != nil,
                    isPulling: isPulling,
                    isCompact: horizontalSizeClass == .compact,
                    actions: actions
                )
                FeedbackButton(workspace: workspace, action: actions.openFeedback)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            Spacer()

            HStack(alignment: .bottom, spacing: 12) {
                ZoomControls(
                    zoom: workspace.currentCanvas?.camera.zoom ?? 1,
                    onZoomOut: actions.zoomOut,
                    onZoomIn: actions.zoomIn,
                    onFitAll: actions.fitAll
                )
                Spacer(minLength: 12)
                ToolPalette(tool: $tool, canUndo: canUndo, canRedo: canRedo, onUndo: actions.undo, onRedo: actions.redo)
                Spacer(minLength: 12)
                    .frame(maxWidth: horizontalSizeClass == .compact ? 0 : 160)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
    }
}
