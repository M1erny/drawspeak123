import Foundation
import Testing
import Synchronization
import DrawspeakCore
@testable import T3Kit

/// New-thread launch and the project catalog. In the serialized suite: the URL stub is shared.
extension T3KitTests {
    @Test(arguments: ["success", "timeout", "unreadable", "rejected", "sessionExpired"])
    func launchUploadsThenLaunchesOnce(_ scenario: String) async throws {
        let order = Mutex<[String]>([])
        let launches = Mutex<[JSONValue]>([])
        let session = StubProtocol.session { request in
            if request.url!.path.hasPrefix("/api/") {
                order.withLock { $0.append("upload") }
                return (204, [:], Data())
            }
            let body = try Self.body(request)
            if let reply = try Self.handshake(request, body) { return reply }
            let name = body["params"]["name"].string!
            order.withLock { $0.append(name) }
            var content: JSONValue = .object([:])
            switch name {
            case "t3_attachment_prepare_upload":
                content = .object(["attachmentId": .string("pending-\(UUID().uuidString)"), "relativeUrl": .string("/api/attachments/upload/signed")])
            default:
                let arguments = body["params"]["arguments"]
                launches.withLock { $0.append(arguments) }
                if scenario == "timeout" { throw URLError(.timedOut) }
                // A lost MCP session proves the call did not run; the client repeats it once.
                if scenario == "sessionExpired" && launches.withLock({ $0.count }) == 1 { return (404, [:], Data()) }
                if scenario == "rejected" {
                    return try Self.rpc(body, result: .object(["isError": .bool(true), "structuredContent": .object(["code": .string("not_found"), "message": .string("Unknown project")])]))
                }
                content = scenario == "unreadable" ? .object(["ok": .bool(true)])
                    : .object(["thread": .object(["threadId": .string("mcp:new"), "title": .string("Server title"), "link": .string("https://fake.test/env/mcp:new")]), "messageId": .string("m-1")])
            }
            return try Self.rpc(body, result: .object(["structuredContent": content]))
        }
        let service = T3ThreadService(client: MCPClient(credentials: credential(), session: session))
        let files = [OutgoingAttachment(fileName: "a.png", contentType: "image/png", data: Data([1, 2, 3])), OutgoingAttachment(fileName: "b.json", contentType: "application/json", data: Data([4, 5, 6]))]
        let progress = Mutex<[Int]>([])
        do {
            let launched = try await service.launchThread(projectId: "proj", title: "Review", text: "Feedback", attachments: files, clientRequestId: "ds-1") { done, _ in
                progress.withLock { $0.append(done) }
            }
            #expect(["success", "sessionExpired"].contains(scenario))
            #expect(launched == LaunchedThread(threadId: "mcp:new", title: "Server title", messageId: "m-1"))
        } catch {
            switch scenario {
            case "timeout", "unreadable": #expect(error == .outcomeUnknown)
            case "rejected": #expect(error == .notSent("Unknown project"))
            default: Issue.record("Unexpected failure: \(error)")
            }
        }
        let launchCalls = scenario == "sessionExpired" ? 2 : 1
        #expect(order.withLock { $0 } == ["t3_attachment_prepare_upload", "upload", "t3_attachment_prepare_upload", "upload"] + Array(repeating: "t3_thread_launch", count: launchCalls))
        #expect(progress.withLock { $0 } == [1, 2])
        for arguments in launches.withLock({ $0 }) {
            #expect(arguments["clientRequestId"].string == "ds-1")
            #expect(arguments["projectId"].string == "proj")
            #expect(arguments["title"].string == "Review")
            #expect(arguments["message"].string == "[drawspeak-batch:ds-1]\nFeedback")
            #expect(arguments["attachments"].array.count == 2)
            #expect(arguments["attachments"].array.first?["type"].string == "image")
            #expect(arguments["attachments"].array.allSatisfy { $0["id"].string?.hasPrefix("pending-") == true })
        }
    }

    @Test func launchResultShapes() {
        let top = T3ThreadService.launchedThread(from: .object(["threadId": .string("t1"), "title": .string("A"), "messageId": .string("m")]), requestedTitle: "Requested")
        #expect(top == LaunchedThread(threadId: "t1", title: "A", messageId: "m"))
        let nested = T3ThreadService.launchedThread(from: .object(["thread": .object(["threadId": .string("t2")])]), requestedTitle: "Requested")
        #expect(nested == LaunchedThread(threadId: "t2", title: "Requested", messageId: nil))
        let byId = T3ThreadService.launchedThread(from: .object(["thread": .object(["id": .string("t3"), "title": .string("B")])]), requestedTitle: "Requested")
        #expect(byId == LaunchedThread(threadId: "t3", title: "B", messageId: nil))
        #expect(T3ThreadService.launchedThread(from: .object(["threadId": .string("")]), requestedTitle: "R") == nil)
        #expect(T3ThreadService.launchedThread(from: .object(["link": .string("x")]), requestedTitle: "R") == nil)
    }

    @Test func launchValidationHappensBeforeNetwork() async throws {
        let session = StubProtocol.session { _ in Issue.record("Invalid launch reached network"); return (500, [:], Data()) }
        let service = T3ThreadService(client: MCPClient(credentials: credential(), session: session))
        let nine = (0..<9).map { OutgoingAttachment(fileName: "\($0).png", contentType: "image/png", data: Data([1])) }
        for (project, title, files) in [("", "T", [OutgoingAttachment]()), ("p", " ", []), ("p", "T", nine)] {
            do { _ = try await service.launchThread(projectId: project, title: title, text: "x", attachments: files, clientRequestId: "ds", progress: { _, _ in }); Issue.record("Expected validation failure") }
            catch { if case .notSent = error {} else { Issue.record("Incorrect failure: \(error)") } }
        }
    }

    @Test func projectListPaging() async throws {
        let cursors = Mutex<[Int]>([])
        let session = StubProtocol.session { request in
            let body = try Self.body(request)
            if let reply = try Self.handshake(request, body) { return reply }
            #expect(body["params"]["name"].string == "t3_project_list")
            let args = body["params"]["arguments"]
            #expect(args["limit"].int == 100)
            let cursor = args["cursor"].int ?? 0
            cursors.withLock { $0.append(cursor) }
            var projects: [JSONValue] = [.object(["id": .string("p\(cursor)"), "title": .string("Project \(cursor)"), "workspaceRoot": .string("/w/p\(cursor)"), "archivedAt": .null, "deletedAt": .null])]
            if cursor == 100 {
                projects.append(.object(["id": .string("archived"), "title": .string("Old"), "archivedAt": .string("2026-01-01T00:00:00Z")]))
                projects.append(.object(["id": .string("rooted"), "workspaceRoot": .string("/Users/me/Dev/app")]))
            }
            return try Self.rpc(body, result: .object(["structuredContent": .object(["projects": .array(projects), "nextCursor": cursor < 200 ? .number(Double(cursor + 100)) : .null])]))
        }
        let projects = try await T3ThreadService(client: MCPClient(credentials: credential(), session: session)).listProjects()
        #expect(projects == [
            ProjectSummary(id: "p0", title: "Project 0"), ProjectSummary(id: "p100", title: "Project 100"),
            ProjectSummary(id: "rooted", title: "app"), ProjectSummary(id: "p200", title: "Project 200"),
        ])
        #expect(cursors.withLock { $0 } == [0, 100, 200])
    }
}
