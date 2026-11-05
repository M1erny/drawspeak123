import Foundation

/// Reframes a canvas when it changes or its view size changes.
struct FramingKey: Equatable {
    var canvasId: UUID?
    var width: Int
    var height: Int
    /// Width covered by the Comments panel, so opening it frames the canvas again.
    var coverage: Int = 0
}
