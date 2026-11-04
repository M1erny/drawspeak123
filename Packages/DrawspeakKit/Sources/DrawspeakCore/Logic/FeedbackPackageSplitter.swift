import Foundation

/// Splits one feedback package into messages that fit T3's limits.
///
/// `t3_thread_send_attachments` and `t3_thread_launch` accept at most eight attachments
/// per message (docs/T3-MCP-CONTRACT.md, sections 8.8 and 11). Instead of asking the
/// reviewer to deselect comments, a large review goes out as several messages. Every
/// part is self-contained: its own composites, HTML sources, manifest and batch marker,
/// so each one is delivered, reconciled and retried on its own.
public enum FeedbackPackageSplitter {
    public static let maxAttachmentsPerMessage = 8
    public static let maxMessageCharacters = 120_000

    /// A composite PNG per snapshot, plus the exact HTML source for an HTML snapshot.
    public static func attachmentCount(of group: FeedbackPackage.Group) -> Int {
        group.snapshot.kind == .html ? 2 : 1
    }

    /// Every attachment of the package, including its one manifest.
    public static func attachmentCount(of package: FeedbackPackage) -> Int {
        package.groups.map(attachmentCount(of:)).reduce(1, +)
    }

    /// The parts in sending order. A package that fits one message comes back unchanged
    /// (no `part`, same batch id). Otherwise part `i` gets batch id `<batchId>-<i>`.
    /// Snapshots keep their order and are never split across parts.
    public static func split(_ package: FeedbackPackage) -> [FeedbackPackage] {
        guard !fits(package) else { return [package] }
        var chunks: [[FeedbackPackage.Group]] = []
        var current: [FeedbackPackage.Group] = []
        var used = 1 // the manifest
        for group in package.groups {
            let cost = attachmentCount(of: group)
            if !current.isEmpty, used + cost > maxAttachmentsPerMessage {
                chunks.append(current)
                current = []
                used = 1
            }
            current.append(group)
            used += cost
        }
        if !current.isEmpty { chunks.append(current) }
        chunks = chunks.flatMap { splitByText($0, template: package) }
        guard chunks.count > 1 else { return [package] }
        return chunks.enumerated().map { offset, groups in
            var part = package
            part.groups = groups
            part.batchId = "\(package.batchId)-\(offset + 1)"
            part.part = FeedbackPackage.Part(index: offset + 1, count: chunks.count, seriesId: package.batchId)
            return part
        }
    }

    public static func fits(_ package: FeedbackPackage) -> Bool {
        attachmentCount(of: package) <= maxAttachmentsPerMessage
            && FeedbackPackageBuilder.messageText(for: package).count <= maxMessageCharacters
    }

    /// Halves a chunk until each half's text fits; a single snapshot is never divided.
    private static func splitByText(_ groups: [FeedbackPackage.Group], template: FeedbackPackage) -> [[FeedbackPackage.Group]] {
        var probe = template
        probe.groups = groups
        // A part header is a few hundred characters at most; measure with the longest one.
        probe.part = FeedbackPackage.Part(index: 99, count: 99, seriesId: template.batchId)
        guard groups.count > 1, FeedbackPackageBuilder.messageText(for: probe).count > maxMessageCharacters else { return [groups] }
        let middle = groups.count / 2
        return splitByText(Array(groups[..<middle]), template: template) + splitByText(Array(groups[middle...]), template: template)
    }
}
