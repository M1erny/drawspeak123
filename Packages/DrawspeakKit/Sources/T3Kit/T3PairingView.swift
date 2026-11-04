import SwiftUI
import DrawspeakCore

public struct T3PairingView: View {
    @Bindable private var connection: T3Connection
    @State private var host: String
    @State private var code = ""
    @State private var accessLevel = "full-access"
    @State private var inputError: String?
    private let onPaired: () -> Void
    public init(connection: T3Connection, onPaired: @escaping () -> Void = {}) {
        self.connection = connection; _host = State(initialValue: connection.hostURL.absoluteString); self.onPaired = onPaired
    }
    public var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Keep T3 Code open and make sure this iPad can reach your Mac.")
                        .font(.callout)
                } header: {
                    Text("Get a pairing code")
                } footer: {
                    Text("On your Mac: T3 Code › Settings › Sharing & access › Create pairing link › Show code")
                }
                Section("T3 Code") {
                    LabeledContent("Host") {
                        TextField("https://your-mac", text: $host)
                            .multilineTextAlignment(.trailing)
                            .autocorrectionDisabled()
                            #if os(iOS)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            #endif
                            .accessibilityLabel("Host")
                            .frame(minHeight: 44)
                    }
                    LabeledContent("Pairing code") {
                        TextField("12-character code", text: $code)
                            .font(.body.monospaced())
                            .multilineTextAlignment(.trailing)
                            .textContentType(.oneTimeCode)
                            .autocorrectionDisabled()
                            #if os(iOS)
                            .textInputAutocapitalization(.characters)
                            #endif
                            .accessibilityLabel("Pairing code")
                            .frame(minHeight: 44)
                            .onChange(of: code) { _, value in code = String(value.uppercased().prefix(12)) }
                    }
                }
                Section {
                    Picker("Access level", selection: $accessLevel) {
                        Text("Full access").tag("full-access")
                        Text("Auto").tag("auto")
                        Text("Auto accept edits").tag("auto-accept-edits")
                        Text("Approval required").tag("approval-required")
                        Text("Read only").tag("read-only")
                    }
                    Text(accessDescription).font(.footnote).foregroundStyle(Theme.secondaryInk)
                } header: {
                    Text("Choose access")
                } footer: {
                    Text("Full access is selected because new T3 threads default to full access. Threads created with full access need full access to receive feedback. Lower levels can send only to threads at or below that level. You can revoke access on your Mac.")
                }
                Section {
                    Button { Task { await connect() } } label: {
                        Label("Connect", systemImage: "link")
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canConnect)
                    if !canConnect && connection.state != .connecting {
                        Text("Enter a host and a 12-character pairing code to connect.")
                            .font(.footnote).foregroundStyle(Theme.secondaryInk)
                    }
                    if let warning = connection.compatibilityWarning { Text(warning).foregroundStyle(Theme.secondaryInk) }
                    if connection.state == .connecting { ProgressView("Connecting to T3 Code") }
                    if let error = inputError { Text(error).foregroundStyle(Theme.annotation) }
                    if case .failed(let error) = connection.state { Text(error).foregroundStyle(Theme.annotation) }
                    if connection.state == .expired { Text("Pairing expired. Create a new code on your Mac.").foregroundStyle(Theme.annotation) }
                }
                Section { Text("To revoke access, remove Drawspeak (iPad) in T3 Code › Settings › Sharing & access.").font(.footnote) }
            }.navigationTitle("Connect to T3").tint(Theme.action)
        }
    }
    private var accessDescription: String {
        switch accessLevel {
        case "read-only": "View threads. Sending feedback is unavailable."
        case "approval-required": "Agent actions require approval on your Mac."
        case "auto-accept-edits": "Edits are accepted automatically; other actions need approval."
        case "auto": "Agent actions run automatically within T3 Code's permissions."
        default: "Includes settings and source control changes."
        }
    }
    private var canConnect: Bool {
        code.count == 12 && !host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && connection.state != .connecting
    }
    private func connect() async {
        inputError = nil
        do {
            let url = try T3Pairing.normalizeHost(host)
            await connection.pair(host: url, code: code, accessLevel: accessLevel)
            if case .connected = connection.state { code = ""; onPaired() }
        } catch { inputError = error.message }
    }
}
