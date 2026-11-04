import DrawspeakCore
import SwiftUI
import T3Kit

struct T3ConnectionSection: View {
    let connection: T3Connection
    @State private var showsPairing = false

    var body: some View {
        Section {
            LabeledContent("Status", value: statusText)
            LabeledContent("Host", value: connection.hostURL.host() ?? connection.hostURL.absoluteString)
            if let warning = connection.compatibilityWarning {
                Text(warning)
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }
            switch connection.state {
            case .connected:
                Button("Disconnect", role: .destructive) { connection.disconnect() }
            case .connecting:
                ProgressView()
            case .notPaired, .expired, .failed:
                Button("Connect to T3 Code…") { showsPairing = true }
            }
        } header: {
            Text("T3 Code")
        } footer: {
            Text("Drawspeak reaches T3 Code over your tailnet and signs in with a pairing code. Sending feedback starts or steers the agent in the canvas's thread.")
        }
        .sheet(isPresented: $showsPairing) {
            NavigationStack {
                T3PairingView(connection: connection) { showsPairing = false }
                    .navigationTitle("Connect to T3 Code")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { showsPairing = false }
                        }
                    }
            }
        }
    }

    private var statusText: String {
        switch connection.state {
        case .notPaired: "Not connected"
        case .connecting: "Connecting…"
        case .connected: "Connected"
        case .expired: "Pairing expired — connect again"
        case .failed(let message): message
        }
    }
}
