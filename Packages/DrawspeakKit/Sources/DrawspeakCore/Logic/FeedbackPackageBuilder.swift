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
        displayNumbers: [UUID: Int]? = nil,
        directive: AgentDirective? = nil
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
            let screen = canvas.screens.first { $0.id == snapshot.screenId }
            let latest = snapshot.role == .proposal
                ? CanvasLayout.proposalIterations(in: canvas, screenId: snapshot.screenId, proposalId: snapshot.proposalId ?? "").last?.iteration
                : nil
            return FeedbackPackage.Group(
                snapshot: snapshot,
                screenTitle: screenTitle,
                laneTitle: laneTitle,
                items: bySnapshot[snapshotId] ?? [],
                compositeFileName: String(format: "%02d-%@.png", index + 1, safeFileComponent(snapshot.id)),
                latestIteration: latest,
                existingProposalIds: screen.map { CanvasLayout.proposalIds(in: canvas, screen: $0) } ?? []
            )
        }
        let alreadySent = notes.contains { $0.lastSentRevision != nil }
        return FeedbackPackage(
            batchId: batchId,
            canvasTitle: canvas.title,
            thread: thread,
            groups: groups,
            isRepeat: alreadySent,
            createdAt: now,
            directive: directive ?? .suggested(forProposalFlags: groups.map(\.isProposal))
        )
    }

    public static func safeFileComponent(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let mapped = value.unicodeScalars.map { allowed.contains($0) ? Character($0) : "-" }
        return String(String(mapped).prefix(48))
    }

    /// The reviewer's instruction to the agent for this batch.
    static func instructionLines(for package: FeedbackPackage) -> [String] {
        let directive = package.directive
        let script = "`python3 -I ~/.agents/skills/ui-review-variants/scripts/drawspeak_bundle.py`"
        var lines: [String] = []
        switch directive.mode {
        case .replyOnly:
            lines.append("Instruction: answer the comments in text only. Do not build mockups and do not change any files.")
        case .continueProposals:
            lines.append("Instruction: apply these comments to the proposals they are on, as the next iteration of each. Use the ui-review-variants skill. Do not create new proposals for comments on a proposal.")
            for group in package.groups {
                if group.isProposal, let proposalId = group.snapshot.proposalId {
                    let next = (group.latestIteration ?? group.snapshot.iteration) + 1
                    lines.append("- \(group.screenTitle), \(group.laneTitle): export iteration \(next) with proposalId `\(proposalId)`, screenId `\(group.snapshot.screenId)`, parentSnapshotId `\(group.snapshot.id)`.")
                } else {
                    let used = group.existingProposalIds.isEmpty ? "" : " (already used on this screen: \(group.existingProposalIds.joined(separator: ", ")))"
                    lines.append("- \(group.screenTitle), \(group.laneTitle): this is the current UI, so put the changes into one new proposal with an unused proposalId\(used) and screenId `\(group.snapshot.screenId)`.")
                }
            }
            lines.append("End your reply with the verbatim output of \(script). Pass `--previous <your last review-manifest.json>` so every row continues its chain (Drawspeak imports them with Pull from Thread).")
        case .newVariants:
            let count = directive.variantCount
            lines.append("Instruction: create \(count) new alternative proposal\(count == 1 ? "" : "s") that address these comments. Use the ui-review-variants skill. Leave existing proposals unchanged.")
            for group in package.groups where !group.existingProposalIds.isEmpty {
                lines.append("- \(group.screenTitle): proposalIds already used: \(group.existingProposalIds.joined(separator: ", ")). Choose others.")
            }
            lines.append("End your reply with the verbatim output of \(script) (Drawspeak imports them with Pull from Thread).")
        }
        let note = directive.note.trimmingCharacters(in: .whitespacesAndNewlines)
        if !note.isEmpty { lines.append("Additional instruction from the reviewer: \(note)") }
        return lines
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
        lines.append(contentsOf: instructionLines(for: package))
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
