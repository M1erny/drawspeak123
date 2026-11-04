import Foundation

/// How a component locator was built, in order of preference.
public enum LocatorStrategy: String, Codable, Hashable, Sendable {
    case dataReviewId = "data-review-id"
    case id
    case cssPath = "css-path"
}

public struct DOMLocator: Codable, Hashable, Sendable {
    public var strategy: LocatorStrategy
    public var value: String

    public init(strategy: LocatorStrategy, value: String) {
        self.strategy = strategy
        self.value = value
    }

    public var displayText: String {
        switch strategy {
        case .dataReviewId: "[data-review-id=\"\(value)\"]"
        case .id: "#\(value)"
        case .cssPath: value
        }
    }
}

/// One element on the hit-to-root chain of a component selection.
public struct DOMElementInfo: Codable, Hashable, Sendable {
    public var label: String
    public var tagName: String
    public var locator: DOMLocator
    /// Outline of the element in normalized capture space.
    public var bounds: NRect

    public init(label: String, tagName: String, locator: DOMLocator, bounds: NRect) {
        self.label = label
        self.tagName = tagName
        self.locator = locator
        self.bounds = bounds
    }
}

public enum SelectionMethod: String, Codable, Hashable, Sendable {
    case pencilPressure = "pencil-pressure"
    case touch
    case pointer
    case keyboard
}

/// A versioned HTML component target. The locator is local to this snapshot
/// version; it is never carried to another iteration as identity.
public struct DOMTarget: Codable, Hashable, Sendable {
    public var snapshotId: String
    public var sourceHash: String
    public var renderHash: String
    public var renderPolicy: RenderPolicy
    public var viewport: Viewport
    public var locator: DOMLocator
    public var label: String
    public var tagName: String
    /// Hit element first, root last.
    public var ancestry: [DOMElementInfo]
    public var selectedDepth: Int
    /// Index in the element stack under the point; 0 is the topmost element.
    public var layer: Int
    public var selectionMethod: SelectionMethod
    public var pressure: Double?
    public var bounds: NRect

    public init(
        snapshotId: String,
        sourceHash: String,
        renderHash: String,
        renderPolicy: RenderPolicy,
        viewport: Viewport,
        locator: DOMLocator,
        label: String,
        tagName: String,
        ancestry: [DOMElementInfo],
        selectedDepth: Int,
        layer: Int,
        selectionMethod: SelectionMethod,
        pressure: Double?,
        bounds: NRect
    ) {
        self.snapshotId = snapshotId
        self.sourceHash = sourceHash
        self.renderHash = renderHash
        self.renderPolicy = renderPolicy
        self.viewport = viewport
        self.locator = locator
        self.label = label
        self.tagName = tagName
        self.ancestry = ancestry
        self.selectedDepth = selectedDepth
        self.layer = layer
        self.selectionMethod = selectionMethod
        self.pressure = pressure
        self.bounds = bounds
    }
}
