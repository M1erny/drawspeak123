import DrawspeakCore
import SwiftUI

/// Canvas title with its thread underneath, when it has one.
struct CanvasRow: View {
    let canvas: ReviewCanvas

    var body: some View {
        VStack(alignment: .leading) {
            Text(canvas.title)
                .lineLimit(2)
            if let thread = canvas.thread {
                Text(thread.displayName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(minHeight: Theme.minTarget, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
