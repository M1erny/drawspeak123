#if canImport(WebKit)
import Foundation
import WebKit

/// Content rules that keep a mockup offline: every load is blocked except the
/// initial `about:` document and inline `data:` resources.
enum HTMLContentRules {
    static let identifier = "drawspeak-offline-v1"

    static let encodedRules = """
    [
      {"trigger": {"url-filter": "^https?://"}, "action": {"type": "block"}},
      {"trigger": {"url-filter": "^wss?://"}, "action": {"type": "block"}},
      {"trigger": {"url-filter": "^file:"}, "action": {"type": "block"}},
      {"trigger": {"url-filter": ".*"}, "action": {"type": "block"}},
      {"trigger": {"url-filter": "^data:"}, "action": {"type": "ignore-previous-rules"}},
      {"trigger": {"url-filter": "^about:"}, "action": {"type": "ignore-previous-rules"}}
    ]
    """

    private static var cached: WKContentRuleList?

    /// Compiles once per process. Callers must not load HTML when this throws.
    static func compiled() async throws -> WKContentRuleList {
        if let cached { return cached }
        let list: WKContentRuleList?
        do {
            list = try await WKContentRuleListStore.default().compileContentRuleList(
                forIdentifier: identifier,
                encodedContentRuleList: encodedRules
            )
        } catch {
            throw HTMLKitError.contentRulesUnavailable
        }
        guard let list else { throw HTMLKitError.contentRulesUnavailable }
        cached = list
        return list
    }
}
#endif
