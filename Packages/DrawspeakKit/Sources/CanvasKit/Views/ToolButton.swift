#if canImport(UIKit)
import DrawspeakCore
import SwiftUI
import UIKit

/// One tool in the palette, with its single-key shortcut.
struct ToolButton: View {
    let tool: CanvasTool
    let isSelected: Bool
    let action: () -> Void

    private var symbol: String {
        tool == .pen && UIImage(systemName: tool.systemImage) == nil ? "scribble" : tool.systemImage
    }

    var body: some View {
        Button(tool.title, systemImage: symbol, action: action)
            .labelStyle(.iconOnly)
            .font(.title3)
            .foregroundStyle(isSelected ? Theme.action : Theme.ink)
            .frame(width: Theme.minTarget, height: Theme.minTarget)
            .background(isSelected ? Theme.action.opacity(0.16) : .clear, in: .capsule)
            .contentShape(.capsule)
            .hoverEffect(.highlight)
            .keyboardShortcut(KeyEquivalent(tool.shortcutKey), modifiers: [])
            .help("\(tool.title) (\(String(tool.shortcutKey).uppercased()))")
            .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
#endif
