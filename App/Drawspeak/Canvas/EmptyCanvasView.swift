import DrawspeakCore
import SwiftUI

/// Shown on a canvas without screens.
struct EmptyCanvasView: View {
    let onImport: () -> Void
    let onPull: (() -> Void)?

    var body: some View {
        ContentUnavailableView {
            Label("Nothing to review yet", systemImage: "rectangle.on.rectangle.angled")
        } description: {
            Text("Import a screenshot or an HTML mockup, or pull the versions an agent returned in this canvas's thread.")
        } actions: {
            Button("Import Image or HTML…", systemImage: "square.and.arrow.down", action: onImport)
                .buttonStyle(.borderedProminent)
            if let onPull {
                Button("Pull from Thread", systemImage: "arrow.down.circle", action: onPull)
            }
        }
        .frame(maxWidth: 520)
        .padding(24)
        .paletteBackground()
    }
}
