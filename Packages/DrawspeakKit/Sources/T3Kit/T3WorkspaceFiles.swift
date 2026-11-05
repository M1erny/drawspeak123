import DrawspeakCore
import Foundation

/// Why a workspace file could not be downloaded.
nonisolated public enum T3FileError: Error, Sendable, Equatable, LocalizedError {
    case notPaired, unauthorized, outsideWorkspace, notFound, typeNotAllowed, tooLarge, timeout, invalidResponse
    case rejected(String)
    public var errorDescription: String? {
        switch self {
        case .notPaired: String(localized: "Pair with T3 Code again so Drawspeak can download files the agent saved on the Mac.", bundle: .module)
        case .unauthorized: String(localized: "T3 Code no longer accepts Drawspeak's file access. Pair again.", bundle: .module)
        case .outsideWorkspace: String(localized: "The file is outside the thread's project folder. Ask the agent to save it inside the project, then pull again.", bundle: .module)
        case .notFound: String(localized: "The file does not exist on the Mac.", bundle: .module)
        case .typeNotAllowed: String(localized: "T3 Code does not serve this file type.", bundle: .module)
        case .tooLarge: String(localized: "The file exceeds the 10 MiB limit.", bundle: .module)
        case .timeout: String(localized: "T3 Code did not answer in time.", bundle: .module)
        case .invalidResponse: String(localized: "T3 Code returned an invalid response.", bundle: .module)
        case .rejected(let reason): reason
        }
    }
}

/// The Effect RPC call Drawspeak needs on T3 Code's `/ws`: `assets.createUrl`.
nonisolated public protocol T3AssetRPC: Sendable {
    /// Returns the signed relative URL (`/api/assets/<token>/<name>`, valid one hour).
    func createAssetURL(resource: JSONValue) async throws -> String
    func close() async
}

