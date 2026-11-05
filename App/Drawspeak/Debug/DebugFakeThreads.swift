#if DEBUG
import DrawspeakCore
import Foundation

/// A T3 thread double for simulator screenshots of Send (launch argument
/// -DrawspeakFakeThreads). Uploads take a moment and every message is acknowledged.
/// Never part of a release build.
struct DebugFakeThreads: ThreadService {
    static let host = URL(string: "https://t3.example")!
    static let binding = ThreadBinding(hostURL: host, threadId: "debug-thread", threadTitle: "Redesign App and Extension Flows",
                                       projectId: "debug-project", projectTitle: "apassy")

    var hostURL: URL { Self.host }

    func listThreads() async throws -> [ThreadSummary] { [] }
    func listProjects() async throws -> [ProjectSummary] { [ProjectSummary(id: "debug-project", title: "apassy")] }
    func readMessages(threadId: String) async throws -> [ThreadMessage] { [] }

    func send(threadId: String, text: String, attachments: [OutgoingAttachment], progress: @Sendable (Int, Int) -> Void) async throws(DeliveryFailure) -> MessageAck {
        for index in attachments.indices {
            try? await Task.sleep(for: .milliseconds(250))
            progress(index + 1, attachments.count)
        }
        return MessageAck(messageId: UUID().uuidString, acknowledgedAt: .now)
    }

    func launchThread(projectId: String, title: String, text: String, attachments: [OutgoingAttachment], clientRequestId: String,
                      progress: @Sendable (Int, Int) -> Void) async throws(DeliveryFailure) -> LaunchedThread {
        _ = try await send(threadId: "", text: text, attachments: attachments, progress: progress)
        return LaunchedThread(threadId: "debug-new-thread", title: title, messageId: UUID().uuidString)
    }

    func downloadAttachment(threadId: String, attachment: ThreadAttachment) async throws -> Data { Data() }
    func downloadWorkspaceFile(threadId: String, path: String) async throws -> Data { throw CocoaError(.fileNoSuchFile) }
    func reconcile(threadId: String, batchId: String) async throws -> MessageAck? { nil }
    func threadStatus(threadId: String) async throws -> String? { nil }
}
#endif
