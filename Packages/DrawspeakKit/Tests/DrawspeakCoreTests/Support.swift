import DrawspeakCore
import Foundation
import Synchronization

let fixedDate = Date(timeIntervalSince1970: 1_800_000_000)

let testThread = ThreadBinding(
    hostURL: URL(string: "https://t3.example.com")!,
    threadId: "thread-1",
    threadTitle: "Checkout redesign",
    projectId: "proj-1",
    projectTitle: "Shop"
)

let regionShape = AnnotationShape.region(NRect(x: 0.1, y: 0.1, width: 0.3, height: 0.2))
let arrowShape = AnnotationShape.arrow(from: NPoint(x: 0.1, y: 0.1), to: NPoint(x: 0.6, y: 0.6))

func makeTranscript(_ text: String) -> Transcript {
    Transcript(
        text: text, requestedLanguage: nil, detectedLanguage: "eng", languageProbability: 0.99,
        provider: "fake", modelId: "fake-1", receivedAt: fixedDate
    )
}

func makeTempRoot() -> URL {
    FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
}

/// A workspace backed by a temp directory (`root`) with one project and one bound canvas.
@MainActor
func makeWorkspace(thread: ThreadBinding? = testThread, root: URL = makeTempRoot()) -> Workspace {
    let project = Project(name: "Test", createdAt: fixedDate)
    let canvas = ReviewCanvas(projectId: project.id, title: "Review", thread: thread, createdAt: fixedDate, updatedAt: fixedDate)
    let document = LibraryDocument(projects: [project], canvases: [canvas], lastCanvasId: canvas.id)
    let locations = StorageLocations(root: root)
    let workspace = Workspace(
        document: document,
        blobs: BlobStore(root: locations.blobs),
        store: LibraryStore(fileURL: locations.libraryFile)
    )
    workspace.now = { fixedDate }
    return workspace
}

/// Decodes the library file as saved on disk.
func persistedDocument(root: URL) -> LibraryDocument? {
    guard let data = try? Data(contentsOf: StorageLocations(root: root).libraryFile) else { return nil }
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return try? decoder.decode(LibraryDocument.self, from: data)
}

func persistedOutboxState(root: URL, batchId: String) -> DeliveryState? {
    persistedDocument(root: root)?.canvases.flatMap(\.outbox).first { $0.id == batchId }?.state
}

/// Makes a directory read-only (or writable again) to simulate storage failures.
func setWritable(_ url: URL, _ writable: Bool) throws {
    try FileManager.default.setAttributes([.posixPermissions: writable ? 0o755 : 0o555], ofItemAtPath: url.path(percentEncoded: false))
}

@MainActor
func waitUntil(timeout: Duration = .seconds(5), _ condition: () -> Bool) async -> Bool {
    let clock = ContinuousClock()
    let deadline = clock.now + timeout
    while !condition() {
        if clock.now > deadline { return false }
        try? await Task.sleep(for: .milliseconds(5))
    }
    return true
}

/// Imports a distinct image as a new screen with the given snapshot id.
@MainActor
@discardableResult
func addImage(_ workspace: Workspace, id: String, canvasId: UUID? = nil) throws -> Snapshot {
    try workspace.importArtifact(
        into: canvasId ?? workspace.currentCanvasId!,
        data: Data("image-bytes-\(id)".utf8),
        kind: .image,
        contentType: "image/png",
        fileName: "\(id).png",
        pixelSize: (width: 100, height: 200),
        target: .newScreen(title: id),
        snapshotId: id
    )
}

@MainActor
@discardableResult
func addTextNote(
    _ workspace: Workspace, snapshotId: String, text: String, shape: AnnotationShape = regionShape
) -> UUID {
    let id = workspace.addNote(snapshotId: snapshotId, shape: shape, autoVoice: false)!
    if !text.isEmpty { workspace.updateNoteText(id, text: text) }
    return id
}

/// Records which service methods were called.
final class CallLog: Sendable {
    private let storage = Mutex<[String]>([])
    func record(_ call: String) { storage.withLock { $0.append(call) } }
    var calls: [String] { storage.withLock { $0 } }
}

enum ReconcileStub: Sendable {
    case found(MessageAck)
    case notFound
    case fails
}

struct ReconcileUnavailable: Error {}

