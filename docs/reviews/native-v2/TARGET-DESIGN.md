# Drawspeak v2 — target design and module contracts

Decided by the main agent from `apple-design.md`, `swiftui-pro-A.md`, `swiftui-pro-B.md` (this folder). Owner feedback: "too much text", "does not meet apple-design", "has errors swiftui-pro warns about". Reference model: Apple Freeform on iPad.

## Principles

- Native chrome: one `.toolbar` with `.toolbarRole(.editor)` and Liquid Glass groups; no custom floating palettes except a small zoom menu at bottom leading.
- Text: labels only. No explanatory footers or hints that repeat what the UI shows. Keep only text that prevents an error (ElevenLabs upload/billing line; delivery-unknown warning). Vocabulary: Screen, Now, Proposal, Version, Comment, Thread. Title Case for buttons/titles. Plurals via `^[\(n) comment](inflect: true)`. No "we".
- Color: only Send is tinted (Theme.actionFill). Annotations are Theme.annotation (fixed red with white halo). Everything else monochrome (`.primary`/`.secondary`).
- Every user-facing string in a package uses that module's bundle (`Text("…", bundle: .module)`, `String(localized: "…", bundle: .module)`), with a `Resources/Localizable.xcstrings` per module (already present, empty). English only for now.
- Sheets: inline title, `Button(role: .close)` leading, labeled confirm trailing for task sheets. No in-body Done/Back buttons. Size forms with `.presentationSizing(.form)` on iPad; no detents on regular width.
- Swift/SwiftUI: follow `/Users/rafalw/.claude/skills/swiftui-pro` references strictly (one type per file, subviews as structs, no `Binding(get:set:)` in body, no heavy work/decoding in `body` or on MainActor, Dynamic Type safe layouts, VoiceOver labels, Reduce Motion, adaptive to window size incl. compact width).
- Keep PRD features: Save Draft stays (AC-10); Add Region without drawing stays reachable (P-07) from the comments inspector and the card accessibility action.

## Main screen (App shell)

```
┌ NavigationSplitView (sidebar hidden by default: Canvases list, thread as subtitle, New Canvas) ┐
│ [sidebar] [Title ▾]        [hand][region][arrow][pen][component] | [undo][redo]    [+][💬][⋯] [Send 3] │
│                                                                                                         │
│   Checkout                                                                                              │
│   Now            Proposal A ▾        Proposal B ▾  [hand.tap]                                           │
│   ┌──────┐       ┌──────┐            ┌──────┐                                    ┌ Comments (inspector) ┐│
│   │      │       │      │            │      │                                    │ ① Pay button…       ││
│   │ ①▭  │       │      │            │      │                                    │   [editor, live text]││
│   └──────┘       └──────┘            └──────┘                                    │   ● 0:07 ▁▃▅ [Stop] ││
│                                                                                  │ ② …                 ││
│ [64% ▾]                                                                          └──────────────────────┘│
└─────────────────────────────────────────────────────────────────────────────────────────────────────────┘
```

- Title menu (toolbar `ToolbarTitleMenu`): Rename, Choose Thread… (shows current thread as subtitle via `.navigationSubtitle`), Pull Versions, Drafts and Sent, Settings.
- `+` menu: Import Image or HTML…, Add Region…
- 💬 toggles `.inspector(isPresented:)` with `CommentsInspector` (`.inspectorColumnWidth(min: 300, ideal: 360, max: 440)`). Opening a comment (pin tap) opens the inspector and selects it.
- Send: `.buttonStyle(.glassProminent)` tinted Theme.actionFill, label "Send" + count badge; opens the feedback preview as a popover (sheet in compact width). With no thread, the preview's To row offers Choose Thread.
- Zoom: small `ZoomMenu` bottom leading (percentage menu: Zoom In, Zoom Out, Fit All, 100%).
- Pencil Pro squeeze: system `.popover` anchored at the hover point with the tool controls.
- No bottom recording bar: recording UI lives in the selected comment row of the inspector (and the pulsing ring at the mark on canvas).

## Module contracts (public API)

- CanvasKit: `CanvasView(workspace:tool:drawWithFinger:overlayInsets:squeezeAnchor:onSqueeze:onAddRegion:)` unchanged; new `CanvasToolControls(tool: Binding<CanvasTool>)` (content for a `ToolbarItemGroup`, each tool a toggle-style button with symbol, VoiceOver label, keyboard shortcut, selected state not by color alone); new `ZoomMenu(zoom: Double, onZoomIn:onZoomOut:onFitAll:onActualSize:)`. `ToolPalette`/`ZoomControls` may be removed. Lane headers monochrome, version menu only when >1 version, Try icon-only, no tool-name overlay, no "Interacting" banner (keep an icon-only Done toggle state on the Try button).
- NotesKit: new `CommentsInspector(workspace: Workspace, onShowSource: (UUID) -> Void, onAddRegion: () -> Void)` — comments grouped by screen; `workspace.focusedNoteId` is the selection; the selected row expands inline: multi-line `TextField(axis: .vertical)` autosaving, live text from `workspace.liveText(for:)` while recording, a compact recording row (red dot, level, timer, red Stop, Discard in a menu), Record button when idle, transcript states as small inline status, More menu (Show on Canvas, Delete). `AddRegionSheet` as a centered form. `RecordingBar`, `NoteInspector`, `NotesListView` may be removed after the app stops using them.
- FeedbackKit: `FeedbackPreviewSheet(workspace:canvasId:initialSelection:onChooseThread:onClose:)` unchanged signature, redesigned to work in a popover (inline title, Close leading, Send trailing with progress inside the button, To row, comments grouped by screen with system-style selection, result state replaces content). `SendFeedbackButton(workspace:action:)` for the toolbar (replaces `FeedbackButton`). `DraftsAndHistoryView` rows headline = recipient/date, not batch id.
- T3Kit: `T3PairingView(connection:onPaired:)` and `T3ThreadPickerView(service:selected:onPick:)` unchanged signatures; no nested NavigationStack inside them; pairing = Host, Code, Connect (toolbar confirm) + one footer line; access level as one compact row; thread rows on two lines.
