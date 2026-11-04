import DrawspeakCore
import SwiftUI

struct SettingsView: View {
    let model: AppModel
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppPreferences.autoVoice) private var autoVoice = true
    @AppStorage(AppPreferences.drawWithFinger) private var drawWithFinger = false
    @AppStorage(AppPreferences.transcriptionLanguage) private var language = TranscriptionLanguage.automatic.rawValue

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Record After Marking", isOn: $autoVoice)
                    Picker("Language", selection: $language) {
                        ForEach(TranscriptionLanguage.allCases) { option in
                            Text(option.title).tag(option.rawValue)
                        }
                    }
                } header: {
                    Text("Voice")
                } footer: {
                    Text("Audio is sent to ElevenLabs for transcription.")
                }

                Section("Apple Pencil") {
                    Toggle("Draw with Finger", isOn: $drawWithFinger)
                }

                T3ConnectionSection(connection: model.connection)

                Section("About") {
                    LabeledContent("Version", value: Bundle.main.versionDescription)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close, action: dismiss.callAsFunction)
                }
            }
        }
        .tint(.primary)
        .frame(idealHeight: ShellMetrics.settingsHeight)
        .presentationSizing(.form.fitted(horizontal: false, vertical: true))
    }
}
