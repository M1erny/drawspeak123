import DrawspeakCore
import Foundation
import Testing

@MainActor
@Suite("Library load and recovery (F01)")
struct LibraryLoadTests {
    private func writeGarbage(_ locations: StorageLocations) throws -> Data {
        try FileManager.default.createDirectory(at: locations.root, withIntermediateDirectories: true)
        let bytes = Data("{\"schemaVersion\": 1, \"projects\": [tru".utf8)
        try bytes.write(to: locations.libraryFile)
        return bytes
    }

    @Test func missingFileOpensAFreshLibrary() async throws {
        let locations = StorageLocations(root: makeTempRoot())
        guard case .loaded(let ws) = await Workspace.open(locations: locations) else {
            Issue.record("Expected a fresh library")
            return
        }
        #expect(ws.canvases.count == 1)
        #expect(ws.currentCanvas?.title == "First review")
    }

    @Test func unreadableFileIsReportedAndLeftUntouched() async throws {
        let locations = StorageLocations(root: makeTempRoot())
        let bytes = try writeGarbage(locations)

        let outcome = await Workspace.open(locations: locations)

        guard case .unreadable(let error, let fileURL) = outcome else {
            Issue.record("Expected unreadable")
            return
        }
        #expect(!error.isEmpty)
        #expect(fileURL == locations.libraryFile)
        #expect(try Data(contentsOf: locations.libraryFile) == bytes)
        let names = try FileManager.default.contentsOfDirectory(atPath: locations.root.path(percentEncoded: false))
        #expect(names == ["library.json"])
    }

    @Test func newerSchemaIsUnreadable() async throws {
        let locations = StorageLocations(root: makeTempRoot())
        try await LibraryStore(fileURL: locations.libraryFile).save(LibraryDocument(schemaVersion: LibraryDocument.currentSchemaVersion + 1))
        guard case .unreadable = await Workspace.open(locations: locations) else {
            Issue.record("Expected unreadable")
            return
        }
    }

    @Test func startFreshKeepsTheOldFileRenamed() async throws {
        let locations = StorageLocations(root: makeTempRoot())
        let bytes = try writeGarbage(locations)

        let ws = await Workspace.startFresh(locations: locations)

        let names = try FileManager.default.contentsOfDirectory(atPath: locations.root.path(percentEncoded: false))
        let backup = try #require(names.first { $0.hasPrefix("library.unreadable-") && $0.hasSuffix(".json") })
        #expect(try Data(contentsOf: locations.root.appending(path: backup)) == bytes)
        #expect(ws.lastSaveError == nil)
        let saved = try #require(persistedDocument(root: locations.root))
        #expect(saved.canvases.map(\.id) == ws.canvases.map(\.id))
    }

    @Test func legacyLoadNeverOverwritesAnUnreadableFile() async throws {
        let locations = StorageLocations(root: makeTempRoot())
        let bytes = try writeGarbage(locations)

        let ws = await Workspace.load(locations: locations)
        ws.createCanvas(title: "New", thread: nil)
        await ws.saveNow()

        #expect(try Data(contentsOf: locations.libraryFile) == bytes)
        #expect(ws.lastSaveError != nil)
    }
}
