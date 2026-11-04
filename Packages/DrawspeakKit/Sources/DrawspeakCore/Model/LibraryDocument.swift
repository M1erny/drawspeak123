import Foundation

/// Everything the app persists, except blob bytes and secrets.
public struct LibraryDocument: Codable, Hashable, Sendable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var projects: [Project]
    public var canvases: [ReviewCanvas]
    public var lastCanvasId: UUID?

    public init(schemaVersion: Int = LibraryDocument.currentSchemaVersion, projects: [Project] = [], canvases: [ReviewCanvas] = [], lastCanvasId: UUID? = nil) {
        self.schemaVersion = schemaVersion
        self.projects = projects
        self.canvases = canvases
        self.lastCanvasId = lastCanvasId
    }
}
