#if canImport(UIKit)
import DrawspeakCore
import SwiftUI

/// A monochrome tool toggle with a shape cue as well as selected semantics.
struct ToolButton: View {
    let tool: CanvasTool
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(tool.title, systemImage: tool.systemImage, action: action)
            .labelStyle(.iconOnly)
            .font(.title3)
            .foregroundStyle(.primary)
            .frame(minWidth: Theme.minTarget, minHeight: Theme.minTarget)
            .background(isSelected ? Color.primary.opacity(0.12) : .clear, in: .capsule)
            .overlay { Capsule().strokeBorder(.primary, lineWidth: isSelected ? 1.5 : 0) }
            .contentShape(.capsule)
            .hoverEffect(.highlight)
            .keyboardShortcut(KeyEquivalent(tool.shortcutKey), modifiers: [])
            .help(tool.title)
            .accessibilityAddTraits(isSelected ? .isSelected : [])
            .accessibilityShowsLargeContentViewer()
    }
}
#endif
