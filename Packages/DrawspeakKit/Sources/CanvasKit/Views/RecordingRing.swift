#if canImport(UIKit)
import DrawspeakCore
import SwiftUI

/// The anchor ring around the pin of the note being recorded. It pulses,
/// and stays still under Reduce Motion.
struct RecordingRing: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Environment(\.annotationStyle) private var annotationStyle
    var body: some View {
        Circle()
            .stroke(Theme.annotation, lineWidth: annotationStyle.lineWidth)
            .frame(width: annotationStyle.pinSize + 12, height: annotationStyle.pinSize + 12)
            .phaseAnimator(reduceMotion ? [1.0] : [1.0, 1.3]) { ring, scale in
                ring
                    .scaleEffect(scale)
                    .opacity(1.6 - scale)
            } animation: { _ in
                .easeInOut(duration: 0.8)
            }
            .accessibilityHidden(true)
    }
}
#endif
