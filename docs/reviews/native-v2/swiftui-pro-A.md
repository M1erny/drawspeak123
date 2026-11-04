Review basis: all 109 Swift files in the requested three trees, plus their plist, asset metadata and JavaScript resource; Package.swift declares Swift tools 6.4 and iOS 27; project.yml declares iOS 27, Swift language mode 6.0 and default MainActor isolation. Review assumes the requested Xcode 27 toolchain; it was not built here. All eleven required references were read; performance-plus.md was excluded. Snippets illustrating new view/model/theme types are proposed refactor sketches, not compiled patches. No builds, tests, simulator or accessibility/contrast measurements were run. The offscreen WebKit capture, isolated content-world DOM bridge and Pencil-force input are integration-specific UIKit uses; a blanket WebView rewrite is not recommended without proving equivalent isolation/snapshot/input behavior. UIImage in WebKit snapshot encoding is needed by that API. Existing @ViewBuilder, @State caches/reference owners, and let-held observable models without binding requirements are not violations. navigationBarTitleDisplayMode is not prohibited by the supplied references. Launch-screen configuration and core-logic test files exist. No source files were edited and no commit was created. Layout/accessibility impacts are source-based findings, not simulator reproductions. Concurrent changes outside the reviewed source trees were observed during the review and were left untouched.

### App/Drawspeak/App/AppModel.swift

**Lines 40: Localize interface strings created outside SwiftUI.** Rule: `swift.md; localization.md`.

The recovery view interpolates this already-created String verbatim. The English sentence has no extracted localization key.

```swift
// Before
loadError = "Drawspeak could not open its storage."

// After
loadError = String(localized: "Drawspeak could not open its storage.")
```

**Lines 48: Show failures caused by user actions.** Rule: `swift.md`.

Start Empty Library silently does nothing if obtaining the storage location fails. Preserve the error in the recovery UI.

```swift
// Before
guard let locations = try? StorageLocations.applicationSupport() else { return }

// After
do {
    let locations = try StorageLocations.applicationSupport()
    // Start the replacement library.
} catch {
    loadError = String(localized: "Drawspeak could not open its storage.")
}
```

### App/Drawspeak/App/LibraryRecoveryView.swift

**Lines 17–24: Extract button actions; attach confirmation dialogs to their triggering controls.** Rule: `views.md; navigation.md`.

The destructive dialog is attached to the entire unavailable view, rather than Start with an Empty Library. Its load/retry tasks also belong in named actions.

```swift
// Before
Button("Start with an Empty Library…") { confirmsFresh = true }
// Dialog attached to ContentUnavailableView.

// After
Button("Start with an Empty Library…", action: requestFreshLibrary)
    .confirmationDialog("Start with an empty library?", isPresented: $confirmsFresh) {
        Button("Start Empty Library", role: .destructive, action: startFresh)
    }
// Named startFresh/retry methods launch the corresponding tasks.
```

### App/Drawspeak/Canvas/BannerView.swift

**Lines 9–15, 27–28: Centralize spacing and avoid arbitrary semibold weights.** Rule: `design.md`.

Several literal spacing/padding values and a semibold override bypass the shared design constants. This is a low-priority explicit skill rule, not a claim of measured contrast failure.

```swift
// Before
HStack(alignment: .top, spacing: 12) { /* … */ }
Text(banner.message).font(.subheadline.weight(.semibold))

// After
HStack(alignment: .top, spacing: Theme.bannerSpacing) { /* … */ }
Text(banner.message).font(.subheadline)
// Define the proposed banner spacing/insets in the shared theme.
```

### App/Drawspeak/Canvas/CanvasActionsPalette.swift

**Lines 47: Use shared spacing/padding constants.** Rule: `design.md`.

Low priority: the reference explicitly discourages scattered hard-coded spacing/padding. Define the proposed semantic constant in the shared theme rather than merely relocating a literal to another view.

```swift
// Before
.padding(.horizontal, 4)

// After
.padding(.horizontal, Theme.actionPaletteInset)
```

### App/Drawspeak/Canvas/CanvasBanner.swift

**Lines 7–23: Localize generated messages and use grammatical number agreement.** Rule: `api.md; localization.md; swift.md`.

Manual English suffixes and String storage bypass extraction and cannot support languages with other plural categories. Localize the full sentence, including interpolated counts.

```swift
// Before
message = "Added \(report.importedSnapshots) version\(report.importedSnapshots == 1 ? "" : "s") from the thread"

// After
message = String(localized: "Added ^[\(report.importedSnapshots) version](inflect: true) from the thread",
                 comment: "Count is the number of newly imported versions.")
// Localize the other status literals too; supply plural variations in localization resources.
```

### App/Drawspeak/Canvas/CanvasChrome.swift

**Lines 55–65: Preserve feature access at every window size.** Rule: `design.md; resizability.md`.

Compact width sets the only zoom palette to zero opacity. Fit All has no equivalent touch/VoiceOver action elsewhere in the app chrome; a pinch does not replace Fit All.

```swift
// Before
ZoomControls(/* … */)
    .opacity(horizontalSizeClass == .compact ? 0 : 1)

// After
ViewThatFits {
    ZoomControls(/* … */)
    Menu("Zoom", systemImage: "plus.magnifyingglass") {
        Button("Fit All", action: actions.fitAll)
        Button("Zoom In", action: actions.zoomIn)
        Button("Zoom Out", action: actions.zoomOut)
    }
}
```

**Lines 38–68: Provide adaptive layouts instead of overlapping fixed horizontal palettes.** Rule: `design.md; resizability.md`.

The bottom ZStack centers a roughly 353-point tool palette while anchoring a roughly 250-point zoom palette at the leading edge. They overlap even in medium regular windows. The top row also has no compact fallback despite receiving the size class. Use a layout that measures available space.

```swift
// Before
ZStack(alignment: .bottom) {
    ToolPalette(/* … */).frame(maxWidth: .infinity)
    ZoomControls(/* … */).frame(maxWidth: .infinity, alignment: .leading)
}

// After
ViewThatFits(in: .horizontal) {
    HStack { ZoomControls(/* … */); Spacer(); ToolPalette(/* … */) }
    VStack { ZoomControls(/* … */); ToolPalette(/* … */) }
}
// Give the title/actions row an equivalent compact alternative.
```

**Lines 9–25: Put every type in its own Swift file.** Rule: `views.md`.

CanvasChrome.Actions is a second type declaration in the view file.

```swift
// Before
struct CanvasChrome: View {
    struct Actions { /* callbacks */ }
}

// After
// CanvasChromeActions.swift
struct CanvasChromeActions { /* callbacks */ }
// CanvasChrome.swift
struct CanvasChrome: View { let actions: CanvasChromeActions /* … */ }
```

