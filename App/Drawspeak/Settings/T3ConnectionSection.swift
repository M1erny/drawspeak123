import DrawspeakCore
import SwiftUI
import T3Kit

struct T3ConnectionSection: View {
    let connection: T3Connection
    /// Pushes the pairing screen in the Settings stack.
    let onPair: () -> Void

    var body: some View {
        Section("T3 Code") {
            LabeledContent("Status") {
                T3StatusText(state: connection.state)
            }
            if let warning = connection.compatibilityWarning {
                Text(warning)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            switch connection.state {
            case .connected:
                Button("Pair Again…", action: onPair)
                Button("Disconnect", role: .destructive, action: connection.disconnect)
            case .connecting:
                ProgressView()
            case .notPaired, .expired, .failed:
                if connection.canReconnect {
                    Button("Reconnect", action: reconnect)
                }
                Button("Connect…", action: onPair)
            }
        }
    }

    private func reconnect() {
        Task { await connection.reconnect() }
    }
}
