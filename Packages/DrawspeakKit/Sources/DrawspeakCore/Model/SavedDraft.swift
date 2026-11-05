import Foundation

/// A feedback package set aside locally. Never sent or queued.
public struct SavedDraft: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var createdAt: Date
    public var thread: ThreadBinding?
    public var items: [BatchItem]
    /// What the reviewer asked the agent to do; nil for drafts saved before directives existed.
    public var directive: AgentDirective?

    public init(id: UUID = UUID(), createdAt: Date, thread: ThreadBinding?, items: [BatchItem], directive: AgentDirective? = nil) {
        self.id = id
        self.createdAt = createdAt
        self.thread = thread
        self.items = items
        self.directive = directive
    }
}
