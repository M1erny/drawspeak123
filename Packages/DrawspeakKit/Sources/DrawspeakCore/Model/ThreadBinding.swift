import Foundation

/// The single T3 thread a canvas belongs to.
public struct ThreadBinding: Codable, Hashable, Sendable {
    public var hostURL: URL
    public var threadId: String
    public var threadTitle: String
    public var projectId: String?
    public var projectTitle: String?

    public init(hostURL: URL, threadId: String, threadTitle: String, projectId: String?, projectTitle: String?) {
        self.hostURL = hostURL
        self.threadId = threadId
        self.threadTitle = threadTitle
        self.projectId = projectId
        self.projectTitle = projectTitle
    }

    public var displayName: String {
        if let projectTitle, !projectTitle.isEmpty { "\(projectTitle) › \(threadTitle)" } else { threadTitle }
    }
}
