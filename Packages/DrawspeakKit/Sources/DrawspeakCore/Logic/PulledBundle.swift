import Foundation

/// Normalized HTML artifacts received in a thread reply. Issues are non-fatal unless
/// the affected entry was omitted; callers should display them alongside imports.
public struct PulledBundle: Sendable {
    public struct Entry: Sendable {
        public var screenId: String
        public var screenTitle: String
        public var role: SnapshotRole
        public var proposalId: String?
        public var iteration: Int
        public var parentSnapshotId: String?
        public var html: Data
        public var viewport: Viewport
        public var widthPx: Int
        public var heightPx: Int
        public var renderPolicy: RenderPolicy
        public var changeSummary: String?
        public var addressedNoteIds: [String]
        public var snapshotId: String
    }
    public var entries: [Entry]
    public var issues: [ManifestIssue]
    public var diagnosis: String?
}

public enum PulledBundleReader {
    public static func read(_ text: String, canvas: ReviewCanvas) -> PulledBundle {
        let blocks = TextBundleParser.blocks(text)
        let htmlBlocks = blocks.filter { $0.words.contains("html") || $0.words.contains("drawspeak-file") }
        var issues: [ManifestIssue] = []
        var entries: [PulledBundle.Entry] = []
        func issue(_ message: String, _ id: String? = nil) {
            issues.append(ManifestIssue(snapshotId: id, message: message))
        }
        func path(_ block: TextBundleParser.Block) -> String? {
            TextBundleParser.attribute("path", in: block.info)
                ?? TextBundleParser.attribute("data-review-path", in: block.text)
                ?? TextBundleParser.capture("(?i)<!--\\s*path:\\s*(.*?)\\s*-->", in: block.text)
        }
        var rows: [[String: Any]]?
        if let manifest = blocks.first(where: { $0.words.contains("drawspeak-manifest") }) {
            if let object = (try? JSONSerialization.jsonObject(with: manifest.data)) as? [String: Any] {
                guard object["schemaVersion"] as? Int == 1 else {
                    return PulledBundle(entries: [], issues: [ManifestIssue(snapshotId: nil, message: "Unsupported manifest schema (expected 1)")], diagnosis: "The review manifest uses an unsupported schema")
                }
                if let thread = object["threadId"] as? String, let bound = canvas.thread?.threadId, thread != bound {
                    return PulledBundle(entries: [], issues: [ManifestIssue(snapshotId: nil, message: "Manifest belongs to another thread")], diagnosis: "The review manifest belongs to another thread")
                }
                rows = object["snapshots"] as? [[String: Any]] ?? []
                if rows!.isEmpty { issue("Manifest contains no snapshot entries") }
            } else {
                issue("Could not decode the review manifest; trying full HTML documents")
            }
        }
        var used = Set<Int>()
        let count = rows?.count ?? htmlBlocks.count
        for index in 0..<min(count, 12) {
            let row = rows?[index] ?? [:]
            let explicitPath = row["htmlPath"] as? String ?? row["prototypePath"] as? String
            if let explicitPath, !ManifestValidator.isSafeRelativePath(explicitPath) {
                issue("HTML path is unsafe"); continue
            }
            let blockIndex: Int?
            if rows != nil {
                // Exact path wins, then an unclaimed, unlabelled HTML block in reply order.
                blockIndex = htmlBlocks.indices.first { !used.contains($0) && explicitPath != nil && path(htmlBlocks[$0]) == explicitPath && htmlBlocks[$0].words.contains("drawspeak-file") }
                    ?? htmlBlocks.indices.first { !used.contains($0) && explicitPath != nil && path(htmlBlocks[$0]) == explicitPath }
                    ?? htmlBlocks.indices.first { !used.contains($0) && (explicitPath == nil || path(htmlBlocks[$0]) == nil) }
            } else { blockIndex = index }
            guard let blockIndex else { issue("HTML file missing for \(explicitPath ?? "manifest entry")"); continue }
            used.insert(blockIndex)
            let block = htmlBlocks[blockIndex]
            if let hint = path(block), !ManifestValidator.isSafeRelativePath(hint) {
                issue("HTML path is unsafe"); continue
            }
            guard block.data.count <= 2 * 1024 * 1024 else { issue("HTML exceeds the 2 MiB limit"); continue }
            if rows == nil && !isFullHTML(block.text) { issue("HTML block is not a full HTML document"); continue }
            let hints = [TextBundleParser.attribute("data-review-screen", in: block.text),
                TextBundleParser.capture("(?is)<title[^>]*>\\s*(.*?)\\s*</title>", in: block.text)].compactMap { $0 }
            let screen = hints.lazy.compactMap { hint in
                canvas.screens.first { $0.id.caseInsensitiveCompare(hint) == .orderedSame || $0.title.caseInsensitiveCompare(hint) == .orderedSame }
            }.first ?? canvas.screens.first
            let screenId = row["screenId"] as? String ?? screen?.id ?? "from-thread"
            let screenTitle = row["screenTitle"] as? String ?? canvas.screens.first(where: { $0.id == screenId })?.title ?? "From Thread"
            let roleText = row["role"] as? String ?? "proposal"
            guard let role = SnapshotRole(rawValue: roleText) else { issue("Unknown snapshot role \(roleText)"); continue }
            let occupied = Set(canvas.snapshots.filter { $0.screenId == screenId }.compactMap(\.proposalId)
                + (canvas.screens.first { $0.id == screenId }?.proposalOrder ?? [])
                + entries.filter { $0.screenId == screenId }.compactMap(\.proposalId))
            var letter = 0
            while occupied.contains(proposalLetter(letter)) { letter += 1 }
            let proposal = role == .baseline ? nil : (row["proposalId"] as? String ?? TextBundleParser.attribute("data-review-proposal", in: block.text) ?? proposalLetter(letter))
            let prior = canvas.snapshots.filter { $0.screenId == screenId && $0.proposalId == proposal }
            let pending = entries.filter { $0.screenId == screenId && $0.proposalId == proposal }
            let maximum = max(prior.map(\.iteration).max() ?? 0, pending.map(\.iteration).max() ?? 0)
            guard maximum < Int.max else { issue("Iteration limit reached"); continue }
            let next = maximum + 1
            let iteration = row["iteration"] as? Int ?? (role == .baseline ? 0 : next)
            guard !screenId.isEmpty, role == .baseline ? iteration == 0 : (proposal?.isEmpty == false && iteration > 0) else {
                issue("Invalid screen, proposal or iteration"); continue
            }
            let vp = row["viewport"] as? [String: Any]
            let inferred = viewport(in: block.text)
            let viewport = Viewport(width: vp?["width"] as? Int ?? inferred.width,
                                    height: vp?["height"] as? Int ?? inferred.height,
                                    deviceScaleFactor: vp?["deviceScaleFactor"] as? Double ?? inferred.deviceScaleFactor)
            guard viewport.isWithinCaptureLimits else { issue("Viewport is outside the supported range"); continue }
            let width = row["widthPx"] as? Int ?? Int(Double(viewport.width) * viewport.deviceScaleFactor)
            let height = row["heightPx"] as? Int ?? Int(Double(viewport.height) * viewport.deviceScaleFactor)
            guard width > 0, height > 0, Double(width) * Double(height) <= Viewport.maxPixelCount else { issue("Invalid dimensions"); continue }
            let hash = BlobStore.sha256Hex(block.data)
            let id = row["snapshotId"] as? String ?? "\(screenId)-\(proposal ?? "baseline")-\(hash.prefix(10))"
            if let expected = row["htmlSha256"] as? String, expected.lowercased() != hash {
                issue("HTML hash differs, imported the text as received", id)
            }
            if let existing = canvas.snapshots.first(where: { $0.id == id }) {
                if existing.sourceBlob?.sha256 != hash { issue("Snapshot id already exists with other bytes", id) }
                continue
            }
            guard !entries.contains(where: { $0.snapshotId == id }) else { issue("Duplicate snapshot id", id); continue }
            let policyText = row["renderPolicy"] as? String ?? RenderPolicy.staticNoScript.rawValue
            guard let policy = RenderPolicy(rawValue: policyText) else { issue("Unsupported render policy", id); continue }
            entries.append(PulledBundle.Entry(screenId: screenId, screenTitle: screenTitle, role: role,
                proposalId: proposal, iteration: iteration, parentSnapshotId: row["parentSnapshotId"] as? String,
                html: block.data, viewport: viewport, widthPx: width, heightPx: height, renderPolicy: policy,
                changeSummary: row["changeSummary"] as? String, addressedNoteIds: row["addressedNoteIds"] as? [String] ?? [], snapshotId: id))
        }
        if count > 12 { issue("Only the first 12 entries in a message can be imported") }
        // Remove invalid parent chains transitively so every returned entry is importable.
        var changed = true
        while changed {
            changed = false
            let rejected = entries.filter { entry in
                guard let parentId = entry.parentSnapshotId else { return false }
                let parent = entries.first { $0.snapshotId == parentId }
                let stored = canvas.snapshots.first { $0.id == parentId }
                let screen = parent?.screenId ?? stored?.screenId
                let proposal = parent?.proposalId ?? stored?.proposalId
                if parentId == entry.snapshotId || screen == nil || screen != entry.screenId || (proposal != nil && proposal != entry.proposalId) {
                    issue("Parent snapshot missing or belongs to another proposal or screen", entry.snapshotId)
                    changed = true
                    return true
                }
                return false
            }.map(\.snapshotId)
            entries.removeAll { rejected.contains($0.snapshotId) }
        }
        // Parents must be imported before children. Unresolvable cycles are quarantined.
        var ordered: [PulledBundle.Entry] = []
        var remaining = entries
        var available = Set(canvas.snapshots.map(\.id))
        while !remaining.isEmpty {
            guard let index = remaining.firstIndex(where: { $0.parentSnapshotId == nil || available.contains($0.parentSnapshotId!) }) else {
                for entry in remaining { issue("Parent snapshot chain contains a cycle", entry.snapshotId) }
                break
            }
            let entry = remaining.remove(at: index)
            ordered.append(entry)
            available.insert(entry.snapshotId)
        }
        entries = ordered
        let attempted = text.lowercased().contains("drawspeak") || text.lowercased().contains("manifest") || text.contains("```") || text.contains("~~~")
        let diagnosis: String? = entries.isEmpty && attempted
            ? (htmlBlocks.isEmpty ? "The reply mentions a review bundle but contains no HTML block" : "The reply contains no importable HTML; check the bundle issues") : nil
        return PulledBundle(entries: entries, issues: issues, diagnosis: diagnosis)
    }

