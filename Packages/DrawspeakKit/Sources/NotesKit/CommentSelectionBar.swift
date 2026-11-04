import SwiftUI
import DrawspeakCore

/// Actions for the comments picked in Select mode, at the bottom of the Comments column.
struct CommentSelectionBar: View {
    let selectedCount: Int
    let deletableCount: Int
    let allSelected: Bool
    let canSelectAll: Bool
    let canSend: Bool
    let onToggleAll: () -> Void
    let onSend: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(spacing: NotesMetrics.controlSpacing) {
            HStack {
                Button(action: onToggleAll) {
                    if allSelected { Text("Deselect All", bundle: .module) } else { Text("Select All", bundle: .module) }
                }
                .disabled(!canSelectAll)
                Spacer()
                Group {
                    if selectedCount == 0 { Text("Tap comments or pins on the canvas", bundle: .module) }
                    else { Text("\(selectedCount) Selected", bundle: .module) }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .lineLimit(1)
            }
            HStack(spacing: NotesMetrics.controlSpacing) {
                if canSend {
                    Button(action: onSend) {
                        Label { Text("Send Selected", bundle: .module) } icon: { Image(systemName: "paperplane") }
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(Theme.actionFill)
                    .disabled(selectedCount == 0)
                }
                Button(role: .destructive, action: onDelete) {
                    Label { Text("Delete ^[\(deletableCount) Comments](inflect: true)", bundle: .module) } icon: { Image(systemName: "trash") }
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.glass)
                .disabled(deletableCount == 0)
            }
            .controlSize(.large)
        }
        .padding(.horizontal)
        .padding(.vertical, NotesMetrics.controlSpacing)
    }
}
