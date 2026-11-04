#if DEBUG && canImport(UIKit)
import DrawspeakCore
import SwiftUI

/// The canvas with its palettes, roughly as the app lays them out.
struct CanvasPreviewHost: View {
    @State private var workspace = CanvasPreviewSeed.makeWorkspace()
    @State private var tool: CanvasTool = .region
    @State private var viewSize: CGSize = .zero

    var body: some View {
        NavigationStack {
            CanvasView(workspace: workspace, tool: $tool, drawWithFinger: true)
                .toolbar { ToolbarItemGroup { CanvasToolControls(tool: $tool) } }
                .toolbarRole(.editor)
                .safeAreaInset(edge: .bottom, alignment: .leading) {
                    ZoomMenu(zoom: workspace.currentCanvas?.camera.zoom ?? 1, onZoomIn: zoomIn,
                             onZoomOut: zoomOut, onFitAll: fitAll, onActualSize: actualSize).padding()
                }
        }
            .onGeometryChange(for: CGSize.self) { proxy in
                proxy.size
            } action: { size in
                viewSize = size
            }
    }

    private func actualSize() {
        guard let canvas = workspace.currentCanvas else { return }
        zoom(by: 1 / canvas.camera.zoom)
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
        workspace.updateCamera(CanvasFraming.fitAll(canvas: canvas, viewSize: viewSize, insets: EdgeInsets()), canvasId: canvas.id)
    }
}

#Preview("Canvas", traits: .landscapeLeft) {
    CanvasPreviewHost()
}
#endif