**Lines 38–68: Reserve space for custom bars with safeAreaBar.** Rule: `resizability.md; api.md`.

The bars overlay the canvas while CanvasScreen and CanvasSidePanels independently guess their heights using 72/84/88/96-point constants. Dynamic Type and resized rows invalidate those guesses.

```swift
// Before
VStack { topPalettes; Spacer(); bottomPalettes }

// After
canvas
    .safeAreaBar(edge: .top) { CanvasTopBar(/* … */) }
    .safeAreaBar(edge: .bottom) { CanvasBottomBar(/* … */) }
// Proposed extracted views; keep world geometry separate from bar layout.
```

### App/Drawspeak/Canvas/CanvasListSheet.swift

**Lines 53–81: Use optional-item alerts/dialogs rather than closure Boolean bindings.** Rule: `navigation.md; data.md`.

Both presentations are driven by optional records but reconstruct Binding<Bool> during body evaluation. Xcode 27 item overloads provide the record and clear it on dismissal.

```swift
// Before
 .alert("Rename Canvas", isPresented: renameBinding) { /* … */ }
 .confirmationDialog("Delete…", isPresented: deleteBinding) { /* … */ }

// After
 .alert("Rename Canvas", item: $renaming) { canvas in
     TextField("Title", text: $newTitle)
     Button("Rename") { rename(canvas) }
 }
 .confirmationDialog("Delete Canvas?", item: $pendingDelete) { canvas in
     Button("Delete Canvas", role: .destructive) { delete(canvas) }
 }
// Remove renameBinding and deleteBinding.
```

**Lines 62–72: Attach a confirmation dialog to the triggering control.** Rule: `navigation.md`.

The delete dialog is attached to List rather than the row invoking deletion. Keep item-driven presentation on the originating row (a separate row view can own pending deletion).

```swift
// Before
List { /* rows with Delete actions */ }
    .confirmationDialog(/* … */)

// After
CanvasListRow(/* … */)
// In CanvasListRow: attach the item-driven dialog to its row button,
// with both swipe/context Delete actions driving that row’s pending item.
```

**Lines 14–73: Extract long bodies and multi-step button logic.** Rule: `views.md`.

Selection, renaming, deletion and canvas creation are mixed into a roughly 60-line body. Extract row/presentation views and named action methods.

```swift
// Before
Button("New Canvas", systemImage: "plus") {
    workspace.createCanvas(title: "Review \(workspace.canvases.count + 1)", thread: nil)
    dismiss()
}

// After
Button("New Canvas", systemImage: "plus", action: createCanvas)
// Move selection/rename/delete/create logic to methods; rows to CanvasListRow.swift.
```

**Lines 48: Localize default names produced by actions.** Rule: `swift.md; localization.md`.

Generated default canvas titles contain an English prefix created as a plain String.

```swift
// Before
workspace.createCanvas(title: "Review \(workspace.canvases.count + 1)", thread: nil)

// After
let title = String(localized: "Review \(workspace.canvases.count + 1)",
                   comment: "Number distinguishes automatically named review canvases.")
workspace.createCanvas(title: title, thread: nil)
```

### App/Drawspeak/Canvas/CanvasRow.swift

**Lines 13: Localize fallback text before combining it with runtime content.** Rule: `localization.md`.

The nil-coalescing expression is a runtime String, so Text does not extract No thread.

```swift
// Before
Text(canvas.thread?.displayName ?? "No thread")

// After
if let thread = canvas.thread {
    Text(thread.displayName)
} else {
    Text("No thread")
}
```

**Lines 9–10: Use shared spacing/padding constants.** Rule: `design.md`.

Low priority: the reference explicitly discourages scattered hard-coded spacing/padding. Define the proposed semantic constant in the shared theme rather than merely relocating a literal to another view.

```swift
// Before
VStack(alignment: .leading, spacing: 2) { /* … */ }

// After
VStack(alignment: .leading, spacing: Theme.canvasRowSpacing) { /* … */ }
```

**Lines 16: Explain interpolated count placeholders to translators.** Rule: `localization.md`.

The inflected sentence correctly uses automatic grammar agreement, but its two numeric placeholders have no translator context.

```swift
// Before
Text("^[\(canvas.snapshots.count) version](inflect: true) · ^[\(canvas.notes.count) comment](inflect: true)")

// After
Text("^[\(canvas.snapshots.count) version](inflect: true) · ^[\(canvas.notes.count) comment](inflect: true)",
     comment: "First count is versions in this canvas; second count is comments in this canvas.")
```

### App/Drawspeak/Canvas/CanvasScreen.swift

**Lines 30–107, 139–188: Extract oversized bodies and view-returning helper methods into View structs.** Rule: `views.md`.

The body spans 78 lines; sheetContent is another 50-line builder containing multiple separate presentation concerns. This exceeds the small-helper exception.

```swift
// Before
 .sheet(item: $sheet) { sheet in sheetContent(sheet) }

// After
 .sheet(item: $sheet) { selection in
     CanvasSheetContent(selection: selection, workspace: workspace, model: model, /* callbacks */)
 }
// CanvasSheetContent.swift owns the switch; extract the canvas overlays too.
```

**Lines 109–112: Put each type in its own Swift file.** Rule: `views.md`.

TaskKey is an additional struct inside CanvasScreen.

```swift
// Before
private struct TaskKey: Equatable { var canvasId: UUID?; var hasSize: Bool }

// After
// CanvasTaskKey.swift
struct CanvasTaskKey: Equatable { var canvasId: UUID?; var hasSize: Bool }
```

**Lines 36–42, 198–224: Keep interactive content within safe areas and derive clearance from actual layout.** Rule: `resizability.md; design.md`.

The whole interactive CanvasView ignores all safe areas; framing then uses fixed chrome/inspector widths. Controls and framed marks can land behind bars or outside a narrow window. Background extension alone is appropriate for the decorative canvas.

```swift
// Before
CanvasView(/* … */).ignoresSafeArea()
let inspectorMinX = viewSize.width - 412

// After
CanvasView(/* … */)
    .background { Theme.canvas.ignoresSafeArea() }
// Reserve real bars/inspector through system containers and pass the
// resulting available canvas region to framing instead of subtracting 412.
```

**Lines 61–65: Prefer system popovers to manually positioned palettes.** Rule: `resizability.md; design.md`.

The squeeze palette clamps only y; near a window’s left/right edges its fixed width extends offscreen. It also does not adapt to larger text.

