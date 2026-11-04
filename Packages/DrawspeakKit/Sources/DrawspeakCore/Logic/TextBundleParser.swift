import Foundation

/// Extracts a review manifest and text files from an agent reply.
///
/// T3 Code does not let an MCP client download thread files, so the
/// ui-review-variants skill returns them as fenced blocks in its reply:
///
///     ````drawspeak-manifest
///     { "schemaVersion": 1, ... }
///     ````
///     ````drawspeak-file path="prototypes/a/index.html"
///     <!doctype html> ...
///     ````
///
/// A fence is three or more backticks; the closing fence has the same count.
public enum TextBundleParser {
    public struct Bundle: Equatable, Sendable {
        public var manifest: Data?
        public var files: [String: Data]
    }

    public static func parse(_ text: String) -> Bundle {
        var manifest: Data?
        var files: [String: Data] = [:]
        let lines = text.components(separatedBy: "\n")
        var index = 0
        while index < lines.count {
            let line = lines[index]
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let ticks = trimmed.prefix { $0 == "`" }.count
            guard ticks >= 3 else { index += 1; continue }
            let info = trimmed.dropFirst(ticks).trimmingCharacters(in: .whitespaces)
            let fence = String(repeating: "`", count: ticks)
            var body: [String] = []
            var cursor = index + 1
            var closed = false
            while cursor < lines.count {
                if lines[cursor].trimmingCharacters(in: .whitespaces) == fence { closed = true; break }
                body.append(lines[cursor])
                cursor += 1
            }
            guard closed else { break }
            let content = Data(body.joined(separator: "\n").utf8)
            if info == "drawspeak-manifest" {
                manifest = content
            } else if info.hasPrefix("drawspeak-file"), let path = attribute("path", in: info), ManifestValidator.isSafeRelativePath(path) {
                files[path] = content
            }
            index = cursor + 1
        }
        return Bundle(manifest: manifest, files: files)
    }

    static func attribute(_ name: String, in info: String) -> String? {
        guard let range = info.range(of: "\(name)=\"") else { return nil }
        let rest = info[range.upperBound...]
        guard let end = rest.firstIndex(of: "\"") else { return nil }
        return String(rest[..<end])
    }
}
