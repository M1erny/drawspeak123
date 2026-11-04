import Foundation
import Observation

/// The single source of truth for persisted review data. Every mutation goes
/// through this type so autosave, ownership and late results stay consistent.
@MainActor
@Observable
public final class Workspace {
    public private(set) var document: LibraryDocument
    public var currentCanvasId: UUID?
    /// The note whose inspector is open, if any.
    public var focusedNoteId: UUID?
    /// The single active recording, captured with its owner at start.
    public private(set) var activeRecording: RecordingScope?
    public private(set) var lastSaveError: String?

    public let blobs: BlobStore
    @ObservationIgnored private let store: LibraryStore
    @ObservationIgnored private var saveTask: Task<Void, Never>?
    /// When set, nothing is written to disk (an unreadable library could not be set aside).
    @ObservationIgnored private var savesBlockedReason: String?
    /// Increments whenever the in-memory document is queued for saving.
    @ObservationIgnored private var saveGeneration = 0
    /// Temporary capture files to delete once a save at or after `generation` succeeded.
    @ObservationIgnored private var pendingTempDeletions: [(url: URL, generation: Int)] = []
    /// The live transcription attempt per recording id; older completions are ignored.
    @ObservationIgnored private var transcriptionAttempts: [UUID: UUID] = [:]
    @ObservationIgnored public var voice: (any VoiceCapturing)?
    @ObservationIgnored public var transcriber: (any Transcribing)?
    @ObservationIgnored public var threads: (any ThreadService)?
    @ObservationIgnored public var undoManager: UndoManager?
    @ObservationIgnored public var now: () -> Date = Date.init
    /// Preferences read at the moment of use.
    @ObservationIgnored public var autoVoiceEnabled: () -> Bool = { true }
    @ObservationIgnored public var transcriptionLanguage: () -> String? = { nil }

    public init(document: LibraryDocument, blobs: BlobStore, store: LibraryStore) {
        self.document = document
        self.blobs = blobs
        self.store = store
        self.currentCanvasId = document.lastCanvasId ?? document.canvases.first?.id
        // Nothing resumes after a restart: no recording, no sending.
        for index in self.document.canvases.indices {
            self.document.canvases[index].outbox = self.document.canvases[index].outbox.map(OutboxRecovery.recover)
            for noteIndex in self.document.canvases[index].notes.indices {
                for recIndex in self.document.canvases[index].notes[noteIndex].recordings.indices {
                    switch self.document.canvases[index].notes[noteIndex].recordings[recIndex].state {
                    case .recording:
                        self.document.canvases[index].notes[noteIndex].recordings[recIndex].state = .interrupted
                    case .transcribing:
                        self.document.canvases[index].notes[noteIndex].recordings[recIndex].state = .failed(code: "interrupted", mayHaveBeenProcessed: true)
                    case .saved, .transcribed, .failed, .interrupted, .saveFailed:
                        break
                    }
                }
            }
        }
    }

    public enum LoadOutcome {
        /// The library was read, or no library file exists yet (first launch).
        case loaded(Workspace)
        /// A library file exists but could not be read or decoded. Nothing was
        /// written; the file is untouched until the person chooses Start Fresh.
        case unreadable(error: String, fileURL: URL)
    }

    /// Opens the library. A missing file is a fresh library; any read or decode
    /// failure is reported and never replaced by a new library.
    public static func open(locations: StorageLocations) async -> LoadOutcome {
        let store = LibraryStore(fileURL: locations.libraryFile)
        let stored: LibraryDocument?
        do {
            stored = try await store.load()
        } catch {
            return .unreadable(error: String(describing: error), fileURL: locations.libraryFile)
        }
        if let stored, stored.schemaVersion > LibraryDocument.currentSchemaVersion {
            return .unreadable(
                error: "The library was saved by a newer version of Drawspeak (schema \(stored.schemaVersion)).",
                fileURL: locations.libraryFile
            )
        }
        return .loaded(Workspace(document: seeded(stored ?? LibraryDocument()), blobs: BlobStore(root: locations.blobs), store: store))
    }

    /// Start Fresh after `open` reported an unreadable library: the old file is
    /// kept, renamed to `library.unreadable-<timestamp>.json`, and a new library starts.
    /// If the old file cannot be set aside, the new library is not saved at all.
    public static func startFresh(locations: StorageLocations) async -> Workspace {
        let store = LibraryStore(fileURL: locations.libraryFile)
        let workspace = Workspace(document: seeded(LibraryDocument()), blobs: BlobStore(root: locations.blobs), store: store)
        if FileManager.default.fileExists(atPath: locations.libraryFile.path(percentEncoded: false)) {
            do {
                try FileManager.default.moveItem(at: locations.libraryFile, to: unreadableBackupURL(for: locations.libraryFile, at: Date()))
            } catch {
                workspace.blockSaves("The unreadable library could not be set aside, so new changes are not saved.")
                return workspace
            }
        }
        await workspace.saveNow()
        return workspace
    }

    /// Kept for existing callers; prefer `open(locations:)`. An unreadable library
    /// yields an in-memory workspace that never saves, so the file is never overwritten.
    public static func load(locations: StorageLocations) async -> Workspace {
        switch await open(locations: locations) {
        case .loaded(let workspace):
            return workspace
        case .unreadable:
            let workspace = Workspace(
                document: seeded(LibraryDocument()),
                blobs: BlobStore(root: locations.blobs),
                store: LibraryStore(fileURL: locations.libraryFile)
            )
            workspace.blockSaves("Your review library could not be opened. Your files have been kept; changes are not saved.")
            return workspace
        }
    }

    /// `library.unreadable-<UTC timestamp>.json` next to the library, unused so far.
    public static func unreadableBackupURL(for libraryFile: URL, at date: Date) -> URL {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        let directory = libraryFile.deletingLastPathComponent()
        let base = libraryFile.deletingPathExtension().lastPathComponent + ".unreadable-" + formatter.string(from: date)
        var candidate = directory.appending(path: base + ".json")
        var suffix = 2
        while FileManager.default.fileExists(atPath: candidate.path(percentEncoded: false)) {
            candidate = directory.appending(path: "\(base)-\(suffix).json")
            suffix += 1
        }
        return candidate
    }

    /// Adds a first project and canvas to an empty library.
    private static func seeded(_ document: LibraryDocument) -> LibraryDocument {
        var document = document
        if document.projects.isEmpty {
            document.projects = [Project(name: "Drawspeak", createdAt: Date())]
        }
        if document.canvases.isEmpty, let project = document.projects.first {
            let canvas = ReviewCanvas(projectId: project.id, title: "First review", createdAt: Date(), updatedAt: Date())
            document.canvases = [canvas]
            document.lastCanvasId = canvas.id
        }
        return document
    }

    // MARK: - Persistence

    private struct SaveBlocked: Error {}

    private func blockSaves(_ reason: String) {
        savesBlockedReason = reason
        lastSaveError = reason
        saveTask?.cancel()
    }

