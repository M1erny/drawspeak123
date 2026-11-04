#if DEBUG && canImport(UIKit)
import DrawspeakCore
import SwiftUI

/// The canvas with its palettes, roughly as the app lays them out.
struct CanvasPreviewHost: View {
    @State private var workspace = CanvasPreviewSeed.makeWorkspace()
    @State private var tool: CanvasTool = .region
    @State private var viewSize: CGSize = .zero

    var body: some View {
        CanvasView(workspace: workspace, tool: $tool, drawWithFinger: true, overlayInsets: EdgeInsets(top: 0, leading: 0, bottom: 88, trailing: 0))
            .overlay(alignment: .bottom) {
                HStack(alignment: .bottom) {
                    ZoomControls(zoom: workspace.currentCanvas?.camera.zoom ?? 1, onZoomOut: zoomOut, onZoomIn: zoomIn, onFitAll: fitAll)
                    Spacer()
                    ToolPalette(tool: $tool, canUndo: false, canRedo: false, onUndo: {}, onRedo: {})
                }
                .padding()
            }
            .onGeometryChange(for: CGSize.self) { proxy in
                proxy.size
            } action: { size in
                viewSize = size
            }
    }

    private func zoomOut() { zoom(by: 0.8) }
    private func zoomIn() { zoom(by: 1.25) }

    private func zoom(by factor: Double) {
        guard let canvas = workspace.currentCanvas else { return }
        let center = CGPoint(x: viewSize.width / 2, y: viewSize.height / 2)
        workspace.updateCamera(CanvasFraming.zoomed(canvas.camera, by: factor, around: center), canvasId: canvas.id)
    }

    private func fitAll() {
        guard let canvas = workspace.currentCanvas else { return }
        workspace.updateCamera(CanvasFraming.fitAll(canvas: canvas, viewSize: viewSize, insets: EdgeInsets(top: 0, leading: 0, bottom: 88, trailing: 0)), canvasId: canvas.id)
    }
}

#Preview("Canvas", traits: .landscapeLeft) {
    CanvasPreviewHost()
}
#endif
