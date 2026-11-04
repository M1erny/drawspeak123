import Foundation
import Testing
import Synchronization
import DrawspeakCore
@testable import T3Kit

/// `assets.createUrl` stand-in: records resources, returns a fixed signed URL.
final class FakeAssetRPC: T3AssetRPC, Sendable {
    let resources = Mutex<[JSONValue]>([])
    let relativeURL: String
    let failure: T3FileError?
    init(relativeURL: String = "/api/assets/signed/file", failure: T3FileError? = nil) { self.relativeURL = relativeURL; self.failure = failure }
    func createAssetURL(resource: JSONValue) async throws -> String {
        resources.withLock { $0.append(resource) }
        if let failure { throw failure }
        return relativeURL
    }
    func close() async {}
}

/// Workspace file downloads. In the serialized suite: the URL stub is shared.
extension T3KitTests {
    @Test func workspaceResourceStaysInsideTheWorkspace() {
        let root = "/Users/me/Dev/apassy"
        #expect(T3WorkspaceFiles.resource(threadId: "t", path: root + "/output/a/x.html", worktree: nil, project: root)
            == .object(["_tag": .string("workspace-file"), "threadId": .string("t"), "path": .string("output/a/x.html")]))
        #expect(T3WorkspaceFiles.resource(threadId: "t", path: "output/s.png", worktree: nil, project: root)
            == .object(["_tag": .string("workspace-file"), "threadId": .string("t"), "path": .string("output/s.png")]))
        // T3 serves JSON only as an absolute media file; Drawspeak checks the root itself.
        #expect(T3WorkspaceFiles.resource(threadId: "t", path: "output/review-manifest.json", worktree: nil, project: root)
            == .object(["_tag": .string("media-file"), "threadId": .string("t"), "path": .string(root + "/output/review-manifest.json"), "disposition": .string("attachment")]))
        // A worktree thread serves from the worktree; the project checkout is reachable as a media file.
        #expect(T3WorkspaceFiles.resource(threadId: "t", path: root + "/output/x.html", worktree: "/wt/apassy-1", project: root)?["_tag"].string == "media-file")
        #expect(T3WorkspaceFiles.resource(threadId: "t", path: "/wt/apassy-1/out/x.html", worktree: "/wt/apassy-1", project: root)?["path"].string == "out/x.html")
        for outside in ["/Users/me/Dev/drawspeak/a.html", "/Users/me/Dev/apassy-old/a.html", root + "/../drawspeak/a.html", "../a.html", "/etc/passwd"] {
            #expect(T3WorkspaceFiles.resource(threadId: "t", path: outside, worktree: nil, project: root) == nil, "\(outside)")
        }
    }

    @Test(arguments: ["ok", "traversal", "tooLarge", "otherHost", "notFound", "notPaired"])
    func downloadWorkspaceFile(_ scenario: String) async throws {
        let page = Data("<!doctype html><html></html>".utf8)
        let session = StubProtocol.session { request in
            if request.url!.path.hasPrefix("/api/assets/") {
                #expect(request.value(forHTTPHeaderField: "Authorization") == nil, "the signed URL is the capability")
                if scenario == "notFound" { return (404, [:], Data()) }
                return (200, ["Content-Type": "text/html"], scenario == "tooLarge" ? Data(count: PulledBundleReader.maxRemoteFileBytes + 1) : page)
            }
            let body = try Self.body(request)
            if let reply = try Self.handshake(request, body) { return reply }
            let content: JSONValue = switch body["params"]["name"].string {
            case "t3_thread_read": .object(["thread": .object(["projectId": .string("p1"), "worktreePath": .null])])
            case "t3_project_read": .object(["id": .string("p1"), "workspaceRoot": .string("/Users/me/Dev/apassy")])
            default: .null
            }
            return try Self.rpc(body, result: .object(["structuredContent": content]))
        }
        let rpc = FakeAssetRPC(relativeURL: scenario == "otherHost" ? "https://evil.test/api/assets/x/y" : "/api/assets/signed/ios-setup.html")
        let client = MCPClient(credentials: credential(), session: session)
        let files = scenario == "notPaired" ? nil : T3WorkspaceFiles(origin: host, rpc: rpc, session: session)
        let service = T3ThreadService(client: client, files: files)
        let path = scenario == "traversal" ? "/Users/me/Dev/apassy/../drawspeak/secret.html" : "/Users/me/Dev/apassy/output/prototypes/a/ios-setup.html"
        do {
            let data = try await service.downloadWorkspaceFile(threadId: "thread", path: path)
            #expect(scenario == "ok"); #expect(data == page)
            #expect(rpc.resources.withLock { $0 } == [.object(["_tag": .string("workspace-file"), "threadId": .string("thread"), "path": .string("output/prototypes/a/ios-setup.html")])])
        } catch let error as T3FileError {
            let expected: [String: T3FileError] = ["traversal": .outsideWorkspace, "tooLarge": .tooLarge, "otherHost": .invalidResponse, "notFound": .notFound]
            #expect(expected[scenario] == error)
            if scenario == "traversal" { #expect(rpc.resources.withLock { $0 }.isEmpty) }
        } catch let error as WorkspaceFileUnavailable {
            #expect(scenario == "notPaired"); #expect(!error.message.isEmpty)
        }
    }

    @Test func assetFailuresMapToReasons() {
        #expect(T3WebSocketAssetRPC.failure(.object(["_tag": .string("AssetWorkspacePathValidationError")])) == .outsideWorkspace)
        #expect(T3WebSocketAssetRPC.failure(.object(["_tag": .string("AssetPreviewTypeValidationError")])) == .typeNotAllowed)
        #expect(T3WebSocketAssetRPC.failure(.object(["_tag": .string("AssetWorkspaceAssetNotFoundError")])) == .notFound)
        #expect(T3WebSocketAssetRPC.failure(.object(["_tag": .string("EnvironmentScopeRequiredError")])) == .unauthorized)
    }

    @Test func oldCredentialsDecodeWithoutAFilesToken() throws {
        let old = #"{"hostURL":"https://fake.test","clientId":"c","accessToken":"t","scope":"s","expiresAt":0,"accessLevel":"full-access"}"#
        let decoded = try JSONDecoder().decode(T3Credentials.self, from: Data(old.utf8))
        #expect(decoded.filesToken == nil); #expect(decoded.usableFilesToken == nil)
        var expired = decoded; expired.filesToken = "f"; expired.filesTokenExpiresAt = .distantPast
        #expect(expired.usableFilesToken == nil)
    }
}
