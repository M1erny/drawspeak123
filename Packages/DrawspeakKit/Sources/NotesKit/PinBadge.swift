import SwiftUI
import DrawspeakCore

public struct PinBadge: View {
    @Environment(\.annotationStyle) private var annotationStyle
    public let number: Int
    public let isActive: Bool

    public init(number: Int, isActive: Bool = false) {
        self.number = number
        self.isActive = isActive
    }

    public var body: some View {
        Text(number.formatted()).font(.system(size: annotationStyle.pinFontSize, weight: .bold)).monospacedDigit()
            .foregroundStyle(.white)
            .frame(minWidth: annotationStyle.pinSize, minHeight: annotationStyle.pinSize)
            .background(Theme.annotation, in: .circle)
            .overlay { Circle().strokeBorder(.white, lineWidth: 1.5) }
            .accessibilityLabel(Text("Comment \(number)", bundle: .module))
            .accessibilityValue(isActive ? Text("Active", bundle: .module) : Text(verbatim: ""))
    }
}

#Preview { PinBadge(number: 3, isActive: true) }
