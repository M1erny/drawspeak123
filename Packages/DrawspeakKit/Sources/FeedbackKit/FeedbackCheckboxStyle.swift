import SwiftUI
import DrawspeakCore

struct FeedbackCheckboxStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button { configuration.isOn.toggle() } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: configuration.isOn ? "checkmark.square.fill" : "square").foregroundStyle(Theme.action)
                configuration.label.foregroundStyle(.primary).frame(maxWidth: .infinity, alignment: .leading)
            }.padding(.vertical, 10).contentShape(.rect)
        }.buttonStyle(.plain)
            .accessibilityValue(configuration.isOn ? "Selected" : "Not selected")
            .accessibilityAddTraits(configuration.isOn ? [.isSelected] : [])
    }
}
