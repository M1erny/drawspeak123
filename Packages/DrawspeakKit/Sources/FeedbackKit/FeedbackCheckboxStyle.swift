import SwiftUI
import DrawspeakCore

struct FeedbackCheckboxStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button { configuration.isOn.toggle() } label: {
            HStack(alignment: .top, spacing: FeedbackLayout.spacing) {
                Image(systemName: configuration.isOn ? "checkmark.square.fill" : "square").foregroundStyle(.primary)
                configuration.label.foregroundStyle(.primary).frame(maxWidth: .infinity, alignment: .leading)
            }.padding(.vertical, FeedbackLayout.rowPadding).contentShape(.rect)
        }.buttonStyle(.plain)
            .accessibilityValue(configuration.isOn ? Text("Selected", bundle: .module) : Text("Not Selected", bundle: .module))
            .accessibilityAddTraits(configuration.isOn ? [.isSelected] : [])
    }
}
