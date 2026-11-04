#if canImport(UIKit)
import DrawspeakCore
import SwiftUI

struct ComponentChooser: View {
    @Bindable var pick: ComponentPick
    let onCommit: () -> Void
    let onCancel: () -> Void
    var body: some View {
        ScrollView {
            if let selection = pick.selection {
                LazyVStack(alignment: .leading) {
                    if selection.layers.count > 1 {
                        Picker(selection: $pick.layerIndex) {
                            ForEach(selection.layers.enumerated(), id: \.element.first?.locator) { index, chain in
                                Text(chain.first?.label ?? "").tag(index)
                            }
                        } label: { Text("Components", bundle: .module) }
                        .pickerStyle(.menu)
                    }
                    ForEach(selection.chain.enumerated(), id: \.element.locator) { index, item in
                        ComponentChainRow(title: item.label, detail: item.locator.displayText, isSelected: index == selection.depth) {
                            pick.select(depth: index)
                        }
                        .padding(.leading, Double(min(index, 6)) * CanvasMetrics.inset)
                    }
                    ComponentChooserActions(pick: pick, selection: selection, onCancel: onCancel)
                    Button(String(localized: "Comment", bundle: .module), action: onCommit)
                        .frame(maxWidth: .infinity, minHeight: Theme.minTarget)
                        .buttonStyle(.bordered).keyboardShortcut(.defaultAction)
                }
                .id(selection.snapshotId)
                .padding()
            }
        }
        .frame(idealWidth: 360, maxWidth: 420, idealHeight: 400)
        .tint(.primary)
    }
}
#endif
