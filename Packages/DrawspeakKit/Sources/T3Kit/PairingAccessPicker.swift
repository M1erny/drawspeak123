import SwiftUI

struct PairingAccessPicker: View {
    @Binding var selection: String

    var body: some View {
        Picker(selection: $selection) {
            Text("Full Access", bundle: .module, comment: "T3 Code access policy permitting all agent actions.").tag("full-access")
            Text("Auto", bundle: .module).tag("auto")
            Text("Auto Accept Edits", bundle: .module).tag("auto-accept-edits")
            Text("Approval Required", bundle: .module).tag("approval-required")
            Text("Read Only", bundle: .module).tag("read-only")
        } label: {
            Text("Access", bundle: .module)
        }
        .pickerStyle(.menu)
    }
}
