import Foundation

/// The device behind a touch. Only Pencil reports usable force.
nonisolated enum InputKind: Sendable, Equatable {
    case pencil
    case finger
    /// Trackpad or mouse pointer.
    case pointer
}
