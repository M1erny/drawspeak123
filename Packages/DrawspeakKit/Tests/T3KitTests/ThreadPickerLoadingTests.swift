import Foundation
import Testing
import Synchronization
import DrawspeakCore
@testable import T3Kit

extension T3KitTests {
    @Test @MainActor func threadPickerFreshCacheAndForcedRefresh() async throws {
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let cache = ThreadListCache(directory: directory)
        let cached = ThreadSummary(id: "cached", title: "Cached", projectId: nil, projectTitle: nil, status: "idle", updatedAt: .now)
        cache.save([cached], host: host)
        let calls = Mutex(0)
        let session = StubProtocol.session { request in
            let body = try Self.body(request)
            if let reply = try Self.handshake(request, body) { return reply }
            calls.withLock { $0 += 1 }
            return try Self.rpc(body, result: .object(["structuredContent": .object(["threads": .array([
                .object(["threadId": .string("new"), "title": .string("New"), "status": .string("waiting")])
            ])])]))
        }
        let service = T3ThreadService(client: MCPClient(credentials: credential(), session: session))
        let model = ThreadPickerModel(cache: cache)
        await model.load(service: service)
        #expect(calls.withLock { $0 } == 0)
        #expect(model.groups.flatMap(\.threads) == [cached])
        await model.load(service: service, force: true)
        #expect(calls.withLock { $0 } == 1)
        #expect(Set(model.groups.flatMap(\.threads).map(\.id)) == ["cached", "new"])
        #expect(!model.loading && !model.refreshing)
        #expect(model.error == nil)
    }

    @Test @MainActor func staleCacheSurvivesRefreshFailure() async throws {
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let cache = ThreadListCache(directory: directory)
        let cached = ThreadSummary(id: "cached", title: "Cached", projectId: nil, projectTitle: nil, status: "idle", updatedAt: .now)
        cache.save([cached], host: host, fetchedAt: .now.addingTimeInterval(-61))
        let session = StubProtocol.session { request in
            let body = try Self.body(request)
            if let reply = try Self.handshake(request, body) { return reply }
            throw URLError(.notConnectedToInternet)
        }
        let service = T3ThreadService(client: MCPClient(credentials: credential(), session: session))
        let model = ThreadPickerModel(cache: cache)
        await model.load(service: service)
        #expect(model.groups.flatMap(\.threads) == [cached])
        #expect(model.error != nil)
        #expect(!model.loading && !model.refreshing)
        cache.invalidate(host: host)
        await model.load(service: service)
        #expect(model.groups.isEmpty)
    }

    @Test func threadListStopsAfterThreePages() async throws {
        let calls = Mutex(0)
        let session = StubProtocol.session { request in
            let body = try Self.body(request)
            if let reply = try Self.handshake(request, body) { return reply }
            let page = calls.withLock { $0 += 1; return $0 }
            let args = body["params"]["arguments"]
            #expect(body["params"]["name"].string == "t3_thread_list")
            #expect(args["limit"].int == 100)
            #expect(args["allProjects"].bool)
            #expect(!args["includeSubagents"].bool)
            #expect(page == 1 ? args["cursor"].int == nil : args["cursor"].int == page - 1)
            return try Self.rpc(body, result: .object(["structuredContent": .object([
                "threads": .array([.object(["threadId": .string("\(page)")])]),
                "nextCursor": .number(Double(page))
            ])]))
        }
        let threads = try await T3ThreadService(client: MCPClient(credentials: credential(), session: session)).listThreads()
        #expect(threads.count == 3)
        #expect(calls.withLock { $0 } == 3)
    }
}
