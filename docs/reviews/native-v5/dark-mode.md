# Drawspeak iPadOS 27 dark-mode review

Source read-only; no Swift changes, builds, commits, or runtime interactions. Review date: 2026-11-04. Findings describe supplied PNG evidence and source; proposed snippets require implementation and runtime validation. Goal: compare and annotate screens while keeping controls legible in a dark workspace.

## Evidence and method

Opened all ten images individually: [dark-canvas](dark-canvas.png), [dark-comments](dark-comments.png), [dark-feedback](dark-feedback.png), [dark-settings](dark-settings.png), [dark-history](dark-history.png), [dark-addRegion](dark-addRegion.png), [dark-threads](dark-threads.png), [dark-canvases](dark-canvases.png), [light-canvas](light-canvas.png), [light-comments](light-comments.png). All are 1050 × 1400 pixels. Coordinates below are PNG pixels from the top left.

Read `/Users/rafalw/.claude/skills/swiftui-pro/SKILL.md` and references `design.md`, `accessibility.md`, `api.md`, `views.md`; and `/Users/rafalw/.claude/skills/apple-design/SKILL.md` with HIG `dark-mode.md`, `color.md`, `materials.md`, `liquid-glass.md`, `accessibility.md`, `layout.md`, `typography.md`, `designing-for-ios.md`. Rule paths below are relative to these skills. Inspected hard-coded RGB/hex/white/black/gray colors, UIKit color construction, materials, appearance overrides, image rendering, pins, chips, bubbles, snapshot cards, and relevant consumers across both requested source roots.

Contrast: Pillow sampled original PNG RGB values; dominant flat fills and solid glyph interiors avoid antialiased edge samples. WCAG sRGB calculation: linearize each channel with c/12.92 for c ≤ 0.04045, otherwise ((c+0.055)/1.055)^2.4; L = 0.2126R + 0.7152G + 0.0722B; ratio = (Llighter+0.05)/(Ldarker+0.05). Thresholds requested: 4.5:1 text, 3:1 functional glyphs. Translucent surfaces use their final screenshot pixels. Source-token calculations are explicitly distinguished from screenshot measurements. A missing appearance setting on an ImageRenderer is not automatically a defect if all rendered colors are intentionally fixed.

## Packages/DrawspeakKit/Sources/FeedbackKit/SendFeedbackButton.swift

### 1. P1 — Send label loses its contrasting foreground (lines 16–21)

[dark-canvas](dark-canvas.png), top-right “Send 1”, and [dark-canvases](dark-canvases.png) show black text on saturated blue; [light-canvas](light-canvas.png) has a white label. In dark-canvas rectangle (955,34)–(1038,77), dominant blue is **#1859BF**; black text contrast is **3.22:1**, below 4.5:1. White on that same fill is **6.53:1**. The fixed `Theme.actionFill` explicitly assumes a white label, but the prominent glass style selects black in dark appearance.

Rule: Apple Design `references/hig/dark-mode.md › Dark Mode colors`: “Aim for sufficient color contrast in all appearances.” `references/hig/accessibility.md › Vision`: “Strive to meet color contrast minimum standards.”

```swift
// Before
Text(count > 0 ? "Send \(count)" : "Send", bundle: .module)
    .monospacedDigit()
// After — constrain the label, retaining glass and its existing fill
Text(count > 0 ? "Send \(count)" : "Send", bundle: .module)
    .monospacedDigit()
    .foregroundStyle(.white)
```

Verify enabled, disabled and pressed states over both bright and dark content; keep disabled differentiation provided by the button style.

## Packages/DrawspeakKit/Sources/FeedbackKit/FeedbackSendAction.swift

### 2. P1 — Feedback confirmation repeats the black-on-blue label (lines 10–15)

[dark-feedback](dark-feedback.png), top-right Send: sampled blue **#195BC1**, black glyph interiors **#000000**, **3.30:1**; white would be **6.35:1**. The spinner already explicitly uses white, so the busy label and spinner also have inconsistent foregrounds. Related unpictured same-pattern consumer: `FeedbackDeliveryResult.swift:23–24` ready-to-send action; apply the fix there as well, but its rendered failure is not independently verified.

Rule: Apple Design `references/hig/dark-mode.md › Dark Mode colors`; `references/hig/accessibility.md › Vision` (same contrast rules as finding 1).

```swift
// Before
HStack {
    if model.busy { ProgressView().tint(.white) }
    Text("Send", bundle: .module)
}
// After
HStack {
    if model.busy { ProgressView().tint(.white) }
    Text("Send", bundle: .module).foregroundStyle(.white)
}
// FeedbackDeliveryResult.swift:23 — also explicitly style its Text("Send") white.
```

## App/Drawspeak/Settings/SettingsView.swift

### 3. P1 — Enabled toggle thumbs disappear into white tracks (lines 16–17, 47)

