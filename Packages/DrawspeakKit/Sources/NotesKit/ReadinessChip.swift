import SwiftUI
import DrawspeakCore

struct ReadinessChip: View {
    let readiness: NoteReadiness

    var body: some View {
        Text(readiness.label)
            .font(.caption)
            .foregroundStyle(Theme.secondaryInk)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(Theme.secondaryInk.opacity(0.1), in: .capsule)
            .accessibilityLabel("Status: \(readiness.label)")
    }
}

#Preview { ReadinessChip(readiness: .ready) }
