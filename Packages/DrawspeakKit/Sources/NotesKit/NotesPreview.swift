import Foundation
import DrawspeakCore

/// Isolated fixture data; no microphone, network, or owner library access.
@MainActor
enum NotesPreview {
    static func workspace(recording: Bool = false) -> Workspace {
        let root = FileManager.default.temporaryDirectory.appending(path: "NotesKit-preview-" + UUID().uuidString)
        let date = Date.now
        let blobs = BlobStore(root: root.appending(path: "blobs"))
        // A tiny fixture PNG; previews never read the owner's snapshots.
        let png = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aX1sAAAAASUVORK5CYII=")!
        let image = try? blobs.put(png, contentType: "image/png")
        let audio = try? blobs.put(Data("preview audio fixture".utf8), contentType: "audio/mp4")
        let snapshot = Snapshot(id: "home-now", screenId: "home", role: .baseline, proposalId: nil, iteration: 0,
                                parentSnapshotId: nil, kind: .image, image: image, html: nil, renderPolicy: nil, stateId: nil,
                                widthPx: 800, heightPx: 600, viewport: Viewport(width: 800, height: 600, deviceScaleFactor: 1),
                                capturedAt: date, changeSummary: nil, addressedNoteIds: [], origin: .manualImport(fileName: "Home.png"), title: "Home")
        let transcript = Transcript(text: "Make this action easier to find.", requestedLanguage: nil, detectedLanguage: "eng", languageProbability: 0.98, provider: "Fixture", modelId: "fixture", receivedAt: date)
        let notes = [
            Note(ordinal: 1, snapshotId: snapshot.id, shape: .region(NRect(x: 0.1, y: 0.2, width: 0.5, height: 0.3)), text: "Give the primary action more space.", textSource: .typed, createdAt: date, updatedAt: date),
            Note(ordinal: 2, snapshotId: snapshot.id, shape: .ellipse(NRect(x: 0.3, y: 0.4, width: 0.2, height: 0.2)), text: "Keep my typed text.", textSource: .typed, recordings: [Recording(startedAt: date, duration: 12, state: .transcribed, transcript: transcript)], createdAt: date, updatedAt: date),
            Note(ordinal: 3, snapshotId: snapshot.id, shape: .region(NRect(x: 0.2, y: 0.3, width: 0.4, height: 0.4)), recordings: [Recording(startedAt: date, duration: 8, audio: audio, state: .failed(code: "network", mayHaveBeenProcessed: true))], createdAt: date, updatedAt: date)
        ]
        let canvas = ReviewCanvas(projectId: UUID(), title: "Preview", screens: [Screen(id: "home", title: "Home", origin: WorldPoint(x: 0, y: 0))], snapshots: [snapshot], baselineRevisions: [BaselineRevision(screenId: "home", snapshotId: snapshot.id, promotedFromSnapshotId: nil, createdAt: date)], notes: notes, nextOrdinal: 4, createdAt: date, updatedAt: date)
        let workspace = Workspace(document: LibraryDocument(canvases: [canvas]), blobs: blobs, store: LibraryStore(fileURL: root.appending(path: "library.json")))
        if recording {
            workspace.voice = NotesPreviewVoice()
            Task { await workspace.startRecording(noteId: notes[0].id) }
        }
        return workspace
    }
}
