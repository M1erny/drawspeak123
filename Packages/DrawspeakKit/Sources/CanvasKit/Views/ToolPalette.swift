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
        ViewThatFits(in: .horizontal) {
            HStack(spacing: CanvasMetrics.spacing) { LegacyToolPaletteContent(tool: $tool, canUndo: canUndo, canRedo: canRedo, onUndo: onUndo, onRedo: onRedo) }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: Theme.minTarget))]) {
                LegacyToolPaletteContent(tool: $tool, canUndo: canUndo, canRedo: canRedo, onUndo: onUndo, onRedo: onRedo)
            }
        }
        .padding(CanvasMetrics.inset)
        .modifier(CanvasPaletteBackground())
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Tools", bundle: .module))
    }
}
#endif
