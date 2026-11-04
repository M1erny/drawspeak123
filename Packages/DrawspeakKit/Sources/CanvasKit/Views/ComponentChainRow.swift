#if canImport(UIKit)
import DrawspeakCore
import SwiftUI

/// One element of the hit-to-root chain in the component chooser.
struct ComponentChainRow: View {
    let title: String
    let detail: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .foregroundStyle(Theme.ink)
                    Text(detail)
                        .font(.footnote.monospaced())
                        .foregroundStyle(Theme.secondaryInk)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer()
                Image(systemName: "checkmark")
                    .foregroundStyle(Theme.action)
                    .opacity(isSelected ? 1 : 0)
                    .accessibilityHidden(true)
            }
            .padding(.vertical, 6)
            .frame(minHeight: Theme.minTarget)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
#endif