/// `wss://<host>/ws?orchestrationProtocol=2` with `Authorization: Bearer <files token>`.
/// Frames are JSON Effect RPC messages: `{"_tag":"Request","id","tag","payload","headers":[]}`
/// out, `{"_tag":"Exit","requestId","exit":{"_tag":"Success","value"}|{"_tag":"Failure","cause"}}` in.
public actor T3WebSocketAssetRPC: T3AssetRPC {
    private let url: URL
    private let token: String
    private let session: URLSession
    private var task: URLSessionWebSocketTask?
    private var nextId = 0
    private var pending: [String: CheckedContinuation<JSONValue, any Error>] = [:]

    public init(origin: URL, token: String, session: URLSession) {
        var parts = URLComponents(url: origin.appending(path: "ws"), resolvingAgainstBaseURL: false)!
        parts.scheme = parts.scheme == "http" ? "ws" : "wss"
        parts.queryItems = [URLQueryItem(name: "orchestrationProtocol", value: "2")]
        self.url = parts.url!; self.token = token; self.session = session
    }

    public func createAssetURL(resource: JSONValue) async throws -> String {
        let value = try await call(tag: "assets.createUrl", payload: .object(["resource": resource]))
        guard let relative = value["relativeUrl"].string else { throw T3FileError.invalidResponse }
        return relative
    }

    public func close() {
        task?.cancel(with: .normalClosure, reason: nil); task = nil
    }

    private func connection() -> URLSessionWebSocketTask {
        if let task, task.state == .running { return task }
        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        request.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        let task = session.webSocketTask(with: request)
        task.maximumMessageSize = 4 * 1024 * 1024
        self.task = task
        task.resume()
        Task { await self.receive(on: task) }
        return task
    }

    private func receive(on task: URLSessionWebSocketTask) async {
        while true {
            let message: URLSessionWebSocketTask.Message
            do { message = try await task.receive() } catch {
                let status = (task.response as? HTTPURLResponse)?.statusCode
                let failure: T3FileError = status == 401 || status == 403 ? .unauthorized : .rejected(String(localized: "The file connection to T3 Code closed.", bundle: .module))
                if self.task === task { self.task = nil }
                for continuation in pending.values { continuation.resume(throwing: failure) }
                pending.removeAll()
                return
            }
            let data: Data
            switch message {
            case .string(let text): data = Data(text.utf8)
            case .data(let bytes): data = bytes
            @unknown default: continue
            }
            guard let decoded = try? JSONDecoder().decode(JSONValue.self, from: data) else { continue }
            let frames = if case .array(let list) = decoded { list } else { [decoded] }
            for frame in frames { handle(frame, on: task) }
        }
    }

    private func handle(_ frame: JSONValue, on task: URLSessionWebSocketTask) {
        switch frame["_tag"].string {
        case "Ping":
            task.send(.string("{\"_tag\":\"Pong\"}")) { _ in }
        case "Exit":
            guard let id = frame["requestId"].string, let continuation = pending.removeValue(forKey: id) else { return }
            let exit = frame["exit"]
            if exit["_tag"].string == "Success" { continuation.resume(returning: exit["value"]); return }
            let error = exit["cause"].array.first { $0["_tag"].string == "Fail" }?["error"] ?? .null
            continuation.resume(throwing: Self.failure(error))
        case "Defect":
            for continuation in pending.values { continuation.resume(throwing: T3FileError.invalidResponse) }
            pending.removeAll()
        default: return
        }
    }

    nonisolated static func failure(_ error: JSONValue) -> T3FileError {
        switch error["_tag"].string {
        case "AssetWorkspacePathValidationError": .outsideWorkspace
        case "AssetWorkspaceAssetNotFoundError", "AssetWorkspaceContextNotFoundError": .notFound
        case "AssetPreviewTypeValidationError": .typeNotAllowed
        case "EnvironmentScopeRequiredError", "EnvironmentAuthorizationError": .unauthorized
        default: .rejected(error["message"].string ?? String(localized: "T3 Code refused the file (\(error["_tag"].string ?? "unknown")).", bundle: .module))
        }
    }

    private func call(tag: String, payload: JSONValue) async throws -> JSONValue {
        let task = connection()
        nextId += 1
        let id = String(nextId)
        defer { scheduleIdleClose(after: nextId) }
        let frame = JSONValue.object(["_tag": .string("Request"), "id": .string(id), "tag": .string(tag), "payload": payload, "headers": .array([])])
        let text = String(decoding: try JSONEncoder().encode(frame), as: UTF8.self)
        return try await withCheckedThrowingContinuation { continuation in
            pending[id] = continuation
            task.send(.string(text)) { error in
                guard let error else { return }
                Task { await self.fail(id, with: error) }
            }
            Task { [weak self] in
                try? await Task.sleep(for: .seconds(30))
                await self?.fail(id, with: T3FileError.timeout)
            }
        }
    }

    /// Closes the socket 20 s after the last call so an idle connection is not kept open.
    private func scheduleIdleClose(after id: Int) {
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(20))
            await self?.closeIfIdle(since: id)
        }
    }

    private func closeIfIdle(since id: Int) {
        guard nextId == id, pending.isEmpty else { return }
        close()
    }

    private func fail(_ id: String, with error: any Error) {
        pending.removeValue(forKey: id)?.resume(throwing: error)
    }
}

