import DrawspeakCore
import SwiftUI
import T3Kit

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
                    Toggle("Start Voice After Selection", isOn: $autoVoice)
                    Picker("Speech Language", selection: $language) {
                        ForEach(TranscriptionLanguage.allCases) { option in
                            Text(option.title).tag(option.rawValue)
                        }
                    }
                } header: {
                    Text("Voice Comments")
                } footer: {
                    Text("When on, marking a region or choosing a component starts recording. Opening an older comment never does.")
                }

                ElevenLabsKeySection(onChange: model.transcriberChanged)

                Section {
                    Toggle("Draw with Finger", isOn: $drawWithFinger)
                } header: {
                    Text("Apple Pencil")
                } footer: {
                    Text("Your finger moves the canvas unless this is on. With it on, use two fingers to move and zoom.")
                }

                T3ConnectionSection(connection: model.connection)

                Section("About") {
                    LabeledContent("Version", value: Bundle.main.versionDescription)
                    Text("Drawspeak is licensed under the Apache License 2.0.")
                        .font(.footnote)
                        .foregroundStyle(Theme.secondaryInk)
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

extension Bundle {
    var versionDescription: String {
        let version = infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }
}
