#if canImport(UIKit)
import DrawspeakCore
import SwiftUI

struct ComponentChooserActions: View {
    let pick: ComponentPick
    let selection: ComponentSelection
    let onCancel: () -> Void
    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack { ComponentChooserActionButtons(pick: pick, selection: selection, onCancel: onCancel) }
            VStack { ComponentChooserActionButtons(pick: pick, selection: selection, onCancel: onCancel) }
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
    }
}
#endif
