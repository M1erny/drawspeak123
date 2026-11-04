import SwiftUI
import DrawspeakCore

struct ReadinessChip: View {
    let readiness: NoteReadiness

    private var symbol: String {
        switch readiness {
        case .ready: "checkmark.circle"
        case .sourceUnavailable: "exclamationmark.triangle"
        case .markOnly: "text.bubble"
        case .recording: "mic.fill"
        case .transcribing: "waveform"
        case .sent: "paperplane"
        }
    }

    var body: some View {
        Label(readiness.label, systemImage: symbol)
            .font(.caption)
            .foregroundStyle(Theme.secondaryInk)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(Theme.secondaryInk.opacity(0.1), in: .capsule)
            .accessibilityLabel("Status: \(readiness.label)")
    }
}

#Preview { ReadinessChip(readiness: .ready) }
