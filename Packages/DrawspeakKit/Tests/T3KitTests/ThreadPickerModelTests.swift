import Foundation
import Testing
import DrawspeakCore
@testable import T3Kit

@MainActor
struct ThreadPickerModelTests {
    @Test func searchMatchesTitlesAndProjects() {
        let threads = [thread("1", title: "Checkout", projectTitle: "Store"), thread("2", title: "Login", projectTitle: "Account")]
        #expect(ThreadPickerModel.statusGroups(threads: threads, search: "check").flatMap(\.threads).map(\.id) == ["1"])
        #expect(ThreadPickerModel.statusGroups(threads: threads, search: "ACCOUNT").flatMap(\.threads).map(\.id) == ["2"])
        #expect(ThreadPickerModel.statusGroups(threads: threads, search: "missing").isEmpty)
        #expect(ThreadPickerModel.statusGroups(threads: threads, search: "  ").flatMap(\.threads).count == 2)
    }

    @Test func groupsLikeTheT3CodeSidebar() {
        let threads = [
            thread("done", status: "completed", settled: true),
            thread("nap", status: "completed", snoozed: true),
            thread("running", status: "running"), thread("queued", status: "queued"),
            thread("waiting", status: "waiting"), thread("failed", status: "failed"),
            thread("finished", status: "completed"), thread("idle", status: "idle"),
        ]
        let groups = ThreadPickerModel.statusGroups(threads: threads, search: "")
        #expect(groups.map(\.id) == [.needsAttention, .working, .snoozed, .settled])
        #expect(Set(groups[0].threads.map(\.id)) == ["waiting", "failed", "finished", "idle"])
        #expect(Set(groups[1].threads.map(\.id)) == ["running", "queued"])
        #expect(groups[2].threads.map(\.id) == ["nap"])
        #expect(groups[3].threads.map(\.id) == ["done"])
    }

    private func thread(_ id: String, title: String = "Thread", projectTitle: String? = nil, status: String? = nil, date: Date? = nil,
                        settled: Bool = false, snoozed: Bool = false) -> ThreadSummary {
        ThreadSummary(id: id, title: title, projectId: "project", projectTitle: projectTitle, status: status, updatedAt: date,
                      settled: settled, snoozed: snoozed)
    }
}
