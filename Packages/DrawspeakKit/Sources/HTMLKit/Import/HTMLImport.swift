import DrawspeakCore
import Foundation

/// Lightweight inspection of imported HTML bytes. It does not render or sanitize.
nonisolated public enum HTMLImport {
    static let widthRange = 120...4096
    static let heightRange = 120...8192

    public static func inspect(_ data: Data) -> HTMLImportInfo {
        let html = String(data: data, encoding: .utf8) ?? String(decoding: data, as: UTF8.self)
        return HTMLImportInfo(
            title: title(in: html),
            containsScripts: containsScripts(html),
            suggestedViewport: suggestedViewport(in: html)
        )
    }

    static func title(in html: String) -> String? {
        let pattern = #/<title\b[^>]*>(?<text>.*?)</title\s*>/#.ignoresCase().dotMatchesNewlines()
        guard let match = html.firstMatch(of: pattern) else { return nil }
        let text = decodeEntities(String(match.output.text))
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
        return text.isEmpty ? nil : text
    }

    static func containsScripts(_ html: String) -> Bool {
        let scriptTag = #/<script\b/#.ignoresCase()
        let inlineHandler = #/<[a-z][^>]*\son[a-z]+\s*=/#.ignoresCase()
        return html.contains(scriptTag) || html.contains(inlineHandler)
    }

    static func suggestedViewport(in html: String) -> Viewport {
        let fallback = Viewport.defaultHTML
        if let size = reviewViewport(in: html) {
            return Viewport(width: size.width, height: size.height, deviceScaleFactor: fallback.deviceScaleFactor)
        }
        if let width = metaViewportWidth(in: html) {
            return Viewport(width: width, height: fallback.height, deviceScaleFactor: fallback.deviceScaleFactor)
        }
        return fallback
    }

    /// `data-review-viewport="390x844"` on the opening `<html>` or `<body>` tag.
    static func reviewViewport(in html: String) -> (width: Int, height: Int)? {
        let openingTag = #/<(?:html|body)\b[^>]*>/#.ignoresCase()
        let attribute = #/data-review-viewport\s*=\s*["']?\s*(?<width>\d{2,5})\s*[x×]\s*(?<height>\d{2,5})/#.ignoresCase()
        for tag in html.matches(of: openingTag) {
            guard let match = tag.output.firstMatch(of: attribute),
                  let width = Int(match.output.width), let height = Int(match.output.height),
                  widthRange.contains(width), heightRange.contains(height)
            else { continue }
            return (width, height)
        }
        return nil
    }

    /// `width=N` from `<meta name="viewport" content="...">`, in either attribute order.
    static func metaViewportWidth(in html: String) -> Int? {
        let metaTag = #/<meta\b[^>]*>/#.ignoresCase()
        let name = #/\bname\s*=\s*["']?viewport\b/#.ignoresCase()
        let content = #/\bcontent\s*=\s*(?:"(?<double>[^"]*)"|'(?<single>[^']*)')/#.ignoresCase()
        let width = #/(?:^|[\s,;])width\s*=\s*(?<value>\d+)(?:\.\d+)?\s*(?:$|[\s,;])/#.ignoresCase()
        for tag in html.matches(of: metaTag) {
            let text = tag.output
            guard text.contains(name), let contentMatch = text.firstMatch(of: content) else { continue }
            let value = contentMatch.output.double ?? contentMatch.output.single ?? ""
            guard let widthMatch = value.firstMatch(of: width),
                  let pixels = Int(widthMatch.output.value), widthRange.contains(pixels)
            else { continue }
            return pixels
        }
        return nil
    }

    static func decodeEntities(_ text: String) -> String {
        text.replacing("&lt;", with: "<")
            .replacing("&gt;", with: ">")
            .replacing("&quot;", with: "\"")
            .replacing("&#39;", with: "'")
            .replacing("&apos;", with: "'")
            .replacing("&nbsp;", with: " ")
            .replacing("&amp;", with: "&")
    }
}
