import DrawspeakCore
import SwiftUI
import T3Kit

struct ThreadLabel: View {
    let binding: ThreadBinding?
    let state: T3ConnectionState

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(indicatorColor)
                .frame(width: 8, height: 8)
                .accessibilityHidden(true)
            if let binding {
                Text(binding.threadTitle)
                    .font(.subheadline)
                    .lineLimit(1)
            } else {
                Text("Choose Thread")
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryInk)
            }
        }
    }

    private var indicatorColor: Color {
        switch state {
        case .connected: .green
        case .connecting: .orange
        case .notPaired, .expired, .failed: .secondary
        }
    }
}
