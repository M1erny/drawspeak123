#if canImport(UIKit)
import DrawspeakCore
import SwiftUI

/// The floating drawing palette: tools, then Undo and Redo.
/// Shortcuts: V hand, R region, A arrow, P pen, C component, ⌘Z, ⇧⌘Z.
public struct ToolPalette: View {
    @Binding private var tool: CanvasTool
    private let canUndo: Bool
    private let canRedo: Bool
    private let onUndo: () -> Void
    private let onRedo: () -> Void

    public init(
        tool: Binding<CanvasTool>,
        canUndo: Bool,
        canRedo: Bool,
        onUndo: @escaping () -> Void,
        onRedo: @escaping () -> Void
    ) {
        self._tool = tool
        self.canUndo = canUndo
        self.canRedo = canRedo
        self.onUndo = onUndo
        self.onRedo = onRedo
    }

    public var body: some View {
        HStack(spacing: 4) {
            ForEach(CanvasTool.allCases) { item in
                ToolButton(tool: item, isSelected: item == tool) {
                    tool = item
                }
            }
            Divider()
                .frame(height: 28)
                .padding(.horizontal, 4)
            PaletteIconButton(title: "Undo", systemImage: "arrow.uturn.backward", isEnabled: canUndo, action: onUndo)
                .keyboardShortcut("z", modifiers: .command)
            PaletteIconButton(title: "Redo", systemImage: "arrow.uturn.forward", isEnabled: canRedo, action: onRedo)
                .keyboardShortcut("z", modifiers: [.command, .shift])
        }
        .padding(6)
        .paletteBackground()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Tools")
    }
}
#endif
