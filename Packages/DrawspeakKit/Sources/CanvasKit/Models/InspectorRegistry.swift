import DrawspeakCore
import HTMLKit

/// One `DOMInspector` per HTML card on screen, and the render hash of each
/// HTML snapshot, read once and reused for every selection on it.
final class InspectorRegistry {
    private var inspectors: [String: DOMInspector] = [:]
    private var renderHashes: [String: Task<String, any Error>] = [:]

    /// The inspector for a card. A snapshot shown in two lanes (for example a
    /// promoted proposal) has one inspector per lane.
    func inspector(slotId: String, snapshotId: String) -> DOMInspector {
        let key = Self.key(slotId: slotId, snapshotId: snapshotId)
        if let inspector = inspectors[key] { return inspector }
        let inspector = DOMInspector()
        inspectors[key] = inspector
        return inspector
    }

    func existingInspector(slotId: String, snapshotId: String) -> DOMInspector? {
        inspectors[Self.key(slotId: slotId, snapshotId: snapshotId)]
    }

    /// The rendered document hash of a snapshot. Concurrent callers share one read.
    func renderHash(snapshotId: String, inspector: DOMInspector) async throws -> String {
        if let task = renderHashes[snapshotId] { return try await task.value }
        let task = Task { try await inspector.renderHash() }
        renderHashes[snapshotId] = task
        do {
            return try await task.value
        } catch {
            renderHashes[snapshotId] = nil
            throw error
        }
    }

    private static func key(slotId: String, snapshotId: String) -> String {
        "\(slotId)#\(snapshotId)"
    }
}
