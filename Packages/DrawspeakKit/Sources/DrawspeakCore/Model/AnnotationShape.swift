import Foundation

/// The geometry of one mark on a snapshot, in normalized snapshot space.
public enum AnnotationShape: Codable, Hashable, Sendable {
    /// A rectangular region.
    case region(NRect)
    /// An oval region.
    case ellipse(NRect)
    /// A closed freehand loop drawn around something.
    case lasso([NPoint])
    /// An arrow pointing from `from` to `to`.
    case arrow(from: NPoint, to: NPoint)
    /// An open freehand stroke.
    case stroke([NPoint])
    /// A selected HTML component; the geometry is the component outline.
    case component(NRect)

    public var bounds: NRect {
        switch self {
        case .region(let rect), .ellipse(let rect), .component(let rect):
            rect
        case .lasso(let points), .stroke(let points):
            NRect(bounding: points)
        case .arrow(let from, let to):
            NRect(bounding: [from, to])
        }
    }

    /// Regions and components identify a subject, so they start voice when
    /// auto voice is on. Arrows and strokes may stay marks without comments.
    public var identifiesSubject: Bool {
        switch self {
        case .region, .ellipse, .lasso, .component: true
        case .arrow, .stroke: false
        }
    }

    public var kindLabel: String {
        switch self {
        case .region: "Region"
        case .ellipse: "Oval"
        case .lasso: "Loop"
        case .arrow: "Arrow"
        case .stroke: "Mark"
        case .component: "Component"
        }
    }

    public var isValid: Bool {
        switch self {
        case .region(let rect), .ellipse(let rect), .component(let rect):
            rect.isValid
        case .lasso(let points):
            points.count >= 3 && NRect(bounding: points).isValid
        case .stroke(let points):
            points.count >= 2
        case .arrow(let from, let to):
            hypot(to.x - from.x, to.y - from.y) > 0.005
        }
    }
}
