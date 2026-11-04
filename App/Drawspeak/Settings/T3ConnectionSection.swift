import DrawspeakCore
import SwiftUI
import T3Kit

struct T3ConnectionSection: View {
    let connection: T3Connection
    @State private var showsPairing = false

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
                Button("Pair Again…", action: showPairing)
                Button("Disconnect", role: .destructive, action: connection.disconnect)
            case .connecting:
                ProgressView()
            case .notPaired, .expired, .failed:
                if connection.canReconnect {
                    Button("Reconnect", action: reconnect)
                }
                Button("Connect…", action: showPairing)
            }
        }
        .sheet(isPresented: $showsPairing) {
            T3PairingSheet(connection: connection, onClose: hidePairing)
        }
    }

    private func showPairing() { showsPairing = true }
    private func hidePairing() { showsPairing = false }

    private func reconnect() {
        Task { await connection.reconnect() }
    }
}
