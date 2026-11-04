import Foundation

/// A frozen feedback batch on its way to the agent, with its delivery history.
public struct OutboxEntry: Codable, Hashable, Identifiable, Sendable {
    /// The batch id, also written into the message text for reconciliation.
    public var id: String
    public var createdAt: Date
    public var thread: ThreadBinding
    public var items: [BatchItem]
    public var isRepeat: Bool
    public var state: DeliveryState
    public var receipt: DeliveryReceipt?
    public var attempts: [DeliveryAttempt]
    /// Agent work status reported by the thread, separate from delivery.
    public var agentStatus: String?
    /// Set while the batch starts a new thread that the server has not returned yet.
    /// `thread` then holds the host and the requested title, with an empty `threadId`.
    public var newThread: NewThreadTarget?

    public init(id: String, createdAt: Date, thread: ThreadBinding, items: [BatchItem], isRepeat: Bool, state: DeliveryState, receipt: DeliveryReceipt? = nil, attempts: [DeliveryAttempt] = [], agentStatus: String? = nil, newThread: NewThreadTarget? = nil) {
        self.id = id
        self.createdAt = createdAt
        self.thread = thread
        self.items = items
        self.isRepeat = isRepeat
        self.state = state
        self.receipt = receipt
        self.attempts = attempts
        self.agentStatus = agentStatus
        self.newThread = newThread
    }
}

/// Where a batch that starts a new thread goes, kept until the server returns the thread.
public struct NewThreadTarget: Codable, Hashable, Sendable {
    public var projectId: String
    public var projectTitle: String?
    public var title: String
    /// Sent with every launch attempt; the server returns the same thread for the same value.
    public var clientRequestId: String

    public init(projectId: String, projectTitle: String?, title: String, clientRequestId: String) {
        self.projectId = projectId
        self.projectTitle = projectTitle
        self.title = title
        self.clientRequestId = clientRequestId
    }
}

public struct DeliveryAttempt: Codable, Hashable, Sendable {
    public var startedAt: Date
    public var endedAt: Date?
    public var outcome: String

    public init(startedAt: Date, endedAt: Date?, outcome: String) {
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.outcome = outcome
    }
}
