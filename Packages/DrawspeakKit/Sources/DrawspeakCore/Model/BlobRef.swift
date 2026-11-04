import Foundation

/// A reference to immutable bytes in the content-addressed blob store.
public struct BlobRef: Codable, Hashable, Sendable {
    /// Lowercase hex SHA-256 of the exact bytes.
    public var sha256: String
    public var byteCount: Int
    public var contentType: String

    public init(sha256: String, byteCount: Int, contentType: String) {
        self.sha256 = sha256
        self.byteCount = byteCount
        self.contentType = contentType
    }
}