/// A thread service double. `sendFailure` makes `send` throw; `messages` is what the thread contains.
struct FakeThreadService: ThreadService {
    var hostURL: URL = testThread.hostURL
    var sendFailure: DeliveryFailure?
    var messages: [ThreadMessage] = []
    var reconcileResult: ReconcileStub = .notFound
    var log = CallLog()
    /// Runs when `send` starts, before any upload.
    var onSend: @Sendable () -> Void = {}

    func listThreads() async throws -> [ThreadSummary] { log.record("listThreads"); return [] }
    func readMessages(threadId: String) async throws -> [ThreadMessage] { log.record("readMessages"); return messages }
    func send(
        threadId: String, text: String, attachments: [OutgoingAttachment],
        progress: @Sendable (Int, Int) -> Void
    ) async throws(DeliveryFailure) -> MessageAck {
        log.record("send")
        onSend()
        progress(attachments.count, attachments.count)
        if let sendFailure { throw sendFailure }
        return MessageAck(messageId: "msg-1", acknowledgedAt: fixedDate)
    }
    func downloadAttachment(threadId: String, attachment: ThreadAttachment) async throws -> Data { Data() }
    func reconcile(threadId: String, batchId: String) async throws -> MessageAck? {
        log.record("reconcile")
        switch reconcileResult {
        case .found(let ack): return ack
        case .notFound: return nil
        case .fails: throw ReconcileUnavailable()
        }
    }
    func threadStatus(threadId: String) async throws -> String? { log.record("threadStatus"); return nil }
}

/// A microphone double that writes a small temporary file on Stop. Live events are
/// sent with `emit`; by default nothing arrives until the test sends it.
@MainActor
final class FakeVoice: VoiceCapturing {
    private(set) var scope: RecordingScope?
    private(set) var discardCount = 0
    private(set) var startCount = 0
    private(set) var lastFile: URL?
    private(set) var lastLanguage: String?
    private(set) var onEvent: (@MainActor (LiveTranscriptEvent) -> Void)?
    var hasPermission = true
    var permissionGranted = true
    /// Sent right after Stop, as a live session finishing in the background would.
    var eventsAfterStop: [LiveTranscriptEvent] = []
    let directory = makeTempRoot()

    func requestPermission() async -> Bool {
        if permissionGranted { hasPermission = true }
        return permissionGranted
    }
    func start(scope: RecordingScope, language: String?, onEvent: @escaping @MainActor (LiveTranscriptEvent) -> Void) throws {
        self.scope = scope
        lastLanguage = language
        startCount += 1
        self.onEvent = onEvent
    }
    func emit(_ event: LiveTranscriptEvent) { onEvent?(event) }
    func stop() -> CapturedAudio? {
        guard let scope else { return nil }
        self.scope = nil
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appending(path: "\(UUID().uuidString).m4a")
        try? Data("audio-\(scope.recordingId)".utf8).write(to: url)
        lastFile = url
        let pending = eventsAfterStop
        if let onEvent, !pending.isEmpty {
            Task { for event in pending { onEvent(event) } }
        }
        return CapturedAudio(scope: scope, fileURL: url, contentType: "audio/mp4", duration: 1.5)
    }
    func discard() {
        scope = nil
        onEvent = nil
        discardCount += 1
    }
    var isRecording: Bool { scope != nil }
    var level: Double { 0 }
    var elapsed: TimeInterval { 0 }
}

/// Returns `text` after a short delay and counts requests.
final class FakeTranscriber: Transcribing, Sendable {
    let text: String
    private let count = Mutex(0)
    init(text: String) { self.text = text }
    var calls: Int { count.withLock { $0 } }
    var isConfigured: Bool { true }
    func transcribe(audio: Data, contentType: String, language: String?) async throws(TranscriptionFailure) -> Transcript {
        count.withLock { $0 += 1 }
        try? await Task.sleep(for: .milliseconds(30))
        return makeTranscript(text)
    }
}

/// Builds a package for the given notes and sends it through the workspace.
@MainActor
func sendNotes(
    _ workspace: Workspace, noteIds: Set<UUID>, batchId: String = "ds-test-1"
) async -> (package: FeedbackPackage, entry: OutboxEntry?) {
    let canvas = workspace.currentCanvas!
    let package = FeedbackPackageBuilder.build(canvas: canvas, noteIds: noteIds, thread: testThread, batchId: batchId, now: fixedDate)
    let attachments = [OutgoingAttachment(fileName: "01.png", contentType: "image/png", data: Data("png".utf8))]
    let entry = await workspace.send(package: package, attachments: attachments, canvasId: canvas.id)
    return (package, entry)
}
