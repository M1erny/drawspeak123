#if canImport(UIKit)
import DrawspeakCore
import SwiftUI

/// An icon-only palette action with a 44 pt target and a VoiceOver title.
struct PaletteIconButton: View {
    let title: String
    let systemImage: String
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button(title, systemImage: systemImage, action: action)
            .labelStyle(.iconOnly)
            .font(.title3)
            .foregroundStyle(Theme.ink)
            .frame(width: Theme.minTarget, height: Theme.minTarget)
            .contentShape(.rect(cornerRadius: 12))
            .hoverEffect(.highlight)
            .disabled(!isEnabled)
    }
}
#endif
