import Foundation

/// Microphone capture with live transcription. Implemented in VoiceKit.
@MainActor
public protocol VoiceCapturing: AnyObject {
    /// True when microphone access was already granted, so `start` needs no prompt.
    var hasPermission: Bool { get }
    /// Requests permission in context on first use. Returns false when denied.
    func requestPermission() async -> Bool
    /// Starts recording a new file and streaming it for live transcription.
    /// `language` is nil for automatic detection, or "pol"/"eng".
    /// `onEvent` is never called synchronously from `start`; after `discard()` it is not called again.
    /// Throws when the microphone is unavailable.
    func start(scope: RecordingScope, language: String?, onEvent: @escaping @MainActor (LiveTranscriptEvent) -> Void) throws
    /// Stops and returns the finished local file, or nil when nothing was captured.
    /// Live transcription then finishes in the background and ends with `finished` or `failed`.
    func stop() -> CapturedAudio?
    /// Stops and deletes the current capture; live transcription is cancelled without events.
    func discard()
    var isRecording: Bool { get }
    /// Live level 0...1 for the recording indicator.
    var level: Double { get }
    var elapsed: TimeInterval { get }
}

public struct CapturedAudio: Sendable {
    public var scope: RecordingScope
    public var fileURL: URL
    public var contentType: String
    public var duration: TimeInterval

    public init(scope: RecordingScope, fileURL: URL, contentType: String, duration: TimeInterval) {
        self.scope = scope
        self.fileURL = fileURL
        self.contentType = contentType
        self.duration = duration
    }
}

/// Batch speech-to-text, the fallback when live transcription failed. Implemented in VoiceKit (ElevenLabs Scribe v2).
public protocol Transcribing: Sendable {
    var isConfigured: Bool { get }
    /// `language` is nil for automatic detection, or "pol"/"eng".
    func transcribe(audio: Data, contentType: String, language: String?) async throws(TranscriptionFailure) -> Transcript
}

public struct TranscriptionFailure: Error, Hashable, Sendable {
    public enum Code: String, Sendable {
        case notConfigured = "not_configured"
        case invalidRequest = "invalid_request"
        case auth
        case rateLimited = "rate_limited"
        case network
        case upstream
        case invalidResponse = "invalid_response"
        case aborted
    }

    public var code: Code
    public var requestMayHaveBeenProcessed: Bool

    public init(code: Code, requestMayHaveBeenProcessed: Bool) {
        self.code = code
        self.requestMayHaveBeenProcessed = requestMayHaveBeenProcessed
    }
}

/// A file to attach to a thread message.
public struct OutgoingAttachment: Sendable {
    public var fileName: String
    public var contentType: String
    public var data: Data

    public init(fileName: String, contentType: String, data: Data) {
        self.fileName = fileName
        self.contentType = contentType
        self.data = data
    }
}

public struct MessageAck: Sendable, Hashable {
    public var messageId: String?
    public var acknowledgedAt: Date

    public init(messageId: String?, acknowledgedAt: Date) {
        self.messageId = messageId
        self.acknowledgedAt = acknowledgedAt
    }
}

public enum DeliveryFailure: Error, Sendable, Hashable {
    /// Failed before the message request was sent; nothing was delivered.
    case notSent(String)
    /// The message request started but no definite answer came back.
    case outcomeUnknown
    case notAuthorized
}

/// An attachment found in a thread, available for Pull.
public struct ThreadAttachment: Sendable, Hashable {
    public var id: String
    public var fileName: String
    public var contentType: String
    public var byteCount: Int?

    public init(id: String, fileName: String, contentType: String, byteCount: Int?) {
        self.id = id
        self.fileName = fileName
        self.contentType = contentType
        self.byteCount = byteCount
    }
}

public struct ThreadMessage: Sendable, Hashable {
    public var id: String
    public var role: String
    public var text: String
    public var createdAt: Date?
    public var attachments: [ThreadAttachment]

    public init(id: String, role: String, text: String, createdAt: Date?, attachments: [ThreadAttachment]) {
        self.id = id
        self.role = role
        self.text = text
        self.createdAt = createdAt
        self.attachments = attachments
    }
}

public struct ThreadSummary: Sendable, Hashable, Identifiable {
    public var id: String
    public var title: String
    public var projectId: String?
    public var projectTitle: String?
    public var status: String?
    public var updatedAt: Date?

    public init(id: String, title: String, projectId: String?, projectTitle: String?, status: String?, updatedAt: Date?) {
        self.id = id
        self.title = title
        self.projectId = projectId
        self.projectTitle = projectTitle
        self.status = status
        self.updatedAt = updatedAt
    }
}

/// A T3 Code project a new thread can be started in.
public struct ProjectSummary: Sendable, Hashable, Identifiable {
    public var id: String
    public var title: String

    public init(id: String, title: String) {
        self.id = id
        self.title = title
    }
}

/// The thread created by `ThreadService.launchThread`.
public struct LaunchedThread: Sendable, Hashable {
    public var threadId: String
    public var title: String
    public var messageId: String?

    public init(threadId: String, title: String, messageId: String?) {
        self.threadId = threadId
        self.title = title
        self.messageId = messageId
    }
}

/// The T3 Code thread operations the app needs. Implemented in T3Kit.
public protocol ThreadService: Sendable {
    /// The T3 host this service talks to; operations require it to match the canvas binding.
    var hostURL: URL { get }
    func listThreads() async throws -> [ThreadSummary]
    /// Projects a new thread can be started in (archived and deleted ones excluded).
    func listProjects() async throws -> [ProjectSummary]
    func readMessages(threadId: String) async throws -> [ThreadMessage]
    /// Uploads every attachment, then sends exactly one message.
    /// Must throw `DeliveryFailure.outcomeUnknown` when the send request may have reached the server.
    func send(threadId: String, text: String, attachments: [OutgoingAttachment], progress: @Sendable (Int, Int) -> Void) async throws(DeliveryFailure) -> MessageAck
    /// Uploads every attachment, then starts one new thread whose first message is `text`.
    /// A retry with the same `clientRequestId` after an error or lost reply returns the
    /// same thread instead of creating another one.
    /// Must throw `DeliveryFailure.outcomeUnknown` when the launch request may have reached the server.
    func launchThread(projectId: String, title: String, text: String, attachments: [OutgoingAttachment], clientRequestId: String, progress: @Sendable (Int, Int) -> Void) async throws(DeliveryFailure) -> LaunchedThread
    func downloadAttachment(threadId: String, attachment: ThreadAttachment) async throws -> Data
    /// Finds the outgoing user message (or accepted queue item) carrying the exact
    /// batch marker `[drawspeak-batch:<batchId>]`. Nil when no such message exists.
    /// Throws when the thread cannot be read, so uncertainty is preserved.
    func reconcile(threadId: String, batchId: String) async throws -> MessageAck?
    /// Agent work status of the thread, for display only.
    func threadStatus(threadId: String) async throws -> String?
}
