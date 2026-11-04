import SwiftUI
import DrawspeakCore

/// Actions of the open comment, below its text where the hand already is.
struct CommentActionBar: View {
    let recording: Bool
    let canRecord: Bool
    let canDelete: Bool
    let onToggleRecording: () -> Void
    let onShowSource: () -> Void
    let onDelete: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: NotesMetrics.controlSpacing) {
            Button(action: onToggleRecording) {
                Label {
                    if recording { Text("Stop", bundle: .module) }
                    else { Text("Record Again", bundle: .module) }
                } icon: {
                    Image(systemName: recording ? "stop.fill" : "mic")
                        // HIG: “Aim for brevity and precision in feedback animations.”
                        .symbolEffect(.pulse, options: .nonRepeating, value: recording)
                        .symbolEffectsRemoved(reduceMotion)
                }
            }
            .disabled(!recording && !canRecord)
            Button(action: onShowSource) {
                Label { Text("Show on Canvas", bundle: .module) } icon: { Image(systemName: "viewfinder") }
            }
            Spacer(minLength: 0)
            Button(role: .destructive, action: onDelete) {
                Label { Text("Delete", bundle: .module) } icon: { Image(systemName: "trash") }
            }
            .labelStyle(.iconOnly)
            .disabled(!canDelete)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .frame(minHeight: Theme.minTarget)
    }
}
