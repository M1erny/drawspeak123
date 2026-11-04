import Foundation
import ImageIO

/// Normalized artifacts received in a thread reply. Issues are non-fatal unless
/// the affected entry was omitted; callers should display them alongside imports.
public struct PulledBundle: Sendable {
    public struct Entry: Sendable {
        public var screenId: String
        public var screenTitle: String
        public var role: SnapshotRole
        public var proposalId: String?
        public var iteration: Int
        public var parentSnapshotId: String?
        /// HTML source; empty for image entries.
        public var html: Data
        public var viewport: Viewport
        public var widthPx: Int
        public var heightPx: Int
        public var renderPolicy: RenderPolicy
        public var changeSummary: String?
        public var addressedNoteIds: [String]
        public var snapshotId: String
        public var kind: ArtifactKind = .html
        /// Image bytes and MIME type for image entries.
        public var image: Data?
        public var imageContentType: String?
    }

    /// Files the reply points to in the thread's workspace on the Mac. They must be
    /// downloaded before entries can be built (`PulledBundleReader.read(manifest:…)`
    /// or `read(linked:…)`).
    public enum Remote: Sendable, Hashable {
        /// A `drawspeak-bundle path="…/review-manifest.json"` pointer.
        case manifest(path: String)
        /// Local `.html`/`.png`/`.jpg` files linked from the reply (tolerant mode).
        case files([LinkedFile])
    }

    public var entries: [Entry]
    public var issues: [ManifestIssue]
    public var diagnosis: String?
    public var remote: Remote?

    public init(entries: [Entry], issues: [ManifestIssue], diagnosis: String?, remote: Remote? = nil) {
        self.entries = entries; self.issues = issues; self.diagnosis = diagnosis; self.remote = remote
    }
}

/// A local file linked from a reply: a workspace-relative or absolute path.
public struct LinkedFile: Sendable, Hashable {
    public var path: String
    public var kind: ArtifactKind
    public init(path: String, kind: ArtifactKind) { self.path = path; self.kind = kind }
}

public enum PulledBundleReader {
    /// Entries per reply with inline text bundles.
    public static let maxInlineEntries = 12
    /// Files downloaded from the workspace in one Pull.
    public static let maxRemoteFiles = 40
    /// Bytes per downloaded file.
    public static let maxRemoteFileBytes = 10 * 1024 * 1024

    /// Reads inline bundles. When the reply has none, returns `remote` for a
    /// `drawspeak-bundle` pointer, or (with `linkedFiles`) for linked local files.
    public static func read(_ text: String, canvas: ReviewCanvas, linkedFiles: Bool = false) -> PulledBundle {
        let blocks = TextBundleParser.blocks(text)
        var (bundle, htmlBlockCount) = build(blocks: blocks, rows: nil, images: nil, canvas: canvas, limit: maxInlineEntries)
        guard bundle.entries.isEmpty, bundle.diagnosis == nil else { return bundle }
        if let pointer = bundlePointer(in: text) {
            guard WorkspaceFilePath.isAcceptable(pointer), WorkspaceFilePath.fileExtension(pointer) == "json" else {
                bundle.issues.append(ManifestIssue(snapshotId: nil, message: "Bundle path is unsafe or not a JSON manifest"))
                return bundle
            }
            bundle.remote = .manifest(path: pointer)
            return bundle
        }
        if linkedFiles {
            let files = self.linkedFiles(in: text)
            if !files.isEmpty { bundle.remote = .files(files); return bundle }
        }
        let attempted = text.lowercased().contains("drawspeak") || text.lowercased().contains("manifest") || text.contains("```") || text.contains("~~~")
        if attempted {
            bundle.diagnosis = htmlBlockCount == 0 ? "The reply mentions a review bundle but contains no HTML block" : "The reply contains no importable HTML; check the bundle issues"
        }
        return bundle
    }

