import SwiftUI
import DrawspeakCore

/// A comment number. In lists it keeps the standard size (scaled with Dynamic Type);
/// over a screen preview (`matchesMarks`) it follows the Marks settings like the canvas pin.
public struct PinBadge: View {
    @Environment(\.annotationStyle) private var annotationStyle
    @ScaledMetric(relativeTo: .body) private var listSize = AnnotationStyle.standard.pinSize
    public let number: Int
    public let isActive: Bool
    public let matchesMarks: Bool

    public init(number: Int, isActive: Bool = false, matchesMarks: Bool = false) {
        self.number = number
        self.isActive = isActive
        self.matchesMarks = matchesMarks
    }

    private var size: CGFloat { matchesMarks ? annotationStyle.pinSize : listSize }

    public var body: some View {
        Text(number.formatted()).font(.system(size: size * 0.5, weight: .bold, design: .monospaced))
            .minimumScaleFactor(0.5)
            .lineLimit(1)
            .foregroundStyle(.white)
            .frame(minWidth: size, minHeight: size)
            .background(Theme.annotation, in: .circle)
            .padding(AnnotationStyle.pinRingWidth)
            .background(Theme.annotationHalo, in: .circle)
            .accessibilityLabel(Text("Comment \(number)", bundle: .module))
            .accessibilityValue(isActive ? Text("Active", bundle: .module) : Text(verbatim: ""))
    }
}

#Preview { PinBadge(number: 3, isActive: true) }
