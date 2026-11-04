#if canImport(UIKit)
import DrawspeakCore
import SwiftUI

struct ComponentChooserActionButtons: View {
    let pick: ComponentPick
    let selection: ComponentSelection
    let onCancel: () -> Void
    var body: some View {
            Button(String(localized: "Child", bundle: .module), systemImage: "chevron.down", action: pick.selectChild)
                .labelStyle(.iconOnly).keyboardShortcut(.downArrow, modifiers: .command)
                .disabled(!selection.canSelectChild)
            Button(String(localized: "Parent", bundle: .module), systemImage: "chevron.up", action: pick.selectParent)
                .labelStyle(.iconOnly).keyboardShortcut(.upArrow, modifiers: .command)
                .disabled(!selection.canSelectParent)
            Button(String(localized: "Cancel", bundle: .module), systemImage: "xmark", role: .cancel, action: onCancel)
                .labelStyle(.iconOnly).keyboardShortcut(.cancelAction)
    }
}
#endif
