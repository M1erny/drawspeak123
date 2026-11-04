import Foundation

public enum FeedbackPackageBuilder {
    /// Groups the chosen notes by their source snapshot, ordered by the first
    /// note number in each group. One snapshot appears once with all its marks.
    ///
    /// `displayNumbers` are the numbers shown to the person at send time
    /// (`Workspace.displayNumbers`). When nil they are computed with sent notes
    /// hidden, counting the chosen notes as visible.
    public static func build(
        canvas: ReviewCanvas,
        noteIds: Set<UUID>,
        thread: ThreadBinding,
        batchId: String,
        now: Date,
        displayNumbers: [UUID: Int]? = nil
    ) -> FeedbackPackage {
        let numbers = displayNumbers ?? NoteNumbering.displayNumbers(in: canvas, showsSentNotes: false, including: noteIds)
        let notes = canvas.notes
            .filter { noteIds.contains($0.id) }
            .sorted { $0.ordinal < $1.ordinal }
        var order: [String] = []
        var bySnapshot: [String: [BatchItem]] = [:]
        for note in notes {
            if bySnapshot[note.snapshotId] == nil { order.append(note.snapshotId) }
            bySnapshot[note.snapshotId, default: []].append(BatchItem(note: note, displayNumber: numbers[note.id]))
        }
        let groups: [FeedbackPackage.Group] = order.enumerated().compactMap { index, snapshotId in
            guard let snapshot = canvas.snapshots.first(where: { $0.id == snapshotId }) else { return nil }
            let screenTitle = canvas.screens.first { $0.id == snapshot.screenId }?.title ?? snapshot.screenId
            let laneTitle = snapshot.role == .baseline
                ? "Now"
                : "\(CanvasLayout.proposalTitle(snapshot.proposalId ?? "?")) · Iteration \(snapshot.iteration)"
            return FeedbackPackage.Group(
                snapshot: snapshot,
                screenTitle: screenTitle,
                laneTitle: laneTitle,
                items: bySnapshot[snapshotId] ?? [],
                compositeFileName: String(format: "%02d-%@.png", index + 1, safeFileComponent(snapshot.id))
            )
        }
        let alreadySent = notes.contains { $0.lastSentRevision != nil }
        return FeedbackPackage(
            batchId: batchId,
            canvasTitle: canvas.title,
            thread: thread,
            groups: groups,
            isRepeat: alreadySent,
            createdAt: now
        )
    }

    public static func safeFileComponent(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let mapped = value.unicodeScalars.map { allowed.contains($0) ? Character($0) : "-" }
        return String(String(mapped).prefix(48))
    }

    /// The message text: brief, numbered comments per snapshot and the batch marker.
    public static func messageText(for package: FeedbackPackage) -> String {
        let count = package.items.count
        var lines: [String] = []
        lines.append("\(package.marker) Drawspeak feedback for review \"\(package.canvasTitle)\": \(count) comment\(count == 1 ? "" : "s") on \(package.groups.count) snapshot\(package.groups.count == 1 ? "" : "s").")
        if package.isRepeat {
            lines.append("Note: this repeats comments that were sent before.")
        }
        lines.append("Each attached PNG is one snapshot with numbered marks. The JSON manifest maps every number to its noteId, snapshotId, geometry and HTML component target. Comment text is the reviewer's intent; old coordinates apply only to their own snapshot.")
        lines.append("To return new versions to the iPad, use the ui-review-variants skill: build self-contained HTML proposals and end your reply with the verbatim output of `python3 -I ~/.agents/skills/ui-review-variants/scripts/drawspeak_bundle.py` (Drawspeak imports them with Pull from Thread).")
        for group in package.groups {
            lines.append("")
            lines.append("## \(group.screenTitle) — \(group.laneTitle)")
            lines.append("Snapshot `\(group.snapshot.id)` · image `\(group.compositeFileName)`")
            if let summary = group.snapshot.changeSummary, !summary.isEmpty {
                lines.append("Version summary: \(summary)")
            }
            for item in group.items {
                var line = "\(item.number). [\(item.shape.kindLabel)] \(item.text)"
                if let target = item.domTarget {
                    line += "\n   Component: \(target.label) <\(target.tagName)> \(target.locator.displayText)"
                }
                lines.append(line)
            }
        }
        lines.append("")
        lines.append("Manifest: `\(package.manifestFileName)`. Batch: \(package.marker)")
        return lines.joined(separator: "\n")
    }
}