[dark-settings](dark-settings.png): “Record After Marking” and “Refine with Claude” look like solid white pills; unlike “Draw with Finger”, their knob boundary is invisible. The NavigationStack-wide `.tint(.primary)` makes the on track white in dark mode, matching the white thumb. Region (726,483)–(788,511) is overwhelmingly **#FFFFFF**; white thumb against white track is **1.00:1**, below 3:1 for the visible control indicator. Text itself is legible. This is an appearance-driven control-state defect, not a request to change toggle behavior.

Rule: Apple Design `references/hig/color.md › Inclusive color`: “Avoid using colors that make it hard to perceive content in your app.” `references/hig/dark-mode.md › Best practices`: test content in both appearances.

```swift
// Before
Toggle("Record After Marking", isOn: $autoVoice)
Toggle("Refine with Claude", isOn: $refineWithClaude)
// ... NavigationStack ends with .tint(.primary)
// After — scope the override to switches; repeat on Draw with Finger
Toggle("Record After Marking", isOn: $autoVoice).tint(Theme.actionFill)
Toggle("Refine with Claude", isOn: $refineWithClaude).tint(Theme.actionFill)
```

Source-token check: white thumb on #1758BD = **6.63:1**. Measure final rendered track/knob again, including Increase Contrast. Removing the global primary tint and accepting system switch styling is another valid fix, subject to measured contrast.

## App/Drawspeak/Sidebar/CanvasSidebar.swift

### 4. P2 — Selected canvas title has insufficient contrast (lines 12–16)

[dark-canvases](dark-canvases.png): “First review” is white on bright cyan. Dominant selection pixels in (18,89)–(308,153) are **#1BACFF** (also #1AABFF); white label is **2.50:1**, below 4.5:1 (and even below 3:1). This is system-selected row styling rather than a literal hard-coded cyan in `CanvasRow`; changing normal unselected text alone will not fix it.

Rule: Apple Design `references/hig/accessibility.md › Vision`; `references/hig/color.md › Inclusive color`.

```swift
// Before
List(selection: $selection) {
    ForEach(workspace.canvases) { canvas in
        CanvasSidebarRow(workspace: workspace, canvas: canvas, onRename: rename)
    }
}
// After — scope a contrasting selection tint to this list
List(selection: $selection) {
    ForEach(workspace.canvases) { canvas in
        CanvasSidebarRow(workspace: workspace, canvas: canvas, onRename: rename)
    }
}
.tint(Theme.actionFill)
```

Expected white on source tint #1758BD: **6.63:1**. Confirm that iPadOS 27 actually honors this tint for selected rows. If the system substitutes a lighter selection fill, supply an explicit selected-row background and selected foreground together, retaining List selection semantics. Do not report the expected source-token ratio as a tested runtime result.

## Packages/DrawspeakKit/Sources/CanvasKit/Views/SnapshotCard.swift

### 5. P1 — Large white snapshot backgrounds glare against the dark workspace (lines 29–45)

[dark-canvas](dark-canvas.png), Now and Proposal A, [dark-comments](dark-comments.png), [dark-feedback](dark-feedback.png), and [dark-canvases](dark-canvases.png) retain large #FFFFFF source-paper regions against approximately #181B1F canvas (**17.28:1** luminance contrast). This is glare judgment, not a WCAG failure: high contrast is appropriate for text but uncomfortable for enormous paper rectangles in a dark workspace. Imported screenshots must retain their actual source colors in storage and exports. The fixed white source is intentional content, not evidence that Theme.surface fails to adapt.

Rule: Apple Design `references/hig/dark-mode.md › Dark Mode colors`: “Soften the color of white backgrounds.” It specifically recommends slightly darkening content images with white backgrounds.

```swift
// Before
// Snapshot image / live HTML ZStack is displayed at source brightness.
.frame(width: slot.frame.width, height: slot.frame.height)
// After — display-only treatment on that content ZStack, before annotation layers
.brightness(colorScheme == .dark ? -0.10 : 0)
.frame(width: slot.frame.width, height: slot.frame.height)
```

Apply consistently to bitmap and live HTML presentation; keep annotations, selection outlines, and all saved/exported pixels unaffected. The amount is a design proposal, not an Apple-mandated value. A color-review workflow may need an explicit temporary original-color inspection action. Also treat display-only feedback/add-region thumbnails consistently if their white paper remains distracting; their smaller size makes them lower priority. Do not replace white with Theme.surface inside imported content.

### 6. P2 — Empty/dark snapshot edges recede into the canvas (lines 55–62)

[dark-canvas](dark-canvas.png), Proposal B: flat card **#24272B**, canvas **#181B1F**, **1.15:1**; the sampled inner edge includes **#30343A**, only **1.20:1** against the card. The half-point 20%-primary border plus black shadow scarcely separates a blank/dark card from the workspace. This matters for identifying the card extent before content appears. The 3:1 recommendation here concerns a functional boundary, not every decorative separator.

