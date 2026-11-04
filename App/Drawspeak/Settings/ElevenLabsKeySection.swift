import DrawspeakCore
import SwiftUI
import VoiceKit

/// Bring-your-own ElevenLabs key, stored only in this iPad's Keychain.
struct ElevenLabsKeySection: View {
    let onChange: () -> Void
    @State private var hasKey = ElevenLabsKeyStore().hasKey
    @State private var draft = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        Section {
            if hasKey {
                LabeledContent("ElevenLabs Key") {
                    Label("Saved", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                }
                Button("Remove Key", role: .destructive) {
                    ElevenLabsKeyStore().remove()
                    hasKey = false
                    onChange()
                }
            } else {
                SecureField("ElevenLabs API key", text: $draft)
                    .textContentType(.password)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .focused($isFocused)
                    .onSubmit(save)
                Button("Save Key", action: save)
                    .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        } header: {
            Text("Transcription")
        } footer: {
            Text("Speech is transcribed by ElevenLabs Scribe v2 after you tap Stop. The key stays in this iPad's Keychain. Audio leaves the device only for transcription; usage is billed to your ElevenLabs account.")
        }
    }

    private func save() {
        if ElevenLabsKeyStore().save(draft) {
            hasKey = true
            draft = ""
            isFocused = false
            onChange()
        }
    }
}
