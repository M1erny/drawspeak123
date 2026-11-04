import CanvasKit
import SwiftUI

/// Bottom leading: the zoom menu and, briefly, the last confirmation.
struct CanvasStatusBar: View {
    let controller: CanvasController
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack {
            ZoomMenu(
                zoom: controller.zoom,
                onZoomIn: controller.zoomIn,
                onZoomOut: controller.zoomOut,
                onFitAll: controller.fitAll,
                onActualSize: controller.actualSize
            )
            if let status = controller.status {
                Text(status.text)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .leading)))
                    .task(id: status.id) { await expire(status) }
            }
        }
        .padding()
        .animation(reduceMotion ? .easeInOut : .snappy, value: controller.status)
    }

    private func expire(_ status: CanvasStatus) async {
        AccessibilityNotification.Announcement(String(status.text.characters)).post()
        do {
            try await Task.sleep(for: ShellMetrics.statusDuration)
        } catch {
            return
        }
        controller.clearStatus(status.id)
    }
}
