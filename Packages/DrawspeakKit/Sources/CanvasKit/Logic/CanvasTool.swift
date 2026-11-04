import Foundation

/// The active canvas tool. Apple Pencil marks with it; fingers pan unless
/// Draw with Finger is on.
nonisolated public enum CanvasTool: String, CaseIterable, Identifiable, Sendable {
    case hand
    case region
    case arrow
    case pen
    case component

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .hand: String(localized: "Hand", bundle: .module)
        case .region: String(localized: "Region", bundle: .module)
        case .arrow: String(localized: "Arrow", bundle: .module)
        case .pen: String(localized: "Pen", bundle: .module)
        case .component: String(localized: "Component", bundle: .module)
        }
    }

    public var systemImage: String {
        switch self {
        case .hand: "hand.raised"
        case .region: "rectangle.dashed"
        case .arrow: "arrow.up.right"
        case .pen: "pencil.and.scribble"
        case .component: "cursorarrow.and.square.on.square.dashed"
        }
    }

    /// Single-key shortcut on a hardware keyboard.
    public var shortcutKey: Character {
        switch self {
        case .hand: "v"
        case .region: "r"
        case .arrow: "a"
        case .pen: "p"
        case .component: "c"
        }
    }

    /// The mark a drag draws. The component tool draws regions on images.
    var markKind: MarkKind? {
        switch self {
        case .hand: nil
        case .region, .component: .region
        case .arrow: .arrow
        case .pen: .pen
        }
    }
}
