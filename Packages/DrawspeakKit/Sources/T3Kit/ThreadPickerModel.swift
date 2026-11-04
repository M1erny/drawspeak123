import Foundation
import Observation
import DrawspeakCore

@MainActor @Observable
final class ThreadPickerModel {
    var search = "" {
        didSet { rebuildGroups() }
    }
    private(set) var groups: [ThreadProjectGroup] = []
    private(set) var error: String?
    private(set) var loading = true
    private var isLoading = false
    private var threads: [ThreadSummary] = []

    func load(service: T3ThreadService) async {
        guard !isLoading else { return }
        isLoading = true
        loading = true
        defer {
            loading = false
            isLoading = false
        }
        do {
            let result = try await service.listThreads()
            try Task.checkCancellation()
            threads = result
            error = nil
            rebuildGroups()
        } catch {
            guard !Task.isCancelled else { return }
            self.error = error.localizedDescription
        }
    }

    func rebuildGroups() {
        groups = Self.projectGroups(threads: threads, search: search)
    }

    static func projectGroups(threads: [ThreadSummary], search: String) -> [ThreadProjectGroup] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        let filtered = threads.filter {
            query.isEmpty || $0.title.localizedStandardContains(query)
                || ($0.projectTitle?.localizedStandardContains(query) ?? false)
        }
        return Dictionary(grouping: filtered, by: \.projectId).map { id, threads in
            ThreadProjectGroup(
                id: id,
                title: threads.first?.projectTitle ?? id ?? String(localized: "Other Threads", bundle: .module),
                threads: threads
            )
        }.sorted {
            let comparison = $0.title.localizedStandardCompare($1.title)
            return comparison == .orderedSame ? ($0.id ?? "") < ($1.id ?? "") : comparison == .orderedAscending
        }
    }
}
