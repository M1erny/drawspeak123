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
                    let state = self.document.canvases[index].notes[noteIndex].recordings[recIndex].state
                    if state == .recording { self.document.canvases[index].notes[noteIndex].recordings[recIndex].state = .interrupted }
                    if state == .transcribing {
                        self.document.canvases[index].notes[noteIndex].recordings[recIndex].state = .failed(code: "interrupted", mayHaveBeenProcessed: true)
                    }
                }
            }
        }
    }

    /// Loads the library from disk, creating a first project and canvas when empty.
    public static func load(locations: StorageLocations) async -> Workspace {
        let store = LibraryStore(fileURL: locations.libraryFile)
        let blobs = BlobStore(root: locations.blobs)
        var document = (try? await store.load()) ?? LibraryDocument()
        if document.projects.isEmpty {
            let project = Project(name: "Drawspeak", createdAt: Date())
            document.projects = [project]
        }
        if document.canvases.isEmpty, let project = document.projects.first {
            let canvas = ReviewCanvas(projectId: project.id, title: "First review", createdAt: Date(), updatedAt: Date())
            document.canvases = [canvas]
            document.lastCanvasId = canvas.id
        }
        return Workspace(document: document, blobs: blobs, store: store)
    }

    // MARK: - Persistence

    /// Debounced autosave of the whole library.
    public func scheduleSave() {
        saveTask?.cancel()
        let snapshot = document
        let store = store
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            do {
                try await store.save(snapshot)
                self?.lastSaveError = nil
            } catch {
                self?.lastSaveError = "Could not save changes"
            }
        }
    }

    /// Saves immediately (for example when the app moves to the background).
    public func saveNow() async {
        saveTask?.cancel()
        do {
            try await store.save(document)
            lastSaveError = nil
        } catch {
            lastSaveError = "Could not save changes"
        }
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
        if let existing = canvas.thread, existing.threadId != binding.threadId, !canvas.outbox.isEmpty { return false }
        mutateCanvas(canvasId) { $0.thread = binding }
        return true
    }

    public func deleteCanvas(_ id: UUID) {
        if activeRecording?.canvasId == id { discardRecording() }
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
        guard let canvas = canvas(canvasId) else { throw ImportError.noCanvas }
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
        let viewport = viewport ?? Viewport(width: pixelSize.width, height: pixelSize.height, deviceScaleFactor: 1)
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
        if shape.identifiesSubject, autoVoice ?? autoVoiceEnabled() {
            Task { await self.startRecording(noteId: note.id) }
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
            canvas.notes[index].textSource = text.isEmpty ? .none : .typed
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

    /// Deletes a note. Undo restores the same id, number and data.
    public func deleteNote(_ id: UUID, canvasId: UUID? = nil) {
        guard let canvasId = canvasId ?? currentCanvasId, let canvas = canvas(canvasId),
              let index = canvas.notes.firstIndex(where: { $0.id == id }) else { return }
        if activeRecording?.noteId == id { discardRecording() }
        let removed = canvas.notes[index]
        mutateCanvas(canvasId) { $0.notes.removeAll { $0.id == id } }
        if focusedNoteId == id { focusedNoteId = nil }
        registerUndo(name: "Delete Comment \(removed.ordinal)") { workspace in
            workspace.restore(removed, at: index, canvasId: canvasId)
        }
    }

    private func restore(_ note: Note, at index: Int, canvasId: UUID) {
        guard let canvas = canvas(canvasId), !canvas.notes.contains(where: { $0.id == note.id }) else { return }
        mutateCanvas(canvasId) { canvas in
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

    /// Starts a recording owned by the note. Requests permission in context on first use.
    public func startRecording(noteId: UUID) async {
        guard let canvasId = currentCanvasId, let voice, note(noteId) != nil else { return }
        if activeRecording != nil { stopRecording() }
        guard await voice.requestPermission() else {
            voiceIssue = .permissionDenied
            return
        }
        // The canvas or note may have changed while the permission prompt was open.
        guard currentCanvasId == canvasId, note(noteId, canvasId: canvasId) != nil else { return }
        let recording = Recording(startedAt: now(), state: .recording)
        let scope = RecordingScope(canvasId: canvasId, noteId: noteId, recordingId: recording.id)
        do {
            try voice.start(scope: scope)
        } catch {
            voiceIssue = .microphoneUnavailable
            return
        }
        voiceIssue = nil
        activeRecording = scope
        mutateCanvas(canvasId) { canvas in
            guard let index = canvas.notes.firstIndex(where: { $0.id == noteId }) else { return }
            canvas.notes[index].recordings.append(recording)
        }
    }

    /// Stop: the audio is saved locally first, then transcribed in the background.
    public func stopRecording() {
        guard let scope = activeRecording else { return }
        activeRecording = nil
        let captured = voice?.stop()
        var blob: BlobRef?
        if let captured, let ref = try? blobs.putFile(at: captured.fileURL, contentType: captured.contentType) {
            blob = ref
        }
        updateRecording(scope) { recording in
            recording.duration = captured?.duration ?? 0
            recording.audio = blob
            recording.state = blob == nil ? .interrupted : .saved
        }
        if blob != nil { transcribe(scope) }
    }

    /// Discard the current recording; an empty new region is removed (Undo restores it).
    public func discardRecording() {
        guard let scope = activeRecording else { return }
        activeRecording = nil
        voice?.discard()
        mutateCanvas(scope.canvasId) { canvas in
            guard let index = canvas.notes.firstIndex(where: { $0.id == scope.noteId }) else { return }
            canvas.notes[index].recordings.removeAll { $0.id == scope.recordingId }
        }
        if let note = note(scope.noteId, canvasId: scope.canvasId), !note.hasText, note.recordings.isEmpty {
            deleteNote(scope.noteId, canvasId: scope.canvasId)
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

    /// Sends the saved audio once. Failures keep the audio; retries are always deliberate.
    public func transcribe(_ scope: RecordingScope) {
        guard let recording = recording(scope), let audio = recording.audio else { return }
        guard let transcriber, transcriber.isConfigured else {
            updateRecording(scope) { $0.state = .failed(code: TranscriptionFailure.Code.notConfigured.rawValue, mayHaveBeenProcessed: false) }
            return
        }
        guard let data = try? blobs.data(for: audio) else {
            updateRecording(scope) { $0.state = .failed(code: "audio_missing", mayHaveBeenProcessed: false) }
            return
        }
        updateRecording(scope) { $0.state = .transcribing }
        let language = transcriptionLanguage()
        Task {
            do {
                let transcript = try await transcriber.transcribe(audio: data, contentType: audio.contentType, language: language)
                self.applyTranscript(transcript, scope: scope)
            } catch let failure as TranscriptionFailure {
                self.updateRecording(scope) { $0.state = .failed(code: failure.code.rawValue, mayHaveBeenProcessed: failure.requestMayHaveBeenProcessed) }
            } catch {
                self.updateRecording(scope) { $0.state = .failed(code: "unknown", mayHaveBeenProcessed: true) }
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

    /// Resuming a draft never overwrites newer edits: notes edited since the draft
    /// keep their text, and deleted notes come back as copies with new numbers.
    /// Returns the note ids that represent the draft now.
    public func resumeDraft(_ draftId: UUID, canvasId: UUID) -> Set<UUID> {
        guard let canvas = canvas(canvasId), let draft = canvas.drafts.first(where: { $0.id == draftId }) else { return [] }
        var ids = Set<UUID>()
        var copies: [Note] = []
        var ordinal = canvas.nextOrdinal
        for item in draft.items {
            if canvas.notes.contains(where: { $0.id == item.noteId }) {
                ids.insert(item.noteId)
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
        return ids
    }

    /// Freezes the shown package into the outbox and delivers it with one message.
    /// `attachments` are the rendered composites and the manifest, in message order.
    @discardableResult
    public func send(package: FeedbackPackage, attachments: [OutgoingAttachment], canvasId: UUID) async -> OutboxEntry? {
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

    /// Delivers a Ready to Send entry. Never called automatically after restart or reconnect.
    public func deliver(batchId: String, canvasId: UUID) async {
        guard let entry = canvas(canvasId)?.outbox.first(where: { $0.id == batchId }) else { return }
        switch entry.state {
        case .readyToSend, .failed: break
        default: return
        }
        guard let threads else {
            updateOutbox(batchId, canvasId: canvasId) { $0.state = .failed(reason: "Not connected to T3 Code") }
            return
        }
        guard let staged = stagedAttachments[batchId] else {
            updateOutbox(batchId, canvasId: canvasId) { $0.state = .failed(reason: "Open the package again to rebuild its images") }
            return
        }
        let started = now()
        updateOutbox(batchId, canvasId: canvasId) {
            $0.state = .uploading(done: 0, total: staged.attachments.count)
            $0.attempts.append(DeliveryAttempt(startedAt: started, endedAt: nil, outcome: "started"))
        }
        let total = staged.attachments.count
        do {
            let ack = try await threads.send(threadId: entry.thread.threadId, text: staged.text, attachments: staged.attachments) { done, _ in
                Task { @MainActor in
                    self.updateOutbox(batchId, canvasId: canvasId) { entry in
                        // Progress never overrides a final state that arrived first.
                        guard case .uploading = entry.state else { return }
                        entry.state = done >= total ? .sending : .uploading(done: done, total: total)
                    }
                }
            }
            markSent(batchId: batchId, canvasId: canvasId, receipt: DeliveryReceipt(
                threadId: entry.thread.threadId, messageId: ack.messageId, acknowledgedAt: ack.acknowledgedAt,
                attachmentCount: total, confirmation: .response
            ))
        } catch {
            let ended = now()
            updateOutbox(batchId, canvasId: canvasId) { entry in
                switch error {
                case .outcomeUnknown: entry.state = .deliveryUnknown
                case .notAuthorized: entry.state = .failed(reason: "T3 Code authorization expired. Connect again.")
                case .notSent(let reason): entry.state = .failed(reason: reason)
                }
                if !entry.attempts.isEmpty {
                    entry.attempts[entry.attempts.count - 1].endedAt = ended
                    entry.attempts[entry.attempts.count - 1].outcome = "\(entry.state)"
                }
            }
        }
    }

    private func markSent(batchId: String, canvasId: UUID, receipt: DeliveryReceipt) {
        stagedAttachments[batchId] = nil
        mutateCanvas(canvasId) { canvas in
            guard let index = canvas.outbox.firstIndex(where: { $0.id == batchId }) else { return }
            canvas.outbox[index].state = .sent
            canvas.outbox[index].receipt = receipt
            if !canvas.outbox[index].attempts.isEmpty {
                canvas.outbox[index].attempts[canvas.outbox[index].attempts.count - 1].endedAt = receipt.acknowledgedAt
                canvas.outbox[index].attempts[canvas.outbox[index].attempts.count - 1].outcome = "sent"
            }
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

    /// Delivery Unknown: look for the batch marker in the thread before any retry.
    public func reconcile(batchId: String, canvasId: UUID) async -> ReconcileResult {
        guard let entry = canvas(canvasId)?.outbox.first(where: { $0.id == batchId }), let threads else { return .unavailable }
        guard let messages = try? await threads.readMessages(threadId: entry.thread.threadId) else { return .unavailable }
        let marker = "drawspeak-batch:\(batchId)"
        if let message = messages.first(where: { $0.text.contains(marker) }) {
            markSent(batchId: batchId, canvasId: canvasId, receipt: DeliveryReceipt(
                threadId: entry.thread.threadId, messageId: message.id, acknowledgedAt: message.createdAt ?? now(),
                attachmentCount: message.attachments.count, confirmation: .reconciledFromThread
            ))
            return .found
        }
        updateOutbox(batchId, canvasId: canvasId) { $0.state = .readyToSend }
        return .notFound
    }

    public func refreshAgentStatus(canvasId: UUID) async {
        guard let canvas = canvas(canvasId), let thread = canvas.thread, let threads,
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
    /// in its replies. Each message is imported once.
    public func pull(canvasId: UUID, captureHTML: HTMLCapturer) async -> PullReport {
        guard let canvas = canvas(canvasId), let thread = canvas.thread, let threads else {
            return PullReport(importedSnapshots: 0, issues: ["Connect this canvas to a T3 thread first"], messagesChecked: 0)
        }
        let messages: [ThreadMessage]
        do {
            messages = try await threads.readMessages(threadId: thread.threadId)
        } catch {
            return PullReport(importedSnapshots: 0, issues: ["Could not read the thread"], messagesChecked: 0)
        }
        var imported = 0
        var issues: [String] = []
        for message in messages where message.role != "user" {
            guard !(self.canvas(canvasId)?.pulledMessageIds.contains(message.id) ?? true) else { continue }
            let bundle = TextBundleParser.parse(message.text)
            guard let manifestData = bundle.manifest else { continue }
            guard let manifest = try? ReviewManifest.decode(manifestData) else {
                issues.append("A reply contains a manifest that could not be read")
                mutateCanvas(canvasId) { $0.pulledMessageIds.append(message.id) }
                continue
            }
            guard let current = self.canvas(canvasId) else { break }
            let result = ManifestValidator.validate(manifest, files: bundle.files, canvas: current)
            issues.append(contentsOf: result.issues.map { "\($0.snapshotId ?? manifest.reviewId): \($0.message)" })
            imported += await importManifestEntries(result.valid, manifest: manifest, files: bundle.files, canvasId: canvasId, messageId: message.id, captureHTML: captureHTML, issues: &issues)
            mutateCanvas(canvasId) { $0.pulledMessageIds.append(message.id) }
        }
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

    private func importManifestEntries(
        _ entries: [ReviewManifest.Entry],
        manifest: ReviewManifest,
        files: [String: Data],
        canvasId: UUID,
        messageId: String,
        captureHTML: HTMLCapturer,
        issues: inout [String]
    ) async -> Int {
        var count = 0
        // Baselines first, then iterations in order, so parent chains resolve.
        let ordered = entries.sorted { ($0.role == .baseline ? 0 : 1, $0.iteration) < ($1.role == .baseline ? 0 : 1, $1.iteration) }
        for entry in ordered {
            let screenId = ensureScreen(id: entry.screenId, title: entry.screenTitle ?? entry.screenId, canvasId: canvasId)
            let image = entry.imagePath.flatMap { ManifestValidator.file($0, in: files) }
            let html = (entry.htmlPath ?? entry.prototypePath).flatMap { ManifestValidator.file($0, in: files) }
            let isHTML = entry.artifactKind == .html && html != nil
            let policy = entry.renderPolicy ?? .staticNoScript
            var capture: (data: Data, contentType: String)?
            var pixelSize = (entry.widthPx, entry.heightPx)
            if isHTML, let html {
                if let image {
                    capture = (image, "image/png")
                } else if let rendered = try? await captureHTML(html, policy, entry.viewport) {
                    capture = (rendered.png, "image/png")
                    pixelSize = (rendered.width, rendered.height)
                } else {
                    issues.append("\(entry.snapshotId): HTML capture failed; the version was imported without a capture")
                }
            }
            guard let bytes = isHTML ? html : image else { continue }
            let target: ImportTarget = entry.role == .baseline
                ? .baseline(screenId: screenId)
                : .proposal(screenId: screenId, proposalId: entry.proposalId ?? "a")
            let name = ((isHTML ? (entry.htmlPath ?? entry.prototypePath) : entry.imagePath) ?? entry.snapshotId) as NSString
            do {
                try importArtifact(
                    into: canvasId,
                    data: bytes,
                    kind: isHTML ? .html : .image,
                    contentType: isHTML ? "text/html" : "image/png",
                    fileName: name.lastPathComponent,
                    pixelSize: pixelSize,
                    viewport: entry.viewport,
                    target: target,
                    origin: .t3Pull(messageId: messageId, manifestReviewId: manifest.reviewId),
                    snapshotId: entry.snapshotId,
                    changeSummary: entry.changeSummary,
                    addressedNoteIds: entry.addressedNoteIds ?? [],
                    parentSnapshotId: entry.parentSnapshotId,
                    capturedAt: entry.capturedAt,
                    captureImage: capture,
                    renderPolicy: policy
                )
                // Keep the manifest's iteration number rather than the derived one.
                mutateCanvas(canvasId) { canvas in
                    if let index = canvas.snapshots.firstIndex(where: { $0.id == entry.snapshotId }) {
                        canvas.snapshots[index].iteration = entry.iteration
                    }
                }
                count += 1
            } catch {
                issues.append("\(entry.snapshotId): could not be stored")
            }
        }
        return count
    }
}
