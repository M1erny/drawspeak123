import Foundation

/// A feedback package set aside locally. Never sent or queued.
public struct SavedDraft: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var createdAt: Date
    public var thread: ThreadBinding?
    public var items: [BatchItem]

    public init(id: UUID = UUID(), createdAt: Date, thread: ThreadBinding?, items: [BatchItem]) {
        self.id = id
        self.createdAt = createdAt
        self.thread = thread
        self.items = items
    }
}
