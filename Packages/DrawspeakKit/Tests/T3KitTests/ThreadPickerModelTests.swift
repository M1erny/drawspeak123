import Foundation
import Testing
import DrawspeakCore
@testable import T3Kit

@MainActor
struct ThreadPickerModelTests {
    @Test func searchMatchesTitlesAndProjects() {
        let threads = [
            thread("1", title: "Checkout", projectId: "a", projectTitle: "Store"),
            thread("2", title: "Login", projectId: "b", projectTitle: "Account")
        ]
        #expect(ThreadPickerModel.projectGroups(threads: threads, search: "check").flatMap(\.threads).map(\.id) == ["1"])
        #expect(ThreadPickerModel.projectGroups(threads: threads, search: "ACCOUNT").flatMap(\.threads).map(\.id) == ["2"])
        #expect(ThreadPickerModel.projectGroups(threads: threads, search: "missing").isEmpty)
        #expect(ThreadPickerModel.projectGroups(threads: threads, search: "  ").count == 2)
    }

    @Test func projectsKeepDistinctIdentitiesAndThreadOrder() {
        let threads = [
            thread("1", projectId: nil),
            thread("2", projectId: "Other Threads"),
            thread("3", projectId: "z", projectTitle: "Alpha"),
            thread("4", projectId: "z", projectTitle: "Alpha")
        ]
        let groups = ThreadPickerModel.projectGroups(threads: threads, search: "")
        #expect(groups.count == 3)
        #expect(groups.first?.title == "Alpha")
        #expect(groups.first?.threads.map(\.id) == ["3", "4"])
        #expect(groups.contains { $0.id == nil && $0.threads.map(\.id) == ["1"] })
        #expect(groups.contains { $0.id == "Other Threads" && $0.threads.map(\.id) == ["2"] })
    }

    private func thread(_ id: String, title: String = "Thread", projectId: String?, projectTitle: String? = nil) -> ThreadSummary {
        ThreadSummary(id: id, title: title, projectId: projectId, projectTitle: projectTitle, status: nil, updatedAt: nil)
    }
}
