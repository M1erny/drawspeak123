#if canImport(UIKit)
import CoreGraphics

/// A lane and its card's current screen rect.
struct LaneSlotPlacement: Identifiable {
    let slot: LaneSlot
    let rect: CGRect

    var id: String { slot.id }
}
#endif
