#if canImport(UIKit)
import CoreGraphics

/// A mark and the screen position of its pin.
struct PinPlacement: Identifiable {
    let mark: PlacedMark
    let center: CGPoint

    var id: String { mark.id }
}
#endif
