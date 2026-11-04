#if canImport(UIKit)
import DrawspeakCore
import SwiftUI

/// A transient hint at the top of the canvas.
struct StatusBanner: View {
    let status: CanvasStatus

    var body: some View {
        VStack {
            if let message = status.message {
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .paletteBackground()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: status.message)
        .allowsHitTesting(false)
    }
}
#endif