    /// The manifest-relative files a downloaded manifest needs, in snapshot order:
    /// `htmlPath`/`prototypePath` for HTML entries, `imagePath` for image entries.
    public static func manifestFiles(_ manifest: Data) -> (paths: [String], issues: [ManifestIssue]) {
        guard let object = (try? JSONSerialization.jsonObject(with: manifest)) as? [String: Any],
              let rows = object["snapshots"] as? [[String: Any]] else {
            return ([], [ManifestIssue(snapshotId: nil, message: "Could not decode the review manifest")])
        }
        var paths: [String] = [], issues: [ManifestIssue] = []
        for row in rows {
            guard let path = filePath(row) else { issues.append(ManifestIssue(snapshotId: row["snapshotId"] as? String, message: "Entry names no file")); continue }
            guard ManifestValidator.isSafeRelativePath(path) else { issues.append(ManifestIssue(snapshotId: row["snapshotId"] as? String, message: "File path is unsafe")); continue }
            if !paths.contains(path) { paths.append(path) }
        }
        return (paths, issues)
    }

    /// Entries from a manifest downloaded from the workspace and its files, keyed
    /// by the paths written in the manifest.
    public static func read(manifest: Data, files: [String: Data], canvas: ReviewCanvas) -> PulledBundle {
        var blocks = [TextBundleParser.Block(info: "drawspeak-manifest", text: String(decoding: manifest, as: UTF8.self))]
        var images: [String: Data] = [:]
        for (path, data) in files.sorted(by: { $0.key < $1.key }) {
            if ["html", "htm"].contains(WorkspaceFilePath.fileExtension(path)) {
                blocks.append(TextBundleParser.Block(info: "drawspeak-file path=\"\(path)\"", text: String(decoding: data, as: UTF8.self)))
            } else { images[path] = data }
        }
        return build(blocks: blocks, rows: nil, images: images, canvas: canvas, limit: maxRemoteFiles).bundle
    }

    /// Entries for linked local files (tolerant mode). `prototypes/a/…` gives proposal
    /// "a", a `baseline`/`current` directory gives a baseline, and the file stem names the screen.
    public static func read(linked: [LinkedFile], files: [String: Data], canvas: ReviewCanvas) -> PulledBundle {
        var rows: [[String: Any]] = []
        var blocks: [TextBundleParser.Block] = []
        var images: [String: Data] = [:]
        for (index, file) in linked.enumerated() {
            guard let data = files[file.path] else { continue }
            let group = group(file.path)
            let screen = canvas.screens.first { $0.id.caseInsensitiveCompare(group.stem) == .orderedSame || $0.title.caseInsensitiveCompare(group.stem) == .orderedSame }
            // Paths can be absolute; alias them to safe relative keys for the shared builder.
            let alias = "linked/\(index)/" + (file.path.split(separator: "/").last.map(String.init) ?? "file")
            var row: [String: Any] = ["screenId": screen?.id ?? slug(group.stem), "screenTitle": screen?.title ?? group.stem,
                                      "role": group.baseline ? "baseline" : "proposal",
                                      "artifactKind": file.kind == .image ? "image" : "html"]
            if let proposal = group.proposal { row["proposalId"] = proposal }
            if file.kind == .image { row["imagePath"] = alias; images[alias] = data } else {
                row["htmlPath"] = alias
                blocks.append(TextBundleParser.Block(info: "drawspeak-file path=\"\(alias)\"", text: String(decoding: data, as: UTF8.self)))
            }
            rows.append(row)
        }
        return build(blocks: blocks, rows: rows, images: images, canvas: canvas, limit: maxRemoteFiles).bundle
    }

    /// `drawspeak-bundle path="…"` in a fence info line or inline code.
    public static func bundlePointer(in text: String) -> String? {
        TextBundleParser.capture("(?i)drawspeak-bundle\\s+path\\s*=\\s*(?:\"([^\"]+)\"|'([^']+)'|([^\\s`\"'>]+))", in: text)
            .map { $0.trimmingCharacters(in: .whitespaces) }
    }

