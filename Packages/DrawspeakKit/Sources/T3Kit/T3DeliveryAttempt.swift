import Foundation

/// Retain this in the app outbox before reconciling an interrupted send.
nonisolated public struct T3DeliveryAttempt: Sendable, Hashable {
    public let batchId: String
    public let threadId: String
    public let activeRunId: String?
    public let latestRunId: String?
    public var messageId: String?
    public var runId: String?
    public var status: String?
    public var marker: String { "[drawspeak-batch:\(batchId)]" }
}
