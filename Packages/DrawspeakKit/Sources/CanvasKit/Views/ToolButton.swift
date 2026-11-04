#if canImport(UIKit)
import DrawspeakCore
import SwiftUI

/// One tool in the palette, with its single-key shortcut.
struct ToolButton: View {
    let tool: CanvasTool
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(tool.title, systemImage: tool.systemImage, action: action)
            .labelStyle(.iconOnly)
            .font(.title3)
            .foregroundStyle(isSelected ? Theme.action : Theme.ink)
            .frame(width: Theme.minTarget, height: Theme.minTarget)
            .background(isSelected ? Theme.action.opacity(0.16) : .clear, in: .rect(cornerRadius: 12))
            .contentShape(.rect(cornerRadius: 12))
            .hoverEffect(.highlight)
            .keyboardShortcut(KeyEquivalent(tool.shortcutKey), modifiers: [])
            .help("\(tool.title) (\(String(tool.shortcutKey).uppercased()))")
            .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
#endif
