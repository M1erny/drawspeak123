import DrawspeakCore
import Foundation

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

/// A workspace backed by a fresh temp directory with one project and one bound canvas.
@MainActor
func makeWorkspace(thread: ThreadBinding? = testThread) -> Workspace {
    let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    let project = Project(name: "Test", createdAt: fixedDate)
    let canvas = ReviewCanvas(projectId: project.id, title: "Review", thread: thread, createdAt: fixedDate, updatedAt: fixedDate)
    let document = LibraryDocument(projects: [project], canvases: [canvas], lastCanvasId: canvas.id)
    let workspace = Workspace(
        document: document,
        blobs: BlobStore(root: root.appending(path: "blobs")),
        store: LibraryStore(fileURL: root.appending(path: "library.json"))
    )
    workspace.now = { fixedDate }
    return workspace
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

/// A thread service double. `sendFailure` makes `send` throw; `messages` is what the thread contains.
struct FakeThreadService: ThreadService {
    var sendFailure: DeliveryFailure?
    var messages: [ThreadMessage] = []

    func listThreads() async throws -> [ThreadSummary] { [] }
    func readMessages(threadId: String) async throws -> [ThreadMessage] { messages }
    func send(
        threadId: String, text: String, attachments: [OutgoingAttachment],
        progress: @Sendable (Int, Int) -> Void
    ) async throws(DeliveryFailure) -> MessageAck {
        progress(attachments.count, attachments.count)
        if let sendFailure { throw sendFailure }
        return MessageAck(messageId: "msg-1", acknowledgedAt: fixedDate)
    }
    func downloadAttachment(threadId: String, attachment: ThreadAttachment) async throws -> Data { Data() }
    func threadStatus(threadId: String) async throws -> String? { nil }
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
