import DrawspeakCore
import Foundation

/// Elements under one point of an HTML snapshot.
nonisolated public struct DOMProbeResult: Sendable, Hashable, Codable {
    /// `layers[0]` is the hit-to-root chain of the topmost element. Each further
    /// layer starts at an element of the same point's stack that is not an
    /// ancestor of an earlier layer, followed by its own ancestors. Chains end at
    /// `<body>` and never include `<html>`. Bounds are normalized by the viewport.
    public var layers: [[DOMElementInfo]]

    public init(layers: [[DOMElementInfo]]) {
        self.layers = layers
    }

    public var isEmpty: Bool { layers.allSatisfy(\.isEmpty) }
}
