#if canImport(UIKit)
import DrawspeakCore
import SwiftUI

/// A tool toggle. A Toggle (not a Button with its own background) so the toolbar's
/// glass group draws the selected state itself; it drops custom backgrounds on buttons.
struct ToolButton: View {
    let tool: CanvasTool
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Toggle(tool.title, systemImage: tool.systemImage, isOn: Binding(
            get: { isSelected },
            set: { isOn in if isOn { action() } }
        ))
        .toggleStyle(.button)
        .labelStyle(.iconOnly)
        .keyboardShortcut(KeyEquivalent(tool.shortcutKey), modifiers: [])
        .help(tool.title)
        .accessibilityShowsLargeContentViewer()
    }
}
#endif
