#if canImport(UIKit)
import DrawspeakCore
import SwiftUI

/// A capsule keeps each 44-point tool concentric with its six-point inset.
struct CanvasPaletteBackground: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        content.background {
            if reduceTransparency {
                Capsule().fill(Theme.surface).shadow(color: .black.opacity(0.12), radius: 8, y: 2)
            } else {
                Capsule().fill(.clear).glassEffect(.regular, in: .capsule)
            }
        }
    }
}
#endif
