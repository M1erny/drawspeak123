import SwiftUI

/// How marks and numbered pins look on the canvas, in screen points. Set in Settings.
public struct AnnotationStyle: Hashable, Sendable {
    /// Stroke width of a mark, constant on screen at any zoom.
    public var lineWidth: CGFloat
    /// Diameter of the numbered pin.
    public var pinSize: CGFloat

    public init(lineWidth: CGFloat = Theme.markLineWidth, pinSize: CGFloat = Theme.pinSize) {
        self.lineWidth = lineWidth
        self.pinSize = pinSize
    }

    public static let standard = AnnotationStyle()
    public static let lineWidthRange: ClosedRange<CGFloat> = 1...8
    public static let pinSizeRange: ClosedRange<CGFloat> = 20...48

    /// The numeral size that fits the pin.
    public var pinFontSize: CGFloat { pinSize * 0.5 }
    /// Total width of the white halo drawn under a mark stroke.
    public var haloWidth: CGFloat { lineWidth + Self.haloExtra }
    /// The white ring around a pin, outside its fill. Fixed, so Line Width never
    /// thickens the pin border or covers its number.
    public static let pinRingWidth: CGFloat = 2
    public static let haloExtra: CGFloat = 2.5
}

public extension EnvironmentValues {
    @Entry var annotationStyle: AnnotationStyle = .standard
}
