import DrawspeakCore
import Foundation
import Observation
import RefineKit
import T3Kit
import VoiceKit

/// Owns the long-lived services and wires them into the workspace.
@MainActor
@Observable
final class AppModel {
    private(set) var workspace: Workspace?
    private(set) var loadError: String?
    private(set) var unreadableLibrary: URL?
    let recorder = AudioRecorder()
    let connection = T3Connection()

    func start() async {
        guard workspace == nil else { return }
        AppPreferences.registerDefaults()
        // The key is built in (ADR-0008); a key saved by an earlier build is removed.
        ElevenLabsKeyStore.removeLegacyKeychainKey()
        // Category and engine ready before the first mark, so capture starts at once.
        recorder.prepare()
        do {
            let locations = try StorageLocations.applicationSupport()
            switch await Workspace.open(locations: locations) {
            case .loaded(let workspace):
                install(workspace)
            case .unreadable(let error, let fileURL):
                loadError = error
                unreadableLibrary = fileURL
                return
            }
            guard let workspace else { return }
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-DrawspeakSeedDemo") {
                DemoContent.seed(into: workspace)
            }
            if ProcessInfo.processInfo.arguments.contains("-DrawspeakSeedCanvases") {
                DemoContent.seedCanvasList(into: workspace)
            }
            if ProcessInfo.processInfo.arguments.contains("-DrawspeakSeedLarge") {
                DemoContent.seedLargeReview(into: workspace)
            }
            DemoContent.importFromEnvironment(into: workspace)
            #endif
        } catch {
            loadError = Self.storageError
            return
        }
        await connectAndRunHooks()
    }

    /// Keeps the unreadable file (renamed) and starts an empty library.
    func startFresh() async {
        let locations: StorageLocations
        do {
            locations = try StorageLocations.applicationSupport()
        } catch {
            loadError = Self.storageError
            return
        }
        let workspace = await Workspace.startFresh(locations: locations)
        loadError = nil
        unreadableLibrary = nil
        install(workspace)
        await connectAndRunHooks()
    }

    func retryOpening() async {
        loadError = nil
        unreadableLibrary = nil
        await start()
    }

    private static var storageError: String {
        String(localized: "Drawspeak can't open its storage.")
    }

    private func install(_ workspace: Workspace) {
        configure(workspace)
        self.workspace = workspace
    }

    private func connectAndRunHooks() async {
        await connection.restore()
        #if DEBUG && targetEnvironment(simulator)
        if let code = DebugEndToEnd.setting("DRAWSPEAK_T3_PAIRING_CODE"), !code.isEmpty,
           connection.threadService == nil || connection.credentials?.usableFilesToken == nil {
            await connection.pair(host: connection.hostURL, code: code)
        }
        #endif
        workspace?.threads = connection.threadService
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-DrawspeakFakeThreads"), let workspace {
            workspace.threads = DebugFakeThreads()
            if let canvasId = workspace.currentCanvasId { _ = workspace.bindThread(DebugFakeThreads.binding, to: canvasId) }
        }
        #endif
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
        let refiner = ClaudeRefiner(instructions: {
            UserDefaults.standard.string(forKey: "drawspeak.refineInstructions") ?? ""
        })
        workspace.refiner = refiner
        workspace.refinerModelId = "claude-sonnet-5-5"
        workspace.refineEnabled = { UserDefaults.standard.bool(forKey: AppPreferences.refineWithClaude) }
        workspace.pullFollowUpsAdditive = { UserDefaults.standard.bool(forKey: AppPreferences.pullFollowUpsAdditive) }
        workspace.regionImage = { [blobs = workspace.blobs] note, snapshot in
            await RegionCropper.png(for: note, snapshot: snapshot, blobs: blobs)
        }
    }

    /// Called whenever the T3 connection changes.
    func connectionChanged() {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-DrawspeakFakeThreads") { return }
        #endif
        workspace?.threads = connection.threadService
    }
}
