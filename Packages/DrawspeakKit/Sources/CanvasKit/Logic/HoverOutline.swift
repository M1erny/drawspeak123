import CoreGraphics
import DrawspeakCore

/// The element a hovering Pencil or pointer would select. Preview only.
nonisolated struct HoverOutline: Equatable, Sendable {
    var slotId: String
    var frame: CGRect
    var element: DOMElementInfo
}
