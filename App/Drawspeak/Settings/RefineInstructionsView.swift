import RefineKit
import SwiftUI

struct RefineInstructionsView: View {
    @AppStorage("drawspeak.refineInstructions") private var instructions = ""
    @State private var text = ""

    var body: some View {
        Form {
            Section {
                TextEditor(text: $text)
                    .font(.system(.footnote, design: .monospaced))
                    .frame(minHeight: 320)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .accessibilityLabel("Refine Instructions")
                Button("Restore Default") {
                    text = ClaudeRefiner.systemPrompt
                    instructions = ""
                }
            } footer: {
                Text("The marked area with margin and the transcript are sent to Claude Sonnet.")
            }
        }
        .navigationTitle("Refine Instructions")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { text = instructions.isEmpty ? ClaudeRefiner.systemPrompt : instructions }
        .onChange(of: text) { instructions = text == ClaudeRefiner.systemPrompt ? "" : text }
    }
}
