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
                Section("T3 Code") {
                    TextField("Host", text: $host).autocorrectionDisabled().frame(minHeight: 44)
                    TextField("Pairing code", text: $code).font(.body.monospaced()).textContentType(.oneTimeCode).autocorrectionDisabled().frame(minHeight: 44)
                        #if os(iOS)
                        .textInputAutocapitalization(.characters)
                        #endif
                        .onChange(of: code) { _, value in code = String(value.uppercased().prefix(12)) }
                    Picker("Access level", selection: $accessLevel) {
                        Text("Full access").tag("full-access")
                        Text("Auto").tag("auto")
                        Text("Auto accept edits").tag("auto-accept-edits")
                        Text("Approval required").tag("approval-required")
                        Text("Read only").tag("read-only")
                    }
                    Text("Full access also permits settings and source control changes. Lower levels can send only to threads at or below that level.").font(.footnote).foregroundStyle(Theme.secondaryInk)
                }
                Section {
                    Text("On your Mac: T3 Code › Settings › Sharing & access › Create pairing link › Show code").font(.callout)
                    Button("Connect", systemImage: "link") { Task { await connect() } }.frame(minHeight: 44).disabled(code.count != 12 || connection.state == .connecting)
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
    private func connect() async {
        inputError = nil
        do {
            let url = try T3Pairing.normalizeHost(host)
            await connection.pair(host: url, code: code, accessLevel: accessLevel)
            if case .connected = connection.state { code = ""; onPaired() }
        } catch { inputError = error.message }
    }
}
