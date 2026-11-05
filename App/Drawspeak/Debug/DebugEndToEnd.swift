#if DEBUG && targetEnvironment(simulator)
import DrawspeakCore
import FeedbackKit
import Foundation
import T3Kit

/// Simulator-only end-to-end hook. It runs the same workspace paths as the
/// Feedback and Pull buttons against a real T3 thread and writes a JSON report
/// to Documents/e2e-result.json.
///
/// Environment (or launch arguments `-KEY value`): DRAWSPEAK_E2E_THREAD=<threadId>, DRAWSPEAK_E2E_ACTION=send|pull;
/// or DRAWSPEAK_E2E_ACTION=sendNew with DRAWSPEAK_E2E_PROJECT=<projectId>, which sends the
/// ready notes of a canvas without a thread to a new thread "Drawspeak E2E new thread".
@MainActor
enum DebugEndToEnd {
    /// An environment variable, or the same key passed as a launch argument (`-KEY value`),
    /// for launchers that cannot set the environment.
    static func setting(_ key: String) -> String? {
        ProcessInfo.processInfo.environment[key] ?? UserDefaults.standard.volatileDomain(forName: UserDefaults.argumentDomain)[key] as? String
    }

    static func runIfRequested(workspace: Workspace, connection: T3Connection) async {
        let keys = ["DRAWSPEAK_E2E_ACTION", "DRAWSPEAK_E2E_PROJECT", "DRAWSPEAK_E2E_THREAD"]
        let environment = Dictionary(uniqueKeysWithValues: keys.compactMap { key in setting(key).map { (key, $0) } })
        if environment["DRAWSPEAK_E2E_ACTION"] == "sendNew" {
            guard let projectId = environment["DRAWSPEAK_E2E_PROJECT"], !projectId.isEmpty else { return }
            await sendToNewThread(workspace: workspace, connection: connection, projectId: projectId)
            return
        }
        guard let threadId = environment["DRAWSPEAK_E2E_THREAD"], !threadId.isEmpty,
              let action = environment["DRAWSPEAK_E2E_ACTION"], let canvasId = workspace.currentCanvasId else { return }
        var report: [String: String] = ["action": action, "threadId": threadId]
        defer { write(report) }
        guard connection.threadService != nil else {
            report["error"] = "not connected"
            return
        }
        let binding = ThreadBinding(hostURL: connection.hostURL, threadId: threadId, threadTitle: "Drawspeak E2E", projectId: nil, projectTitle: nil)
        report["bound"] = String(workspace.bindThread(binding, to: canvasId))
        switch action {
        case "send":
            guard let canvas = workspace.currentCanvas, let scope = workspace.feedbackScope(canvasId: canvasId), !scope.ready.isEmpty else {
                report["error"] = "no ready notes"
                return
            }
            let package = FeedbackPackageBuilder.build(
                canvas: canvas, noteIds: Set(scope.ready.map(\.id)), thread: binding,
                batchId: Workspace.newBatchId(now: .now), now: .now
            )
            do {
                // A review over T3's eight attachments per message goes out as several messages.
                let parts = FeedbackPackageSplitter.split(package)
                let blobs = workspace.blobs
                let entries = try await workspace.sendSeries(parts, canvasId: canvasId) { part in
                    try await FeedbackPayloadBuilder.attachments(for: part, blobs: blobs)
                }
                report["batchId"] = package.batchId
                report["messages"] = String(parts.count)
                report["attachments"] = parts.map { String(FeedbackPackageSplitter.attachmentCount(of: $0)) }.joined(separator: ", ")
                report["state"] = entries.map { "\($0.state)" }.joined(separator: ", ")
                report["messageId"] = entries.compactMap { $0.receipt?.messageId }.joined(separator: ", ")
            } catch {
                report["error"] = "\(error)"
            }
        case "pull":
            let result = await workspace.pull(canvasId: canvasId, captureHTML: HTMLCaptureAdapter.capture)
            report["imported"] = String(result.importedSnapshots)
            report["issues"] = result.issues.joined(separator: " | ")
            report["messagesChecked"] = String(result.messagesChecked)
            report["noVersionsReason"] = result.noVersionsReason ?? ""
            if let canvas = workspace.canvas(canvasId) {
                report["snapshots"] = canvas.snapshots.map { "\($0.screenId)/\($0.proposalId ?? "baseline")#\($0.iteration) \($0.kind.rawValue) \($0.widthPx)x\($0.heightPx)\($0.image == nil ? " no-capture" : "")" }.joined(separator: " | ")
            }
        default:
            report["error"] = "unknown action"
        }
    }

    private static func sendToNewThread(workspace: Workspace, connection: T3Connection, projectId: String) async {
        var report: [String: String] = ["action": "sendNew", "projectId": projectId]
        defer { write(report) }
        guard connection.threadService != nil else {
            report["error"] = "not connected"
            return
        }
        // One canvas belongs to one thread: use the current canvas if it has none, else another one.
        let unbound = workspace.document.canvases.filter { $0.thread == nil }
        let candidates = unbound.filter { $0.id == workspace.currentCanvasId } + unbound.filter { $0.id != workspace.currentCanvasId }
        guard let canvas = candidates.first(where: { !(workspace.feedbackScope(canvasId: $0.id)?.ready.isEmpty ?? true) }),
              let scope = workspace.feedbackScope(canvasId: canvas.id) else {
            report["error"] = "no canvas without a thread has ready notes"
            return
        }
        let title = "Drawspeak E2E new thread"
        let placeholder = ThreadBinding(hostURL: connection.hostURL, threadId: "", threadTitle: title, projectId: projectId, projectTitle: nil)
        let package = FeedbackPackageBuilder.build(
            canvas: canvas, noteIds: Set(scope.ready.map(\.id)), thread: placeholder,
            batchId: Workspace.newBatchId(now: .now), now: .now
        )
        report["canvas"] = canvas.title
        report["batchId"] = package.batchId
        do {
            let parts = FeedbackPackageSplitter.split(package)
            let blobs = workspace.blobs
            let entries = try await workspace.sendSeries(
                parts, canvasId: canvas.id, newThread: Workspace.NewThreadRequest(projectId: projectId, projectTitle: nil, title: title)
            ) { part in try await FeedbackPayloadBuilder.attachments(for: part, blobs: blobs) }
            report["messages"] = String(parts.count)
            report["state"] = entries.map { "\($0.state)" }.joined(separator: ", ")
            report["threadId"] = workspace.canvas(canvas.id)?.thread?.threadId ?? ""
            report["messageId"] = entries.compactMap { $0.receipt?.messageId }.joined(separator: ", ")
        } catch {
            report["error"] = "\(error)"
        }
    }

    private static func write(_ report: [String: String]) {
        guard let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first,
              let data = try? JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]) else { return }
        try? data.write(to: directory.appending(path: "e2e-result.json"))
    }
}
#endif
