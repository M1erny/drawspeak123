import Foundation
import DrawspeakCore

nonisolated public struct T3ThreadService: ThreadService, Sendable {
    public let client: MCPClient
    public var hostURL: URL { client.credentials.hostURL }
    public init(client: MCPClient) { self.client = client }
    public func listThreads() async throws -> [ThreadSummary] {
        var threads: [ThreadSummary] = [], cursor: Int?
        var seenCursors = Set<Int>()
        while true {
            var args: [String: JSONValue] = ["allProjects": .bool(true), "includeSubagents": .bool(false), "limit": .number(100)]
            if let cursor { args["cursor"] = .number(Double(cursor)) }
            let page = try await client.callTool(name: "t3_thread_list", arguments: .object(args))
            for item in page["threads"].array {
                guard let id = item["threadId"].string else { throw MCPError.invalidResponse }
                if !threads.contains(where: { $0.id == id }) {
                    threads.append(ThreadSummary(id: id, title: item["title"].string ?? "Untitled thread", projectId: item["projectId"].string, projectTitle: item["projectTitle"].string, status: item["status"].string, updatedAt: date(item["updatedAt"])))
                }
            }
            guard let next = page["nextCursor"].int else { break }
            guard seenCursors.insert(next).inserted else { throw MCPError.invalidResponse }
            cursor = next
        }
        // The thread list schema has no project title; resolve titles from the project catalog.
        if threads.contains(where: { $0.projectId != nil && $0.projectTitle == nil }) {
            var titles: [String: String] = [:], projectCursor: Int?
            var seenProjectCursors = Set<Int>()
            while true {
                var args: [String: JSONValue] = ["limit": .number(100)]
                if let projectCursor { args["cursor"] = .number(Double(projectCursor)) }
                let page = try await client.callTool(name: "t3_project_list", arguments: .object(args))
                for project in page["projects"].array {
                    if let id = project["id"].string, let title = project["title"].string { titles[id] = title }
                }
                guard let next = page["nextCursor"].int else { break }
                guard seenProjectCursors.insert(next).inserted else { throw MCPError.invalidResponse }
                projectCursor = next
            }
            for index in threads.indices { if let id = threads[index].projectId { threads[index].projectTitle = threads[index].projectTitle ?? titles[id] } }
        }
        return threads
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
                    guard text.utf8.count < 2_097_152, let next = offset else { throw MCPError.tool(code: "message_too_large", message: "Message exceeds the 2 MiB reading limit.") }
                    let continuation = try await client.callTool(name: "t3_thread_read", arguments: .object(["threadId": .string(threadId), "itemId": .string(id), "textOffset": .number(Double(next)), "maxCharsPerItem": .number(50_000)]))
                    guard let chunk = continuation["items"].array.first(where: { $0["itemId"].string == id }), let part = chunk["text"].string, !part.isEmpty else { throw MCPError.invalidResponse }
                    text += part
                    truncated = chunk["textTruncated"].bool; offset = chunk["nextTextOffset"].int
                    guard !truncated || (offset ?? 0) > next else { throw MCPError.invalidResponse }
                }
                guard text.utf8.count <= 2_097_152 else { throw MCPError.tool(code: "message_too_large", message: "Message exceeds the 2 MiB reading limit.") }
                let messageId = item["messageId"].string ?? id
                if !result.contains(where: { $0.id == messageId }) { result.append(ThreadMessage(id: messageId, role: type == "user_message" ? "user" : "assistant", text: text, createdAt: date(item["createdAt"]) ?? date(item["updatedAt"]), attachments: [])) }
            }
            guard page["hasMore"].bool else { return result }
            guard let next = page["nextPosition"].int, next != position else { throw MCPError.invalidResponse }; position = next
        }
        throw MCPError.tool(code: "page_limit", message: "Thread exceeds the 10-page reading limit.")
    }
    public func send(threadId: String, text: String, attachments: [OutgoingAttachment], progress: @Sendable (Int, Int) -> Void) async throws(DeliveryFailure) -> MessageAck {
        guard (1...8).contains(attachments.count) else { throw .notSent("Attach between 1 and 8 files.") }
        let batchId: String
        if let range = text.range(of: "drawspeak-batch:") {
            let existing = text[range.upperBound...].prefix { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-" || $0 == "_") }
            batchId = existing.isEmpty ? UUID().uuidString : String(existing)
        } else { batchId = UUID().uuidString }
        let message = "[drawspeak-batch:\(batchId)]\n" + text
        guard message.utf16.count <= 120_000 else { throw .notSent("Message including its delivery marker must be at most 120,000 characters.") }
        for file in attachments {
            let image = file.contentType.hasPrefix("image/")
            guard !file.data.isEmpty, file.data.count <= (image ? 10_485_760 : 52_428_800) else { throw .notSent("\(file.fileName) exceeds the \(image ? "10" : "50") MiB limit or is empty.") }
            guard (1...255).contains(file.fileName.count), (1...100).contains(file.contentType.count) else { throw .notSent("Invalid attachment name or MIME type.") }
            guard !image || ["image/png", "image/jpeg", "image/gif", "image/webp"].contains(file.contentType) else { throw .notSent("Unsupported image type: \(file.contentType).") }
        }
        var uploaded: [JSONValue] = []
        do {
            let snapshot = try await client.callTool(name: "t3_thread_read", arguments: .object(["threadId": .string(threadId), "limit": .number(1), "runLimit": .number(1)]))
            let thread = snapshot["thread"]
            guard !thread["archived"].bool else { throw DeliveryFailure.notSent("Unarchive the target thread before sending.") }
            await client.recordAttempt(T3DeliveryAttempt(batchId: batchId, threadId: threadId, activeRunId: thread["activeRunId"].string, latestRunId: thread["latestRunId"].string, status: thread["status"].string))
            let levels = ["read-only", "approval-required", "auto-accept-edits", "auto", "full-access"]
            if client.credentials.accessLevel == "read-only" { throw DeliveryFailure.notAuthorized }
            if let mode = thread["runtimeMode"].string, let required = levels.firstIndex(of: mode), let granted = levels.firstIndex(of: client.credentials.accessLevel), required > granted { throw DeliveryFailure.notSent("Pair with an access level that permits this thread's runtime mode.") }
            for (index, file) in attachments.enumerated() {
                let type = file.contentType.hasPrefix("image/") ? "image" : "file"
                var descriptor: [String: JSONValue] = ["type": .string(type), "name": .string(file.fileName), "mimeType": .string(file.contentType), "sizeBytes": .number(Double(file.data.count))]
                let prepared = try await client.callTool(name: "t3_attachment_prepare_upload", arguments: .object(["upload": .object(descriptor)]))
                guard let id = prepared["attachmentId"].string, let relative = prepared["relativeUrl"].string else { throw MCPError.invalidResponse }
                try await client.upload(data: file.data, relativeURL: relative, contentType: file.contentType)
                descriptor["id"] = .string(id); uploaded.append(.object(descriptor)); progress(index + 1, attachments.count)
            }
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
            return MessageAck(messageId: id, acknowledgedAt: Date())
        } catch MCPError.unauthorized { throw .notAuthorized }
        catch MCPError.tool(_, let message) { throw .notSent(message) }
        catch MCPError.http(let status) where (400..<500).contains(status) { throw .notSent("T3 Code rejected the send (HTTP \(status)).") }
        catch { throw .outcomeUnknown }
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
                return MessageAck(messageId: id, acknowledgedAt: Date())
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
            if page["items"].array.contains(where: { $0["text"].string?.contains(marker) == true }) { return MessageAck(messageId: nil, acknowledgedAt: Date()) }
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
        return (value["thread"]["status"].string ?? value["recentRuns"].array.first?["status"].string)?.replacingOccurrences(of: "_", with: " ").capitalized
    }
    private func date(_ value: JSONValue) -> Date? {
        guard let string = value.string else { return nil }
        return (try? Date(string, strategy: .iso8601)) ?? (try? Date(string, strategy: .iso8601.time(includingFractionalSeconds: true)))
    }
}
