import DrawspeakCore
import Foundation
import Synchronization
import Testing

final class StateBox: Sendable {
    private let storage = Mutex<DeliveryState?>(nil)
    func set(_ value: DeliveryState?) { storage.withLock { $0 = value } }
    var value: DeliveryState? { storage.withLock { $0 } }
}

@MainActor
@Suite("Durable send, host identity and reconciliation (F02, F03, F04)")
struct DeliveryDurabilityTests {
    private let otherHost = URL(string: "https://other.example.com")!

    @Test func entryIsDurablyCheckpointedBeforeTheMessageRequest() async throws {
        let root = makeTempRoot()
        let ws = makeWorkspace(root: root)
        let atSend = StateBox()
        ws.threads = FakeThreadService(onSend: { atSend.set(persistedOutboxState(root: root, batchId: "ds-test-1")) })
        try addImage(ws, id: "s1")
        let id = addTextNote(ws, snapshotId: "s1", text: "durable")

        let result = await sendNotes(ws, noteIds: [id])

        #expect(atSend.value == .uploading(done: 0, total: 1))
        #expect(result.entry?.state == .sent)
        // Sent is saved immediately, not after the debounce.
        #expect(persistedOutboxState(root: root, batchId: "ds-test-1") == .sent)
    }

    @Test func checkpointSaveFailureNeverSends() async throws {
        let root = makeTempRoot()
        let ws = makeWorkspace(root: root)
        // A directory where the library file belongs makes every save fail.
        try FileManager.default.createDirectory(at: StorageLocations(root: root).libraryFile, withIntermediateDirectories: true)
        let log = CallLog()
        ws.threads = FakeThreadService(log: log)
        try addImage(ws, id: "s1")
        let id = addTextNote(ws, snapshotId: "s1", text: "x")

        let result = await sendNotes(ws, noteIds: [id])

        guard case .failed(let reason) = result.entry?.state else {
            Issue.record("Expected failed, got \(String(describing: result.entry?.state))")
            return
        }
        #expect(reason.hasPrefix("Could not save"))
        #expect(!log.calls.contains("send"))
        #expect(ws.note(id)?.lastSentRevision == nil)
    }

    @Test func sentEntryIsNeverReplacedByAnotherSendWithTheSameBatchId() async throws {
        let ws = makeWorkspace()
        let log = CallLog()
        ws.threads = FakeThreadService(log: log)
        try addImage(ws, id: "s1")
        let id = addTextNote(ws, snapshotId: "s1", text: "once")
        _ = await sendNotes(ws, noteIds: [id])
        let again = await sendNotes(ws, noteIds: [id])
        #expect(again.entry?.state == .sent)
        #expect(log.calls.filter { $0 == "send" }.count == 1)
    }

    @Test func hostMismatchFailsSendWithoutCallingTheService() async throws {
        let ws = makeWorkspace()
        let log = CallLog()
        ws.threads = FakeThreadService(hostURL: otherHost, log: log)
        try addImage(ws, id: "s1")
        let id = addTextNote(ws, snapshotId: "s1", text: "x")

        let result = await sendNotes(ws, noteIds: [id])

        #expect(result.entry?.state == .failed(reason: "Connected to other.example.com, but this canvas belongs to t3.example.com"))
        #expect(log.calls.isEmpty)
    }

