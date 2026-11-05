import SwiftUI
import DrawspeakCore

/// A screen's title with a control that selects or deselects all its comments.
struct FeedbackGroupHeader: View {
    let group: FeedbackPreviewGroup
    let model: FeedbackPreviewModel

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(group.title)
            Spacer()
            if group.notes.count > 1 {
                Button(action: toggle) {
                    if allSelected { Text("Deselect All", bundle: .module) } else { Text("Select All", bundle: .module) }
                }
                .font(.footnote)
                .buttonStyle(.borderless)
                .textCase(nil)
                .accessibilityLabel(allSelected
                    ? Text("Deselect All in \(group.title)", bundle: .module)
                    : Text("Select All in \(group.title)", bundle: .module))
            }
        }
    }

    private var allSelected: Bool { model.isSelected(all: group.notes) }
    private func toggle() { model.setSelection(!allSelected, for: group.notes) }
}
