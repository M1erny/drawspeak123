import Foundation
import Testing
import DrawspeakCore
@testable import T3Kit

@MainActor
struct ThreadListCacheTests {
    let host = URL(string: "https://cache.test")!

    @Test func roundTripHostIsolationAndInvalidation() throws {
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let cache = ThreadListCache(directory: directory)
        let date = Date(timeIntervalSince1970: 10_000)
        cache.save([thread("a", date: date)], host: host, fetchedAt: date)
        let restored = ThreadListCache(directory: directory).load(host: host)
        #expect(restored?.threads == [thread("a", date: date)])
        #expect(restored?.fetchedAt == date)
        #expect(restored?.isFresh(at: date.addingTimeInterval(59)) == true)
        #expect(restored?.isFresh(at: date.addingTimeInterval(60)) == false)
        #expect(restored?.isFresh(at: date.addingTimeInterval(-1)) == false)
        #expect(cache.load(host: URL(string: "https://other.test")!) == nil)
        let generation = cache.generation
        cache.invalidate(host: host)
        #expect(cache.generation != generation)
        #expect(cache.load(host: host) == nil)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("broken".utf8).write(to: cache.fileURL(for: host))
        #expect(cache.load(host: host) == nil)
    }

    @Test func mergeReplacesDuplicatesSortsAndCapsDisk() {
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let cache = ThreadListCache(directory: directory)
        let old = (0..<310).map { thread(String($0), date: Date(timeIntervalSince1970: Double($0))) }
        let updated = thread("0", date: Date(timeIntervalSince1970: 1000))
        let merged = ThreadListCache.merge(cached: old, fetched: [updated])
        #expect(merged.count == 300)
        #expect(merged.first == updated)
        #expect(merged.filter { $0.id == "0" }.count == 1)
        cache.save(merged, host: host)
        #expect(cache.load(host: host)?.threads == merged)
    }

    private func thread(_ id: String, date: Date) -> ThreadSummary {
        ThreadSummary(id: id, title: "Title", projectId: "project", projectTitle: "Project", status: "waiting", updatedAt: date)
    }
}
