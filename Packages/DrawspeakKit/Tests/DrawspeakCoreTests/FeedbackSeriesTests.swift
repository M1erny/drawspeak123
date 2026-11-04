import DrawspeakCore
import Foundation
import Testing

/// One review larger than T3's eight attachments per message goes out as several messages.
@MainActor
@Suite("Feedback series (attachment limit)")
struct FeedbackSeriesTests {
    /// `count` image screens with one comment each.
    private func review(_ ws: Workspace, screens count: Int) throws -> Set<UUID> {
        var ids: Set<UUID> = []
        for index in 1...count {
            try addImage(ws, id: "s\(index)")
            ids.insert(addTextNote(ws, snapshotId: "s\(index)", text: "comment \(index)"))
        }
        return ids
    }

    private func package(_ ws: Workspace, _ ids: Set<UUID>, batchId: String = "ds-series") throws -> FeedbackPackage {
        FeedbackPackageBuilder.build(canvas: try #require(ws.currentCanvas), noteIds: ids, thread: testThread, batchId: batchId, now: fixedDate)
    }

    private func fakeAttachments(_ part: FeedbackPackage) -> [OutgoingAttachment] {
        (0..<FeedbackPackageSplitter.attachmentCount(of: part)).map {
            OutgoingAttachment(fileName: "\($0).png", contentType: "image/png", data: Data("png".utf8))
        }
    }

    @Test func smallReviewStaysOneUnchangedMessage() throws {
        let ws = makeWorkspace()
        let ids = try review(ws, screens: 7) // 7 composites + manifest = 8
        let original = try package(ws, ids)
        let parts = FeedbackPackageSplitter.split(original)
        #expect(parts == [original])
        #expect(parts[0].part == nil)
        #expect(!FeedbackPackageBuilder.messageText(for: parts[0]).contains("Message 1 of"))
    }

    @Test func twentyScreensSplitIntoMessagesOfAtMostEightAttachments() throws {
        let ws = makeWorkspace()
        let ids = try review(ws, screens: 20)
        let original = try package(ws, ids)
        #expect(FeedbackPackageSplitter.attachmentCount(of: original) == 21)

        let parts = FeedbackPackageSplitter.split(original)

        #expect(parts.count == 3)
        #expect(parts.allSatisfy { FeedbackPackageSplitter.attachmentCount(of: $0) <= FeedbackPackageSplitter.maxAttachmentsPerMessage })
        #expect(parts.map(\.groups.count) == [7, 7, 6])
        // Every comment is sent exactly once, in order, with its shown number.
        #expect(parts.flatMap(\.items).map(\.noteId) == original.items.map(\.noteId))
        #expect(parts.map(\.batchId) == ["ds-series-1", "ds-series-2", "ds-series-3"])
        #expect(parts.map { $0.part?.index } == [1, 2, 3])
        #expect(parts.allSatisfy { $0.part?.count == 3 && $0.part?.seriesId == "ds-series" })

        let first = FeedbackPackageBuilder.messageText(for: parts[0])
        let last = FeedbackPackageBuilder.messageText(for: parts[2])
        // Each part has its own exact marker first, for reconciliation.
        #expect(first.hasPrefix("[drawspeak-batch:ds-series-1] "))
        #expect(first.contains("Message 1 of 3"))
        #expect(first.contains("More messages of this series follow"))
        #expect(last.contains("This is the last message of the series"))

        let manifest = try JSONSerialization.jsonObject(with: try FeedbackManifest(package: parts[1]).jsonData()) as? [String: Any]
        #expect(manifest?["part"] as? Int == 2)
        #expect(manifest?["partCount"] as? Int == 3)
        #expect(manifest?["seriesId"] as? String == "ds-series")
        #expect((manifest?["snapshots"] as? [Any])?.count == 7)
    }

    @Test func htmlScreensCountTwoAttachments() throws {
        let ws = makeWorkspace()
        var ids: Set<UUID> = []
        for index in 1...4 {
            let snapshot = try ws.importArtifact(
                data: Data("<html><body>\(index)</body></html>".utf8), kind: .html, contentType: "text/html",
                fileName: "h\(index).html", pixelSize: (100, 200), viewport: Viewport(width: 50, height: 100, deviceScaleFactor: 2),
                target: .newScreen(title: "h\(index)"), renderPolicy: .staticNoScript
            )
            ids.insert(addTextNote(ws, snapshotId: snapshot.id, text: "html \(index)"))
        }
        let parts = FeedbackPackageSplitter.split(try package(ws, ids))
        // 4 × (PNG + HTML) + manifest = 9: three screens fit the first message.
        #expect(parts.map(\.groups.count) == [3, 1])
        #expect(parts.allSatisfy { FeedbackPackageSplitter.attachmentCount(of: $0) <= 8 })
    }

    @Test func seriesSendsEveryPartAndMarksAllNotesSent() async throws {
        let ws = makeWorkspace()
        let service = FakeThreadService()
        ws.threads = service
        let ids = try review(ws, screens: 18)
        let parts = FeedbackPackageSplitter.split(try package(ws, ids))
        #expect(parts.count == 3)

        let entries = try await ws.sendSeries(parts, canvasId: ws.currentCanvasId!) { fakeAttachments($0) }

        #expect(entries.map(\.state) == [.sent, .sent, .sent])
        #expect(entries.map { $0.part?.index } == [1, 2, 3])
        let sent = service.sentMessages.calls
        #expect(sent.count == 3)
        #expect(sent.allSatisfy { $0.hasPrefix("thread-1:") })
        #expect(sent.map { Int($0.split(separator: ":")[1])! } == [8, 8, 5])
        #expect(ids.allSatisfy { ws.note($0)?.isSentAtCurrentRevision == true })
        #expect(ws.feedbackScope()?.count == 0)
    }

    @Test func failedPartStopsTheSeriesAndRetryContinuesWithoutRepeats() async throws {
        let ws = makeWorkspace()
        var service = FakeThreadService()
        service.failSendsAfter = 1
        ws.threads = service
        let ids = try review(ws, screens: 15)
        let parts = FeedbackPackageSplitter.split(try package(ws, ids))
        #expect(parts.count == 3)

        let first = try await ws.sendSeries(parts, canvasId: ws.currentCanvasId!) { fakeAttachments($0) }

        // Part 1 arrived, part 2 failed, part 3 was not started.
        #expect(first.map(\.state) == [.sent, .failed(reason: "offline")])
        let firstIds = Set(parts[0].items.map(\.noteId))
        #expect(ids.filter { ws.note($0)?.isSentAtCurrentRevision == true } == firstIds)

        // The connection is back: continuing sends only parts 2 and 3.
        var healthy = FakeThreadService()
        healthy.sentMessages = service.sentMessages
        ws.threads = healthy
        let second = try await ws.sendSeries(parts, canvasId: ws.currentCanvasId!) { fakeAttachments($0) }

        #expect(second.map(\.state) == [.sent, .sent, .sent])
        let markers = service.sentMessages.calls.map { $0.split(separator: ":")[2] }
        #expect(markers.count == 3)
        #expect(markers.contains { $0.contains("ds-series-1]") })
        #expect(markers.contains { $0.contains("ds-series-2]") })
        #expect(markers.contains { $0.contains("ds-series-3]") })
        #expect(ids.allSatisfy { ws.note($0)?.isSentAtCurrentRevision == true })
    }

    @Test func unknownPartStopsUntilReconciled() async throws {
        let ws = makeWorkspace()
        ws.threads = FakeThreadService(sendFailure: .outcomeUnknown)
        let ids = try review(ws, screens: 10)
        let parts = FeedbackPackageSplitter.split(try package(ws, ids))

        let entries = try await ws.sendSeries(parts, canvasId: ws.currentCanvasId!) { fakeAttachments($0) }
        #expect(entries.map(\.state) == [.deliveryUnknown])

        // Calling again never resends a part that may have arrived.
        ws.threads = FakeThreadService()
        let again = try await ws.sendSeries(parts, canvasId: ws.currentCanvasId!) { fakeAttachments($0) }
        #expect(again.map(\.state) == [.deliveryUnknown])
    }

    @Test func newThreadSeriesLaunchesOnceAndSendsTheRestToIt() async throws {
        let ws = makeWorkspace(thread: nil)
        let service = FakeThreadService()
        ws.threads = service
        let ids = try review(ws, screens: 9)
        let placeholder = ThreadBinding(hostURL: testThread.hostURL, threadId: "", threadTitle: "Review", projectId: "proj-1", projectTitle: "Shop")
        let original = FeedbackPackageBuilder.build(canvas: try #require(ws.currentCanvas), noteIds: ids, thread: placeholder, batchId: "ds-new", now: fixedDate)
        let parts = FeedbackPackageSplitter.split(original)
        #expect(parts.count == 2)

        let entries = try await ws.sendSeries(
            parts, canvasId: ws.currentCanvasId!,
            newThread: Workspace.NewThreadRequest(projectId: "proj-1", projectTitle: "Shop", title: "Review")
        ) { fakeAttachments($0) }

        #expect(entries.map(\.state) == [.sent, .sent])
        #expect(service.log.calls.filter { $0.hasPrefix("launch:") } == ["launch:proj-1:Review:ds-new-1"])
        #expect(service.sentMessages.calls.count == 1)
        #expect(service.sentMessages.calls.first?.hasPrefix("new-thread-1:") == true)
        #expect(ws.currentCanvas?.thread?.threadId == "new-thread-1")
        #expect(ids.allSatisfy { ws.note($0)?.isSentAtCurrentRevision == true })
    }
}
