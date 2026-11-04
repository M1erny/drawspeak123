import Foundation
import Observation
import DrawspeakCore

@MainActor @Observable
final class ThreadPickerModel {
    var search = "" { didSet { rebuildGroups() } }
    private(set) var groups: [ThreadStatusGroup] = []
    private(set) var error: String?
    private(set) var loading = true
    private(set) var refreshing = false
    private(set) var fetchedAt: Date?
    private var threads: [ThreadSummary] = []
    private var loadedHost: URL?
    private var loadedGeneration: UUID?
    private let cache: ThreadListCache

    init(cache: ThreadListCache = .shared) { self.cache = cache }

    func load(service: T3ThreadService, force: Bool = false) async {
        guard !refreshing else { return }
        let host = service.hostURL
        if loadedHost != host || loadedGeneration != cache.generation {
            threads = []; fetchedAt = nil; error = nil; loading = true
            loadedHost = host
            loadedGeneration = cache.generation
            rebuildGroups()
        }
        let generation = cache.generation
        let snapshot = cache.load(host: host)
        if let snapshot {
            threads = snapshot.threads
            fetchedAt = snapshot.fetchedAt
            loading = false
            rebuildGroups()
            if !force && snapshot.isFresh() { return }
        }
        refreshing = true
        defer { loading = false; refreshing = false }
        do {
            let result = try await service.listThreads()
            try Task.checkCancellation()
            guard generation == cache.generation else {
                threads = []; fetchedAt = nil; rebuildGroups(); return
            }
            threads = ThreadListCache.merge(cached: threads, fetched: result)
            fetchedAt = cache.save(threads, host: host).fetchedAt
            error = nil
            rebuildGroups()
        } catch {
            guard !Task.isCancelled else { return }
            self.error = error.localizedDescription
        }
    }

    func rebuildGroups() {
        groups = Self.statusGroups(threads: threads, search: search)
    }

    static func statusGroups(threads: [ThreadSummary], search: String, now: Date = .now) -> [ThreadStatusGroup] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        let filtered = threads.filter {
            query.isEmpty || $0.title.localizedStandardContains(query)
                || ($0.projectTitle?.localizedStandardContains(query) ?? false)
                || ($0.projectId?.localizedStandardContains(query) ?? false)
        }
        let sections = Dictionary(grouping: filtered) { ThreadStatusGroup.Status.classify($0, now: now) }
        return ThreadStatusGroup.Status.allCases.compactMap { status in
            guard let threads = sections[status], !threads.isEmpty else { return nil }
            return ThreadStatusGroup(id: status, threads: threads.sorted {
                if $0.updatedAt != $1.updatedAt { return ($0.updatedAt ?? .distantPast) > ($1.updatedAt ?? .distantPast) }
                return $0.id < $1.id
            })
        }
    }
}