```swift
// Before
ToolPalette(/* … */).fixedSize()
    .position(x: squeezeAnchor.x, y: max(squeezeAnchor.y - 60, 80))

// After
// Attach a system popover to the squeeze anchor in canvas coordinates.
anchorView.popover(isPresented: $showsSqueezePalette) {
    ToolPalette(/* … */)
}
```

**Lines 231: Report file-importer failures instead of swallowing them.** Rule: `swift.md`.

The guard discards every .failure, including provider/access errors. Cancellation may remain silent; other errors need a visible banner.

```swift
// Before
guard case .success(let urls) = result, let url = urls.first else { return }

// After
switch result {
case .success(let urls): /* read first URL */ break
case .failure(let error):
    // Ignore user cancellation only.
    banner = CanvasBanner(message: ImportFailure(error).message, isError: true)
}
```

**Lines 233, 251: Localize complete banner sentences outside SwiftUI.** Rule: `swift.md; localization.md`.

Preparing and Added messages are plain interpolated Strings passed through CanvasBanner into Text.

```swift
// Before
banner = CanvasBanner(message: "Preparing \(url.lastPathComponent)…", isError: false)

// After
banner = CanvasBanner(message: String(localized: "Preparing \(url.lastPathComponent)…",
    comment: "Placeholder is the imported file name."), isError: false)
// Apply the same pattern to Added <version> of <screen>.
```

**Lines 81–103: Move lifecycle business logic into named methods.** Rule: `views.md`.

Initial framing, debug routing and background persistence are inline in body callbacks.

```swift
// Before
 .task(id: TaskKey(/* … */)) {
     guard let canvas = workspace.currentCanvas, /* … */ else { return }
     fitAll()
 }

// After
 .task(id: CanvasTaskKey(/* … */), initialFrameIfNeeded)
// Put the guards/framing in initialFrameIfNeeded(); extract setup and scene handling too.
```

### App/Drawspeak/Canvas/CanvasSidePanels.swift

**Lines 14–25, 48: Use inspector for an adjacent detail panel.** Rule: `resizability.md`.

The custom trailing overlay remains up to 380 points wide in compact windows and has guessed top/bottom clearance. A system inspector provides a column at regular width and a sheet at compact width.

```swift
// Before
HStack { Spacer(); NoteInspector(/* … */).frame(maxWidth: 380) }

// After
canvas.inspector(isPresented: $presentation.isInspectorPresented) {
    NoteInspector(/* … */)
}
// Proposed observable presentation property must clear focusedNoteId on dismissal.
```

**Lines 21, 51: Respect Reduce Motion for large slide transitions.** Rule: `accessibility.md`.

The inspector always slides in/out with .snappy regardless of the accessibility setting. CanvasView’s separate camera handling does not cover this transition.

```swift
// Before
 .transition(.move(edge: .trailing).combined(with: .opacity))
 .animation(.snappy, value: workspace.focusedNoteId)

// After
@Environment(\.accessibilityReduceMotion) private var reduceMotion
// On the panel:
.transition(reduceMotion ? .opacity : .move(edge: .trailing).combined(with: .opacity))
.animation(reduceMotion ? .easeInOut : .snappy, value: workspace.focusedNoteId)
```

**Lines 32–35: Move task logic out of body and preserve cancellation.** Rule: `views.md; performance.md`.

Auto-dismiss is inline and try? continues after cancellation. A named helper can return on cancellation before touching presentation state.

```swift
// Before
 .task(id: banner.id) {
     try? await Task.sleep(for: .seconds(banner.isError ? 12 : 5))
     if self.banner?.id == banner.id { self.banner = nil }
 }

// After
 .task(id: banner.id) { await dismissAfterDelay(banner) }
// In dismissAfterDelay:
do { try await Task.sleep(for: delay) } catch { return }
if self.banner?.id == banner.id { self.banner = nil }
```

### App/Drawspeak/Canvas/CanvasTitlePalette.swift

**Lines 17, 36: Localize fallback labels and interpolated accessibility text.** Rule: `localization.md`.

Both expressions create runtime Strings; the app’s fallback and Thread prefix bypass extraction.

```swift
// Before
Text(canvas?.title ?? "No canvas")
.accessibilityLabel(canvas?.thread.map { "Thread: \($0.displayName)" } ?? "No thread. Choose a T3 thread")

// After
// Show Text("No canvas") in the nil branch.
.accessibilityLabel(threadAccessibilityLabel)
// threadAccessibilityLabel returns Text("Thread: \(thread.displayName)")
// or Text("No thread. Choose a T3 thread"), retaining literal keys.
```

**Lines 14, 24, 34: Use shared spacing/padding constants.** Rule: `design.md`.

Low priority: the reference explicitly discourages scattered hard-coded spacing/padding. Define the proposed semantic constant in the shared theme rather than merely relocating a literal to another view.

```swift
// Before
HStack(spacing: 4) { /* … */ }

// After
HStack(spacing: Theme.titlePaletteSpacing) { /* … */ }
```

### App/Drawspeak/Canvas/EmptyCanvasView.swift

**Lines 22: Use shared spacing/padding constants.** Rule: `design.md`.

Low priority: the reference explicitly discourages scattered hard-coded spacing/padding. Define the proposed semantic constant in the shared theme rather than merely relocating a literal to another view.

```swift
// Before
.padding(24)

// After
.padding(Theme.emptyCanvasInset)
```

### App/Drawspeak/Canvas/ThreadBindingSheet.swift

**Lines 17–25, 34, 37–38: Extract actions and omit redundant dismiss-only OK buttons.** Rule: `views.md; navigation.md`.

Thread binding logic is inline, Cancel wraps dismiss(), and the alert’s only OK action has no behavior.

```swift
// Before
Button("Cancel") { dismiss() }
.alert("This canvas already sent feedback to another thread", isPresented: $rejected) {
    Button("OK", role: .cancel) {}
}

// After
Button("Cancel", action: dismiss.callAsFunction)
.alert("This canvas already sent feedback to another thread", isPresented: $rejected) {}
// Extract the picker callback into bindThread(_:) as well.
```

**Lines 30: Give conditional navigation titles a localizable type.** Rule: `localization.md`.

A ternary of string literals can resolve to String, selecting verbatim runtime text rather than literal-key extraction. Make the title type explicit.

```swift
// Before
 .navigationTitle(connection.threadService == nil ? "Connect to T3 Code" : "Choose Thread")

// After
private var title: LocalizedStringResource {
    connection.threadService == nil ? "Connect to T3 Code" : "Choose Thread"
}
// In body:
.navigationTitle(title)
```

### App/Drawspeak/Canvas/ThreadLabel.swift

**Lines 12–15: Expose meaningful status images to VoiceOver.** Rule: `accessibility.md`.

Connection status is shown only by a hidden icon. The parent button overrides its accessibility label with just the thread name, so connected/connecting/failed is unavailable there.