    private static func proposalLetter(_ index: Int) -> String {
        var value = index + 1
        var result = ""
        while value > 0 { value -= 1; result = String(UnicodeScalar(97 + value % 26)!) + result; value /= 26 }
        return result
    }

    private static func isFullHTML(_ text: String) -> Bool {
        TextBundleParser.capture("(?is)(<(?:!doctype\\s+html|html\\b)[^>]*>)", in: text) != nil
            && text.range(of: "</html\\s*>", options: [.regularExpression, .caseInsensitive]) != nil
    }

    private static func viewport(in html: String) -> Viewport {
        if let hint = TextBundleParser.attribute("data-review-viewport", in: html),
           let data = hint.data(using: .utf8), let vp = try? JSONDecoder().decode(Viewport.self, from: data) { return vp }
        if let hint = TextBundleParser.attribute("data-review-viewport", in: html),
           let regex = try? NSRegularExpression(pattern: "^(\\d+)[x×](\\d+)(?:@([0-9.]+)(?:x)?)?$"),
           let match = regex.firstMatch(in: hint, range: NSRange(hint.startIndex..., in: hint)) {
            func part(_ n: Int) -> String { Range(match.range(at: n), in: hint).map { String(hint[$0]) } ?? "" }
            return Viewport(width: Int(part(1)) ?? 390, height: Int(part(2)) ?? 844, deviceScaleFactor: Double(part(3)) ?? 2)
        }
        if let tag = TextBundleParser.capture("(?is)(<meta\\b[^>]*name\\s*=\\s*[\\\"']?viewport\\b[^>]*>)", in: html) {
            let content = TextBundleParser.attribute("content", in: tag) ?? tag
            let width = TextBundleParser.capture("(?i)width\\s*=\\s*(\\d+)", in: content).flatMap(Int.init) ?? 390
            let height = TextBundleParser.capture("(?i)height\\s*=\\s*(\\d+)", in: content).flatMap(Int.init) ?? 844
            return Viewport(width: width, height: height, deviceScaleFactor: 2)
        }
        return .defaultHTML
    }
}
