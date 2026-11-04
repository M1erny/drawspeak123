import CoreGraphics
import DrawspeakCore

/// A component being chosen on one HTML card: the element stacks under one
/// point (layers) and the position on the chosen layer's hit-to-root chain.
nonisolated struct ComponentSelection: Equatable, Sendable {
    var slotId: String
    var snapshotId: String
    /// World frame of the card, for drawing the outline.
    var frame: CGRect
    /// `layers[0]` is the topmost element's hit-to-root chain.
    var layers: [[DOMElementInfo]]
    var layer = 0
    /// 0 is the hit element; higher values are its parents.
    var depth = 0
    var method: SelectionMethod
    var pressure: Double?

    init(slotId: String, snapshotId: String, frame: CGRect, layers: [[DOMElementInfo]], method: SelectionMethod) {
        self.slotId = slotId
        self.snapshotId = snapshotId
        self.frame = frame
        self.layers = layers.filter { !$0.isEmpty }
        self.method = method
    }

    var chain: [DOMElementInfo] { layers.indices.contains(layer) ? layers[layer] : [] }
    var element: DOMElementInfo? { chain.indices.contains(depth) ? chain[depth] : nil }
    var isEmpty: Bool { element == nil }
    var canSelectParent: Bool { depth < chain.count - 1 }
    var canSelectChild: Bool { depth > 0 }

    mutating func selectParent() {
        if canSelectParent { depth += 1 }
    }

    mutating func selectChild() {
        if canSelectChild { depth -= 1 }
    }

    mutating func select(depth newDepth: Int) {
        depth = min(max(newDepth, 0), max(chain.count - 1, 0))
    }

    /// A different layer starts at its own hit element; parents follow from there.
    mutating func select(layer newLayer: Int) {
        layer = min(max(newLayer, 0), max(layers.count - 1, 0))
        depth = 0
    }
}