    @Test func hostMismatchBlocksReconcilePullAndStatus() async throws {
        let ws = makeWorkspace()
        ws.threads = FakeThreadService(sendFailure: .outcomeUnknown)
        try addImage(ws, id: "s1")
        let id = addTextNote(ws, snapshotId: "s1", text: "x")
        _ = await sendNotes(ws, noteIds: [id], batchId: "ds-host")
        let canvasId = try #require(ws.currentCanvasId)

        let log = CallLog()
        ws.threads = FakeThreadService(hostURL: otherHost, reconcileResult: .found(MessageAck(messageId: "m", acknowledgedAt: fixedDate)), log: log)
        #expect(await ws.reconcile(batchId: "ds-host", canvasId: canvasId) == .unavailable)
        #expect(ws.currentCanvas?.outbox.first?.state == .deliveryUnknown)
        let report = await ws.pull(canvasId: canvasId) { _, _, _ in throw CancellationError() }
        #expect(report.issues == ["Connected to other.example.com, but this canvas belongs to t3.example.com"])
        await ws.refreshAgentStatus(canvasId: canvasId)
        #expect(log.calls.isEmpty)
    }

    @Test func hostIdentityIgnoresCaseDefaultPortAndTrailingSlash() {
        #expect(HostIdentity.matches(URL(string: "https://t3.example.com/")!, URL(string: "HTTPS://T3.Example.com:443")!))
        #expect(!HostIdentity.matches(URL(string: "https://t3.example.com")!, URL(string: "https://t3.example.com:8443")!))
        #expect(!HostIdentity.matches(URL(string: "http://t3.example.com")!, URL(string: "https://t3.example.com")!))
        #expect(HostIdentity.displayName(URL(string: "https://t3.example.com:8443/")!) == "t3.example.com:8443")
    }

    @Test func rebindingComparesHostAndThread() async throws {
        let ws = makeWorkspace()
        ws.threads = FakeThreadService()
        try addImage(ws, id: "s1")
        let id = addTextNote(ws, snapshotId: "s1", text: "x")
        _ = await sendNotes(ws, noteIds: [id])
        let canvasId = try #require(ws.currentCanvasId)

        var sameThreadOtherHost = testThread
        sameThreadOtherHost.hostURL = otherHost
        #expect(!ws.bindThread(sameThreadOtherHost, to: canvasId))
        var sameWithSlash = testThread
        sameWithSlash.hostURL = URL(string: "https://t3.example.com/")!
        #expect(ws.bindThread(sameWithSlash, to: canvasId))
    }

    @Test func reconcileErrorKeepsDeliveryUnknown() async throws {
        let ws = makeWorkspace()
        ws.threads = FakeThreadService(sendFailure: .outcomeUnknown)
        try addImage(ws, id: "s1")
        let id = addTextNote(ws, snapshotId: "s1", text: "x")
        _ = await sendNotes(ws, noteIds: [id], batchId: "ds-err")
        let canvasId = try #require(ws.currentCanvasId)

        ws.threads = FakeThreadService(reconcileResult: .fails)
        #expect(await ws.reconcile(batchId: "ds-err", canvasId: canvasId) == .unavailable)
        #expect(ws.currentCanvas?.outbox.first?.state == .deliveryUnknown)
        #expect(ws.note(id)?.lastSentRevision == nil)
    }

    @Test func reconcileUsesTheServiceAndPersistsSentImmediately() async throws {
        let root = makeTempRoot()
        let ws = makeWorkspace(root: root)
        ws.threads = FakeThreadService(sendFailure: .outcomeUnknown)
        try addImage(ws, id: "s1")
        let id = addTextNote(ws, snapshotId: "s1", text: "x")
        _ = await sendNotes(ws, noteIds: [id], batchId: "ds-ok")
        #expect(persistedOutboxState(root: root, batchId: "ds-ok") == .deliveryUnknown)
        let canvasId = try #require(ws.currentCanvasId)

        let log = CallLog()
        ws.threads = FakeThreadService(reconcileResult: .found(MessageAck(messageId: "m-7", acknowledgedAt: fixedDate)), log: log)
        #expect(await ws.reconcile(batchId: "ds-ok", canvasId: canvasId) == .found)
        #expect(log.calls == ["reconcile"])
        #expect(persistedOutboxState(root: root, batchId: "ds-ok") == .sent)
        #expect(ws.currentCanvas?.outbox.first?.receipt?.messageId == "m-7")
    }
}
