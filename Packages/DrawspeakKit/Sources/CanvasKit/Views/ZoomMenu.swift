#if canImport(UIKit)
import DrawspeakCore
import SwiftUI

/// Compact zoom menu that remains reachable in narrow windows.
public struct ZoomMenu: View {
    let zoom: Double
    let onZoomIn: () -> Void
    let onZoomOut: () -> Void
    let onFitAll: () -> Void
    let onActualSize: () -> Void

    public init(zoom: Double, onZoomIn: @escaping () -> Void, onZoomOut: @escaping () -> Void,
                onFitAll: @escaping () -> Void, onActualSize: @escaping () -> Void) {
        self.zoom = zoom
        self.onZoomIn = onZoomIn
        self.onZoomOut = onZoomOut
        self.onFitAll = onFitAll
        self.onActualSize = onActualSize
    }

    public var body: some View {
        Menu {
            Button(String(localized: "Zoom In", bundle: .module), systemImage: "plus.magnifyingglass", action: onZoomIn)
                .disabled(zoom >= CameraState.maxZoom).keyboardShortcut("=", modifiers: .command)
            Button(String(localized: "Zoom Out", bundle: .module), systemImage: "minus.magnifyingglass", action: onZoomOut)
                .disabled(zoom <= CameraState.minZoom).keyboardShortcut("-", modifiers: .command)
            Button(String(localized: "Fit All", bundle: .module), action: onFitAll).keyboardShortcut("0", modifiers: .command)
            Button(String(localized: "100%", bundle: .module), action: onActualSize)
        } label: {
            HStack {
                Text(zoom, format: .percent.precision(.fractionLength(0)))
                Image(systemName: "chevron.down").imageScale(.small).accessibilityHidden(true)
            }
            .font(.subheadline.monospacedDigit())
            .padding(.horizontal)
            .frame(minHeight: Theme.minTarget)
        }
        .foregroundStyle(.primary)
        .modifier(CanvasPaletteBackground())
        .accessibilityLabel(Text("Zoom", bundle: .module))
        .accessibilityValue(Text(zoom, format: .percent.precision(.fractionLength(0))))
    }
}
#endif