```swift
// Before
Image(systemName: statusSymbol).accessibilityHidden(true)

// After
// Keep the decorative icon hidden, but expose status on the parent button:
.accessibilityValue(connectionStatusText)
// connectionStatusText must be localized and distinguish the connection states.
```

**Lines 23: Avoid unnecessary semibold font overrides.** Rule: `design.md`.

The Choose Thread label arbitrarily increases a system subheadline weight.

```swift
// Before
 .font(.subheadline.weight(.semibold))

// After
 .font(.subheadline)
```

### App/Drawspeak/Debug/DebugEndToEnd.swift

**Lines 57–59: Use modern Foundation directory access.** Rule: `swift.md`.

The debug report uses the old FileManager document-directory lookup.

```swift
// Before
guard let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first,
      let data = try? JSONSerialization.data(withJSONObject: report) else { return }

// After
let directory = URL.documentsDirectory
guard let data = try? JSONSerialization.data(withJSONObject: report) else { return }
```

### App/Drawspeak/Debug/DemoContent.swift

**Lines 40, 44: Use builder overlays instead of the soft-deprecated view overload.** Rule: `api.md`.

Both debug-rendered artwork overlays pass a view argument. The rule also applies to debug code.

```swift
// Before
 .overlay(Text("Item \(index + 1)").font(.title3))
 .overlay(Text(button).font(.title2.bold()).foregroundStyle(.white))

// After
 .overlay { Text("Item \(index + 1)").font(.title3) }
 .overlay { Text(button).font(.title2.bold()).foregroundStyle(.white) }
```

### App/Drawspeak/Import/ImportCoordinator.swift

**Lines 18, 32, 38, 67, 69: Localize user-facing error strings outside SwiftUI.** Rule: `swift.md; localization.md`.

These English strings become verbatim banner messages; they need localization where created.

```swift
// Before
ImportFailure(message: "The HTML could not be rendered.")

// After
ImportFailure(message: String(localized: "The HTML could not be rendered."))
// Apply to file-read and image-decode failures too.
```

### App/Drawspeak/Import/ImportFailure.swift

**Lines 13–17: Localize full error messages including placeholders.** Rule: `swift.md; localization.md`.

The error type creates all messages as unlocalized Strings.

```swift
// Before
message = "The file is larger than \(limit) MiB."

// After
message = String(localized: "The file is larger than \(limit) MiB.",
                 comment: "Maximum allowed file size in mebibytes.")
// Localize the invalid-viewport, unsupported-type and generic errors too.
```

### App/Drawspeak/Import/ImportTargetSheet.swift

**Lines 17, 26–29: Extract action logic and provide translator context for formatted dimensions.** Rule: `views.md; localization.md`.

The title normalization/target construction belongs in an action; the dimension placeholders have no translator explanation.

```swift
// Before
Button("Add as New Screen", systemImage: "rectangle.badge.plus") {
    let title = newScreenTitle.trimmingCharacters(in: .whitespaces)
    onChoose(.newScreen(title: title.isEmpty ? pending.suggestedTitle : title))
}

// After
Button("Add as New Screen", systemImage: "rectangle.badge.plus", action: addNewScreen)
// Keep the existing action behavior in addNewScreen().
// Add a localization comment: first dimension is width, second height, in pixels.
```

### App/Drawspeak/Import/ScreenTargetSection.swift

**Lines 10, 20–21: Derive collection data outside repeatedly evaluated body.** Rule: `performance.md`.

Each evaluation searches proposals and computes the next proposal twice. Supply a prepared row model from the import-target model, invalidated when the canvas changes.

```swift
// Before
let proposals = canvas.map { CanvasLayout.proposalIds(in: $0, screen: screen) } ?? []

// After
// Prepared on canvas/screen changes, not through an uninvalidated State cache:
let proposals = model.proposalIDs
let nextProposalID = model.nextProposalID
```

### App/Drawspeak/Settings/ElevenLabsKeySection.swift

**Lines 19–23, 45–50: Show user-action failures and extract button logic.** Rule: `swift.md; views.md`.

When Keychain save returns false, Save silently does nothing. Removal logic is also inline in body.

```swift
// Before
if ElevenLabsKeyStore().save(draft) {
    hasKey = true
    draft = ""
    isFocused = false
    onChange()
}

// After
guard ElevenLabsKeyStore().save(draft) else {
    showsSaveError = true
    return
}
// Retain success handling; present a localized alert for showsSaveError.
// Extract Remove Key into removeKey().
```

### App/Drawspeak/Settings/SettingsView.swift

**Lines 50: Pass an existing button action directly.** Rule: `views.md`.

The body closure only forwards to dismiss.

```swift
// Before
Button("Done") { dismiss() }

// After
Button("Done", action: dismiss.callAsFunction)
```

### App/Drawspeak/Settings/T3ConnectionSection.swift

**Lines 20, 25, 27, 41: Extract actions and localize conditional button labels.** Rule: `views.md; localization.md`.

Reconnect task logic is in body; the conditional pairing title is an inferred runtime String.

```swift
// Before
Button(connection.canReconnect ? "Pair Again…" : "Connect to T3 Code…") { showsPairing = true }

// After
private var pairingTitle: LocalizedStringResource {
    connection.canReconnect ? "Pair Again…" : "Connect to T3 Code…"
}
// In body:
Button(pairingTitle, action: showPairing)
// Extract reconnect()/disconnect() actions too.
```

**Lines 48–55: Localize generated connection status values.** Rule: `localization.md; swift.md`.

LabeledContent displays statusText as a verbatim String; status literals are never localized.

```swift
// Before
case .notPaired: "Not connected"
case .connecting: "Connecting…"

// After
case .notPaired: String(localized: "Not connected")
case .connecting: String(localized: "Connecting…")
// Localize Connected/Pairing expired too; preserve provider error content.
```

### Packages/DrawspeakKit/Sources/CanvasKit/Logic/CanvasLabels.swift

**Lines 7–45: Localize complete labels, grammar and display lists.** Rule: `localization.md; api.md; swift.md`.

Every helper returns unlocalized English. card/componentChip manually select singular/plural; card joins a user-facing list with an English delimiter. pin truncation is content summarization and does not itself require replacement.

```swift
// Before
parts.append(commentCount == 1 ? "1 comment" : "\(commentCount) comments")
return parts.joined(separator: ", ")

// After
parts.append(String(localized: "^[\(commentCount) comment](inflect: true)",
    bundle: #bundle, comment: "Number of comments on the selected version."))
return parts.formatted(.list(type: .and))
// Localize revision, iteration, screen, pin, depth and layer sentence templates
// in this package’s resources, with placeholder comments and plural variants.
```

