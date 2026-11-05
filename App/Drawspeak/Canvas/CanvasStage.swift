import CanvasKit
import DrawspeakCore
import SwiftUI

/// The canvas itself with its empty state, zoom menu and Pencil squeeze palette.
struct CanvasStage: View {
    let workspace: Workspace
    @Bindable var controller: CanvasController
    let drawWithFinger: Bool

    var body: some View {
        CanvasView(
            workspace: workspace,
            tool: $controller.tool,
            drawWithFinger: drawWithFinger,
            squeezeAnchor: $controller.squeezeAnchor,
            onSqueeze: controller.toggleSqueezePalette,
            onAddRegion: controller.addRegion(snapshotId:)
        )
        .onGeometryChange(for: CGSize.self) { $0.size } action: { size in
            controller.viewSize = size
            controller.keepFocusedMarkVisible()
        }
        .popover(isPresented: $controller.showsSqueezePalette, attachmentAnchor: .rect(.rect(squeezeRect))) {
            SqueezeToolPalette(controller: controller)
        }
        .overlay {
            if workspace.currentCanvas?.screens.isEmpty ?? true {
                EmptyCanvasView(controller: controller)
            }
        }
        .overlay(alignment: .bottomLeading) {
            CanvasStatusBar(controller: controller)
        }
        .task(id: FramingKey(canvasId: workspace.currentCanvasId, width: Int(controller.viewSize.width),
                             height: Int(controller.viewSize.height), coverage: Int(controller.inspectorCoverage))) {
            controller.frameIfNeeded()
            controller.keepFocusedMarkVisible()
        }
    }

    private var squeezeRect: CGRect {
        CGRect(origin: controller.squeezeAnchor ?? .zero, size: CGSize(width: 1, height: 1))
    }
}