Rule: Apple Design `references/hig/dark-mode.md › Icons and images`: images need visible edges in both appearances; `references/hig/color.md › Inclusive color`. Applying a stronger boundary to this particular card is reviewer judgment.

```swift
// Before
.strokeBorder(CanvasMetrics.separator.opacity(colorScheme == .dark ? 1 : 0), lineWidth: 0.5)
// After — keep the stronger outline local to cards
.strokeBorder(
    colorScheme == .dark ? Theme.secondaryInk : .clear,
    lineWidth: 1
)
```

Measure final antialiased edge pixels; do not globally strengthen every separator. Prefer the stronger edge for selected/loading/empty dark cards if a permanent outline is visually excessive. Add a loading indicator to the blank card as a separate rendering-state improvement; see the evidence limitation below.

## Packages/DrawspeakKit/Sources/CanvasKit/Preview/MockScreenArt.swift

### 7. P2 — Preview renderer mixes fixed white paper with implicit label appearance (lines 12–18, 34–39)

Source-derived coverage defect, not a visible failure in the supplied images. [dark-canvas](dark-canvas.png) versus [light-canvas](light-canvas.png) demonstrates the white-paper content pattern this helper produces, but these screenshots use DemoContent rather than proving this helper failed. `MockScreenArt` fixes paper to white, leaves heading/title color implicit and uses semantic secondary text, then renders `self` with no declared colorScheme. If used directly in a dark preview, those labels resolve light on white; ImageRenderer's detached default can also differ from the preview environment. Make this intentionally light source document deterministic instead of relying on implicit renderer defaults.

Rule: SwiftUI Pro `references/api.md › Using modern SwiftUI API` (scoped environment override); Apple Design `references/hig/dark-mode.md › Best practices` (legible content in both appearances).

```swift
// Before
.background(.white)
// ...
let renderer = ImageRenderer(content: self)
// After — fixed source-art appearance, not an app-wide appearance override
.background(.white)
.environment(\.colorScheme, .light)
// ...
let renderer = ImageRenderer(content: self.environment(\.colorScheme, .light))
```

Apply the same deterministic source-art contract to `App/Drawspeak/Debug/DemoContent.swift:59–60`: `ImageRenderer(content: view.environment(\.colorScheme, .light))`. Existing PNG text is black and readable, so there is no demonstrated current DemoContent contrast failure. Display glare remains finding 5.

## Checked without an additional defect

- Theme.swift already has light/dark variants for action, canvas, surface, ink, secondary ink, and component outlines. UIKit dynamic-color construction selects dark correctly on iPadOS; its non-UIKit light-only fallback does not affect this iPad review.
- Fixed red annotation #BD3048 and white numbers have **5.71:1** contrast. White halos are deliberate boundaries over arbitrary source images; replacing them with a dark semantic background would reduce mark visibility on some screenshots. PinBadge, PinButton and CompositeCanvas share this intentional contract.
- `CompositeRenderer.swift:12` has no colorScheme injection, but CompositeCanvas draws a CGImage and intentionally fixed annotation/halo/number colors. No adaptive foreground is being lost: absence of injection is not itself a defect. FeedbackFixtureImage explicitly pairs white paper and black labels.
- Comment bubble in dark-comments adapts to a dark fill and readable white text; light-comments confirms the corresponding light state. No light-only bubble/chip defect established. Palette fallbacks observe Reduce Transparency. Regular materials and system sheets adapt rather than forcing light appearance.
- History empty state, Add Region controls and thread-picker search/loading state are legible in the provided images. `dark-threads.png` shows Choose Thread, not the pairing form; pairing was inspected in source only. No pairing screenshot or successful populated-thread state was supplied.
- Proposal B is blank in dark-canvas but visible in dark-feedback/history/addRegion and light-canvas. `LiveHTMLLayer.swift:37–43` hides the web view until loaded; SnapshotCard has no placeholder when capture is absent. This supports a transient loading-state explanation, not a proven dark-only rendering failure. Capture/live appearance parity and loading/error states need runtime verification; do not claim dark mode makes the HTML text invisible.
- No forced light app-wide appearance, fixed light material, or unconditional black app-chrome label was found in the searched roots. The before/after fixes are proposals, not compile-tested changes. Increase Contrast, Reduce Transparency combinations, Auto appearance changes, selected/populated threads, pairing, delivery-result states and actual devices were not exercised.

## Prioritized list

1. **P1:** Explicitly contrast Send labels against blue fills in SendFeedbackButton and FeedbackSendAction; cover FeedbackDeliveryResult's matching action.
2. **P1:** Give Settings toggles contrasting on tracks so their thumbs and states remain visible.
3. **P1:** Soften snapshot paper in dark presentation while preserving original imported/exported pixels.
4. **P2:** Darken the sidebar selection fill or pair it with a contrasting selected label; current white/cyan is 2.50:1.
5. **P2:** Strengthen functional edges of dark/empty snapshot cards.
6. **P2:** Declare the fixed light appearance of white-paper preview/demo renderers explicitly; verify direct dark previews.
