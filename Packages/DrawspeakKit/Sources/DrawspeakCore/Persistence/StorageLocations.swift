import Foundation

public struct StorageLocations: Sendable {
    public let root: URL

    public init(root: URL) {
        self.root = root
    }

    /// `Application Support/Drawspeak`, excluded from nothing: it is backed up with the device.
    public static func applicationSupport() throws -> StorageLocations {
        let base = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        return StorageLocations(root: base.appending(path: "Drawspeak", directoryHint: .isDirectory))
    }

    public var libraryFile: URL { root.appending(path: "library.json") }
    public var blobs: URL { root.appending(path: "blobs", directoryHint: .isDirectory) }
    public var scratch: URL { root.appending(path: "scratch", directoryHint: .isDirectory) }
}
