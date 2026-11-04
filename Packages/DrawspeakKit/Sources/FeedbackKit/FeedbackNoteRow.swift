import SwiftUI
import DrawspeakCore

struct FeedbackNoteRow: View {
    let note: Note
    let reason: String?
    @Binding var selection: Set<UUID>

    var body: some View {
        Button(action: toggleSelection) {
            HStack(alignment: .top, spacing: FeedbackLayout.spacing) {
                Image(systemName: selection.contains(note.id) ? "checkmark.circle.fill" : "circle").accessibilityHidden(true)
                VStack(alignment: .leading) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(note.ordinal, format: .number).monospacedDigit()
                        Text(note.trimmedText)
                    }
                    if note.lastSentRevision != nil {
                        Image(systemName: "paperplane").accessibilityLabel(Text("Previously Sent", bundle: .module))
                    }
                    if let reason { Text(reason).font(.caption).foregroundStyle(.secondary) }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .frame(minHeight: Theme.minTarget)
        .accessibilityValue(selection.contains(note.id) ? Text("Selected", bundle: .module) : Text("Not Selected", bundle: .module))
        .accessibilityAddTraits(selection.contains(note.id) ? [.isSelected] : [])
    }

    private func toggleSelection() {
        if selection.contains(note.id) { selection.remove(note.id) }
        else { selection.insert(note.id) }
    }
}
