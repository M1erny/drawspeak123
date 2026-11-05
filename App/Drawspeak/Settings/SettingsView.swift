import DrawspeakCore
import SwiftUI

struct SettingsView: View {
    let model: AppModel
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppPreferences.autoVoice) private var autoVoice = true
    @AppStorage(AppPreferences.drawWithFinger) private var drawWithFinger = false
    @AppStorage(AppPreferences.transcriptionLanguage) private var language = TranscriptionLanguage.automatic.rawValue
    @AppStorage(AppPreferences.refineWithClaude) private var refineWithClaude = true
    @State private var path: [SettingsRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            Form {
                Section {
                    Toggle("Record After Marking", isOn: $autoVoice)
                    Toggle("Refine with Claude", isOn: $refineWithClaude)
                    NavigationLink("Refine Instructions") { RefineInstructionsView() }
                    Picker("Language", selection: $language) {
                        ForEach(TranscriptionLanguage.allCases) { option in
                            Text(option.title).tag(option.rawValue)
                        }
                    }
                } header: {
                    Text("Voice")
                } footer: {
                    Text("Audio goes to ElevenLabs; refining sends the marked area and its text to Anthropic.")
                }

                MarksSettingsSection()

                Section("Apple Pencil") {
                    Toggle("Draw with Finger", isOn: $drawWithFinger)
                }

                T3ConnectionSection(connection: model.connection) { path.append(.pairing) }

                Section("About") {
                    LabeledContent("Version", value: Bundle.main.versionDescription)
                }
            }
            .navigationDestination(for: SettingsRoute.self) { route in
                switch route {
                case .pairing: T3PairingDestination(connection: model.connection)
                }
            }
            .navigationTitle("Settings")
            #if DEBUG
            .task {
                // Simulator check: push pairing, then change the connection state the way
                // pairing does, and confirm the pushed screen stays.
                guard DebugLaunch.requestedState == .pairing else { return }
                path = [.pairing]
                try? await Task.sleep(for: .seconds(1))
                await model.connection.reconnect()
            }
            #endif
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
