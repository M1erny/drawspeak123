#if canImport(UIKit)
import DrawspeakCore
import SwiftUI

/// A transient hint at the top of the canvas.
struct StatusBanner: View {
    let status: CanvasStatus
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack {
            if let message = status.message {
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(Theme.ink)
                    .padding(CanvasMetrics.statusInsets)
                    .paletteBackground()
                    .transition(.opacity)
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: status.message)
        .allowsHitTesting(false)
    }
}
#endif
