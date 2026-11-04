import Foundation

nonisolated public struct T3Credentials: Codable, Sendable, Equatable {
    public var hostURL: URL
    public var clientId: String
    public var accessToken: String
    public var scope: String
    public var expiresAt: Date
    public var accessLevel: String
    public var endpoint: T3Endpoint?
    /// Read-only environment token (`orchestration:read filesystem:read`) for downloading
    /// workspace files over `/ws` `assets.createUrl`. Nil when paired before file access existed
    /// or when the server could not issue it.
    public var filesToken: String?
    public var filesTokenExpiresAt: Date?
    public init(hostURL: URL, clientId: String, accessToken: String, scope: String, expiresAt: Date, accessLevel: String, endpoint: T3Endpoint? = nil,
                filesToken: String? = nil, filesTokenExpiresAt: Date? = nil) {
        self.hostURL = hostURL; self.clientId = clientId; self.accessToken = accessToken
        self.scope = scope; self.expiresAt = expiresAt; self.accessLevel = accessLevel; self.endpoint = endpoint
        self.filesToken = filesToken; self.filesTokenExpiresAt = filesTokenExpiresAt
    }
    /// The files token, when present and unexpired.
    public var usableFilesToken: String? {
        guard let filesToken, (filesTokenExpiresAt ?? .distantFuture) > Date.now else { return nil }
        return filesToken
    }
}
