import DrawspeakCore
import Foundation

/// Reads and verifies blob bytes away from the main actor.
nonisolated enum BlobLoader {
    @concurrent
    static func data(for ref: BlobRef, in blobs: BlobStore) async -> Data? {
        try? blobs.data(for: ref)
    }
}
