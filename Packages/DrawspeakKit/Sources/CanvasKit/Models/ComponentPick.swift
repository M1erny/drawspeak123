import CoreGraphics
import Observation

/// Component selection state shared by the outline, the chip near the Pencil
/// tip and the chooser panel.
@Observable
final class ComponentPick {
    /// The selection being made with Pencil pressure or in the chooser.
    var selection: ComponentSelection?
    /// Screen position of the Pencil tip during a pressure selection.
    var tipLocation: CGPoint?
    var isChooserPresented = false
    /// Screen point the chooser popover points at.
    var chooserAnchor: CGPoint = .zero
    /// Hover preview; never creates a comment.
    var hover: HoverOutline?

    /// The chosen layer, bindable from the Layers picker.
    var layerIndex: Int {
        get { selection?.layer ?? 0 }
        set { selection?.select(layer: newValue) }
    }

    func selectParent() { selection?.selectParent() }
    func selectChild() { selection?.selectChild() }
    func select(depth: Int) { selection?.select(depth: depth) }

    func showChooser(_ selection: ComponentSelection, at anchor: CGPoint) {
        hover = nil
        tipLocation = nil
        self.selection = selection
        chooserAnchor = anchor
        isChooserPresented = true
    }

    func clear() {
        if selection != nil { selection = nil }
        if tipLocation != nil { tipLocation = nil }
        if isChooserPresented { isChooserPresented = false }
    }
}
