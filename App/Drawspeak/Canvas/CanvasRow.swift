import DrawspeakCore
import SwiftUI

struct CanvasRow: View {
    let canvas: ReviewCanvas
    let isCurrent: Bool

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(canvas.title)
                    .font(.headline)
                Text(canvas.thread?.displayName ?? "No thread")
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryInk)
                Text("\(canvas.snapshots.count) versions · \(canvas.notes.count) comments")
                    .font(.footnote)
                    .foregroundStyle(Theme.secondaryInk)
            }
            Spacer()
            if isCurrent {
                Image(systemName: "checkmark")
                    .foregroundStyle(Theme.action)
                    .accessibilityLabel("Current canvas")
            }
        }
        .frame(minHeight: Theme.minTarget)
        .accessibilityElement(children: .combine)
    }
}
