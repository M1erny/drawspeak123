import DrawspeakCore
import SwiftUI

/// The detail when every canvas was deleted.
struct NoCanvasView: View {
    let workspace: Workspace

    var body: some View {
        ContentUnavailableView {
            Label("No Canvases", systemImage: "rectangle.on.rectangle.angled")
        } actions: {
            Button("New Canvas", systemImage: "plus", action: createCanvas)
                .buttonStyle(.borderedProminent)
        }
        .background { Theme.canvas.ignoresSafeArea() }
    }

    private func createCanvas() {
        workspace.createCanvas(title: CanvasNaming.nextTitle(in: workspace), thread: nil)
    }
}