### Packages/DrawspeakKit/Sources/CanvasKit/Logic/CanvasTool.swift

**Lines 14–20: Localize interface titles stored outside views.** Rule: `localization.md; swift.md`.

All tool names are Strings used by Button/Text/help, so no literal SwiftUI localization key survives.

```swift
// Before
case .hand: "Hand"

// After
case .hand: String(localized: "Hand", bundle: #bundle,
                   comment: "Canvas navigation tool, not a body part.")
// Apply to Region, Arrow, Pen and Component, or carry LocalizedStringResource.
```

### Packages/DrawspeakKit/Sources/CanvasKit/Models/CanvasInteraction.swift

**Lines 169, 194, 221, 290, 318, 325, 357: Localize status messages at their source.** Rule: `localization.md; swift.md`.

These user-facing sentences are passed as plain Strings to CanvasStatus.show.

```swift
// Before
status.show("Images have no components. Draw a region instead.")

// After
status.show(String(localized: "Images have no components. Draw a region instead.", bundle: #bundle))
// If CanvasStatus is changed to resource input, pass LocalizedStringResource
// instead. Apply consistently to every loading/inspection/drawing hint.
```

### Packages/DrawspeakKit/Sources/CanvasKit/Models/CanvasStatus.swift

**Lines 8, 11–13: Preserve localizable status strings through the model.** Rule: `localization.md`.

show accepts a String, then Text and the VoiceOver announcement receive untranslated text from CanvasInteraction.

```swift
// Before
func show(_ text: String) {
    message = text
    AccessibilityNotification.Announcement(text).post()
}

// After
func show(_ text: LocalizedStringResource) {
    let resolved = String(localized: text)
    message = resolved
    AccessibilityNotification.Announcement(resolved).post()
}
// Call with resources explicitly belonging to CanvasKit’s bundle.
```

### Packages/DrawspeakKit/Sources/CanvasKit/Preview/CanvasPreviewHost.swift

**Lines 12–20: Reserve bar space instead of overlaying controls with guessed clearance.** Rule: `resizability.md`.

The preview repeats the production overlay problem and can hide it by always fitting at a large seeded viewport.

```swift
// Before
CanvasView(/* overlayInsets.bottom = 88 */)
    .overlay(alignment: .bottom) { HStack { /* palettes */ }.padding() }

// After
CanvasView(/* … */)
    .safeAreaBar(edge: .bottom) {
        ViewThatFits {
            HStack { ZoomControls(/* … */); ToolPalette(/* … */) }
            VStack { ZoomControls(/* … */); ToolPalette(/* … */) }
        }
    }
```

### Packages/DrawspeakKit/Sources/CanvasKit/Preview/MockScreenArt.swift

**Lines 13, 15, 17, 27: Use Dynamic Type rather than fixed font sizes.** Rule: `accessibility.md; design.md`.

All four text roles use fixed point sizes. Impact is confined to debug preview art, not production snapshot text imported from users.

```swift
// Before
 .font(.system(size: 30, weight: .semibold))

// After
 .font(.largeTitle)
// Use .headline/.body/.title3 for the other roles, or scaled semantic fonts
// if the fixture intentionally needs a relative size.
```

### Packages/DrawspeakKit/Sources/CanvasKit/Views/CanvasPaletteBackground.swift

**Lines 10–15: Keep modifier-only differences from replacing view identity.** Rule: `performance.md`.

Toggling Reduce Transparency switches the entire content subtree between conditional branches. Controls/popover state can be recreated even though only the surrounding decoration changes.

```swift
// Before
if reduceTransparency {
    content.background(Theme.surface, in: .capsule).shadow(/* … */)
} else {
    content.glassEffect(.regular, in: .capsule)
}

// After
content.background {
    if reduceTransparency {
        Capsule().fill(Theme.surface).shadow(/* … */)
    } else {
        Capsule().fill(.clear).glassEffect(.regular, in: .capsule)
    }
}
// Branch only decoration; retain the interactive content’s structural identity.
```

### Packages/DrawspeakKit/Sources/CanvasKit/Views/CanvasView.swift

**Lines 57–62: Move repeated transforms out of frequently evaluated body.** Rule: `performance.md`.

A screen-row drag changes dragState and rebuilds world layout, sorted placed marks and comment grouping for the entire canvas on each move. Comment counts do not depend on drag at all.

```swift
// Before
let marks = layout.map { PlacedMark.marks(in: $0, notes: notes) } ?? []
let commentCounts = Dictionary(grouping: notes, by: \.snapshotId).mapValues(\.count)

// After
let marks = presentation.placedMarks
let commentCounts = presentation.commentCounts
// Proposed retained model: invalidate note counts on note changes; keep
// drag transforms separate from sorting/grouping stable note data.
```

**Lines 57–158: Extract the oversized body into separate View structs.** Rule: `views.md`.

More than 100 lines combine world layers, hints, popover presentation and input lifecycle. Keep existing small computed non-view values; move distinct view concerns into files.

```swift
// Before
ZStack { /* layers, hints and component UI */ }
// More than 100 lines of modifiers.

// After
CanvasContent(/* … */)
    .modifier(CanvasInputLifecycle(/* … */))
// CanvasContent.swift and CanvasInputLifecycle.swift own their separate concerns.
```

**Lines 96, 101–112: Keep interactive overlays inside safe areas and reserve custom notice space.** Rule: `resizability.md; api.md`.

The inner ignoresSafeArea remains even if the app wrapper is fixed. Interacting/Done and status UI use a guessed top inset.

```swift
// Before
 .ignoresSafeArea()
 .overlay(alignment: .top) { /* notices */ }

// After
 .background { Theme.canvas.ignoresSafeArea() }
 .safeAreaInset(edge: .top) { CanvasInteractionNotice(/* … */) }
// Keep freely panning world imagery distinct from safe-area-aware controls.
```

**Lines 101–108: Resolve package interface text in its containing bundle.** Rule: `localization.md`.

These controls omit the containing bundle, so lookups target the application bundle. CanvasKit currently declares no localization resources; add package resources and preserve extractable literal keys. Runtime user content remains verbatim.

```swift
// Before
Text("Interacting — tap Done to annotate")

// After
Text("Interacting — tap Done to annotate", bundle: #bundle)
```

### Packages/DrawspeakKit/Sources/CanvasKit/Views/ComponentChainRow.swift

**Lines 15, 30: Use shared spacing/padding constants.** Rule: `design.md`.

Low priority: the reference explicitly discourages scattered hard-coded spacing/padding. Define the proposed semantic constant in the shared theme rather than merely relocating a literal to another view.

