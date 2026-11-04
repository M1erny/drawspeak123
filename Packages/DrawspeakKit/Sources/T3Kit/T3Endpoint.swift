import Foundation

nonisolated public struct T3Endpoint: Codable, Sendable, Hashable {
    public let origin: URL
    public let issuer: String
    public let resource: String
    public let environmentId: String?
    public let serverVersion: String?
}
