#if canImport(UIKit)
import DrawspeakCore
import SwiftUI

/// The floating zoom palette: −, percentage, +, Fit All.
/// Shortcuts: ⌘- zoom out, ⌘= zoom in, ⌘0 Fit All.
public struct ZoomControls: View {
    private let zoom: Double
    private let onZoomOut: () -> Void
    private let onZoomIn: () -> Void
    private let onFitAll: () -> Void

    public init(zoom: Double, onZoomOut: @escaping () -> Void, onZoomIn: @escaping () -> Void, onFitAll: @escaping () -> Void) {
        self.zoom = zoom
        self.onZoomOut = onZoomOut
        self.onZoomIn = onZoomIn
        self.onFitAll = onFitAll
    }

    public var body: some View {
        HStack(spacing: 2) {
            PaletteIconButton(title: "Zoom Out", systemImage: "minus", isEnabled: zoom > CameraState.minZoom, action: onZoomOut)
                .keyboardShortcut("-", modifiers: .command)
            Text(zoom, format: .percent.precision(.fractionLength(0)))
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(Theme.ink)
                .frame(minWidth: 52)
                .accessibilityLabel("Zoom")
                .accessibilityValue(zoom.formatted(.percent.precision(.fractionLength(0))))
            PaletteIconButton(title: "Zoom In", systemImage: "plus", isEnabled: zoom < CameraState.maxZoom, action: onZoomIn)
                .keyboardShortcut("=", modifiers: .command)
            Button("Fit All", action: onFitAll)
                .font(.subheadline)
                .foregroundStyle(Theme.action)
                .padding(.horizontal, 10)
                .frame(minHeight: Theme.minTarget)
                .contentShape(.rect(cornerRadius: 12))
                .hoverEffect(.highlight)
                .keyboardShortcut("0", modifiers: .command)
        }
        .padding(6)
        .paletteBackground()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Zoom")
    }
}
#endif