```swift
// Before
VStack(alignment: .leading, spacing: 2) { /* … */ }

// After
VStack(alignment: .leading, spacing: Theme.componentDetailSpacing) { /* … */ }
```

### Packages/DrawspeakKit/Sources/CanvasKit/Views/ComponentChip.swift

**Lines 16–17: Use shared spacing/padding constants.** Rule: `design.md`.

Low priority: the reference explicitly discourages scattered hard-coded spacing/padding. Define the proposed semantic constant in the shared theme rather than merely relocating a literal to another view.

```swift
// Before
.padding(.horizontal, 12).padding(.vertical, 8)

// After
.padding(Theme.componentChipInsets)
```

### Packages/DrawspeakKit/Sources/CanvasKit/Views/ComponentChooser.swift

**Lines 20, 29: Use element identity instead of mutable layer indices and chain offsets.** Rule: `data.md`.

Changing Layers replaces the chain while reusing offsets for unrelated DOM elements. Give rows stable identities based on the DOM locator (and snapshot); layer options should use the identity of their hit element.

```swift
// Before
ForEach(selection.chain.enumerated(), id: \.offset) { index, item in /* … */ }

// After
ForEach(selection.chain.enumerated(), id: \.element.locator) { index, item in
    ComponentChainRow(/* … */)
}
// For layer options use their first element’s locator, not layers.indices.
```

**Lines 15–63: Allow chooser controls to fit narrow and short windows.** Rule: `design.md; resizability.md`.

Only the chain scrolls. The mandatory 320-point minimum width and nonadaptive Child/Parent/Cancel row can overflow at accessibility text sizes or in short popovers.

```swift
// Before
HStack { childButton; parentButton; Spacer(); cancelButton }
.frame(minWidth: 320, idealWidth: 360, maxWidth: 420)

// After
ViewThatFits {
    HStack { childButton; parentButton; cancelButton }
    VStack { childButton; parentButton; cancelButton }
}
// Extract controls into views; remove the mandatory minimum width and
// allow the whole chooser content to scroll when vertical space is scarce.
```

**Lines 27–39: Use a lazy stack for an unbounded DOM ancestor list.** Rule: `performance.md`.

Imported HTML can contain deeply nested ancestors, and the eager stack creates every chain button even when only 264 points are visible.

```swift
// Before
ScrollView { VStack(alignment: .leading, spacing: 0) { /* chain */ } }

// After
ScrollView { LazyVStack(alignment: .leading, spacing: 0) { /* chain */ } }
```

**Lines 16, 19, 42–55: Resolve package interface text in its containing bundle.** Rule: `localization.md`.

These controls omit the containing bundle, so lookups target the application bundle. CanvasKit currently declares no localization resources; add package resources and preserve extractable literal keys. Runtime user content remains verbatim.

```swift
// Before
Text("Select Component")

// After
Text("Select Component", bundle: #bundle)
```

### Packages/DrawspeakKit/Sources/CanvasKit/Views/LaneHeader.swift

**Lines 13–23: Retain access to features in smaller layouts.** Rule: `design.md; resizability.md`.

ViewThatFits eventually drops VersionMenu, then Try, then all content. Low zoom or larger text therefore removes version switching and prototype interaction instead of offering a compact menu.

```swift
// Before
HStack { title; tryButton }
title
Color.clear.frame(width: 0)

// After
Menu("Lane Actions", systemImage: "ellipsis.circle") {
    // Include version selection, changes, promotion and Try/Done actions.
}
// Keep this reachable through a screen-level fallback if a lane is too narrow.
```

**Lines 28–46: Extract subviews once the helper exception is exceeded.** Rule: `views.md`.

tryButton is a 10-line conditional interactive concern and title is reused four times in a 36-line layout/builders section. Extract the reusable components rather than continuing to evaluate view helpers.

```swift
// Before
@ViewBuilder private var tryButton: some View { /* conditional control */ }
private var title: some View { /* title styling */ }

// After
// LaneTryButton.swift
struct LaneTryButton: View { /* control and action */ }
// LaneTitle.swift
struct LaneTitle: View { /* title styling */ }
```

**Lines 30, 36: Resolve package interface text in its containing bundle.** Rule: `localization.md`.

These controls omit the containing bundle, so lookups target the application bundle. CanvasKit currently declares no localization resources; add package resources and preserve extractable literal keys. Runtime user content remains verbatim.

```swift
// Before
Button(interactingSnapshotId == snapshot.id ? "Done" : "Try", systemImage: "hand.tap") { /* … */ }

// After
// Build the title as a bundle-specific LocalizedStringResource before Button:
let title = LocalizedStringResource("Try", bundle: #bundle)
Button(title, systemImage: "hand.tap", action: tryPrototype)
```

### Packages/DrawspeakKit/Sources/CanvasKit/Views/MissingSourceCard.swift

**Lines 11–13: Resolve package interface text in its containing bundle.** Rule: `localization.md`.

These controls omit the containing bundle, so lookups target the application bundle. CanvasKit currently declares no localization resources; add package resources and preserve extractable literal keys. Runtime user content remains verbatim.

```swift
// Before
Label("Source file is missing", systemImage: "exclamationmark.triangle")

// After
Label { Text("Source file is missing", bundle: #bundle) } icon: {
    Image(systemName: "exclamationmark.triangle")
}
// Localize HTML/image kind separately and document the filename placeholder.
```

### Packages/DrawspeakKit/Sources/CanvasKit/Views/PaletteIconButton.swift

**Lines 7, 13: Resolve package interface text in its containing bundle.** Rule: `localization.md`.

These controls omit the containing bundle, so lookups target the application bundle. CanvasKit currently declares no localization resources; add package resources and preserve extractable literal keys. Runtime user content remains verbatim.

```swift
// Before
let title: String
Button(title, systemImage: systemImage, action: action)

// After
let title: LocalizedStringResource
Button(title, systemImage: systemImage, action: action)
// Callers supply resources bound to CanvasKit’s bundle.
```

### Packages/DrawspeakKit/Sources/CanvasKit/Views/PinButton.swift

**Lines 35: Resolve package interface text in its containing bundle.** Rule: `localization.md`.

These controls omit the containing bundle, so lookups target the application bundle. CanvasKit currently declares no localization resources; add package resources and preserve extractable literal keys. Runtime user content remains verbatim.

```swift
// Before
 .accessibilityValue(isRecording ? "Recording" : "")

// After
 .accessibilityValue(isRecording
    ? Text("Recording", bundle: #bundle) : Text(verbatim: ""))
```

### Packages/DrawspeakKit/Sources/CanvasKit/Views/ScreenOverlay.swift

**Lines 20–37: Move repeated filtering and projection logic out of body.** Rule: `performance.md`.