    /// Local `.html`/`.htm`/`.png`/`.jpg`/`.jpeg` paths in markdown links or bare absolute
    /// paths, in reply order without duplicates. URLs and unsafe paths are skipped.
    public static func linkedFiles(in text: String) -> [LinkedFile] {
        var result: [LinkedFile] = []
        let patterns = ["\\]\\(\\s*<?([^)\\s>]+)>?(?:\\s+\"[^\"]*\")?\\s*\\)", "(?:^|[\\s`'\"(\\[<])(/[^\\s`'\"()\\[\\]<>|*]+)"]
        var candidates: [(Int, String)] = []
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]) else { continue }
            for match in regex.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
                if let range = Range(match.range(at: 1), in: text) { candidates.append((match.range(at: 1).location, String(text[range]))) }
            }
        }
        for (_, raw) in candidates.sorted(by: { $0.0 < $1.0 }) {
            var path = raw.hasPrefix("file://") ? String(raw.dropFirst(7)) : raw
            if let hash = path.firstIndex(of: "#") { path = String(path[..<hash]) }
            if let query = path.firstIndex(of: "?") { path = String(path[..<query]) }
            path = path.removingPercentEncoding ?? path
            while let last = path.last, ".,;:!".contains(last) { path.removeLast() }
            let kind: ArtifactKind
            switch WorkspaceFilePath.fileExtension(path) {
            case "html", "htm": kind = .html
            case "png", "jpg", "jpeg": kind = .image
            default: continue
            }
            guard WorkspaceFilePath.isAcceptable(path), !result.contains(where: { $0.path == path }) else { continue }
            result.append(LinkedFile(path: path, kind: kind))
        }
        return result
    }

    static func group(_ path: String) -> (stem: String, proposal: String?, baseline: Bool) {
        let parts = path.split(separator: "/").map(String.init)
        let name = parts.last ?? path
        let stem = name.lastIndex(of: ".").map { String(name[..<$0]) }.flatMap { $0.isEmpty ? nil : $0 } ?? name
        let dirs = parts.dropLast().map { $0.lowercased() }
        if dirs.contains(where: { ["baseline", "baselines", "current", "now", "before", "existing"].contains($0) }) {
            return (stem, nil, true)
        }
        for dir in dirs.reversed() {
            if dir.count == 1, let letter = dir.first, letter.isASCII, letter.isLetter { return (stem, dir, false) }
            if let id = TextBundleParser.capture("^(?:proposal|variant|option|alt|alternative)[-_ ]?([a-z0-9]{1,8})$", in: dir) { return (stem, id, false) }
        }
        return (stem, nil, false)
    }

    private static func slug(_ text: String) -> String {
        let mapped = text.lowercased().map { $0.isASCII && ($0.isLetter || $0.isNumber) ? $0 : "-" }
        let joined = String(mapped).split(separator: "-").joined(separator: "-")
        return joined.isEmpty ? "from-thread" : String(joined.prefix(64))
    }

    private static func filePath(_ row: [String: Any]) -> String? {
        let html = row["htmlPath"] as? String ?? row["prototypePath"] as? String
        let image = row["imagePath"] as? String
        return (row["artifactKind"] as? String == "image" || html == nil) ? image ?? html : html
    }

    /// Shared builder. `images` is nil for inline text bundles (image rows then
    /// match fenced blocks as before); otherwise image rows use those bytes.
    private static func build(blocks: [TextBundleParser.Block], rows explicitRows: [[String: Any]]?, images: [String: Data]?, canvas: ReviewCanvas, limit: Int) -> (bundle: PulledBundle, htmlBlockCount: Int) {
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
        var rows: [[String: Any]]? = explicitRows
        if rows == nil, let manifest = blocks.first(where: { $0.words.contains("drawspeak-manifest") }) {
            if let object = (try? JSONSerialization.jsonObject(with: manifest.data)) as? [String: Any] {
                guard object["schemaVersion"] as? Int == 1 else {
                    return (PulledBundle(entries: [], issues: [ManifestIssue(snapshotId: nil, message: "Unsupported manifest schema (expected 1)")], diagnosis: "The review manifest uses an unsupported schema"), htmlBlocks.count)
                }
                if let thread = object["threadId"] as? String, let bound = canvas.thread?.threadId, thread != bound {
                    return (PulledBundle(entries: [], issues: [ManifestIssue(snapshotId: nil, message: "Manifest belongs to another thread")], diagnosis: "The review manifest belongs to another thread"), htmlBlocks.count)
                }
                rows = object["snapshots"] as? [[String: Any]] ?? []
                if rows!.isEmpty { issue("Manifest contains no snapshot entries") }
            } else {
                issue("Could not decode the review manifest; trying full HTML documents")
            }
        }
        var used = Set<Int>()
        let count = rows?.count ?? htmlBlocks.count
        for index in 0..<min(count, limit) {
            let row = rows?[index] ?? [:]
            let isImage = images != nil && (row["artifactKind"] as? String == "image" || (row["htmlPath"] == nil && row["prototypePath"] == nil && row["imagePath"] != nil))
            var source: String
            var payload: Data
            var image: (data: Data, contentType: String, width: Int, height: Int)?
            if isImage {
                guard let imagePath = row["imagePath"] as? String, ManifestValidator.isSafeRelativePath(imagePath) else { issue("Image path is missing or unsafe"); continue }
                guard let data = images?[imagePath] else { issue("Image file missing for \(imagePath)"); continue }
                guard data.count <= maxRemoteFileBytes else { issue("Image exceeds the 10 MiB limit"); continue }
                guard let decoded = imageInfo(data) else { issue("\(imagePath) is not a PNG or JPEG image"); continue }
                image = (data, decoded.contentType, decoded.width, decoded.height)
                source = ""; payload = data
            } else {
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
                source = block.text; payload = block.data
            }
            let hints = [TextBundleParser.attribute("data-review-screen", in: source),
                TextBundleParser.capture("(?is)<title[^>]*>\\s*(.*?)\\s*</title>", in: source)].compactMap { $0 }
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
            let proposal = role == .baseline ? nil : (row["proposalId"] as? String ?? TextBundleParser.attribute("data-review-proposal", in: source) ?? proposalLetter(letter))
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
            let inferred = image.map { Viewport(width: $0.width, height: $0.height, deviceScaleFactor: 1) } ?? viewport(in: source)
            let viewport = Viewport(width: vp?["width"] as? Int ?? inferred.width,
                                    height: vp?["height"] as? Int ?? inferred.height,
                                    deviceScaleFactor: vp?["deviceScaleFactor"] as? Double ?? inferred.deviceScaleFactor)
            guard image != nil || viewport.isWithinCaptureLimits else { issue("Viewport is outside the supported range"); continue }
            let width = image?.width ?? row["widthPx"] as? Int ?? Int(Double(viewport.width) * viewport.deviceScaleFactor)
            let height = image?.height ?? row["heightPx"] as? Int ?? Int(Double(viewport.height) * viewport.deviceScaleFactor)
            guard width > 0, height > 0, image != nil || Double(width) * Double(height) <= Viewport.maxPixelCount else { issue("Invalid dimensions"); continue }
            let hash = BlobStore.sha256Hex(payload)
            let id = row["snapshotId"] as? String ?? "\(screenId)-\(proposal ?? "baseline")-\(hash.prefix(10))"
            if let expected = (image == nil ? row["htmlSha256"] : row["sha256"]) as? String, expected.lowercased() != hash {
                issue(image == nil ? "HTML hash differs, imported the text as received" : "Image hash differs, imported the file as received", id)
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
                html: image == nil ? payload : Data(), viewport: viewport, widthPx: width, heightPx: height, renderPolicy: policy,
                changeSummary: row["changeSummary"] as? String, addressedNoteIds: row["addressedNoteIds"] as? [String] ?? [], snapshotId: id,
                kind: image == nil ? .html : .image, image: image?.data, imageContentType: image?.contentType))
        }
        if count > limit { issue("Only the first \(limit) entries can be imported at once") }
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
        return (PulledBundle(entries: ordered, issues: issues, diagnosis: nil), htmlBlocks.count)
    }

    /// Pixel size and MIME type of PNG or JPEG bytes.
    static func imageInfo(_ data: Data) -> (contentType: String, width: Int, height: Int)? {
        let png = data.starts(with: [0x89, 0x50, 0x4E, 0x47]), jpeg = data.starts(with: [0xFF, 0xD8, 0xFF])
        guard png || jpeg, let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int, let height = properties[kCGImagePropertyPixelHeight] as? Int,
              width > 0, height > 0 else { return nil }
        return (png ? "image/png" : "image/jpeg", width, height)
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
        // Boards often fix the page width in CSS (`body{width:1440px}`) instead of a viewport meta.
        if let width = TextBundleParser.capture("(?is)(?:^|[}\\s])body\\s*\\{[^}]*?(?:^|[;{\\s])(?:min-)?width\\s*:\\s*(\\d{3,4})px", in: html).flatMap(Int.init),
           Viewport.dimensionRange.contains(width) {
            return Viewport(width: width, height: Viewport.defaultHTML.height, deviceScaleFactor: Viewport.defaultHTML.deviceScaleFactor)
        }
        return .defaultHTML
    }
}
