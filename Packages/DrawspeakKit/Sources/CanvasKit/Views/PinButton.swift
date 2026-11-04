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
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(ordinal, format: .number)
                .font(.footnote.bold().monospacedDigit())
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .foregroundStyle(.white)
                .frame(width: Theme.pinSize, height: Theme.pinSize)
                .background(Theme.annotation, in: .circle)
                .overlay {
                    Circle().stroke(Theme.annotationHalo, lineWidth: isFocused ? 3 : 2.5)
                }
                .background {
                    if isRecording { RecordingRing() }
                }
                .frame(width: Theme.minTarget, height: Theme.minTarget)
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