Every live pan/zoom builds flattened slots and three placement collections on the UI thread. Retain stable flattened inputs and derive visibility/placements in a presentation model with explicit camera/layout invalidation.

```swift
// Before
let headers = rows.flatMap(\.slots).compactMap { /* projection and culling */ }

// After
let headers = placements.headers
let titles = placements.titles
let pins = placements.pins
// Proposed placements model updates on camera/layout/mark changes; avoid
// moving the same transforms into an uncached computed view property.
```

**Lines 17, 25, 53: Let text-bearing headers grow with Dynamic Type.** Rule: `accessibility.md; design.md`.

All lane headers are forced to 44 points even though they contain Dynamic Type headline/subheadline text. Large text clips or collides with the preceding title row.

```swift
// Before
static let headerHeight: CGFloat = 44
LaneHeader(/* … */).frame(width: width, height: Self.headerHeight)

// After
@ScaledMetric(relativeTo: .headline) private var headerHeight = 44.0
// Use the scaled value consistently in projection, row separation and layout,
// with a minimum height rather than clipping text to an unscaled 44 points.
```

### Packages/DrawspeakKit/Sources/CanvasKit/Views/ScreenTitleChip.swift

**Lines 39–48: Resolve package interface text in its containing bundle.** Rule: `localization.md`.

These controls omit the containing bundle, so lookups target the application bundle. CanvasKit currently declares no localization resources; add package resources and preserve extractable literal keys. Runtime user content remains verbatim.

```swift
// Before
 .accessibilityLabel("Screen \(screen.title)")

// After
 .accessibilityLabel(Text("Screen \(screen.title)", bundle: #bundle,
    comment: "Placeholder is the user-assigned screen name."))
// Apply package resources to Rename/Cancel/Title and the movement hint too.
```

**Lines 23, 32: Use shared spacing/padding constants.** Rule: `design.md`.

Low priority: the reference explicitly discourages scattered hard-coded spacing/padding. Define the proposed semantic constant in the shared theme rather than merely relocating a literal to another view.

```swift
// Before
HStack(spacing: 6) { /* … */ }

// After
HStack(spacing: Theme.screenTitleSpacing) { /* … */ }
```

**Lines 54–64: Extract multi-step gesture logic from view construction.** Rule: `views.md`.

The drag builder mutates the model inline, mixing input logic with view composition.

```swift
// Before
 .onEnded { value in
    move(dx: value.translation.width / zoom, dy: value.translation.height / zoom)
    dragState.drag = nil
 }

// After
 .onEnded(endDrag)
// endDrag(_:) performs the move and clears dragState.drag.
```

### Packages/DrawspeakKit/Sources/CanvasKit/Views/SnapshotCard.swift

**Lines 58–59: Use SwiftUI or asset colors instead of UIKit colors.** Rule: `design.md`.

The card border reaches through UIColor.separator from SwiftUI. Keep the intended adaptive border in the shared SwiftUI theme.

```swift
// Before
 .strokeBorder(Color(uiColor: .separator).opacity(colorScheme == .dark ? 1 : 0), lineWidth: 0.5)

// After
 .strokeBorder(Theme.cardSeparator.opacity(colorScheme == .dark ? 1 : 0), lineWidth: 0.5)
// Define cardSeparator as a SwiftUI style/asset color with light/dark variants.
```

**Lines 50, 65, 69–76: Resolve package interface text in its containing bundle.** Rule: `localization.md`.

These controls omit the containing bundle, so lookups target the application bundle. CanvasKit currently declares no localization resources; add package resources and preserve extractable literal keys. Runtime user content remains verbatim.

```swift
// Before
ContentUnavailableView("No version yet", systemImage: "square.dashed")

// After
ContentUnavailableView {
    Label { Text("No version yet", bundle: #bundle) } icon: {
        Image(systemName: "square.dashed")
    }
}
// Supply package-bound resources for Add Region/Select Component/Show Comments
// and localize the missing-source accessibility sentence.
```

### Packages/DrawspeakKit/Sources/CanvasKit/Views/StatusBanner.swift

**Lines 15–16: Use shared spacing/padding constants.** Rule: `design.md`.

Low priority: the reference explicitly discourages scattered hard-coded spacing/padding. Define the proposed semantic constant in the shared theme rather than merely relocating a literal to another view.

```swift
// Before
.padding(.horizontal, 16).padding(.vertical, 10)

// After
.padding(Theme.statusBannerInsets)
```

### Packages/DrawspeakKit/Sources/CanvasKit/Views/ToolButton.swift

**Lines 4, 12–14: Avoid unnecessary UIKit image construction and redundant imports.** Rule: `swift.md; SKILL.md Core Instructions`.

A UIImage is constructed during symbol evaluation merely to test a fixed SF Symbol name. For this fixed iOS 27 target, select a supported symbol once rather than testing per body update. SwiftUI already imports UIKit.

```swift
// Before
import UIKit
private var symbol: String {
    tool == .pen && UIImage(systemName: tool.systemImage) == nil ? "scribble" : tool.systemImage
}

// After
// Remove redundant UIKit import. Choose the supported pen symbol in CanvasTool.
private var symbol: String { tool.systemImage }
```

**Lines 20–27: Differentiate selected tools with more than color.** Rule: `accessibility.md`.

For sighted users the selection changes only foreground/background color. The accessibility selected trait helps VoiceOver, but Differentiate Without Color needs an additional visual cue.

```swift
// Before
 .background(isSelected ? Theme.action.opacity(0.16) : .clear, in: .capsule)

// After
@Environment(\.accessibilityDifferentiateWithoutColor) private var differentiate
// On the button:
.overlay {
    if differentiate && isSelected { Capsule().strokeBorder(Theme.ink, lineWidth: 2) }
}
```

### Packages/DrawspeakKit/Sources/CanvasKit/Views/ToolPalette.swift

**Lines 30–45: Provide an adaptive alternative for a fixed-width tool row.** Rule: `design.md; resizability.md`.

Five tools plus Undo/Redo each reserve 44 points, plus spacing/padding/divider: about 353 points before outer padding. The palette cannot fit every freely resized iPad window.

```swift
// Before
HStack(spacing: 4) { /* seven controls plus divider */ }

// After
ViewThatFits(in: .horizontal) {
    ToolPaletteRow(/* … */)
    ToolPaletteGrid(/* … */)
}
// Separate files; preserve every action and 44×44 minimum hit area.
```

**Lines 40–48: Resolve package interface text in its containing bundle.** Rule: `localization.md`.

These controls omit the containing bundle, so lookups target the application bundle. CanvasKit currently declares no localization resources; add package resources and preserve extractable literal keys. Runtime user content remains verbatim.

