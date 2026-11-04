import Foundation

/// A short confirmation shown next to the zoom menu for a few seconds.
struct CanvasStatus: Identifiable, Equatable {
    let id = UUID()
    var text: AttributedString
}
