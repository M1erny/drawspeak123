#if canImport(UIKit)
import DrawspeakCore
import SwiftUI

/// "Pay Button · parent 1 of 4", floating above the Pencil tip while
/// pressure chooses the depth.
struct ComponentChip: View {
    let pick: ComponentPick

    var body: some View {
        if let tip = pick.tipLocation, let selection = pick.selection, let element = selection.element {
            Text(CanvasLabels.componentChip(label: element.label, depth: selection.depth, chainCount: selection.chain.count))
                .font(.subheadline.bold())
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .paletteBackground()
                .fixedSize()
                .position(x: tip.x, y: tip.y - 56)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }
}
#endif
