import Foundation

/// What a drawn stroke can become once it ends.
nonisolated enum MarkKind: Sendable, Equatable {
    /// A closed loop becomes a lasso, any other drag a rectangular region.
    case region
    case arrow
    /// An open freehand stroke.
    case pen
}
