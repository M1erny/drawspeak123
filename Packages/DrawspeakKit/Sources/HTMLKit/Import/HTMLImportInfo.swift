import DrawspeakCore
import Foundation

/// What an imported HTML document says about itself before it is rendered.
nonisolated public struct HTMLImportInfo: Sendable, Hashable {
    /// Text of `<title>`, or nil when missing or empty.
    public var title: String?
    /// True when the document has `<script>` elements or inline event handlers;
    /// the UI notes that scripts do not run in static mode.
    public var containsScripts: Bool
    /// From `data-review-viewport="WxH"` on `<html>`/`<body>`, else
    /// `<meta name="viewport" content="width=N">`, else `Viewport.defaultHTML`.
    public var suggestedViewport: Viewport

    public init(title: String?, containsScripts: Bool, suggestedViewport: Viewport) {
        self.title = title
        self.containsScripts = containsScripts
        self.suggestedViewport = suggestedViewport
    }
}
