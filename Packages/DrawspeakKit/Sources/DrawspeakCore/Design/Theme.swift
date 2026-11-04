import SwiftUI

/// Shared visual language. Annotations get the strongest contrast; chrome stays calm.
public enum Theme {
    /// Pencil marks, pins, composites and the recording anchor. Fixed in both
    /// appearances: marks sit on screenshots, which do not change with Dark Mode.
    public static let annotation = Color(hex: 0xBD3048)
    /// Halo drawn under marks and pins so they stay visible on any screenshot.
    public static let annotationHalo = Color.white
    /// Text-tinted controls (links, borderless and bordered buttons).
    public static let action = Color(light: 0x1758BD, dark: 0x95BAFF)
    /// Fill of filled primary buttons (Send to Agent, Feedback) with a white label.
    /// Fixed so the white label keeps its contrast in Dark Mode.
    public static let actionFill = Color(hex: 0x1758BD)
    /// Canvas background behind snapshots.
    public static let canvas = Color(light: 0xF5F6F8, dark: 0x181B1F)
    /// Snapshot paper and opaque palette fallback.
    public static let surface = Color(light: 0xFFFFFF, dark: 0x24272B)
    public static let ink = Color(light: 0x20252D, dark: 0xF2F3F5)
    public static let secondaryInk = Color(light: 0x556171, dark: 0xB9C2CF)
    /// Component selection outline in HTML snapshots.
    public static let componentOutline = Color(light: 0x1758BD, dark: 0x95BAFF)

    /// Minimum touch target, in points.
    public static let minTarget: CGFloat = 44
    /// Pin diameter on screen, independent of zoom.
    public static let pinSize: CGFloat = 30
    public static let paletteCornerRadius: CGFloat = 22
    public static let cardCornerRadius: CGFloat = 10
    /// Mark stroke width on screen, independent of zoom.
    public static let markLineWidth: CGFloat = 3
}

public extension Color {
    /// A fixed color from a 0xRRGGBB value, identical in light and dark appearance.
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }

    /// A dynamic color from 0xRRGGBB values for light and dark appearance.
    init(light: UInt32, dark: UInt32) {
        #if canImport(UIKit)
        self.init(uiColor: UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(
                red: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255,
                alpha: 1
            )
        })
        #else
        let hex = light
        self.init(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
        #endif
    }
}

/// Floating palette chrome: Liquid Glass, opaque when Reduce Transparency is on.
public struct PaletteBackground: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    public init() {}

    public func body(content: Content) -> some View {
        if reduceTransparency {
            content
                .background(Theme.surface, in: .rect(cornerRadius: Theme.paletteCornerRadius))
                .shadow(color: .black.opacity(0.12), radius: 8, y: 2)
        } else {
            content.glassEffect(.regular, in: .rect(cornerRadius: Theme.paletteCornerRadius))
        }
    }
}

public extension View {
    func paletteBackground() -> some View { modifier(PaletteBackground()) }
}
