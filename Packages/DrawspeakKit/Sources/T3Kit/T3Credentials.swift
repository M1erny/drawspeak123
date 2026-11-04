import Foundation

nonisolated public struct T3Credentials: Codable, Sendable, Equatable {
    public var hostURL: URL
    public var clientId: String
    public var accessToken: String
    public var scope: String
    public var expiresAt: Date
    public var accessLevel: String
    public var endpoint: T3Endpoint?
    public init(hostURL: URL, clientId: String, accessToken: String, scope: String, expiresAt: Date, accessLevel: String, endpoint: T3Endpoint? = nil) {
        self.hostURL = hostURL; self.clientId = clientId; self.accessToken = accessToken
        self.scope = scope; self.expiresAt = expiresAt; self.accessLevel = accessLevel; self.endpoint = endpoint
    }
}