```swift
// Before
PaletteIconButton(title: "Undo", systemImage: "arrow.uturn.backward", action: onUndo)

// After
PaletteIconButton(title: LocalizedStringResource("Undo", bundle: #bundle),
                  systemImage: "arrow.uturn.backward", action: onUndo)
// Apply to Redo and the Tools accessibility label.
```

**Lines 30, 39, 45, 53: Use shared spacing/padding constants.** Rule: `design.md`.

Low priority: the reference explicitly discourages scattered hard-coded spacing/padding. Define the proposed semantic constant in the shared theme rather than merely relocating a literal to another view.

```swift
// Before
.padding(6)

// After
.padding(Theme.toolPaletteInset)
```

### Packages/DrawspeakKit/Sources/CanvasKit/Views/VersionMenu.swift

**Lines 25, 65–78: Localize labels, format display lists, and respect environment locale.** Rule: `localization.md; swift.md`.

No change summary supplied and Returned capture are runtime English Strings; iterationLabel concatenates translated and untranslated pieces. Date.formatted uses process locale rather than the view environment; addressedComments hand-joins a display list.

```swift
// Before
Text(selected.changeSummary ?? "No change summary supplied")
let label = "\(versionTitle(snapshot)) · \(snapshot.capturedAt.formatted(.dateTime.month(.abbreviated).day().hour().minute()))"
// … .joined(separator: ", ")

// After
@Environment(\.locale) private var locale
// Also read calendar/timeZone where formatting must follow view overrides.
let date = snapshot.capturedAt.formatted(.dateTime.month(.abbreviated).day().hour().minute().locale(locale))
let label = String(localized: "\(versionTitle(snapshot)) · \(date)", bundle: #bundle,
                   comment: "Version title followed by its capture date/time.")
// Localize fallback branches; use .formatted(.list(type: .and)) for comment labels.
```

**Lines 26–27, 60–78: Avoid repeated collection searches/filtering in body.** Rule: `performance.md`.

addressedComments is called twice and scans/sorts all canvas notes each time; isReturned and versionTitle also query the canvas repeatedly. Prepare menu entries when the lane/canvas changes.

```swift
// Before
if !addressedComments(selected).isEmpty {
    Text("Addressed comments: \(addressedComments(selected))")
}

// After
// In a retained model, recompute when selected version or notes change:
let comments = menuModel.addressedComments
if !comments.isEmpty { Text("Addressed comments: \(comments)", bundle: #bundle) }
```

**Lines 15, 18, 24, 27, 31, 48: Resolve package interface text in its containing bundle.** Rule: `localization.md`.

These controls omit the containing bundle, so lookups target the application bundle. CanvasKit currently declares no localization resources; add package resources and preserve extractable literal keys. Runtime user content remains verbatim.

```swift
// Before
Text("Now")

// After
Text("Now", bundle: #bundle)
// Version/Changes/Promote to Now and accessibility text also need
// resources in CanvasKit’s bundle, with translator context for Now.
```

**Lines 36, 41: Use shared spacing/padding constants.** Rule: `design.md`.

Low priority: the reference explicitly discourages scattered hard-coded spacing/padding. Define the proposed semantic constant in the shared theme rather than merely relocating a literal to another view.

```swift
// Before
HStack(spacing: 4) { /* … */ }

// After
HStack(spacing: Theme.versionMenuSpacing) { /* … */ }
```

### Packages/DrawspeakKit/Sources/CanvasKit/Views/ZoomControls.swift

**Lines 22, 28–32, 44: Resolve package interface text in its containing bundle.** Rule: `localization.md`.

These controls omit the containing bundle, so lookups target the application bundle. CanvasKit currently declares no localization resources; add package resources and preserve extractable literal keys. Runtime user content remains verbatim.

```swift
// Before
Button("Fit All", action: onFitAll)

// After
Button(LocalizedStringResource("Fit All", bundle: #bundle), action: onFitAll)
// Apply to Zoom In/Out and Zoom accessibility labels.
```

**Lines 21, 35, 41: Use shared spacing/padding constants.** Rule: `design.md`.

Low priority: the reference explicitly discourages scattered hard-coded spacing/padding. Define the proposed semantic constant in the shared theme rather than merely relocating a literal to another view.

```swift
// Before
HStack(spacing: 2) { /* … */ }

// After
HStack(spacing: Theme.zoomControlSpacing) { /* … */ }
```

### Summary

1. **High — CanvasChrome:** Restore touch and VoiceOver access to Zoom In, Zoom Out and Fit All in compact windows.

2. **High — CanvasChrome:** Replace overlapping top/bottom palette arrangements with layouts that fit resized windows.

3. **High — ToolPalette:** Add an adaptive layout for the approximately 353-point tool row; retain every action.

4. **High — CanvasSidePanels:** Replace the fixed floating note panel with a system inspector that adapts to compact width.

5. **High — CanvasScreen / CanvasView:** Keep controls inside safe areas and reserve actual bar space instead of guessing insets.

6. **High — LaneHeader:** Preserve version selection and Try actions when a lane becomes narrow.

7. **High — ComponentChooser:** Remove rigid minimum sizing and adapt/scroll controls at large text sizes.

8. **High — CanvasScreen:** Present the squeeze palette with a system popover so edge actions stay reachable.

9. **High — CanvasScreen:** Surface file-importer failures while allowing intentional cancellation.

10. **High — ElevenLabsKeySection / AppModel:** Show Keychain-save and fresh-library-location failures.

11. **Medium — CanvasSidePanels:** Honor Reduce Motion for inspector slide transitions.

12. **Medium — ToolButton / ThreadLabel:** Add a non-color selection cue and expose connection status to VoiceOver.

13. **Medium — CanvasKit interface:** Resolve package text in its own bundle and provide package localization resources.

14. **Medium — CanvasBanner / CanvasLabels:** Replace English plural suffixes and hand-joined display text with localized grammar/formatting.

15. **Medium — App status/error producers:** Localize generated messages, fallback labels and conditional titles before displaying them.

16. **Medium — ComponentChooser:** Replace mutable chain/layer position IDs with DOM element identities.

17. **Medium — ScreenOverlay:** Scale header geometry for Dynamic Type rather than fixing text rows to 44 points.

18. **Medium — CanvasView / ScreenOverlay / VersionMenu:** Move repeated grouping, filtering and sorting out of frequently evaluated bodies.

19. **Medium — CanvasListSheet / LibraryRecoveryView:** Use optional-item presentations and attach destructive dialogs to their triggers.

20. **Medium — CanvasScreen / CanvasView / CanvasChrome:** Extract oversized view concerns and place additional types in their own files.
