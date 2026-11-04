import Foundation
import DrawspeakCore

nonisolated public struct T3ThreadService: ThreadService, Sendable {
    public let client: MCPClient
    public var hostURL: URL { client.credentials.hostURL }
    public init(client: MCPClient) { self.client = client }
    public func listThreads() async throws -> [ThreadSummary] {
        var threads: [ThreadSummary] = [], cursor: Int?
        var seenCursors = Set<Int>()
        for _ in 0..<3 {
            var args: [String: JSONValue] = ["allProjects": .bool(true), "includeSubagents": .bool(false), "limit": .number(100)]
            if let cursor { args["cursor"] = .number(Double(cursor)) }
            let page = try await client.callTool(name: "t3_thread_list", arguments: .object(args))
            for item in page["threads"].array {
                guard let id = item["threadId"].string else { throw MCPError.invalidResponse }
                if !threads.contains(where: { $0.id == id }) {
                    threads.append(ThreadSummary(id: id, title: item["title"].string ?? String(localized: "Untitled Thread", bundle: .module), projectId: item["projectId"].string, projectTitle: item["projectTitle"].string, status: item["status"].string, updatedAt: date(item["updatedAt"]), settled: item["settled"].bool, snoozed: item["snoozed"].bool))
                }
            }
            guard let next = page["nextCursor"].int else { break }
            guard seenCursors.insert(next).inserted else { throw MCPError.invalidResponse }
            cursor = next
        }
        // The thread list schema has no project title; resolve titles from the project catalog.
        if threads.contains(where: { $0.projectId != nil && $0.projectTitle == nil }) {
            var titles: [String: String] = [:]
            for project in try await projectCatalog() {
                if let id = project["id"].string, let title = project["title"].string { titles[id] = title }
            }
            for index in threads.indices { if let id = threads[index].projectId { threads[index].projectTitle = threads[index].projectTitle ?? titles[id] } }
        }
        return Array(threads.prefix(ThreadListCache.capacity))
    }
    /// Projects in catalog order, without archived or deleted ones.
    public func listProjects() async throws -> [ProjectSummary] {
        var projects: [ProjectSummary] = []
        for project in try await projectCatalog() {
            guard let id = project["id"].string, !id.isEmpty else { throw MCPError.invalidResponse }
            guard project["archivedAt"].string == nil, project["deletedAt"].string == nil, !projects.contains(where: { $0.id == id }) else { continue }
            let title = project["title"].string ?? project["name"].string ?? project["workspaceRoot"].string.map { URL(filePath: $0).lastPathComponent }
            projects.append(ProjectSummary(id: id, title: title ?? String(localized: "Untitled Project", bundle: .module)))
        }
        return projects
    }
    /// Every page of `t3_project_list` ("Pages can shift": repeated cursors are refused).
    private func projectCatalog() async throws -> [JSONValue] {
        var projects: [JSONValue] = [], cursor: Int?
        var seenCursors = Set<Int>()
        while true {
            var args: [String: JSONValue] = ["limit": .number(100)]
            if let cursor { args["cursor"] = .number(Double(cursor)) }
            let page = try await client.callTool(name: "t3_project_list", arguments: .object(args))
            projects += page["projects"].array
            guard let next = page["nextCursor"].int else { return projects }
            guard seenCursors.insert(next).inserted else { throw MCPError.invalidResponse }
            cursor = next
        }
    }
    public func readMessages(threadId: String) async throws -> [ThreadMessage] {
        var result: [ThreadMessage] = [], position: Int?
        for _ in 0..<10 {
            var args: [String: JSONValue] = ["threadId": .string(threadId), "view": .string("messages"), "limit": .number(100), "maxCharsPerItem": .number(50_000)]
            if let position { args["afterPosition"] = .number(Double(position)) }
            let page = try await client.callTool(name: "t3_thread_read", arguments: .object(args))
            for item in page["items"].array {
                guard let type = item["type"].string, ["user_message", "assistant_message"].contains(type), let id = item["itemId"].string else { continue }
                var text = item["text"].string ?? "", offset = item["nextTextOffset"].int, truncated = item["textTruncated"].bool
                while truncated {
                    guard text.utf8.count < 2_097_152, let next = offset else { throw MCPError.tool(code: "message_too_large", message: String(localized: "Message exceeds the 2 MiB reading limit.", bundle: .module)) }
                    let continuation = try await client.callTool(name: "t3_thread_read", arguments: .object(["threadId": .string(threadId), "itemId": .string(id), "textOffset": .number(Double(next)), "maxCharsPerItem": .number(50_000)]))
                    guard let chunk = continuation["items"].array.first(where: { $0["itemId"].string == id }), let part = chunk["text"].string, !part.isEmpty else { throw MCPError.invalidResponse }
                    text += part
                    truncated = chunk["textTruncated"].bool; offset = chunk["nextTextOffset"].int
                    guard !truncated || (offset ?? 0) > next else { throw MCPError.invalidResponse }
                }
                guard text.utf8.count <= 2_097_152 else { throw MCPError.tool(code: "message_too_large", message: String(localized: "Message exceeds the 2 MiB reading limit.", bundle: .module)) }
                let messageId = item["messageId"].string ?? id
                if !result.contains(where: { $0.id == messageId }) { result.append(ThreadMessage(id: messageId, role: type == "user_message" ? "user" : "assistant", text: text, createdAt: date(item["createdAt"]) ?? date(item["updatedAt"]), attachments: [])) }
            }
            guard page["hasMore"].bool else { return result }
            guard let next = page["nextPosition"].int, next != position else { throw MCPError.invalidResponse }; position = next
        }
        throw MCPError.tool(code: "page_limit", message: String(localized: "Thread exceeds the 10-page reading limit.", bundle: .module))
    }
    public func send(threadId: String, text: String, attachments: [OutgoingAttachment], progress: @Sendable (Int, Int) -> Void) async throws(DeliveryFailure) -> MessageAck {
        guard (1...8).contains(attachments.count) else { throw .notSent(String(localized: "Attach between 1 and 8 files.", bundle: .module)) }
        let batchId: String
        if let range = text.range(of: "drawspeak-batch:") {
            let existing = text[range.upperBound...].prefix { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-" || $0 == "_") }
            batchId = existing.isEmpty ? UUID().uuidString : String(existing)
        } else { batchId = UUID().uuidString }
        let message = "[drawspeak-batch:\(batchId)]\n" + text
        guard message.utf16.count <= 120_000 else { throw .notSent(String(localized: "Message including its delivery marker must be at most 120,000 characters.", bundle: .module)) }
        try validate(attachments)
        var uploaded: [JSONValue] = []
        do {
            let snapshot = try await client.callTool(name: "t3_thread_read", arguments: .object(["threadId": .string(threadId), "limit": .number(1), "runLimit": .number(1)]))
            let thread = snapshot["thread"]
            guard !thread["archived"].bool else { throw DeliveryFailure.notSent(String(localized: "Unarchive the target thread before sending.", bundle: .module)) }
            await client.recordAttempt(T3DeliveryAttempt(batchId: batchId, threadId: threadId, activeRunId: thread["activeRunId"].string, latestRunId: thread["latestRunId"].string, status: thread["status"].string))
            let levels = ["read-only", "approval-required", "auto-accept-edits", "auto", "full-access"]
            if client.credentials.accessLevel == "read-only" { throw DeliveryFailure.notAuthorized }
            if let mode = thread["runtimeMode"].string, let required = levels.firstIndex(of: mode), let granted = levels.firstIndex(of: client.credentials.accessLevel), required > granted { throw DeliveryFailure.notSent(String(localized: "Pair with an access level that permits this thread's runtime mode.", bundle: .module)) }
            uploaded = try await upload(attachments, progress: progress)
        } catch MCPError.unauthorized { throw .notAuthorized }
        catch let failure as DeliveryFailure { throw failure }
        catch { throw .notSent(error.localizedDescription) }
        do {
            let ack = try await client.callTool(name: "t3_thread_send_attachments", arguments: .object(["threadId": .string(threadId), "message": .string(message), "attachments": .array(uploaded)]))
            guard let id = ack["messageId"].string else { throw MCPError.invalidResponse }
            if var attempt = await client.deliveryAttempt(threadId: threadId) {
                attempt.messageId = id; attempt.runId = ack["runId"].string; attempt.status = ack["status"].string
                await client.recordAttempt(attempt)
            }
            return MessageAck(messageId: id, acknowledgedAt: Date.now)
        } catch MCPError.unauthorized { throw .notAuthorized }
        catch MCPError.tool(_, let message) { throw .notSent(message) }
        catch MCPError.http(let status) where (400..<500).contains(status) { throw .notSent(String(localized: "T3 Code rejected the send (HTTP \(status)).", bundle: .module)) }
        catch { throw .outcomeUnknown }
    }
    /// Starts a new thread with one first message (`t3_thread_launch`). The batch marker
    /// `[drawspeak-batch:<clientRequestId>]` leads the message like a normal send. The
    /// server makes a repeated call with the same `clientRequestId` return the same thread.
    public func launchThread(projectId: String, title: String, text: String, attachments: [OutgoingAttachment], clientRequestId: String, progress: @Sendable (Int, Int) -> Void) async throws(DeliveryFailure) -> LaunchedThread {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !projectId.isEmpty, !title.isEmpty else { throw .notSent(String(localized: "Choose a project and a thread title.", bundle: .module)) }
        guard (1...256).contains(clientRequestId.count) else { throw .notSent(String(localized: "Invalid request id.", bundle: .module)) }
        guard attachments.count <= 8 else { throw .notSent(String(localized: "Attach at most 8 files.", bundle: .module)) }
        let marker = "[drawspeak-batch:\(clientRequestId)]"
        let message = text.hasPrefix(marker) ? text : marker + "\n" + text
        guard message.utf16.count <= 120_000 else { throw .notSent(String(localized: "Message including its delivery marker must be at most 120,000 characters.", bundle: .module)) }
        try validate(attachments)
        guard client.credentials.accessLevel != "read-only" else { throw .notAuthorized }
        let uploaded: [JSONValue]
        do { uploaded = try await upload(attachments, progress: progress) }
        catch MCPError.unauthorized { throw .notAuthorized }
        catch { throw .notSent(error.localizedDescription) }
        var args: [String: JSONValue] = ["projectId": .string(projectId), "title": .string(title), "message": .string(message), "clientRequestId": .string(clientRequestId)]
        if !uploaded.isEmpty { args["attachments"] = .array(uploaded) }
        let result: JSONValue
        do { result = try await client.callTool(name: "t3_thread_launch", arguments: .object(args)) }
        catch MCPError.unauthorized { throw .notAuthorized }
        catch MCPError.tool(_, let message) { throw .notSent(message) }
        catch MCPError.http(let status) where (400..<500).contains(status) { throw .notSent(String(localized: "T3 Code rejected the new thread (HTTP \(status)).", bundle: .module)) }
        catch { throw .outcomeUnknown }
        // The server accepted the launch; a reply we cannot read leaves the thread unknown.
        guard let launched = Self.launchedThread(from: result, requestedTitle: title) else { throw .outcomeUnknown }
        return launched
    }
    /// Accepts `threadId` at the top level or under `thread.threadId` / `thread.id`.
    static func launchedThread(from result: JSONValue, requestedTitle: String) -> LaunchedThread? {
        let thread = result["thread"]
        guard let id = [result["threadId"].string, thread["threadId"].string, thread["id"].string].compactMap({ $0 }).first(where: { !$0.isEmpty }) else { return nil }
        let title = [result["title"].string, thread["title"].string].compactMap { $0 }.first { !$0.isEmpty } ?? requestedTitle
        let messageId = result["messageId"].string ?? result["message"]["messageId"].string ?? thread["messageId"].string
        return LaunchedThread(threadId: id, title: title, messageId: messageId)
    }
    private func validate(_ attachments: [OutgoingAttachment]) throws(DeliveryFailure) {
        for file in attachments {
            let image = file.contentType.hasPrefix("image/")
            guard !file.data.isEmpty, file.data.count <= (image ? 10_485_760 : 52_428_800) else { throw .notSent(String(localized: "\(file.fileName) exceeds the \(image ? "10" : "50") MiB limit or is empty.", bundle: .module)) }
            guard (1...255).contains(file.fileName.count), (1...100).contains(file.contentType.count) else { throw .notSent(String(localized: "Invalid attachment name or MIME type.", bundle: .module)) }
            guard !image || ["image/png", "image/jpeg", "image/gif", "image/webp"].contains(file.contentType) else { throw .notSent(String(localized: "Unsupported image type: \(file.contentType).", bundle: .module)) }
        }
    }
    /// Prepares and uploads each file in order; returns the attachment descriptors for the message.
    private func upload(_ attachments: [OutgoingAttachment], progress: @Sendable (Int, Int) -> Void) async throws -> [JSONValue] {
        var uploaded: [JSONValue] = []
        for (index, file) in attachments.enumerated() {
            let type = file.contentType.hasPrefix("image/") ? "image" : "file"
            var descriptor: [String: JSONValue] = ["type": .string(type), "name": .string(file.fileName), "mimeType": .string(file.contentType), "sizeBytes": .number(Double(file.data.count))]
            let prepared = try await client.callTool(name: "t3_attachment_prepare_upload", arguments: .object(["upload": .object(descriptor)]))
            guard let id = prepared["attachmentId"].string, let relative = prepared["relativeUrl"].string else { throw MCPError.invalidResponse }
            try await client.upload(data: file.data, relativeURL: relative, contentType: file.contentType)
            descriptor["id"] = .string(id); uploaded.append(.object(descriptor)); progress(index + 1, attachments.count)
        }
        return uploaded
    }
    /// Read-only reconciliation; nil means no evidence was found, not proof of non-delivery.
    public func reconcile(threadId: String, batchId: String) async throws -> MessageAck? {
        let marker = "[drawspeak-batch:\(batchId)]"
        var position: Int?
        var seenPositions = Set<Int>()
        while true {
            var args: [String: JSONValue] = ["threadId": .string(threadId), "view": .string("messages"), "limit": .number(100), "maxCharsPerItem": .number(50_000)]
            if let position { args["afterPosition"] = .number(Double(position)) }
            let page = try await client.callTool(name: "t3_thread_read", arguments: .object(args))
            if let item = page["items"].array.first(where: { $0["type"].string == "user_message" && $0["createdBy"].string == "agent" && $0["creationSource"].string == "mcp" && ($0["text"].string?.contains(marker) ?? false) }), let id = item["messageId"].string {
                return MessageAck(messageId: id, acknowledgedAt: Date.now)
            }
            guard page["hasMore"].bool else { break }
            guard let next = page["nextPosition"].int, seenPositions.insert(next).inserted else { throw MCPError.invalidResponse }; position = next
        }
        var cursor: Int?
        var seenCursors = Set<Int>()
        while true {
            var args: [String: JSONValue] = ["action": .string("list"), "threadId": .string(threadId), "limit": .number(100)]
            if let cursor { args["cursor"] = .number(Double(cursor)) }
            let page = try await client.callTool(name: "t3_queue", arguments: .object(args))
            if page["items"].array.contains(where: { $0["text"].string?.contains(marker) == true }) { return MessageAck(messageId: nil, acknowledgedAt: Date.now) }
            guard let next = page["nextCursor"].int else { break }
            guard seenCursors.insert(next).inserted else { throw MCPError.invalidResponse }
            cursor = next
        }
        return nil
    }
    public func downloadAttachment(threadId: String, attachment: ThreadAttachment) async throws -> Data { throw MCPError.unsupported }
    /// Display-only warning: sending to an active thread can steer the running agent.
    public func isThreadRunning(threadId: String) async -> Bool {
        guard let value = try? await client.callTool(name: "t3_thread_read", arguments: .object(["threadId": .string(threadId), "limit": .number(1), "runLimit": .number(1)])) else { return false }
        return ["running", "waiting", "preparing", "starting"].contains(value["thread"]["status"].string ?? "")
    }
    public func threadStatus(threadId: String) async throws -> String? {
        let value = try await client.callTool(name: "t3_thread_read", arguments: .object(["threadId": .string(threadId), "limit": .number(1), "runLimit": .number(1)]))
        return (value["thread"]["status"].string ?? value["recentRuns"].array.first?["status"].string)?.replacing("_", with: " ").capitalized
    }
    private func date(_ value: JSONValue) -> Date? {
        guard let string = value.string else { return nil }
        return (try? Date(string, strategy: .iso8601)) ?? (try? Date(string, strategy: .iso8601.time(includingFractionalSeconds: true)))
    }
}
