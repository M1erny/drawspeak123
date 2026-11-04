#if canImport(UIKit)
import DrawspeakCore
import SwiftUI

/// A numbered pin at a mark's top-left corner. Constant size on screen with
/// a 44 pt target; tapping it focuses the note.
struct PinButton: View {
    let ordinal: Int
    let label: String
    let isFocused: Bool
    let isRecording: Bool
    var isNewCommit = false
    let action: () -> Void

    @State private var settled = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.annotationStyle) private var annotationStyle
    var body: some View {
        Button(action: action) {
            Text(ordinal, format: .number)
                .font(.system(size: annotationStyle.pinFontSize, weight: .bold, design: .monospaced))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .foregroundStyle(.white)
                .frame(width: annotationStyle.pinSize, height: annotationStyle.pinSize)
                .background(Theme.annotation, in: .circle)
                .overlay {
                    Circle().stroke(Theme.annotationHalo, lineWidth: annotationStyle.lineWidth + 2.5)
                }
                .background {
                    if isRecording { RecordingRing() }
                }
                .scaleEffect(isFocused ? 1.08 : 1)
                .animation(reduceMotion ? nil : .snappy(duration: 0.2), value: isFocused)
                .scaleEffect(isNewCommit && !settled && !reduceMotion ? 0.85 : 1)
                .task(id: isNewCommit) {
                    guard isNewCommit else { return }
                    withAnimation(reduceMotion ? nil : .snappy(duration: 0.2)) { settled = true }
                }
                .frame(width: max(44, annotationStyle.pinSize), height: max(44, annotationStyle.pinSize))
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .hoverEffect(.lift)
        .accessibilityLabel(label)
        .accessibilityValue(isRecording ? Text("Recording", bundle: .module) : Text(verbatim: ""))
        .accessibilityAddTraits(isFocused ? .isSelected : [])
    }
}
#endif
