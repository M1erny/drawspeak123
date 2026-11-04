#if canImport(UIKit)
import CoreGraphics

/// A screen row and the screen position of its title chip.
struct ScreenRowPlacement: Identifiable {
    let row: ScreenRow
    let origin: CGPoint

    var id: String { row.id }
}
#endif
