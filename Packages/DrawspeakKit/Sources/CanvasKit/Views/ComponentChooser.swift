#if canImport(UIKit)
import DrawspeakCore
import SwiftUI

/// The pressure-free way to choose an HTML component: the hit-to-root chain
/// as buttons, Parent/Child with ⌘↑/⌘↓, and Layers for elements underneath.
/// Browsing only previews the outline; "Comment on…" creates the comment.
struct ComponentChooser: View {
    @Bindable var pick: ComponentPick
    let onCommit: () -> Void
    let onCancel: () -> Void

    var body: some View {
        if let selection = pick.selection, let element = selection.element {
            VStack(alignment: .leading, spacing: 12) {
                Text("Select Component")
                    .font(.headline)
                if selection.layers.count > 1 {
                    Picker("Layer", selection: $pick.layerIndex) {
                        ForEach(selection.layers.indices, id: \.self) { index in
                            Text(CanvasLabels.layerTitle(index: index, label: selection.layers[index].first?.label ?? "Element"))
                                .tag(index)
                        }
                    }
                    .pickerStyle(.menu)
                }
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(selection.chain.enumerated(), id: \.offset) { index, item in
                            ComponentChainRow(
                                title: CanvasLabels.depthTitle(depth: index, label: item.label),
                                detail: item.locator.displayText,
                                isSelected: index == selection.depth
                            ) {
                                pick.select(depth: index)
                            }
                        }
                    }
                }
                .frame(maxHeight: 264)
                HStack {
                    Button("Child", systemImage: "arrow.down", action: pick.selectChild)
                        .keyboardShortcut(.downArrow, modifiers: .command)
                        .disabled(!selection.canSelectChild)
                    Button("Parent", systemImage: "arrow.up", action: pick.selectParent)
                        .keyboardShortcut(.upArrow, modifiers: .command)
                        .disabled(!selection.canSelectParent)
                    Spacer()
                    Button("Cancel", role: .cancel, action: onCancel)
                        .keyboardShortcut(.cancelAction)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                Button(action: onCommit) {
                    Text("Comment on \(element.label)")
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, minHeight: Theme.minTarget)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
            .padding()
            .frame(minWidth: 320, idealWidth: 360, maxWidth: 420)
        }
    }
}
#endif
