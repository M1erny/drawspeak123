import SwiftUI

public struct T3PairingView: View {
    private let connection: T3Connection
    private let onPaired: () -> Void
    @State private var host: String
    @State private var code = ""
    @State private var accessLevel = "full-access"
    @State private var inputError: String?

    public init(connection: T3Connection, onPaired: @escaping () -> Void = {}) {
        self.connection = connection
        self.onPaired = onPaired
        _host = State(initialValue: connection.hostURL.absoluteString)
    }

    public var body: some View {
        Form {
            Section {
                PairingHostFields(host: $host, code: $code)
                PairingAccessPicker(selection: $accessLevel)
            } footer: {
                Text("In T3 Code on your Mac: Settings › Sharing & access › Create pairing link › Show code.", bundle: .module)
            }
            .disabled(connection.state == .connecting)
            if let errorMessage {
                Text(errorMessage)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .accessibilityLabel(errorMessage)
            }
        }
        .navigationTitle(Text("Connect to T3 Code", bundle: .module))
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(action: startConnecting) {
                    HStack {
                        Text("Connect", bundle: .module)
                        if connection.state == .connecting {
                            ProgressView()
                        }
                    }
                }
                .disabled(!canConnect)
            }
        }
        .tint(.primary)
        .onChange(of: host, clearInputError)
        .onChange(of: code, clearInputError)
        .onChange(of: accessLevel, clearInputError)
    }

    private var errorMessage: String? {
        if let inputError { return inputError }
        switch connection.state {
        case .failed(let error): return error
        case .expired: return String(localized: "Code expired. Create a new one.", bundle: .module)
        default: return nil
        }
    }

    private var canConnect: Bool {
        code.count == 12 && !host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && connection.state != .connecting
    }

    private func clearInputError() {
        inputError = nil
    }

    private func startConnecting() {
        Task { await connect() }
    }

    private func connect() async {
        guard canConnect else { return }
        inputError = nil
        do {
            let url = try T3Pairing.normalizeHost(host)
            await connection.pair(host: url, code: code, accessLevel: accessLevel)
            if case .connected = connection.state {
                code = ""
                onPaired()
            }
        } catch {
            inputError = error.message
        }
    }
}