/// Downloads files from a thread's workspace: resolves the thread's workspace root over
/// MCP, checks the path, mints a signed URL over `/ws` and GETs it (no credential needed).
nonisolated public final class T3WorkspaceFiles: Sendable {
    /// File types T3 Code serves as `workspace-file` (inside the thread workspace, checked by the server).
    static let previewExtensions: Set<String> = ["html", "htm", "pdf", "png", "jpg", "jpeg", "gif", "webp"]
    let origin: URL
    let rpc: any T3AssetRPC
    let session: URLSession
    private let roots = RootCache()

    public init(origin: URL, rpc: any T3AssetRPC, session: URLSession) {
        self.origin = origin; self.rpc = rpc; self.session = session
    }

    actor RootCache {
        var values: [String: (worktree: String?, project: String?)] = [:]
        func get(_ id: String) -> (worktree: String?, project: String?)? { values[id] }
        func set(_ id: String, _ value: (worktree: String?, project: String?)) { values[id] = value }
    }

    func roots(threadId: String, client: MCPClient) async throws -> (worktree: String?, project: String?) {
        if let cached = await roots.get(threadId) { return cached }
        let snapshot = try await client.callTool(name: "t3_thread_read", arguments: .object(["threadId": .string(threadId), "limit": .number(1), "runLimit": .number(1)]))
        let thread = snapshot["thread"]
        var project: String?
        if let projectId = thread["projectId"].string {
            let value = try await client.callTool(name: "t3_project_read", arguments: .object(["projectId": .string(projectId)]))
            project = value["workspaceRoot"].string ?? value["project"]["workspaceRoot"].string
        }
        let result = (worktree: thread["worktreePath"].string, project: project)
        await roots.set(threadId, result)
        return result
    }

    /// The `assets.createUrl` resource for `path`, or nil when it is outside every workspace root.
    /// HTML and images use `workspace-file` (the server checks the root and symlinks again);
    /// other types (the JSON manifest) use `media-file` with an absolute path checked here.
    static func resource(threadId: String, path: String, worktree: String?, project: String?) -> JSONValue? {
        let serving = worktree ?? project
        let previewable = previewExtensions.contains(WorkspaceFilePath.fileExtension(path))
        if previewable, let serving, let relative = WorkspaceFilePath.relative(path, root: serving) {
            return .object(["_tag": .string("workspace-file"), "threadId": .string(threadId), "path": .string(relative)])
        }
        for root in [serving, project].compactMap({ $0 }) {
            guard let relative = WorkspaceFilePath.relative(path, root: root) else { continue }
            let base = root.hasSuffix("/") ? String(root.dropLast()) : root
            return .object(["_tag": .string("media-file"), "threadId": .string(threadId), "path": .string(base + "/" + relative), "disposition": .string("attachment")])
        }
        return nil
    }

    func download(threadId: String, path: String, client: MCPClient) async throws -> Data {
        guard WorkspaceFilePath.isAcceptable(path) else { throw T3FileError.outsideWorkspace }
        let roots = try await roots(threadId: threadId, client: client)
        guard roots.worktree != nil || roots.project != nil else { throw T3FileError.notFound }
        guard let resource = Self.resource(threadId: threadId, path: path, worktree: roots.worktree, project: roots.project) else { throw T3FileError.outsideWorkspace }
        let relative = try await rpc.createAssetURL(resource: resource)
        guard relative.hasPrefix("/api/assets/"), let url = URL(string: relative, relativeTo: origin)?.absoluteURL,
              url.host == origin.host, url.scheme == origin.scheme else { throw T3FileError.invalidResponse }
        var request = URLRequest(url: url)
        request.timeoutInterval = 60; request.httpShouldHandleCookies = false
        let (bytes, response) = try await session.bytes(for: request)
        guard let http = response as? HTTPURLResponse else { throw T3FileError.invalidResponse }
        guard http.statusCode == 200 else { throw http.statusCode == 404 ? T3FileError.notFound : T3FileError.rejected(String(localized: "T3 Code returned HTTP \(http.statusCode).", bundle: .module)) }
        let limit = PulledBundleReader.maxRemoteFileBytes
        guard http.expectedContentLength <= Int64(limit) else { throw T3FileError.tooLarge }
        var data = Data()
        if http.expectedContentLength > 0 { data.reserveCapacity(Int(http.expectedContentLength)) }
        for try await byte in bytes {
            data.append(byte)
            if data.count > limit { throw T3FileError.tooLarge }
        }
        return data
    }
}
