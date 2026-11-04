import CryptoKit
import Foundation

/// Content-addressed, immutable storage for images, HTML, audio and composites.
/// Bytes live at `<root>/<sha256>`; writing the same bytes twice is a no-op.
public struct BlobStore: Sendable {
    public let root: URL

    public init(root: URL) {
        self.root = root
    }

    public static func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    @discardableResult
    public func put(_ data: Data, contentType: String) throws -> BlobRef {
        let hash = Self.sha256Hex(data)
        let url = root.appending(path: hash)
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        if !fileManager.fileExists(atPath: url.path(percentEncoded: false)) {
            try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        }
        return BlobRef(sha256: hash, byteCount: data.count, contentType: contentType)
    }

    /// Moves an existing file (for example a finished audio recording) into the store.
    public func putFile(at source: URL, contentType: String) throws -> BlobRef {
        let data = try Data(contentsOf: source)
        let ref = try put(data, contentType: contentType)
        try? FileManager.default.removeItem(at: source)
        return ref
    }

    public func url(for ref: BlobRef) -> URL {
        root.appending(path: ref.sha256)
    }

    public func exists(_ ref: BlobRef) -> Bool {
        FileManager.default.fileExists(atPath: url(for: ref).path(percentEncoded: false))
    }

    public func data(for ref: BlobRef) throws -> Data {
        let data = try Data(contentsOf: url(for: ref))
        guard Self.sha256Hex(data) == ref.sha256 else { throw BlobStoreError.checksumMismatch }
        return data
    }
}

public enum BlobStoreError: Error, Equatable {
    case checksumMismatch
}
