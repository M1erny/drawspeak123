import SwiftUI
import DrawspeakCore

public struct PinBadge: View {
    public let number: Int
    public let isActive: Bool

    public init(number: Int, isActive: Bool = false) {
        self.number = number
        self.isActive = isActive
    }

    public var body: some View {
        Text(number.formatted()).font(.caption.bold()).monospacedDigit()
            .foregroundStyle(.white)
            .frame(minWidth: Theme.pinSize, minHeight: Theme.pinSize)
            .padding(2)
            .background(Theme.annotation, in: .circle)
            .overlay { Circle().strokeBorder(.white, lineWidth: 1.5) }
            .accessibilityLabel("Comment \(number)")
            .accessibilityValue(isActive ? "Active" : "")
    }
}

#Preview { PinBadge(number: 3, isActive: true) }
