import DrawspeakCore
import SwiftUI
import T3Kit

struct ThreadLabel: View {
    let binding: ThreadBinding?
    let state: T3ConnectionState

    var body: some View {
        HStack(spacing: 6) {
            if binding != nil {
                Image(systemName: statusSymbol)
                    .foregroundStyle(indicatorColor)
                    .imageScale(.small)
                    .accessibilityHidden(true)
            }
            if let binding {
                Text(binding.threadTitle)
                    .font(.subheadline)
                    .lineLimit(1)
            } else {
                Label("Choose Thread", systemImage: "link.badge.plus")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.action)
            }
        }
    }

    private var statusSymbol: String {
        switch state {
        case .connected: "checkmark.circle.fill"
        case .connecting: "arrow.triangle.2.circlepath"
        case .notPaired, .expired, .failed: "exclamationmark.circle"
        }
    }

    private var indicatorColor: Color {
        switch state {
        case .connected: .green
        case .connecting: .orange
        case .notPaired, .expired, .failed: .orange
        }
    }
}
