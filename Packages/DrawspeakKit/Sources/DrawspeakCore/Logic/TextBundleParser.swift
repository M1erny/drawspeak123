import Foundation

/// Extracts a review manifest and text files from an agent reply.
///
/// Small bundles come inline as fenced blocks in the reply (larger ones are
/// written to the workspace and referenced with a `drawspeak-bundle` pointer):
///
///     ````drawspeak-manifest
///     { "schemaVersion": 1, ... }
///     ````
///     ````drawspeak-file path="prototypes/a/index.html"
///     <!doctype html> ...
///     ````
///
/// Fences use three or more backticks or tildes; closers use at least that count.
public enum TextBundleParser {
    public struct Bundle: Equatable, Sendable {
        public var manifest: Data?
        public var files: [String: Data]
    }

    struct Block {
        var info: String
        var text: String
        var data: Data { Data(text.utf8) }
        var words: [String] { info.lowercased().split(whereSeparator: { $0.isWhitespace }).map(String.init) }
    }

    static func blocks(_ text: String) -> [Block] {
        let lines = text.components(separatedBy: "\n")
        var result: [Block] = []
        var index = 0
        while index < lines.count {
            let line = lines[index].trimmingCharacters(in: .whitespacesAndNewlines)
            guard let marker = line.first, marker == "`" || marker == "~" else { index += 1; continue }
            let count = line.prefix { $0 == marker }.count
            guard count >= 3 else { index += 1; continue }
            let info = String(line.dropFirst(count)).trimmingCharacters(in: .whitespaces)
            var cursor = index + 1
            while cursor < lines.count {
                let closing = lines[cursor].trimmingCharacters(in: .whitespacesAndNewlines)
                if closing.count >= count && closing.allSatisfy({ $0 == marker }) { break }
                cursor += 1
            }
            guard cursor < lines.count else { break }
            result.append(Block(info: info, text: lines[(index + 1)..<cursor].joined(separator: "\n")))
            index = cursor + 1
        }
        return result
    }

    public static func parse(_ text: String) -> Bundle {
        var manifest: Data?
        var files: [String: Data] = [:]
        for block in blocks(text) {
            if block.words.contains("drawspeak-manifest") { manifest = block.data }
            else if block.words.contains("drawspeak-file"), let path = attribute("path", in: block.info), ManifestValidator.isSafeRelativePath(path) {
                files[path] = block.data
            }
        }
        return Bundle(manifest: manifest, files: files)
    }

    static func attribute(_ name: String, in info: String) -> String? {
        capture("(?i)(?:^|[\\s<])" + NSRegularExpression.escapedPattern(for: name) + "\\s*=\\s*(?:\"([^\"]*)\"|'([^']*)'|([^\\s>]+))", in: info)
    }

    static func capture(_ pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else { return nil }
        for index in 1..<match.numberOfRanges {
            if let range = Range(match.range(at: index), in: text) { return String(text[range]) }
        }
        return nil
    }
}
