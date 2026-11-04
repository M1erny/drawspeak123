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

    @Test func statusOrderAndSevenDayBoundary() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let threads = [
            thread("older", status: "completed", date: now.addingTimeInterval(-7 * 86_400 - 1)),
            thread("boundary", status: "completed", date: now.addingTimeInterval(-7 * 86_400)),
            thread("idle", status: "idle", date: now), thread("waiting", status: "waiting"),
            thread("failed", status: "failed"), thread("interrupted", status: "interrupted"),
            thread("cancelled", status: "cancelled"), thread("rolled_back", status: "rolled_back"),
            thread("running", status: "running"), thread("starting", status: "starting"),
            thread("preparing", status: "preparing"), thread("queued", status: "queued")
        ]
        let groups = ThreadPickerModel.statusGroups(threads: threads, search: "", now: now)
        #expect(groups.map(\.id) == [.running, .waiting, .recent, .stopped, .older])
        #expect(groups[0].threads.count == 4)
        #expect(groups[2].threads.map(\.id) == ["idle", "boundary"])
        #expect(groups[3].threads.count == 4)
        #expect(groups[4].threads.map(\.id) == ["older"])
    }

    private func thread(_ id: String, title: String = "Thread", projectTitle: String? = nil, status: String? = nil, date: Date? = nil) -> ThreadSummary {
        ThreadSummary(id: id, title: title, projectId: "project", projectTitle: projectTitle, status: status, updatedAt: date)
    }
}
