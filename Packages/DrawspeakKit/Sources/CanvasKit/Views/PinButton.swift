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
    /// Nil outside Select mode; otherwise whether this pin's comment is selected.
    var selection: Bool? = nil
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
                .overlay(alignment: .bottomTrailing) {
                    if let selection {
                        Image(systemName: selection ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: annotationStyle.pinFontSize * 0.9, weight: .semibold))
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, selection ? Theme.actionFill : Color.black.opacity(0.45))
                            .background(Circle().fill(selection ? Theme.actionFill : Color.black.opacity(0.25)))
                            .offset(x: annotationStyle.pinSize * 0.28, y: annotationStyle.pinSize * 0.28)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .opacity(selection == false ? 0.75 : 1)
                .animation(reduceMotion ? nil : .snappy(duration: 0.2), value: selection)
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
        .accessibilityAddTraits(isFocused || selection == true ? .isSelected : [])
        .accessibilityHint(selection == nil ? Text(verbatim: "") : Text("Selects or deselects this comment.", bundle: .module))
    }
}
#endif