    /// Debounced autosave of the whole library.
    public func scheduleSave() {
        guard savesBlockedReason == nil else { return }
        saveTask?.cancel()
        saveGeneration += 1
        let generation = saveGeneration
        let snapshot = document
        let store = store
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            do {
                try await store.save(snapshot)
                self?.didSave(generation: generation)
            } catch {
                self?.lastSaveError = "Could not save changes"
            }
        }
    }

    /// Saves immediately (for example when the app moves to the background).
    public func saveNow() async {
        try? await saveDurably()
    }

    /// Writes the current document now and throws when it was not written.
    private func saveDurably() async throws {
        if let savesBlockedReason {
            lastSaveError = savesBlockedReason
            throw SaveBlocked()
        }
        saveTask?.cancel()
        saveTask = nil
        saveGeneration += 1
        let generation = saveGeneration
        do {
            try await store.save(document)
            didSave(generation: generation)
        } catch {
            lastSaveError = "Could not save changes"
            throw error
        }
    }

    private func didSave(generation: Int) {
        lastSaveError = nil
        let due = pendingTempDeletions.filter { $0.generation <= generation }
        pendingTempDeletions.removeAll { $0.generation <= generation }
        for item in due { try? FileManager.default.removeItem(at: item.url) }
    }

    private func mutateCanvas(_ id: UUID, _ body: (inout ReviewCanvas) -> Void) {
        guard let index = document.canvases.firstIndex(where: { $0.id == id }) else { return }
        body(&document.canvases[index])
        document.canvases[index].updatedAt = now()
        scheduleSave()
    }

    // MARK: - Canvases

    public var canvases: [ReviewCanvas] { document.canvases }
    public var projects: [Project] { document.projects }

    public var currentCanvas: ReviewCanvas? {
        guard let currentCanvasId else { return nil }
        return document.canvases.first { $0.id == currentCanvasId }
    }

    public func canvas(_ id: UUID) -> ReviewCanvas? {
        document.canvases.first { $0.id == id }
    }

    @discardableResult
    public func createCanvas(title: String, thread: ThreadBinding?, projectId: UUID? = nil) -> ReviewCanvas {
        let project = projectId ?? document.projects.first?.id ?? UUID()
        let canvas = ReviewCanvas(projectId: project, title: title, thread: thread, createdAt: now(), updatedAt: now())
        document.canvases.append(canvas)
        selectCanvas(canvas.id)
        scheduleSave()
        return canvas
    }

    /// Switching canvases stops an active recording; its audio stays with its own note.
    public func selectCanvas(_ id: UUID) {
        guard id != currentCanvasId else { return }
        if activeRecording != nil { stopRecording() }
        focusedNoteId = nil
        currentCanvasId = id
        document.lastCanvasId = id
        scheduleSave()
    }

    public func renameCanvas(_ id: UUID, title: String) {
        mutateCanvas(id) { $0.title = title }
    }

    /// A canvas belongs to exactly one thread. Binding is allowed while it has no sent batches.
    public func bindThread(_ binding: ThreadBinding, to canvasId: UUID) -> Bool {
        guard let canvas = canvas(canvasId) else { return false }
        if let existing = canvas.thread, !existing.isSameRecipient(as: binding), !canvas.outbox.isEmpty { return false }
        mutateCanvas(canvasId) { $0.thread = binding }
        return true
    }

    public func deleteCanvas(_ id: UUID) {
        if activeRecording?.canvasId == id {
            activeRecording = nil
            voice?.discard()
        }
        document.canvases.removeAll { $0.id == id }
        if currentCanvasId == id { currentCanvasId = document.canvases.first?.id }
        document.lastCanvasId = currentCanvasId
        scheduleSave()
    }

    public func updateCamera(_ camera: CameraState, canvasId: UUID) {
        guard let index = document.canvases.firstIndex(where: { $0.id == canvasId }) else { return }
        document.canvases[index].camera = camera
        scheduleSave()
    }

    // MARK: - Screens and versions

    public enum ImportTarget: Sendable, Hashable {
        /// A new screen row with this snapshot as its first Now.
        case newScreen(title: String)
        /// A new Now revision of an existing screen.
        case baseline(screenId: String)
        /// A new iteration of a proposal (new proposal when the id is unused).
        case proposal(screenId: String, proposalId: String)
    }

    public enum ImportError: Error, Equatable {
        case tooLarge(limitMiB: Int)
        case unsupportedType
        case noCanvas
        /// Viewport outside 1...4096 points, scale outside 0.5...4, or above 40 MP.
        case invalidViewport
    }

    public static let maxImageBytes = 10 * 1024 * 1024
    public static let maxHTMLBytes = 2 * 1024 * 1024

    /// Stores bytes and adds an immutable snapshot to the current canvas.
    @discardableResult
    public func importArtifact(
        data: Data,
        kind: ArtifactKind,
        contentType: String,
        fileName: String,
        pixelSize: (width: Int, height: Int),
        viewport: Viewport? = nil,
        target: ImportTarget,
        origin: SnapshotOrigin? = nil,
        snapshotId: String? = nil,
        changeSummary: String? = nil,
        addressedNoteIds: [String] = [],
        parentSnapshotId: String? = nil,
        capturedAt: Date? = nil,
        captureImage: (data: Data, contentType: String)? = nil,
        renderPolicy: RenderPolicy? = nil
    ) throws -> Snapshot {
        guard let canvasId = currentCanvasId else { throw ImportError.noCanvas }
        return try importArtifact(
            into: canvasId, data: data, kind: kind, contentType: contentType, fileName: fileName,
            pixelSize: pixelSize, viewport: viewport, target: target, origin: origin, snapshotId: snapshotId,
            changeSummary: changeSummary, addressedNoteIds: addressedNoteIds, parentSnapshotId: parentSnapshotId,
            capturedAt: capturedAt, captureImage: captureImage, renderPolicy: renderPolicy
        )
    }

    @discardableResult
    public func importArtifact(
        into canvasId: UUID,
        data: Data,
        kind: ArtifactKind,
        contentType: String,
        fileName: String,
        pixelSize: (width: Int, height: Int),
        viewport: Viewport? = nil,
        target: ImportTarget,
        origin: SnapshotOrigin? = nil,
        snapshotId: String? = nil,
        changeSummary: String? = nil,
        addressedNoteIds: [String] = [],
        parentSnapshotId: String? = nil,
        capturedAt: Date? = nil,
        captureImage: (data: Data, contentType: String)? = nil,
        renderPolicy: RenderPolicy? = nil
    ) throws -> Snapshot {
        try storeArtifact(
            into: canvasId, data: data, kind: kind, contentType: contentType, fileName: fileName,
            pixelSize: pixelSize, viewport: viewport, target: target, origin: origin, snapshotId: snapshotId,
            changeSummary: changeSummary, addressedNoteIds: addressedNoteIds, parentSnapshotId: parentSnapshotId,
            capturedAt: capturedAt, captureImage: captureImage, renderPolicy: renderPolicy, promoteBaseline: true
        )
    }

    /// `promoteBaseline` false stores a baseline snapshot without making it Now
    /// (Pull for a screen that already has a Now).
    @discardableResult
    private func storeArtifact(
        into canvasId: UUID,
        data: Data,
        kind: ArtifactKind,
        contentType: String,
        fileName: String,
        pixelSize: (width: Int, height: Int),
        viewport: Viewport?,
        target: ImportTarget,
        origin: SnapshotOrigin?,
        snapshotId: String?,
        changeSummary: String?,
        addressedNoteIds: [String],
        parentSnapshotId: String?,
        capturedAt: Date?,
        captureImage: (data: Data, contentType: String)?,
        renderPolicy: RenderPolicy?,
        promoteBaseline: Bool
    ) throws -> Snapshot {
        guard let canvas = canvas(canvasId) else { throw ImportError.noCanvas }
        let resolvedViewport = viewport ?? Viewport(width: pixelSize.width, height: pixelSize.height, deviceScaleFactor: 1)
        if viewport != nil || kind == .html, !resolvedViewport.isWithinCaptureLimits { throw ImportError.invalidViewport }
        switch kind {
        case .image: guard data.count <= Self.maxImageBytes else { throw ImportError.tooLarge(limitMiB: 10) }
        case .html: guard data.count <= Self.maxHTMLBytes else { throw ImportError.tooLarge(limitMiB: 2) }
        }
        let blob = try blobs.put(data, contentType: contentType)
        var captureRef: BlobRef? = kind == .image ? blob : nil
        if let captureImage { captureRef = try blobs.put(captureImage.data, contentType: captureImage.contentType) }
        let timestamp = capturedAt ?? now()

        var screenId: String
        var role: SnapshotRole = .baseline
        var proposalId: String?
        var iteration = 0
        var parent = parentSnapshotId
        var newScreen: Screen?
        switch target {
        case .newScreen(let title):
            screenId = "screen-" + UUID().uuidString.prefix(8).lowercased()
            newScreen = Screen(id: screenId, title: title, origin: CanvasLayout.nextScreenOrigin(in: canvas))
        case .baseline(let id):
            screenId = id
        case .proposal(let id, let proposal):
            screenId = id
            role = .proposal
            proposalId = proposal
            let previous = CanvasLayout.proposalIterations(in: canvas, screenId: id, proposalId: proposal)
            iteration = (previous.map(\.iteration).max() ?? 0) + 1
            if parent == nil { parent = previous.last?.id }
        }
        let id = snapshotId ?? "\(screenId)-\(role == .baseline ? "now" : proposalId ?? "p")-\(blob.sha256.prefix(10))"
        let viewport = resolvedViewport
        let snapshot = Snapshot(
            id: id,
            screenId: screenId,
            role: role,
            proposalId: proposalId,
            iteration: iteration,
            parentSnapshotId: parent,
            kind: kind,
            image: captureRef,
            html: kind == .html ? blob : nil,
            renderPolicy: kind == .html ? (renderPolicy ?? .staticNoScript) : nil,
            stateId: nil,
            widthPx: pixelSize.width,
            heightPx: pixelSize.height,
            viewport: viewport,
            capturedAt: timestamp,
            changeSummary: changeSummary,
            addressedNoteIds: addressedNoteIds,
            origin: origin ?? .manualImport(fileName: fileName),
            title: fileName
        )
        if canvas.snapshots.contains(where: { $0.id == id }) { return canvas.snapshots.first { $0.id == id }! }
        mutateCanvas(canvasId) { canvas in
            if let newScreen { canvas.screens.append(newScreen) }
            canvas.snapshots.append(snapshot)
            switch role {
            case .baseline:
                guard promoteBaseline else { break }
                canvas.baselineRevisions.append(BaselineRevision(screenId: screenId, snapshotId: id, promotedFromSnapshotId: nil, createdAt: timestamp))
                canvas.laneSelections[LaneKey(screenId: screenId, proposalId: nil).description] = id
            case .proposal:
                if let index = canvas.screens.firstIndex(where: { $0.id == screenId }), let proposalId,
                   !canvas.screens[index].proposalOrder.contains(proposalId) {
                    canvas.screens[index].proposalOrder.append(proposalId)
                }
                canvas.laneSelections[LaneKey(screenId: screenId, proposalId: proposalId).description] = id
            }
        }
        return snapshot
    }

    /// Records the first capture of an HTML snapshot. An existing capture is never replaced.
    public func attachCapture(_ png: Data, pixelSize: (width: Int, height: Int), to snapshotId: String, canvasId: UUID) {
        guard let canvas = canvas(canvasId),
              let snapshot = canvas.snapshots.first(where: { $0.id == snapshotId }),
              snapshot.image == nil,
              let ref = try? blobs.put(png, contentType: "image/png")
        else { return }
        mutateCanvas(canvasId) { canvas in
            guard let index = canvas.snapshots.firstIndex(where: { $0.id == snapshotId }) else { return }
            canvas.snapshots[index].image = ref
            if canvas.snapshots[index].widthPx <= 0 {
                canvas.snapshots[index].widthPx = pixelSize.width
                canvas.snapshots[index].heightPx = pixelSize.height
            }
        }
    }

    public func selectVersion(_ snapshotId: String, lane: LaneKey) {
        guard let canvasId = currentCanvasId else { return }
        mutateCanvas(canvasId) { $0.laneSelections[lane.description] = snapshotId }
    }

    /// Promote to Now: a new baseline revision; history and the proposal stay.
    public func promoteToNow(_ snapshotId: String) {
        guard let canvasId = currentCanvasId, let canvas = currentCanvas,
              let snapshot = canvas.snapshots.first(where: { $0.id == snapshotId }) else { return }
        mutateCanvas(canvasId) { canvas in
            canvas.baselineRevisions.append(
                BaselineRevision(screenId: snapshot.screenId, snapshotId: snapshotId, promotedFromSnapshotId: snapshotId, createdAt: now())
            )
            canvas.laneSelections[LaneKey(screenId: snapshot.screenId, proposalId: nil).description] = snapshotId
        }
    }

    public func moveScreen(_ screenId: String, to origin: WorldPoint) {
        guard let canvasId = currentCanvasId else { return }
        mutateCanvas(canvasId) { canvas in
            guard let index = canvas.screens.firstIndex(where: { $0.id == screenId }) else { return }
            canvas.screens[index].origin = origin
        }
    }

    public func renameScreen(_ screenId: String, title: String) {
        guard let canvasId = currentCanvasId else { return }
        mutateCanvas(canvasId) { canvas in
            guard let index = canvas.screens.firstIndex(where: { $0.id == screenId }) else { return }
            canvas.screens[index].title = title
        }
    }

    /// HTML imported without a capture image; render it and call `attachCapture`.
    public func needsCapture(_ snapshot: Snapshot) -> Bool {
        snapshot.needsCapture
    }

    public func isSourceAvailable(_ snapshot: Snapshot) -> Bool {
        guard let source = snapshot.sourceBlob, blobs.exists(source) else { return false }
        if let image = snapshot.image { return blobs.exists(image) }
        return snapshot.kind == .html
    }

    // MARK: - Notes

    /// Adds a mark to a snapshot. When it identifies a subject and auto voice is on,
    /// voice starts for this new note. Returns the note id.
    @discardableResult
    public func addNote(snapshotId: String, shape: AnnotationShape, domTarget: DOMTarget? = nil, autoVoice: Bool? = nil) -> UUID? {
        guard let canvasId = currentCanvasId, let canvas = currentCanvas,
              canvas.snapshots.contains(where: { $0.id == snapshotId }), shape.isValid else { return nil }
        let note = Note(
            ordinal: canvas.nextOrdinal,
            snapshotId: snapshotId,
            shape: shape,
            domTarget: domTarget,
            createdAt: now(),
            updatedAt: now()
        )
        if activeRecording != nil { stopRecording() }
        mutateCanvas(canvasId) { canvas in
            canvas.notes.append(note)
            canvas.nextOrdinal += 1
        }
        registerUndo(name: "Add \(shape.kindLabel)") { workspace in workspace.deleteNote(note.id, canvasId: canvasId) }
        focusedNoteId = note.id
        if shape.identifiesSubject, autoVoice ?? autoVoiceEnabled(), let voice {
            if voice.hasPermission {
                // Same event as the mark: capture begins before the next frame.
                beginRecording(noteId: note.id, canvasId: canvasId)
            } else {
                Task { await self.startRecording(noteId: note.id) }
            }
        }
        return note.id
    }

    public func note(_ id: UUID, canvasId: UUID? = nil) -> Note? {
        let canvas = canvasId.flatMap(canvas) ?? currentCanvas
        return canvas?.notes.first { $0.id == id }
    }

    /// Typed edits are autosaved; each change is a new revision.
    public func updateNoteText(_ id: UUID, text: String) {
        guard let canvasId = currentCanvasId else { return }
        mutateCanvas(canvasId) { canvas in
            guard let index = canvas.notes.firstIndex(where: { $0.id == id }), canvas.notes[index].text != text else { return }
            canvas.notes[index].text = text
            // Every edit is the person's, including clearing the text, so a late
            // transcript never refills what they removed.
            canvas.notes[index].textSource = .typed
            canvas.notes[index].revision += 1
            canvas.notes[index].updatedAt = now()
        }
    }

    /// Appends a stored transcript to the text without replacing what was typed.
    public func appendTranscript(noteId: UUID, recordingId: UUID) {
        guard let note = note(noteId), let transcript = note.recordings.first(where: { $0.id == recordingId })?.transcript else { return }
        let joined = note.hasText ? note.trimmedText + "\n" + transcript.text : transcript.text
        updateNoteText(noteId, text: joined)
    }

    /// Deletes a note. Undo restores the same id, number and data. A capture on
    /// this note stops first; its recording is restored as Interrupted, never live.
    public func deleteNote(_ id: UUID, canvasId: UUID? = nil) {
        guard let canvasId = canvasId ?? currentCanvasId,
              canvas(canvasId)?.notes.contains(where: { $0.id == id }) == true else { return }
        if let scope = activeRecording, scope.noteId == id, scope.canvasId == canvasId {
            endActiveRecording()
            voice?.discard()
            liveSessions[scope.recordingId] = nil
            updateRecording(scope) { $0.state = .interrupted }
        }
        removeNote(id, canvasId: canvasId)
    }

    /// Removes a note and registers exactly one undo action. Never touches capture.
    private func removeNote(_ id: UUID, canvasId: UUID) {
        guard let canvas = canvas(canvasId), let index = canvas.notes.firstIndex(where: { $0.id == id }) else { return }
        var removed = canvas.notes[index]
        for recIndex in removed.recordings.indices where removed.recordings[recIndex].state == .recording {
            removed.recordings[recIndex].state = .interrupted
        }
        mutateCanvas(canvasId) { $0.notes.removeAll { $0.id == id } }
        if focusedNoteId == id { focusedNoteId = nil }
        registerUndo(name: "Delete Comment \(removed.ordinal)") { workspace in
            workspace.restore(removed, at: index, canvasId: canvasId)
        }
    }

    private func restore(_ note: Note, at index: Int, canvasId: UUID) {
        guard let canvas = canvas(canvasId), !canvas.notes.contains(where: { $0.id == note.id }) else { return }
        var note = note
        for recIndex in note.recordings.indices {
            let recording = note.recordings[recIndex]
            switch recording.state {
            case .recording:
                note.recordings[recIndex].state = .interrupted
            case .transcribing where transcriptionAttempts[recording.id] == nil && liveSessions[recording.id] == nil:
                // Its result arrived while the note was deleted and was discarded.
                note.recordings[recIndex].state = .failed(code: "interrupted", mayHaveBeenProcessed: true)
            case .transcribing, .saved, .transcribed, .failed, .interrupted, .saveFailed:
                break
            }
        }
        mutateCanvas(canvasId) { [note] canvas in
            canvas.notes.insert(note, at: min(index, canvas.notes.count))
        }
        registerUndo(name: "Restore Comment \(note.ordinal)") { workspace in workspace.deleteNote(note.id, canvasId: canvasId) }
    }

    private func registerUndo(name: String, _ action: @escaping @MainActor (Workspace) -> Void) {
        guard let undoManager else { return }
        undoManager.registerUndo(withTarget: self) { workspace in
            MainActor.assumeIsolated { action(workspace) }
        }
        undoManager.setActionName(name)
    }

    // MARK: - Voice

    public enum VoiceIssue: Equatable, Sendable {
        case permissionDenied
        case microphoneUnavailable
    }

    public private(set) var voiceIssue: VoiceIssue?

    public func clearVoiceIssue() { voiceIssue = nil }

    /// Starts a recording owned by the note. Requests permission in context on first
    /// use; when it was already granted, capture starts before this returns.
    public func startRecording(noteId: UUID) async {
        guard let canvasId = currentCanvasId, let voice, note(noteId) != nil else { return }
        if activeRecording != nil { stopRecording() }
        if !voice.hasPermission {
            guard await voice.requestPermission() else {
                voiceIssue = .permissionDenied
                return
            }
            // The canvas or note may have changed while the permission prompt was open.
            guard currentCanvasId == canvasId, note(noteId, canvasId: canvasId) != nil, activeRecording == nil else { return }
        }
        beginRecording(noteId: noteId, canvasId: canvasId)
    }

    /// Starts capture and live transcription now. Permission must already be granted.
    private func beginRecording(noteId: UUID, canvasId: UUID) {
        guard let voice, activeRecording == nil, let current = note(noteId, canvasId: canvasId) else { return }
        let recording = Recording(startedAt: now(), state: .recording, textRevisionAtStart: current.revision)
        let scope = RecordingScope(canvasId: canvasId, noteId: noteId, recordingId: recording.id)
        let language = transcriptionLanguage()
        liveSequence += 1
        liveSessions[scope.recordingId] = LiveSession(noteId: noteId, sequence: liveSequence, language: language)
        do {
            // Events capture only this scope: late ones never reach the focused note.
            try voice.start(scope: scope, language: language) { [weak self] event in
                self?.handleLiveEvent(event, scope: scope)
            }
        } catch {
            liveSessions[scope.recordingId] = nil
            voiceIssue = .microphoneUnavailable
            return
        }
        voiceIssue = nil
        activeRecording = scope
        livePartialText = ""
        mutateCanvas(canvasId) { canvas in
            guard let index = canvas.notes.firstIndex(where: { $0.id == noteId }) else { return }
            canvas.notes[index].recordings.append(recording)
        }
    }

    /// Stop: the audio is saved locally first, then the live session finishes in the
    /// background (or the batch fallback runs once).
    public func stopRecording() {
        guard let scope = activeRecording else { return }
        endActiveRecording()
        guard let captured = voice?.stop() else {
            liveSessions[scope.recordingId] = nil
            updateRecording(scope) { $0.state = .interrupted }
            return
        }
        updateRecording(scope) { $0.duration = captured.duration }
        storeCapturedAudio(scope, fileURL: captured.fileURL, contentType: captured.contentType)
    }

    private func endActiveRecording() {
        activeRecording = nil
        livePartialText = ""
    }

    /// Retries moving a capture whose save failed (`RecordingState.saveFailed`) into
    /// the blob store, then transcribes it. A missing temporary file becomes Interrupted.
    public func retrySavingAudio(_ scope: RecordingScope) {
        guard let recording = recording(scope), case .saveFailed(let path) = recording.state else { return }
        let url = URL(filePath: path)
        guard FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else {
            liveSessions[scope.recordingId] = nil
            updateRecording(scope) { $0.state = .interrupted }
            return
        }
        storeCapturedAudio(scope, fileURL: url, contentType: Self.audioContentType(for: url))
    }

    /// Copies the capture into the blob store. The temporary file is deleted only
    /// after a library save that references the blob succeeded.
    private func storeCapturedAudio(_ scope: RecordingScope, fileURL: URL, contentType: String) {
        let ref: BlobRef
        do {
            ref = try blobs.put(Data(contentsOf: fileURL), contentType: contentType)
        } catch {
            updateRecording(scope) { $0.state = .saveFailed(tempPath: fileURL.path(percentEncoded: false)) }
            return
        }
        updateRecording(scope) { recording in
            recording.audio = ref
            recording.state = .saved
        }
        pendingTempDeletions.append((fileURL, saveGeneration))
        Task { await self.saveNow() }
        audioSaved(scope)
    }

    /// The audio is durable: use the live result, wait for it, or fall back to batch once.
    private func audioSaved(_ scope: RecordingScope) {
        guard var session = liveSessions[scope.recordingId] else {
            transcribe(scope)
            return
        }
        session.audioSaved = true
        liveSessions[scope.recordingId] = session
        switch session.outcome {
        case .finished(let text): completeLive(scope, text: text, language: session.language)
        case .failed: fallBackToBatch(scope)
        case nil: updateRecording(scope) { $0.state = .transcribing }
        }
    }

    private static func audioContentType(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "wav": "audio/wav"
        case "caf": "audio/x-caf"
        case "mp3": "audio/mpeg"
        default: "audio/mp4"
        }
    }

    // MARK: - Live transcription

    /// Live state of one recording, from start until its result is stored.
    struct LiveSession {
        enum Outcome: Equatable { case finished(String), failed(String) }
        var noteId: UUID
        var sequence: Int
        var language: String?
        var committed = ""
        var partial = ""
        var outcome: Outcome?
        var audioSaved = false
    }

    /// The uncommitted text of the active recording, updated while the person speaks.
    public private(set) var livePartialText = ""
    /// Per recording id; observable so live text redraws.
    private var liveSessions: [UUID: LiveSession] = [:]
    @ObservationIgnored private var liveSequence = 0

    /// What the newest still-streaming recording on this note heard so far
    /// (committed segments plus the current partial); nil when none is streaming.
    public func liveText(for noteId: UUID) -> String? {
        guard let session = liveSessions.values
            .filter({ $0.noteId == noteId && $0.outcome == nil })
            .max(by: { $0.sequence < $1.sequence }) else { return nil }
        return [session.committed, session.partial].filter { !$0.isEmpty }.joined(separator: " ")
    }

    /// Applies one live event through the scope captured at start.
    func handleLiveEvent(_ event: LiveTranscriptEvent, scope: RecordingScope) {
        guard var session = liveSessions[scope.recordingId], session.outcome == nil else { return }
        let isActive = activeRecording == scope
        switch event {
        case .partial(let text):
            session.partial = text
            liveSessions[scope.recordingId] = session
            if isActive { livePartialText = text }
        case .committed(let text):
            let segment = text.trimmingCharacters(in: .whitespacesAndNewlines)
            session.partial = ""
            if isActive { livePartialText = "" }
            guard !segment.isEmpty else {
                liveSessions[scope.recordingId] = session
                return
            }
            session.committed = session.committed.isEmpty ? segment : session.committed + " " + segment
            liveSessions[scope.recordingId] = session
            let transcript = liveTranscript(session.committed, language: session.language)
            if let index = document.canvases.firstIndex(where: { $0.id == scope.canvasId }) {
                _ = TranscriptMerge.applyLiveSegment(segment, transcript: transcript, scope: scope, to: &document.canvases[index], now: now())
                scheduleSave()
            }
        case .finished(let text):
            session.partial = ""
            session.outcome = .finished(text)
            liveSessions[scope.recordingId] = session
            if session.audioSaved { completeLive(scope, text: text, language: session.language) }
        case .failed(let code):
            session.partial = ""
            session.outcome = .failed(code)
            liveSessions[scope.recordingId] = session
            if isActive { livePartialText = "" }
            if session.audioSaved { fallBackToBatch(scope) }
        }
    }

    private func liveTranscript(_ text: String, language: String?) -> Transcript {
        Transcript(
            text: text, requestedLanguage: language, detectedLanguage: nil, languageProbability: nil,
            provider: Transcript.liveProvider, modelId: Transcript.liveModelId, receivedAt: now()
        )
    }

    private func completeLive(_ scope: RecordingScope, text: String, language: String?) {
        liveSessions[scope.recordingId] = nil
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            // Live heard nothing although audio exists: one batch attempt.
            fallBackToBatch(scope)
            return
        }
        guard let index = document.canvases.firstIndex(where: { $0.id == scope.canvasId }) else { return }
        _ = TranscriptMerge.finishLive(liveTranscript(text, language: language), scope: scope, to: &document.canvases[index], now: now())
        scheduleSave()
    }

    /// One batch transcription of the saved audio after live failed. Never repeated automatically.
    private func fallBackToBatch(_ scope: RecordingScope) {
        liveSessions[scope.recordingId] = nil
        guard let recording = recording(scope), recording.audio != nil else { return }
        if recording.state == .transcribing { updateRecording(scope) { $0.state = .saved } }
        transcribe(scope)
    }

    /// Discard the current recording; an empty new region is removed (Undo restores it).
    public func discardRecording() {
        guard let scope = activeRecording else { return }
        endActiveRecording()
        voice?.discard()
        liveSessions[scope.recordingId] = nil
        mutateCanvas(scope.canvasId) { canvas in
            guard let index = canvas.notes.firstIndex(where: { $0.id == scope.noteId }) else { return }
            canvas.notes[index].recordings.removeAll { $0.id == scope.recordingId }
        }
        if let note = note(scope.noteId, canvasId: scope.canvasId), !note.hasText, note.recordings.isEmpty {
            removeNote(scope.noteId, canvasId: scope.canvasId)
        }
    }

    private func updateRecording(_ scope: RecordingScope, _ body: (inout Recording) -> Void) {
        mutateCanvas(scope.canvasId) { canvas in
            guard let noteIndex = canvas.notes.firstIndex(where: { $0.id == scope.noteId }),
                  let recIndex = canvas.notes[noteIndex].recordings.firstIndex(where: { $0.id == scope.recordingId }) else { return }
            body(&canvas.notes[noteIndex].recordings[recIndex])
            canvas.notes[noteIndex].updatedAt = now()
        }
    }

    private func recording(_ scope: RecordingScope) -> Recording? {
        note(scope.noteId, canvasId: scope.canvasId)?.recordings.first { $0.id == scope.recordingId }
    }

    /// True while a transcription request for this recording is in flight.
    public func isTranscriptionInFlight(_ scope: RecordingScope) -> Bool {
        transcriptionAttempts[scope.recordingId] != nil
            || (liveSessions[scope.recordingId].map { $0.audioSaved && $0.outcome == nil } ?? false)
    }

    /// Sends the saved audio once. Failures keep the audio; retries are always deliberate.
    /// A request while the recording is already transcribing is ignored, and only the
    /// latest attempt's result or failure is applied.
    public func transcribe(_ scope: RecordingScope) {
        guard let recording = recording(scope), let audio = recording.audio,
              transcriptionAttempts[scope.recordingId] == nil, liveSessions[scope.recordingId] == nil else { return }
        switch recording.state {
        case .recording, .transcribing: return
        case .saved, .transcribed, .failed, .interrupted, .saveFailed: break
        }
        guard let transcriber, transcriber.isConfigured else {
            updateRecording(scope) { $0.state = .failed(code: TranscriptionFailure.Code.notConfigured.rawValue, mayHaveBeenProcessed: false) }
            return
        }
        guard let data = try? blobs.data(for: audio) else {
            updateRecording(scope) { $0.state = .failed(code: "audio_missing", mayHaveBeenProcessed: false) }
            return
        }
        let attempt = UUID()
        transcriptionAttempts[scope.recordingId] = attempt
        updateRecording(scope) { $0.state = .transcribing }
        let language = transcriptionLanguage()
        Task {
            let result: Result<Transcript, TranscriptionFailure>
            do throws(TranscriptionFailure) {
                result = .success(try await transcriber.transcribe(audio: data, contentType: audio.contentType, language: language))
            } catch {
                result = .failure(error)
            }
            guard self.transcriptionAttempts[scope.recordingId] == attempt else { return }
            self.transcriptionAttempts[scope.recordingId] = nil
            switch result {
            case .success(let transcript):
                self.applyTranscript(transcript, scope: scope)
            case .failure(let failure):
                self.updateRecording(scope) { $0.state = .failed(code: failure.code.rawValue, mayHaveBeenProcessed: failure.requestMayHaveBeenProcessed) }
            }
        }
    }

    /// Late results land only on their own note and recording, on their own canvas.
    public func applyTranscript(_ transcript: Transcript, scope: RecordingScope) {
        guard let index = document.canvases.firstIndex(where: { $0.id == scope.canvasId }) else { return }
        _ = TranscriptMerge.apply(transcript, scope: scope, to: &document.canvases[index], now: now())
        scheduleSave()
    }

    // MARK: - Feedback

    public func feedbackScope(canvasId: UUID? = nil) -> FeedbackScope? {
        guard let canvas = canvasId.flatMap(canvas) ?? currentCanvas else { return nil }
        return FeedbackScope(canvas: canvas, sourceAvailable: isSourceAvailable)
    }

    public static func newBatchId(now: Date) -> String {
        let stamp = ISO8601DateFormatter().string(from: now).replacingOccurrences(of: ":", with: "").prefix(15)
        return "ds-\(stamp)-\(UUID().uuidString.prefix(6).lowercased())"
    }

    /// Save Draft: keeps exactly this package locally. Never sends or queues.
    @discardableResult
    public func saveDraft(noteIds: Set<UUID>, canvasId: UUID) -> SavedDraft? {
        guard let canvas = canvas(canvasId) else { return nil }
        let items = canvas.notes.filter { noteIds.contains($0.id) }.sorted { $0.ordinal < $1.ordinal }.map(BatchItem.init(note:))
        guard !items.isEmpty else { return nil }
        let draft = SavedDraft(createdAt: now(), thread: canvas.thread, items: items)
        mutateCanvas(canvasId) { $0.drafts.insert(draft, at: 0) }
        return draft
    }

    public func deleteDraft(_ id: UUID, canvasId: UUID) {
        mutateCanvas(canvasId) { $0.drafts.removeAll { $0.id == id } }
    }

    public struct DraftResume: Hashable, Sendable {
        /// Notes that reproduce the draft now: unchanged live notes and new copies.
        public var noteIds: Set<UUID>
        /// Copies created because the live note was edited, moved or deleted.
        public var copiedCount: Int
        /// The draft was saved for another host or thread than the canvas uses now.
        public var recipientChanged: Bool

        public init(noteIds: Set<UUID>, copiedCount: Int, recipientChanged: Bool) {
            self.noteIds = noteIds
            self.copiedCount = copiedCount
            self.recipientChanged = recipientChanged
        }
    }

    /// Resuming a draft reproduces its saved content and never overwrites newer
    /// edits. A live note is reused only while it still has the saved revision and
    /// text; otherwise a copy with a new number and the saved text is created.
    public func resumeDraft(_ draftId: UUID, canvasId: UUID) -> DraftResume {
        guard let canvas = canvas(canvasId), let draft = canvas.drafts.first(where: { $0.id == draftId }) else {
            return DraftResume(noteIds: [], copiedCount: 0, recipientChanged: false)
        }
        var ids = Set<UUID>()
        var copies: [Note] = []
        var ordinal = canvas.nextOrdinal
        for item in draft.items {
            if let live = canvas.notes.first(where: { $0.id == item.noteId }),
               live.revision == item.revision, live.trimmedText == item.text,
               live.snapshotId == item.snapshotId, live.shape == item.shape, live.domTarget == item.domTarget {
                ids.insert(live.id)
            } else if canvas.snapshots.contains(where: { $0.id == item.snapshotId }) {
                let copy = Note(ordinal: ordinal, snapshotId: item.snapshotId, shape: item.shape, domTarget: item.domTarget, text: item.text, textSource: .typed, createdAt: now(), updatedAt: now())
                ordinal += 1
                copies.append(copy)
                ids.insert(copy.id)
            }
        }
        if !copies.isEmpty {
            mutateCanvas(canvasId) { canvas in
                canvas.notes.append(contentsOf: copies)
                canvas.nextOrdinal = ordinal
            }
        }
        let recipientChanged: Bool
        switch (draft.thread, canvas.thread) {
        case (nil, nil): recipientChanged = false
        case (let saved?, let current?): recipientChanged = !saved.isSameRecipient(as: current)
        default: recipientChanged = true
        }
        return DraftResume(noteIds: ids, copiedCount: copies.count, recipientChanged: recipientChanged)
    }

    // MARK: - Thread identity

    /// Why thread operations for `binding` cannot run with the current connection,
    /// or nil when the connected host is the bound host.
    public func connectionIssue(for binding: ThreadBinding) -> String? {
        guard let threads else { return "Not connected to T3 Code" }
        guard HostIdentity.matches(threads.hostURL, binding.hostURL) else {
            return "Connected to \(HostIdentity.displayName(threads.hostURL)), but this canvas belongs to \(HostIdentity.displayName(binding.hostURL))"
        }
        return nil
    }

    /// The connected service, only when it talks to the bound host.
    private func service(for binding: ThreadBinding) -> (any ThreadService)? {
        connectionIssue(for: binding) == nil ? threads : nil
    }

    // MARK: - Delivery

    /// Freezes the shown package into the outbox and delivers it with one message.
    /// `attachments` are the rendered composites and the manifest, in message order.
    @discardableResult
    public func send(package: FeedbackPackage, attachments: [OutgoingAttachment], canvasId: UUID) async -> OutboxEntry? {
        if let existing = canvas(canvasId)?.outbox.first(where: { $0.id == package.batchId }) {
            // A batch id is used once; an entry that may have been delivered is never replaced.
            switch existing.state {
            case .readyToSend, .failed: break
            case .uploading, .sending, .sent, .deliveryUnknown: return existing
            }
        }
        let entry = OutboxEntry(
            id: package.batchId,
            createdAt: now(),
            thread: package.thread,
            items: package.items,
            isRepeat: package.isRepeat,
            state: .readyToSend
        )
        mutateCanvas(canvasId) { canvas in
            canvas.outbox.removeAll { $0.id == entry.id }
            canvas.outbox.insert(entry, at: 0)
        }
        stagedAttachments[entry.id] = (FeedbackPackageBuilder.messageText(for: package), attachments)
        await deliver(batchId: entry.id, canvasId: canvasId)
        return canvas(canvasId)?.outbox.first { $0.id == entry.id }
    }

    /// Freezes the shown package into the outbox and starts a new thread in `projectId`
    /// whose first message carries it. Only for a canvas without a thread: on success the
    /// canvas is bound to the new thread. Nil when the canvas already has a thread, a
    /// new-thread batch is still unresolved, or no T3 connection exists.
    @discardableResult
    public func sendToNewThread(
        package: FeedbackPackage, attachments: [OutgoingAttachment], canvasId: UUID,
        projectId: String, projectTitle: String?, threadTitle: String
    ) async -> OutboxEntry? {
        let title = threadTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let canvas = canvas(canvasId), canvas.thread == nil, let threads,
              !projectId.isEmpty, !title.isEmpty else { return nil }
        if let existing = canvas.outbox.first(where: { $0.id == package.batchId }) {
            switch existing.state {
            case .readyToSend, .failed: break
            case .uploading, .sending, .sent, .deliveryUnknown: return existing
            }
        }
        // Another unresolved launch may already have created this canvas's thread.
        if let pending = pendingNewThreadEntry(canvasId: canvasId), pending.id != package.batchId { return nil }
        let entry = OutboxEntry(
            id: package.batchId,
            createdAt: now(),
            thread: ThreadBinding(hostURL: threads.hostURL, threadId: "", threadTitle: title, projectId: projectId, projectTitle: projectTitle),
            items: package.items,
            isRepeat: package.isRepeat,
            state: .readyToSend,
            newThread: NewThreadTarget(projectId: projectId, projectTitle: projectTitle, title: title, clientRequestId: package.batchId)
        )
        mutateCanvas(canvasId) { canvas in
            canvas.outbox.removeAll { $0.id == entry.id }
            canvas.outbox.insert(entry, at: 0)
        }
        stagedAttachments[entry.id] = (FeedbackPackageBuilder.messageText(for: package), attachments)
        await deliver(batchId: entry.id, canvasId: canvasId)
        return self.canvas(canvasId)?.outbox.first { $0.id == entry.id }
    }

    /// A new-thread batch whose thread may exist but was not confirmed (not yet Sent).
    public func pendingNewThreadEntry(canvasId: UUID) -> OutboxEntry? {
        canvas(canvasId)?.outbox.first { entry in
            guard entry.newThread != nil else { return false }
            switch entry.state {
            case .uploading, .sending, .deliveryUnknown: return true
            case .readyToSend, .failed, .sent: return false
            }
        }
    }

    /// Message text and attachments of entries in this session, for an explicit retry.
    @ObservationIgnored private var stagedAttachments: [String: (text: String, attachments: [OutgoingAttachment])] = [:]

    public func hasStagedPayload(batchId: String) -> Bool { stagedAttachments[batchId] != nil }

    /// Stage a payload for an entry restored after restart (rebuilt by the UI from frozen items).
    public func stagePayload(batchId: String, text: String, attachments: [OutgoingAttachment]) {
        stagedAttachments[batchId] = (text, attachments)
    }

    private func updateOutbox(_ batchId: String, canvasId: UUID, _ body: (inout OutboxEntry) -> Void) {
        mutateCanvas(canvasId) { canvas in
            guard let index = canvas.outbox.firstIndex(where: { $0.id == batchId }) else { return }
            body(&canvas.outbox[index])
        }
    }

    private func endAttempt(_ entry: inout OutboxEntry, at date: Date, outcome: String) {
        guard let last = entry.attempts.indices.last else { return }
        entry.attempts[last].endedAt = date
        entry.attempts[last].outcome = outcome
    }

    /// Delivers a Ready to Send entry. Never called automatically after restart or reconnect.
    ///
    /// Before the network call the entry is durably saved as Uploading with an open
    /// attempt; if that save fails nothing is sent. From that checkpoint on, a restart
    /// recovers the entry as Delivery Unknown (see `OutboxRecovery`).
    ///
    /// A new-thread entry launches the thread with its fixed `clientRequestId`, so a
    /// repeated launch returns the same thread.
    public func deliver(batchId: String, canvasId: UUID) async {
        await deliver(batchId: batchId, canvasId: canvasId, resumingUnknownLaunch: false)
    }

    private func deliver(batchId: String, canvasId: UUID, resumingUnknownLaunch: Bool) async {
        guard let entry = canvas(canvasId)?.outbox.first(where: { $0.id == batchId }) else { return }
        switch entry.state {
        case .readyToSend, .failed: break
        case .uploading, .sending, .sent, .deliveryUnknown: return
        }
        if let issue = connectionIssue(for: entry.thread) {
            updateOutbox(batchId, canvasId: canvasId) { $0.state = .failed(reason: issue) }
            return
        }
        // One canvas, one thread: a launch that surely created nothing must not add a second thread.
        // Repeating an unconfirmed launch is safe, because it can only return the same thread.
        if entry.newThread != nil, !resumingUnknownLaunch, canvas(canvasId)?.thread != nil {
            updateOutbox(batchId, canvasId: canvasId) { $0.state = .failed(reason: "This canvas already has a thread.") }
            return
        }
        guard let threads else { return }
        guard let staged = stagedAttachments[batchId] else {
            updateOutbox(batchId, canvasId: canvasId) { $0.state = .failed(reason: "Open the package again to rebuild its images") }
            return
        }
        let total = staged.attachments.count
        updateOutbox(batchId, canvasId: canvasId) {
            $0.state = .uploading(done: 0, total: total)
            $0.attempts.append(DeliveryAttempt(startedAt: now(), endedAt: nil, outcome: "started"))
        }
        do {
            try await saveDurably()
        } catch {
            let ended = now()
            updateOutbox(batchId, canvasId: canvasId) { entry in
                entry.state = .failed(reason: "Could not save the outbox, so nothing was sent. Free some storage and try again.")
                endAttempt(&entry, at: ended, outcome: "not started: save failed")
            }
            return
        }
        let progress: @Sendable (Int, Int) -> Void = { done, _ in
            Task { @MainActor in
                self.updateOutbox(batchId, canvasId: canvasId) { entry in
                    // Progress never overrides a final state that arrived first.
                    guard case .uploading = entry.state else { return }
                    entry.state = done >= total ? .sending : .uploading(done: done, total: total)
                }
            }
        }
        do {
            if let target = entry.newThread {
                let launched = try await threads.launchThread(
                    projectId: target.projectId, title: target.title, text: staged.text, attachments: staged.attachments,
                    clientRequestId: target.clientRequestId, progress: progress
                )
                bindLaunchedThread(launched, target: target, hostURL: threads.hostURL, batchId: batchId, canvasId: canvasId)
                markSent(batchId: batchId, canvasId: canvasId, receipt: DeliveryReceipt(
                    threadId: launched.threadId, messageId: launched.messageId, acknowledgedAt: now(),
                    attachmentCount: total, confirmation: .response
                ))
            } else {
                let ack = try await threads.send(threadId: entry.thread.threadId, text: staged.text, attachments: staged.attachments, progress: progress)
                markSent(batchId: batchId, canvasId: canvasId, receipt: DeliveryReceipt(
                    threadId: entry.thread.threadId, messageId: ack.messageId, acknowledgedAt: ack.acknowledgedAt,
                    attachmentCount: total, confirmation: .response
                ))
            }
        } catch {
            let ended = now()
            updateOutbox(batchId, canvasId: canvasId) { entry in
                switch error {
                case .outcomeUnknown: entry.state = .deliveryUnknown
                case .notAuthorized: entry.state = .failed(reason: "T3 Code authorization expired. Connect again.")
                case .notSent(let reason): entry.state = .failed(reason: reason)
                }
                endAttempt(&entry, at: ended, outcome: "\(entry.state)")
            }
        }
        await saveNow()
    }

    /// The server returned the new thread: the entry targets it from now on, and the
    /// canvas is bound to it unless the canvas got another thread meanwhile.
    private func bindLaunchedThread(_ launched: LaunchedThread, target: NewThreadTarget, hostURL: URL, batchId: String, canvasId: UUID) {
        let binding = ThreadBinding(
            hostURL: hostURL, threadId: launched.threadId,
            threadTitle: launched.title.isEmpty ? target.title : launched.title,
            projectId: target.projectId, projectTitle: target.projectTitle
        )
        mutateCanvas(canvasId) { canvas in
            if canvas.thread == nil { canvas.thread = binding }
            guard let index = canvas.outbox.firstIndex(where: { $0.id == batchId }) else { return }
            canvas.outbox[index].thread = binding
            canvas.outbox[index].newThread = nil
        }
    }

    private func markSent(batchId: String, canvasId: UUID, receipt: DeliveryReceipt) {
        stagedAttachments[batchId] = nil
        mutateCanvas(canvasId) { canvas in
            guard let index = canvas.outbox.firstIndex(where: { $0.id == batchId }) else { return }
            canvas.outbox[index].state = .sent
            canvas.outbox[index].receipt = receipt
            endAttempt(&canvas.outbox[index], at: receipt.acknowledgedAt, outcome: "sent")
            for item in canvas.outbox[index].items {
                guard let noteIndex = canvas.notes.firstIndex(where: { $0.id == item.noteId }) else { continue }
                // Only the sent revision counts; a newer edit stays unsent.
                if canvas.notes[noteIndex].revision == item.revision {
                    canvas.notes[noteIndex].lastSentRevision = item.revision
                }
            }
        }
    }

    public enum ReconcileResult: Equatable, Sendable {
        case found
        case notFound
        case unavailable
    }

    /// Delivery Unknown: ask the bound host for the outgoing message carrying the
    /// exact batch marker before any retry. Found is Sent; a definite "no such
    /// message" is Ready to Send; any error keeps Delivery Unknown.
    ///
    /// A new-thread entry has no thread to read: it repeats the launch with the same
    /// `clientRequestId`, which returns the thread if the first launch created it.
    /// Found is Sent; anything else keeps Delivery Unknown (never `.notFound`).
    public func reconcile(batchId: String, canvasId: UUID) async -> ReconcileResult {
        guard let entry = canvas(canvasId)?.outbox.first(where: { $0.id == batchId }),
              entry.state == .deliveryUnknown,
              let threads = service(for: entry.thread) else { return .unavailable }
        if entry.newThread != nil {
            guard stagedAttachments[batchId] != nil else { return .unavailable }
            // In memory only: the delivery path below checkpoints Uploading durably before the launch.
            updateOutbox(batchId, canvasId: canvasId) { $0.state = .readyToSend }
            await deliver(batchId: batchId, canvasId: canvasId, resumingUnknownLaunch: true)
            switch canvas(canvasId)?.outbox.first(where: { $0.id == batchId })?.state {
            case .sent: return .found
            case .failed:
                // A refused repeat says nothing about the first launch (for example after
                // re-pairing, when the server no longer matches the request id): keep it unconfirmed.
                updateOutbox(batchId, canvasId: canvasId) { $0.state = .deliveryUnknown }
                await saveNow()
                return .unavailable
            default: return .unavailable
            }
        }
        let ack: MessageAck?
        do {
            ack = try await threads.reconcile(threadId: entry.thread.threadId, batchId: batchId)
        } catch {
            return .unavailable
        }
        // The entry may have changed while the thread was read.
        guard canvas(canvasId)?.outbox.first(where: { $0.id == batchId })?.state == .deliveryUnknown else { return .unavailable }
        let result: ReconcileResult
        if let ack {
            let attachmentCount = stagedAttachments[batchId]?.attachments.count
                ?? Set(entry.items.map(\.snapshotId)).count + 1
            markSent(batchId: batchId, canvasId: canvasId, receipt: DeliveryReceipt(
                threadId: entry.thread.threadId, messageId: ack.messageId, acknowledgedAt: ack.acknowledgedAt,
                attachmentCount: attachmentCount, confirmation: .reconciledFromThread
            ))
            result = .found
        } else {
            updateOutbox(batchId, canvasId: canvasId) { $0.state = .readyToSend }
            result = .notFound
        }
        await saveNow()
        return result
    }

    public func refreshAgentStatus(canvasId: UUID) async {
        guard let canvas = canvas(canvasId), let thread = canvas.thread, let threads = service(for: thread),
              let status = try? await threads.threadStatus(threadId: thread.threadId) else { return }
        mutateCanvas(canvasId) { canvas in
            for index in canvas.outbox.indices where canvas.outbox[index].state == .sent {
                canvas.outbox[index].agentStatus = status
            }
        }
    }

    // MARK: - Pull

    public struct PullReport: Equatable, Sendable {
        public var importedSnapshots: Int
        public var issues: [String]
        public var messagesChecked: Int
    }

    /// Renders an HTML capture: PNG bytes and pixel size.
    public typealias HTMLCapturer = @MainActor (Data, RenderPolicy, Viewport) async throws -> (png: Data, width: Int, height: Int)

    /// Imports versions the agent returned as text bundles (manifest + HTML files)
    /// in its replies. A message is marked pulled only after every valid entry was
    /// stored (or already existed), so failed entries stay retryable. Pull never
    /// changes Now of a screen that has one: returned baselines wait for Promote to Now.
    public func pull(canvasId: UUID, captureHTML: HTMLCapturer) async -> PullReport {
        guard let canvas = canvas(canvasId), let thread = canvas.thread else {
            return PullReport(importedSnapshots: 0, issues: ["Connect this canvas to a T3 thread first"], messagesChecked: 0)
        }
        if let issue = connectionIssue(for: thread) {
            return PullReport(importedSnapshots: 0, issues: [issue], messagesChecked: 0)
        }
        guard let threads else { return PullReport(importedSnapshots: 0, issues: ["Not connected to T3 Code"], messagesChecked: 0) }
        let messages: [ThreadMessage]
        do {
            messages = try await threads.readMessages(threadId: thread.threadId)
        } catch {
            return PullReport(importedSnapshots: 0, issues: ["Could not read the thread"], messagesChecked: 0)
        }
        var imported = 0
        var issues: [String] = []
        var diagnoses: [String] = []
        for message in messages where message.role != "user" {
            guard !(self.canvas(canvasId)?.pulledMessageIds.contains(message.id) ?? true) else { continue }
            guard let current = self.canvas(canvasId) else { break }
            // Tolerant reader: strict bundles, manifest + plain html blocks, or html blocks alone.
            let bundle = PulledBundleReader.read(message.text, canvas: current)
            issues.append(contentsOf: bundle.issues.map { issue in
                issue.snapshotId.map { "\($0): \(issue.message)" } ?? issue.message
            })
            guard !bundle.entries.isEmpty else {
                if let diagnosis = bundle.diagnosis { diagnoses.append(diagnosis) }
                continue
            }
            let outcome = await importPulledEntries(bundle.entries, canvasId: canvasId, messageId: message.id, captureHTML: captureHTML, issues: &issues)
            imported += outcome.imported
            if outcome.complete {
                mutateCanvas(canvasId) { $0.pulledMessageIds.append(message.id) }
            }
        }
        if imported == 0, issues.isEmpty, let last = diagnoses.last {
            issues.append(last)
        }
        await saveNow()
        return PullReport(importedSnapshots: imported, issues: issues, messagesChecked: messages.count)
    }

    private func ensureScreen(id: String, title: String, canvasId: UUID) -> String {
        guard let canvas = canvas(canvasId) else { return id }
        if !canvas.screens.contains(where: { $0.id == id }) {
            let origin = CanvasLayout.nextScreenOrigin(in: canvas)
            mutateCanvas(canvasId) { $0.screens.append(Screen(id: id, title: title, origin: origin)) }
        }
        return id
    }

    /// Returns how many new snapshots were stored and whether every entry is now
    /// present on the canvas (stored now or before).
    private func importPulledEntries(
        _ entries: [PulledBundle.Entry],
        canvasId: UUID,
        messageId: String,
        captureHTML: HTMLCapturer,
        issues: inout [String]
    ) async -> (imported: Int, complete: Bool) {
        var count = 0
        var complete = true
        let ordered = entries.sorted { ($0.role == .baseline ? 0 : 1, $0.iteration) < ($1.role == .baseline ? 0 : 1, $1.iteration) }
        for entry in ordered {
            if canvas(canvasId)?.snapshots.contains(where: { $0.id == entry.snapshotId }) == true { continue }
            var capture: (data: Data, contentType: String)?
            var pixelSize = (entry.widthPx, entry.heightPx)
            if let rendered = try? await captureHTML(entry.html, entry.renderPolicy, entry.viewport) {
                capture = (rendered.png, "image/png")
                pixelSize = (rendered.width, rendered.height)
            } else {
                issues.append("\(entry.snapshotId): preview image could not be created; it will be made when shown")
            }
            let screenId = ensureScreen(id: entry.screenId, title: entry.screenTitle, canvasId: canvasId)
            let target: ImportTarget = entry.role == .baseline
                ? .baseline(screenId: screenId)
                : .proposal(screenId: screenId, proposalId: entry.proposalId ?? "a")
            let promote = canvas(canvasId).map { CanvasLayout.now(in: $0, screenId: screenId) == nil } ?? false
            do {
                try storeArtifact(
                    into: canvasId,
                    data: entry.html,
                    kind: .html,
                    contentType: "text/html",
                    fileName: entry.snapshotId + ".html",
                    pixelSize: pixelSize,
                    viewport: entry.viewport,
                    target: target,
                    origin: .t3Pull(messageId: messageId, manifestReviewId: nil),
                    snapshotId: entry.snapshotId,
                    changeSummary: entry.changeSummary,
                    addressedNoteIds: entry.addressedNoteIds,
                    parentSnapshotId: entry.parentSnapshotId,
                    capturedAt: nil,
                    captureImage: capture,
                    renderPolicy: entry.renderPolicy,
                    promoteBaseline: promote
                )
                mutateCanvas(canvasId) { canvas in
                    if let index = canvas.snapshots.firstIndex(where: { $0.id == entry.snapshotId }) {
                        canvas.snapshots[index].iteration = entry.iteration
                    }
                }
                count += 1
            } catch let error as ImportError {
                issues.append("\(entry.snapshotId): could not be imported (\(error))")
            } catch {
                complete = false
                issues.append("\(entry.snapshotId): could not be stored; Pull will try again")
            }
        }
        return (count, complete)
    }
}
