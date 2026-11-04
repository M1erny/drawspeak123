import DrawspeakCore
import Foundation
import Observation
import T3Kit
import VoiceKit

/// Owns the long-lived services and wires them into the workspace.
@MainActor
@Observable
final class AppModel {
    private(set) var workspace: Workspace?
    private(set) var loadError: String?
    let recorder = AudioRecorder()
    let connection = T3Connection()

    func start() async {
        guard workspace == nil else { return }
        AppPreferences.registerDefaults()
        #if DEBUG && targetEnvironment(simulator)
        ElevenLabsKeyStore.bootstrapFromEnvironment()
        #endif
        do {
            let locations = try StorageLocations.applicationSupport()
            let workspace = await Workspace.load(locations: locations)
            configure(workspace)
            self.workspace = workspace
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-DrawspeakSeedDemo") {
                DemoContent.seed(into: workspace)
            }
            #endif
        } catch {
            loadError = "Drawspeak could not open its storage."
        }
        await connection.restore()
        #if DEBUG && targetEnvironment(simulator)
        if let code = ProcessInfo.processInfo.environment["DRAWSPEAK_T3_PAIRING_CODE"], !code.isEmpty,
           connection.threadService == nil {
            await connection.pair(host: connection.hostURL, code: code)
        }
        #endif
        workspace?.threads = connection.threadService
        #if DEBUG && targetEnvironment(simulator)
        if let workspace { await DebugEndToEnd.runIfRequested(workspace: workspace, connection: connection) }
        #endif
    }

    private func configure(_ workspace: Workspace) {
        workspace.voice = recorder
        workspace.transcriber = ElevenLabsTranscriber()
        workspace.autoVoiceEnabled = { UserDefaults.standard.bool(forKey: AppPreferences.autoVoice) }
        workspace.transcriptionLanguage = {
            let raw = UserDefaults.standard.string(forKey: AppPreferences.transcriptionLanguage) ?? ""
            return TranscriptionLanguage(rawValue: raw)?.providerCode
        }
        recorder.onInterruption = { [weak workspace] in workspace?.stopRecording() }
    }

    /// Called whenever the T3 connection changes.
    func connectionChanged() {
        workspace?.threads = connection.threadService
    }

    /// The ElevenLabs key changed in Settings.
    func transcriberChanged() {
        workspace?.transcriber = ElevenLabsTranscriber()
    }
}
