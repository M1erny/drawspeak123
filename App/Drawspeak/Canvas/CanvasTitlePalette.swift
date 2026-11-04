import DrawspeakCore
import SwiftUI
import T3Kit

/// Canvas title and the thread it belongs to. Tapping the title switches canvases.
struct CanvasTitlePalette: View {
    let workspace: Workspace
    let connection: T3Connection
    let onShowCanvases: () -> Void
    let onPickThread: () -> Void

    var body: some View {
        let canvas = workspace.currentCanvas
        HStack(spacing: 4) {
            Button(action: onShowCanvases) {
                Label {
                    Text(canvas?.title ?? "No canvas")
                        .font(.headline)
                        .lineLimit(1)
                } icon: {
                    Image(systemName: "square.grid.2x2")
                }
                .frame(minHeight: Theme.minTarget)
                .padding(.horizontal, 12)
            }
            .accessibilityHint("Shows all review canvases")

            Divider()
                .frame(height: 24)

            Button(action: onPickThread) {
                ThreadLabel(binding: canvas?.thread, state: connection.state)
                    .frame(minHeight: Theme.minTarget)
                    .padding(.horizontal, 12)
            }
            .accessibilityLabel(canvas?.thread.map { "Thread: \($0.displayName)" } ?? "No thread. Choose a T3 thread")
        }
        .buttonStyle(.plain)
        .foregroundStyle(Theme.ink)
        .paletteBackground()
    }
}
