import SwiftUI
import DrawspeakCore

struct PairingHostFields: View {
    @Binding var host: String
    @Binding var code: String

    var body: some View {
        LabeledContent {
            TextField(text: $host, prompt: Text(verbatim: "https://your-mac")) {
                Text("Host", bundle: .module)
            }
            .multilineTextAlignment(.trailing)
            .autocorrectionDisabled()
            #if os(iOS)
            .keyboardType(.URL)
            .textInputAutocapitalization(.never)
            #endif
            .frame(minHeight: Theme.minTarget)
        } label: {
            Text("Host", bundle: .module)
        }
        LabeledContent {
            TextField(text: $code, prompt: Text(verbatim: "XXXXXXXXXXXX")) {
                Text("Code", bundle: .module)
            }
            .font(.body.monospaced())
            .multilineTextAlignment(.trailing)
            .textContentType(.oneTimeCode)
            .autocorrectionDisabled()
            #if os(iOS)
            .textInputAutocapitalization(.characters)
            #endif
            .frame(minHeight: Theme.minTarget)
            .onChange(of: code, normalizeCode)
        } label: {
            Text("Code", bundle: .module)
        }
    }

    private func normalizeCode() {
        code = String(code.uppercased().prefix(12))
    }
}
