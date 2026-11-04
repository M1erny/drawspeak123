#if canImport(UIKit)
import DrawspeakCore
import SwiftUI

/// A capsule keeps each 44-point tool concentric with its six-point inset.
struct CanvasPaletteBackground: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        if reduceTransparency {
            content.background(Theme.surface, in: .capsule)
                .shadow(color: .black.opacity(0.12), radius: 8, y: 2)
        } else {
            content.glassEffect(.regular, in: .capsule)
        }
    }
}
#endif
