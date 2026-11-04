import Foundation
import CryptoKit
import DrawspeakCore

/// Small host-scoped snapshots. Failure to read or write never prevents picking a thread.
@MainActor
final class ThreadListCache {
    static let shared = ThreadListCache()
    nonisolated static let capacity = 300
    private let directory: URL
    private(set) var generation = UUID()

    init(directory: URL = URL.applicationSupportDirectory.appending(path: "Drawspeak")) {
        self.directory = directory
    }

    struct Snapshot {
        let threads: [ThreadSummary]
        let fetchedAt: Date
        func isFresh(at now: Date = .now) -> Bool {
            (0..<60).contains(now.timeIntervalSince(fetchedAt))
        }
    }

    private struct Record: Codable {
        let id: String
        let title: String
        let projectId: String?
        let projectTitle: String?
        let status: String?
        let updatedAt: Date?
        let settled: Bool?
        let snoozed: Bool?
        init(_ thread: ThreadSummary) {
            id = thread.id; title = thread.title; projectId = thread.projectId
            projectTitle = thread.projectTitle; status = thread.status; updatedAt = thread.updatedAt
            settled = thread.settled; snoozed = thread.snoozed
        }
        var summary: ThreadSummary {
            ThreadSummary(id: id, title: title, projectId: projectId, projectTitle: projectTitle,
                          status: status, updatedAt: updatedAt, settled: settled ?? false, snoozed: snoozed ?? false)
        }
    }
    private struct Stored: Codable {
        let fetchedAt: Date
        let threads: [Record]
    }

    func fileURL(for host: URL) -> URL {
        let hash = SHA256.hash(data: Data(host.absoluteString.utf8)).map { ($0 < 16 ? "0" : "") + String($0, radix: 16) }.joined()
        return directory.appending(path: "t3-threads-\(hash).json")
    }

    func load(host: URL) -> Snapshot? {
        guard let data = try? Data(contentsOf: fileURL(for: host)),
              let stored = try? JSONDecoder().decode(Stored.self, from: data) else { return nil }
        return Snapshot(threads: Self.merge(cached: [], fetched: stored.threads.map(\.summary)), fetchedAt: stored.fetchedAt)
    }

    @discardableResult
    func save(_ threads: [ThreadSummary], host: URL, fetchedAt: Date = .now) -> Snapshot {
        let snapshot = Snapshot(threads: Self.merge(cached: [], fetched: threads), fetchedAt: fetchedAt)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(Stored(fetchedAt: fetchedAt, threads: snapshot.threads.map(Record.init)))
            try data.write(to: fileURL(for: host), options: .atomic)
        } catch { /* A best-effort cache; the fetched list is still usable. */ }
        return snapshot
    }

    func invalidate(host: URL) {
        generation = UUID() // Fences writes from requests started before disconnect/pairing.
        try? FileManager.default.removeItem(at: fileURL(for: host))
    }

    static func merge(cached: [ThreadSummary], fetched: [ThreadSummary]) -> [ThreadSummary] {
        var byID: [String: ThreadSummary] = [:]
        for thread in cached { byID[thread.id] = thread }
        for thread in fetched { byID[thread.id] = thread }
        return Array(byID.values.sorted {
            if $0.updatedAt != $1.updatedAt { return ($0.updatedAt ?? .distantPast) > ($1.updatedAt ?? .distantPast) }
            return $0.id < $1.id
        }.prefix(capacity))
    }
}
