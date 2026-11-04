# Strict swiftui-pro review B

Reviewed the initial 106 Swift files (5,985 lines) under NotesKit, FeedbackKit, T3Kit, VoiceKit and DrawspeakCore. Paths below are relative to `Packages/DrawspeakKit/Sources/`. Read the requested `/Users/rafalw/.claude/skills/swiftui-pro/SKILL.md` and all 11 required references: api.md, views.md, data.md, navigation.md, design.md, resizability.md, accessibility.md, localization.md, performance.md, swift.md, hygiene.md. performance-plus.md was excluded.

Package.swift confirms Swift 6.4, iOS 27.0 and MainActor defaults for NotesKit, FeedbackKit, T3Kit and VoiceKit. Workspace explicitly uses MainActor; Core has no module-wide MainActor default. Findings are static source findings. No builds, tests, simulator, accessibility inspection or device measurements were run. Examples are brief proposed changes, not applied patches; helper/model names illustrate the required extraction. I edited no source files and made no commit. Concurrent owner/agent edits appeared during the review in Core and VoiceKit: I read their diffs plus the new PCMConverter.swift and LiveTranscriptEvent.swift (108 scoped files at that checkpoint), removed the superseded key-store type finding, and refreshed affected finding line numbers. The workspace remains in active development; this report is a source checkpoint, not a claim that concurrent integration compiles.

No legacy NavigationView, conflicting destination registrations, manual Binding(get:set:) in body, onTapGesture, DispatchQueue, Combine timers, unstable positional ForEach IDs, or app-storage secrets were found in scope. Existing @ViewBuilder is explicitly allowed. Image cache state and default-isolated observable models were not incorrectly flagged. RecordingStatus already respects Reduce Motion; PaletteBackground already provides an opaque Reduce Transparency fallback. No measured contrast failure is claimed. CompositeCanvas’s pixel-sized pin text is export artwork, not an ordinary fixed-size interface font. No sheet/alert/confirmation-dialog misuse was found in these files. The application Info.plist has UILaunchScreen and does not declare UIRequiresFullScreen; it disables multiple scenes, so shared window-navigation state is not reported as a current multiwindow bug. Core/service test targets exist; test results are unverified.

The loaded hygiene.md does not explicitly prohibit semicolons, long lines or multiple statements per line. Compressed code was inspected, but no standalone formatting finding is attributed to a nonexistent hygiene rule. Long bodies, inline logic and multiple types are reported under the rules that actually name them. Files without actionable reference violations are omitted.

### NotesKit/AddRegionSheet.swift

**Lines 9, 19: Initialize each @State property in exactly one place (`data.md`).**

snapshotId has both a declaration initializer and State(initialValue:) in init. This can diagnose under Xcode 27 and makes the intended initialSnapshotId unreliable.

```swift
// Before
@State private var snapshotId = ""
_snapshotId = State(initialValue: initialSnapshotId ?? "")

// After
@State private var snapshotId: String
// In init:
_snapshotId = State(initialValue: initialSnapshotId ?? "")
```

**Lines 29–39, 41–48, 52–100: Extract substantial some View helpers into separate View structs (`views.md`).**

content contains almost the complete screen, including form, toolbar, and initialization; it exceeds the small structural-helper exception. sourcePicker is another extractable concern.

```swift
// Before
private var content: some View {
    NavigationStack { /* form, toolbar, task */ }
}

// After
// AddRegionContent.swift
struct AddRegionContent: View {
    // Pass workspace, editable region state, and completion action.
    var body: some View { NavigationStack { /* form */ } }
}
```

**Lines 42–47: Keep conditional presentation modifier values on one view (`performance.md`).**

Changing size class replaces content with a different structural branch, resetting the form NavigationStack and its local state. Keep one content identity through live iPad resizing.

```swift
// Before
if horizontalSizeClass == .regular {
    content.presentationSizing(.form)
} else {
    content
}

// After
content.presentationSizing(horizontalSizeClass == .regular ? .form : .automatic)
```

**Lines 34: Interpolate Text rather than concatenate strings (`api.md`).**

The concatenated String selects verbatim Text and prevents localization of the surrounding label structure.

```swift
// Before
Text(NotesPresentation.sourceLabel(snapshot, in: canvas) + " · " + snapshot.title)

// After
Text("\(NotesPresentation.sourceLabel(snapshot, in: canvas)) · \(snapshot.title)", bundle: #bundle)
```

**Lines 86–91, 95, 98: Extract button actions and business logic from view bodies (`views.md`).**

Keep layout separate from mutation and asynchronous orchestration. Parameterized actions should call a named method; directly pass parameterless methods through action:.

```swift
// Before
Button("Add", systemImage: "plus") {
    if workspace.addNote(snapshotId: snapshotId, shape: shape) != nil {
        onDone(); dismiss()
    }
}

// After
Button("Add", systemImage: "plus", action: addRegion)
// Move validation, mutation, completion, dismissal into addRegion().
```

**Lines 30–32, 57–68, 71, 77, 80, 86, 95: Specify the containing bundle and extract localizable interface text (`localization.md`).**

Package interface text must resolve in its containing bundle. No localization resources were found in these targets; implicit lookup uses the app main bundle. Add the keys/resources to the target as part of the correction.

```swift
// Before
Text("Choose a snapshot")

// After
Text("Choose a snapshot", bundle: #bundle)
```

**Lines 58: Centralize spacing and padding in the shared design constants (`design.md`).**

Theme already supplies shared visual constants, but this view adds unrelated literal spacing/padding. The reference explicitly discourages scattered hard-coded spacing.

```swift
// Before
LazyVGrid(columns: columns, spacing: 8) { /* controls */ }

// After
LazyVGrid(columns: columns, spacing: Theme.regionControlSpacing) { /* controls */ }
```

### NotesKit/NoteInspector.swift

**Lines 19, 36, 41: Avoid GeometryReader and mirrored geometry state when ordinary layout suffices (`api.md`).**

The height is measured, copied into State, and fed back to the same view. ScrollView already accepts its proposed height; this adds an extra layout/update cycle without an independent sizing requirement.

```swift
// Before
GeometryReader { geometry in
    inspectorContent.frame(maxHeight: availableHeight ?? geometry.size.height)
}
.onGeometryChange(for: CGFloat.self) { $0.size.height } action: { availableHeight = $0 }

// After
ScrollViewReader { scroll in
    ScrollView { /* inspector content */ }
}.paletteBackground()
```

**Lines 26–27: Specify the containing bundle and extract localizable interface text (`localization.md`).**

Package interface text must resolve in its containing bundle. No localization resources were found in these targets; implicit lookup uses the app main bundle. Add the keys/resources to the target as part of the correction.

```swift
// Before
Text("This comment may have been deleted.")

// After
Text("This comment may have been deleted.", bundle: #bundle)
```

### NotesKit/NoteInspectorContent.swift

**Lines 20: Interpolate Text rather than concatenate strings (`api.md`).**

The shape/source label is assembled as a plain String and displayed verbatim.

```swift
// Before
Text(note.shape.kindLabel + " · " + NotesPresentation.sourceLabel(snapshot, in: canvas))

// After
Text("\(note.shape.kindLabel) · \(NotesPresentation.sourceLabel(snapshot, in: canvas))", bundle: #bundle)
```

**Lines 25–28, 41–43, 47–53, 65: Extract button actions and business logic from view bodies (`views.md`).**

Keep layout separate from mutation and asynchronous orchestration. Parameterized actions should call a named method; directly pass parameterless methods through action:.

```swift
// Before
Button("Record Voice", systemImage: "mic.fill") {
    isStartingVoice = true
    Task {
        await workspace.startRecording(noteId: note.id)
        isStartingVoice = false
    }
}

// After
Button("Record Voice", systemImage: "mic.fill", action: startVoice)
// Move start flag, Task, and reset into startVoice().
```

**Lines 13–70: Extract the oversized inspector body into distinct View structs (`views.md`).**

The body combines header/menu, readiness, editing, permission recovery, recording lifecycle, recording history, and source preview. These are separable concerns, beyond the small-helper exception.

```swift
// Before
VStack { /* header, editor, permission, recording, history, source */ }

// After
VStack {
    NoteInspectorHeader(/* inputs */)
    NoteTextEditor(workspace: workspace, note: note)
    NoteVoiceSection(/* inputs */)
    NoteSourceSection(/* inputs */)
}
// Each extracted type in its own file.
```

**Lines 18, 24–25, 30, 34, 47, 57, 65: Specify the containing bundle and extract localizable interface text (`localization.md`).**

Package interface text must resolve in its containing bundle. No localization resources were found in these targets; implicit lookup uses the app main bundle. Add the keys/resources to the target as part of the correction.

```swift
// Before
Text("Comment \(note.ordinal)")

// After
Text("Comment \(note.ordinal)", bundle: #bundle, comment: "Ordinal number identifying a canvas comment")
```

**Lines 14, 17: Centralize spacing and padding in the shared design constants (`design.md`).**

Theme already supplies shared visual constants, but this view adds unrelated literal spacing/padding. The reference explicitly discourages scattered hard-coded spacing.

```swift
// Before
VStack(alignment: .leading, spacing: 16) { /* sections */ }

// After
VStack(alignment: .leading, spacing: Theme.inspectorSectionSpacing) { /* sections */ }
```

### NotesKit/NoteListRow.swift

**Lines 13, 21: Specify the containing bundle and extract localizable interface text (`localization.md`).**

The ternary becomes a String because its other branch is user text, so the empty-state phrase is displayed verbatim. The recording accessibility ternary also needs explicit localized resources. User-authored text should remain verbatim.

```swift
// Before
Text(note.hasText ? String(note.trimmedText.split(separator: "
").first ?? "") : "No comment yet")

// After
if note.hasText {
    Text(String(note.trimmedText.split(separator: "
").first ?? ""))
} else {
    Text("No comment yet", bundle: #bundle)
}
```

**Lines 19, 25, 28: Specify the containing bundle and extract localizable interface text (`localization.md`).**

Package interface text must resolve in its containing bundle. No localization resources were found in these targets; implicit lookup uses the app main bundle. Add the keys/resources to the target as part of the correction.

```swift
// Before
Image(systemName: "scope").accessibilityLabel("Show on Canvas")

// After
Image(systemName: "scope").accessibilityLabel(Text("Show on Canvas", bundle: #bundle))
```

**Lines 12: Centralize spacing and padding in the shared design constants (`design.md`).**

Theme already supplies shared visual constants, but this view adds unrelated literal spacing/padding. The reference explicitly discourages scattered hard-coded spacing.

```swift
// Before
VStack(alignment: .leading, spacing: 6) { /* text */ }

// After
VStack(alignment: .leading, spacing: Theme.noteRowSpacing) { /* text */ }
```

### NotesKit/NoteTextEditor.swift

**Lines 13–25: Use a vertical TextField for inline multiline editing (`views.md`).**

This is an inline inspector editor, with a custom overlay solely to recreate a placeholder. The reference reserves TextEditor for a full-screen editing experience.

```swift
// Before
ZStack(alignment: .topLeading) {
    if text.isEmpty { Text("Say or type what should change") }
    TextEditor(text: $text).frame(minHeight: 120)
}

// After
TextField("Say or type what should change", text: $text, axis: .vertical)
    .lineLimit(5...)
    .focused($isFocused)
```

**Lines 30–46: Extract button actions and business logic from view bodies (`views.md`).**

Keep layout separate from mutation and asynchronous orchestration. Parameterized actions should call a named method; directly pass parameterless methods through action:.

```swift
// Before
.task(id: note.text) {
    isSaving = true
    do { try await Task.sleep(for: .milliseconds(300)) } catch { return }
    await workspace.saveNow()
    if !Task.isCancelled { isSaving = false }
}

// After
.task(id: note.text) { await saveAfterDebounce() }
// Move debounce/save and synchronization into named methods or an editor model.
```

**Lines 15, 23–27: Specify the containing bundle and extract localizable interface text (`localization.md`).**

Saving/Saved are produced as String values and cannot be extracted from the display site. The placeholder and accessibility text also need their package bundle.

```swift
// Before
Text(workspace.lastSaveError ?? (isSaving ? "Saving…" : "Saved"))

// After
if let error = workspace.lastSaveError {
    Text(error) // Localize the error where it is created.
} else {
    Text(isSaving ? LocalizedStringResource("Saving…", bundle: #bundle)
                  : LocalizedStringResource("Saved", bundle: #bundle))
}
```

**Lines 12, 16: Centralize spacing and padding in the shared design constants (`design.md`).**

Theme already supplies shared visual constants, but this view adds unrelated literal spacing/padding. The reference explicitly discourages scattered hard-coded spacing.

```swift
// Before
VStack(alignment: .leading, spacing: 6) { /* editor */ }

// After
VStack(alignment: .leading, spacing: Theme.editorSpacing) { /* editor */ }
```

### NotesKit/NotesListView.swift

**Lines 16–18, 31: Precompute grouped, sorted rows outside frequent body evaluation (`performance.md`).**

Every render filters and sorts notes separately for each snapshot, then performs another nested missing-source scan. Build groups when notes or snapshots change, with explicit invalidation.

```swift
// Before
ForEach(canvas.snapshots) { snapshot in
    let notes = canvas.notes.filter { $0.snapshotId == snapshot.id }.sorted { $0.ordinal < $1.ordinal }
    // ...
}

// After
ForEach(model.nonemptySnapshotGroups) { group in
    Section { ForEach(group.notes) { note in /* row */ } }
}
// Rebuild model groups whenever source notes/snapshots change.
```

**Lines 16–29: Filter before ForEach so every lazy element has a constant top-level shape (`performance.md`).**

The outer List ForEach conditionally produces a Section or no view. Omit empty snapshot groups before enumerating them.

```swift
// Before
ForEach(canvas.snapshots) { snapshot in
    if !notes.isEmpty { Section { /* rows */ } }
}

// After
ForEach(model.nonemptySnapshotGroups) { group in
    Section { /* rows */ }
}
```

**Lines 27, 33, 42: Specify the containing bundle and extract localizable interface text (`localization.md`).**

Package interface text must resolve in its containing bundle. No localization resources were found in these targets; implicit lookup uses the app main bundle. Add the keys/resources to the target as part of the correction.

```swift
// Before
Text("^[\(notes.count) comment](inflect: true)")

// After
Text("^[\(notes.count) comment](inflect: true)", bundle: #bundle, comment: "Number of comments in this snapshot section")
```

### NotesKit/NotesPresentation.swift

**Lines 12–14: Use FormatStyle instead of C-style formatting (`swift.md`).**

The displayed duration uses String(format:). Use a time-duration style that preserves minutes/seconds and localizes digits.

```swift
// Before
return String(format: "%d:%02d", value / 60, value % 60)

// After
return Duration.seconds(value).formatted(.time(pattern: .minuteSecond))
```

**Lines 7–9, 17–25: Specify the containing bundle and extract localizable interface text (`localization.md`).**

Failure messages and the fallback Screen label return plain English String values to Text. Localize at creation, including an interpolated source-label format, rather than trying to turn runtime strings into keys.

```swift
// Before
case "network": "Offline. Audio is saved."

// After
case "network": String(localized: "Offline. Audio is saved.", bundle: #bundle)
```

### NotesKit/NotesPreview.swift

**Lines 9: Prefer Date.now over Date() (`swift.md`).**

Use the reference’s explicit modern date spelling.

```swift
// Before
let date = Date()

// After
let date = Date.now
```

### NotesKit/PercentControl.swift

**Lines 5, 10: Specify the containing bundle and extract localizable interface text (`localization.md`).**

Width/Height enter through a String parameter, so the caller literals are not extracted. The displayed percent is manually constructed; use a percent FormatStyle and explain the title/value placeholders to translators.

```swift
// Before
let title: String
Stepper("\(title): \(Int(value))%", value: $value, in: 0...100, step: 1)

// After
let title: LocalizedStringResource
Stepper(value: $value, in: 0...100, step: 1) {
    Text("\(Text(title)): \(value / 100, format: .percent)", bundle: #bundle)
}
```

### NotesKit/PinBadge.swift

**Lines 20–21: Specify the containing bundle and extract localizable interface text (`localization.md`).**

Package interface text must resolve in its containing bundle. No localization resources were found in these targets; implicit lookup uses the app main bundle. Add the keys/resources to the target as part of the correction.

```swift
// Before
.accessibilityValue(isActive ? "Active" : "")

// After
.accessibilityValue(isActive ? Text("Active", bundle: #bundle) : Text(verbatim: ""))
```

**Lines 17: Centralize spacing and padding in the shared design constants (`design.md`).**

Theme already supplies shared visual constants, but this view adds unrelated literal spacing/padding. The reference explicitly discourages scattered hard-coded spacing.

```swift
// Before
.padding(2)

// After
.padding(Theme.pinPadding)
```

### NotesKit/ReadinessChip.swift

**Lines 19, 24: Specify the containing bundle and extract localizable interface text (`localization.md`).**

Package interface text must resolve in its containing bundle. No localization resources were found in these targets; implicit lookup uses the app main bundle. Add the keys/resources to the target as part of the correction.

```swift
// Before
Label(readiness.label, systemImage: symbol)

// After
Label { Text(readiness.label) } icon: { Image(systemName: symbol) }
// Make readiness.label a LocalizedStringResource at its definition.
```

**Lines 22: Centralize spacing and padding in the shared design constants (`design.md`).**

Theme already supplies shared visual constants, but this view adds unrelated literal spacing/padding. The reference explicitly discourages scattered hard-coded spacing.

```swift
// Before
.padding(.horizontal, 8).padding(.vertical, 4)

// After
.padding(.horizontal, Theme.chipHorizontalPadding)
.padding(.vertical, Theme.chipVerticalPadding)
```

### NotesKit/RecordingActions.swift

**Lines 9, 13: Extract button actions and business logic from view bodies (`views.md`).**

Keep layout separate from mutation and asynchronous orchestration. Parameterized actions should call a named method; directly pass parameterless methods through action:.

```swift
// Before
Button("Stop", systemImage: "stop.fill") { workspace.stopRecording() }

// After
Button("Stop", systemImage: "stop.fill", action: workspace.stopRecording)
```

**Lines 9, 12–15: Specify the containing bundle and extract localizable interface text (`localization.md`).**

Package interface text must resolve in its containing bundle. No localization resources were found in these targets; implicit lookup uses the app main bundle. Add the keys/resources to the target as part of the correction.

```swift
// Before
Button("Discard", systemImage: "xmark", action: workspace.discardRecording)

// After
Button(action: workspace.discardRecording) {
    Label { Text("Discard", bundle: #bundle) } icon: { Image(systemName: "xmark") }
}
```

### NotesKit/RecordingBar.swift

**Lines 22: Centralize spacing and padding in the shared design constants (`design.md`).**

Theme already supplies shared visual constants, but this view adds unrelated literal spacing/padding. The reference explicitly discourages scattered hard-coded spacing.

```swift
// Before
.padding(12)

// After
.padding(Theme.recordingBarPadding)
```

### NotesKit/RecordingRow.swift

**Lines 25–27, 44–46: Extract button actions and business logic from view bodies (`views.md`).**

Keep layout separate from mutation and asynchronous orchestration. Parameterized actions should call a named method; directly pass parameterless methods through action:.

```swift
// Before
Button("Append Transcript", systemImage: "text.append") {
    workspace.appendTranscript(noteId: note.id, recordingId: recording.id)
}

// After
Button("Append Transcript", systemImage: "text.append", action: appendTranscript)
```

**Lines 12–13, 16–25, 34, 37, 40, 43–44: Specify the containing bundle and extract localizable interface text (`localization.md`).**

The interrupted-state ternary is plain String text. The other recording labels, buttons, and accessibility phrases also omit their package bundle.

```swift
// Before
Text(recording.audio != nil ? "Recording ended early; audio kept" : "Recording ended early; no audio was saved")

// After
Text(recording.audio != nil
    ? LocalizedStringResource("Recording ended early; audio kept", bundle: #bundle)
    : LocalizedStringResource("Recording ended early; no audio was saved", bundle: #bundle))
```

**Lines 11: Centralize spacing and padding in the shared design constants (`design.md`).**

Theme already supplies shared visual constants, but this view adds unrelated literal spacing/padding. The reference explicitly discourages scattered hard-coded spacing.

```swift
// Before
VStack(alignment: .leading, spacing: 8) { /* state */ }

// After
VStack(alignment: .leading, spacing: Theme.recordingRowSpacing) { /* state */ }
```

### NotesKit/RecordingStatus.swift

**Lines 15–16, 23: Specify the containing bundle and extract localizable interface text (`localization.md`).**

Package interface text must resolve in its containing bundle. No localization resources were found in these targets; implicit lookup uses the app main bundle. Add the keys/resources to the target as part of the correction.

```swift
// Before
Text("Comment \(number)")

// After
Text("Comment \(number)", bundle: #bundle, comment: "Canvas comment ordinal for active recording")
```

**Lines 12: Centralize spacing and padding in the shared design constants (`design.md`).**

Theme already supplies shared visual constants, but this view adds unrelated literal spacing/padding. The reference explicitly discourages scattered hard-coded spacing.

```swift
// Before
HStack(spacing: 8) { /* meters */ }

// After
HStack(spacing: Theme.recordingStatusSpacing) { /* meters */ }
```

### NotesKit/SnapshotMarkPreview.swift

**Lines 27–31, 42: Move image cropping out of body evaluation (`performance.md`).**

croppedImage calls CGImage.cropping every time body executes, including geometry changes. Cache the crop in the image-loading task and invalidate it for image/crop changes. The detached thumbnail decode itself is justified background work.

```swift
// Before
private var croppedImage: CGImage? {
    // Derive rect ...
    return image.cropping(to: rect)
}

// After
@State private var croppedImage: CGImage?
// In task keyed by snapshot.image and crop:
// decode and crop off MainActor, then assign the resulting image once.
```

**Lines 45, 57: Specify the containing bundle and extract localizable interface text (`localization.md`).**

Also localize the complete accessibility phrase; lowercasing an English shape label is not a localization strategy.

```swift
// Before
Label("Snapshot Preview Unavailable", systemImage: "photo")

// After
Label { Text("Snapshot Preview Unavailable", bundle: #bundle) } icon: { Image(systemName: "photo") }
```

### NotesKit/TranscribeAgainButton.swift

**Lines 11–13: Extract button actions and business logic from view bodies (`views.md`).**

Keep layout separate from mutation and asynchronous orchestration. Parameterized actions should call a named method; directly pass parameterless methods through action:.

```swift
// Before
Button("Transcribe Again", systemImage: "arrow.clockwise") {
    workspace.transcribe(RecordingScope(canvasId: canvasId, noteId: noteId, recordingId: recordingId))
}

// After
Button("Transcribe Again", systemImage: "arrow.clockwise", action: transcribeAgain)
```

**Lines 11: Specify the containing bundle and extract localizable interface text (`localization.md`).**

Package interface text must resolve in its containing bundle. No localization resources were found in these targets; implicit lookup uses the app main bundle. Add the keys/resources to the target as part of the correction.

```swift
// Before
Button("Transcribe Again", systemImage: "arrow.clockwise", action: transcribeAgain)

// After
Button(action: transcribeAgain) { Label { Text("Transcribe Again", bundle: #bundle) } icon: { Image(systemName: "arrow.clockwise") } }
```

### NotesKit/VoiceNoticeActions.swift

**Lines 11, 14: Specify the containing bundle and extract localizable interface text (`localization.md`).**

Package interface text must resolve in its containing bundle. No localization resources were found in these targets; implicit lookup uses the app main bundle. Add the keys/resources to the target as part of the correction.

```swift
// Before
Button("Type Instead", systemImage: "keyboard", action: onDismiss)

// After
Button(action: onDismiss) { Label { Text("Type Instead", bundle: #bundle) } icon: { Image(systemName: "keyboard") } }
```

### NotesKit/VoicePermissionNotice.swift

**Lines 17–21: Specify the containing bundle and extract localizable interface text (`localization.md`).**

Select resources rather than plain English strings; apply the same correction to the conditional Label title.

```swift
// Before
Text(issue == .permissionDenied
    ? "Microphone access is off. You can type your comment, or allow access in Settings."
    : "The microphone is unavailable. You can type your comment, or try recording again later.")

// After
Text(issue == .permissionDenied
    ? LocalizedStringResource("Microphone access is off. You can type your comment, or allow access in Settings.", bundle: #bundle)
    : LocalizedStringResource("The microphone is unavailable. You can type your comment, or try recording again later.", bundle: #bundle))
```

**Lines 16: Centralize spacing and padding in the shared design constants (`design.md`).**

Theme already supplies shared visual constants, but this view adds unrelated literal spacing/padding. The reference explicitly discourages scattered hard-coded spacing.

```swift
// Before
VStack(alignment: .leading, spacing: 12) { /* notice */ }

// After
VStack(alignment: .leading, spacing: Theme.noticeSpacing) { /* notice */ }
```

### FeedbackKit/CompositeRenderer.swift

**Lines 7–20, 26–34: Move synchronous image preparation off MainActor (`performance.md; swift.md`).**

FeedbackKit defaults to MainActor. async does not offload blob reads/checksumming, ImageIO thumbnail decode, or PNG encoding; Task.yield only yields after an oversized render. Keep ImageRenderer on MainActor, but perform preparation and encoding in a worker actor or @concurrent helper.

```swift
// Before
let bytes = try blobs.data(for: ref)
let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options)
// ImageRenderer ...
CGImageDestinationFinalize(destination)

// After
let image = try await imageWorker.thumbnail(ref: ref, blobs: blobs, side: side)
let output = try renderOnMainActor(image: image, items: items)
let png = try await imageWorker.encodePNG(output)
// Implement imageWorker as an actor; preserve cancellation and size limits.
```

### FeedbackKit/DeliveryState+Feedback.swift

**Lines 4–11: Specify the containing bundle and extract localizable interface text (`localization.md`).**

Every case returns English String text subsequently displayed verbatim. Localize these at creation or return LocalizedStringResource.

```swift
// Before
case .uploading(let done, let total): "Uploading \(done) of \(total)"

// After
case .uploading(let done, let total):
    String(localized: "Uploading \(done) of \(total)", bundle: #bundle, comment: "Completed attachments and total attachments")
```

### FeedbackKit/DraftsAndHistoryView.swift

**Lines 21, 26–27, 30, 35, 38, 43, 48, 58–62: Specify the containing bundle and extract localizable interface text (`localization.md`).**

The hand-built singular/plural sentence bypasses grammatical agreement and extraction. Localize the entire sentence, the No recipient fallback, and all labels in this package bundle.

```swift
// Before
let noun = result.copiedCount == 1 ? "comment changed" : "comments changed"
notices.append("\(result.copiedCount) \(noun) since the draft; the draft's text was restored as new comments.")

// After
notices.append(String(localized: "^[\(result.copiedCount) comment](inflect: true) changed since the draft; the draft’s text was restored as new comments.", bundle: #bundle))
```

**Lines 21, 32, 38, 49: Extract button actions and business logic from view bodies (`views.md`).**

Keep layout separate from mutation and asynchronous orchestration. Parameterized actions should call a named method; directly pass parameterless methods through action:.

```swift
// Before
Button("Delete", role: .destructive) { workspace.deleteDraft(draft.id, canvasId: canvasId) }

// After
// In an extracted DraftRow:
Button("Delete", role: .destructive, action: deleteDraft)
```

**Lines 33, 36: Centralize spacing and padding in the shared design constants (`design.md`).**

Theme already supplies shared visual constants, but this view adds unrelated literal spacing/padding. The reference explicitly discourages scattered hard-coded spacing.

```swift
// Before
VStack(alignment: .leading, spacing: 6) { /* draft */ }.frame(minHeight: 44)

// After
VStack(alignment: .leading, spacing: Theme.draftRowSpacing) { /* draft */ }.frame(minHeight: Theme.minTarget)
```

### FeedbackKit/FeedbackButton.swift

**Lines 12–14: Derive feedback counts outside the button body (`performance.md`).**

feedbackScope sorts and classifies every note, scans snapshots, and checks files on disk (Workspace.isSourceAvailable). Reading the counter should not repeat that work on every render.

```swift
// Before
let scope = workspace.feedbackScope()
let count = scope?.count ?? 0

// After
let count = model.readyFeedbackCount
// Refresh derived counts on note/snapshot/source availability changes.
```

**Lines 14: Use count(where:) rather than filter().count (`swift.md`).**

Avoid allocating a filtered array simply to count matching elements.

```swift
// Before
scope?.pending.filter { $0.isRecording || $0.isTranscribing }.count ?? 0

// After
scope?.pending.count(where: { $0.isRecording || $0.isTranscribing }) ?? 0
```

**Lines 30: Use a minimum height so Dynamic Type can expand the button (`design.md; accessibility.md`).**

A fixed 44-point frame surrounds a large styled label whose semantic font grows. It restricts the layout allocation as the content expands.

```swift
// Before
.frame(height: 44)

// After
.frame(minHeight: Theme.minTarget)
```

**Lines 17, 21, 32–34: Specify the containing bundle and extract localizable interface text (`localization.md`).**

Package interface text must resolve in its containing bundle. No localization resources were found in these targets; implicit lookup uses the app main bundle. Add the keys/resources to the target as part of the correction.

```swift
// Before
.accessibilityHint(count == 0 ? "Add text to a comment and finish recording to prepare feedback." : "Review comments, then send or save a draft.")

// After
.accessibilityHint(count == 0
    ? Text("Add text to a comment and finish recording to prepare feedback.", bundle: #bundle)
    : Text("Review comments, then send or save a draft.", bundle: #bundle))
```

**Lines 18, 22: Centralize spacing and padding in the shared design constants (`design.md`).**

Theme already supplies shared visual constants, but this view adds unrelated literal spacing/padding. The reference explicitly discourages scattered hard-coded spacing.

```swift
// Before
Text(count, format: .number).padding(.horizontal, 8)

// After
Text(count, format: .number).padding(.horizontal, Theme.feedbackCountPadding)
```

### FeedbackKit/FeedbackCheckboxStyle.swift

**Lines 12: Specify the containing bundle and extract localizable interface text (`localization.md`).**

Package interface text must resolve in its containing bundle. No localization resources were found in these targets; implicit lookup uses the app main bundle. Add the keys/resources to the target as part of the correction.

```swift
// Before
.accessibilityValue(configuration.isOn ? "Selected" : "Not selected")

// After
.accessibilityValue(configuration.isOn
    ? Text("Selected", bundle: #bundle)
    : Text("Not selected", bundle: #bundle))
```

**Lines 7, 10: Centralize spacing and padding in the shared design constants (`design.md`).**

Theme already supplies shared visual constants, but this view adds unrelated literal spacing/padding. The reference explicitly discourages scattered hard-coded spacing.

```swift
// Before
HStack(alignment: .top, spacing: 12) { /* label */ }.padding(.vertical, 10)

// After
HStack(alignment: .top, spacing: Theme.checkboxSpacing) { /* label */ }
    .padding(.vertical, Theme.checkboxPadding)
```

### FeedbackKit/FeedbackDeliveryResult.swift

**Lines 13–14, 17, 19–20, 23, 25, 28: Specify the containing bundle and extract localizable interface text (`localization.md`).**

The sent summary always uses comments, even for one. Use grammar agreement or plural resources; use Text formatting for the receipt so it follows environment locale, calendar and time zone. Localize the other package action/status strings too.

```swift
// Before
Text("Sent to \(entry.thread.displayName) · \(entry.items.count) comments · \(entry.receipt?.acknowledgedAt.formatted(date: .omitted, time: .shortened) ?? "")")

// After
Text("Sent to \(entry.thread.displayName) · ^[\(entry.items.count) comment](inflect: true)", bundle: #bundle)
if let receipt = entry.receipt {
    Text(receipt.acknowledgedAt, format: .dateTime.hour().minute())
}
```

**Lines 20, 23, 25: Extract button actions and business logic from view bodies (`views.md`).**

Keep layout separate from mutation and asynchronous orchestration. Parameterized actions should call a named method; directly pass parameterless methods through action:.

```swift
// Before
Button("Try Again") { Task { await model.retry() } }

// After
Button("Try Again", action: retry)
private func retry() { Task { await model.retry() } }
```

**Lines 9: Centralize spacing and padding in the shared design constants (`design.md`).**

Theme already supplies shared visual constants, but this view adds unrelated literal spacing/padding. The reference explicitly discourages scattered hard-coded spacing.

```swift
// Before
VStack(alignment: .leading, spacing: 16) { /* result */ }

// After
VStack(alignment: .leading, spacing: Theme.deliveryResultSpacing) { /* result */ }
```

### FeedbackKit/FeedbackHistoryRow.swift

**Lines 13, 16, 19, 21–22, 25, 27, 39, 50: Specify the containing bundle and extract localizable interface text (`localization.md`).**

The summary hard-codes a plural; check/resend notices are plain String values. Localize notices at creation, and use containing-bundle resources for buttons and labels.

```swift
// Before
Text("\(entry.items.count) comments · \(entry.thread.displayName)")

// After
Text("^[\(entry.items.count) comment](inflect: true) · \(entry.thread.displayName)", bundle: #bundle, comment: "Comment count and recipient thread")
```

**Lines 19, 22, 25: Extract button actions and business logic from view bodies (`views.md`).**

Keep layout separate from mutation and asynchronous orchestration. Parameterized actions should call a named method; directly pass parameterless methods through action:.

```swift
// Before
Button("Send") { Task { await send() } }

// After
Button("Send", action: startSend)
private func startSend() { Task { await send() } }
```

**Lines 11, 14, 32: Centralize spacing and padding in the shared design constants (`design.md`).**

Theme already supplies shared visual constants, but this view adds unrelated literal spacing/padding. The reference explicitly discourages scattered hard-coded spacing.

```swift
// Before
VStack(alignment: .leading, spacing: 10) { /* history */ }.padding(.vertical, 6)

// After
VStack(alignment: .leading, spacing: Theme.historyRowSpacing) { /* history */ }
    .padding(.vertical, Theme.historyRowPadding)
```

### FeedbackKit/FeedbackLimitError.swift

**Lines 13–19: Specify the containing bundle and extract localizable interface text (`localization.md`).**

LocalizedError does not localize the English literals automatically. Localize each description and add plural variations for snapshot/attachment counts where needed.

```swift
// Before
case .textTooLong: "The message exceeds 120,000 characters. Deselect comments to shorten it."

// After
case .textTooLong:
    String(localized: "The message exceeds 120,000 characters. Deselect comments to shorten it.", bundle: #bundle)
```

### FeedbackKit/FeedbackPreviewFixtures.swift

**Lines 12: Prefer Date.now over Date() (`swift.md`).**

Use the reference’s explicit modern date spelling.

```swift
// Before
let now = Date()

// After
let now = Date.now
```

### FeedbackKit/FeedbackPreviewModel.swift

**Lines 21–24: Use count(where:) for predicate counts (`swift.md`).**

Both counters allocate intermediate filtered arrays.

```swift
// Before
selected.filter { $0.lastSentRevision != nil }.count

// After
selected.count(where: { $0.lastSentRevision != nil })
// Apply the same change to pendingCount.
```

**Lines 21–49: Cache expensive preview derivations with explicit invalidation (`performance.md`).**

Computed properties called repeatedly by the sheet recompute scope, file checks, selected notes, package grouping/sorting, full message text and validation. Moving work to a computed model getter alone does not make it cached.

```swift
// Before
var package: FeedbackPackage? {
    // Build from selected notes on each read.
    FeedbackPackageBuilder.build(/* ... */)
}

// After
private(set) var previewPackage: FeedbackPackage?
private(set) var sendBlock: String?
// Recompute after selection, candidates, recipient, or source availability changes.
// Freeze a fresh timestamp/batch id explicitly when sending.
```

**Lines 31, 35–48, 75, 82, 89, 102: Specify the containing bundle and extract localizable interface text (`localization.md`).**

All locally authored blocking/error/reconciliation messages flow into Text as plain String. Localize them at creation, including recipient fallbacks.

```swift
// Before
return "Select at least one comment."

// After
return String(localized: "Select at least one comment.", bundle: #bundle)
```

### FeedbackKit/FeedbackPreviewSheet.swift

**Lines 14–81: Extract the oversized preview screen into separate View types (`views.md`).**

The body combines recipient selection, saved state, delivery state, candidate grouping, validation errors and bottom actions; extract these concerns into files.

```swift
// Before
NavigationStack { /* 65+ lines of branches and controls */ }

// After
NavigationStack {
    FeedbackPreviewContent(model: model, onClose: onClose)
        .safeAreaBar(edge: .bottom) { FeedbackPreviewActions(model: model) }
}
// Each extracted type in its own file.
```

**Lines 46–48, 82–90: Precompute snapshot groups outside body (`performance.md`).**

snapshotIds rebuilds a package and scans candidates; each row filters candidates and searches snapshots/screens again. Cache groups when source data changes.

```swift
// Before
ForEach(snapshotIds, id: \.self) { id in
    FeedbackSnapshotGroup(snapshot: canvas.snapshots.first { $0.id == id },
        title: groupTitle(id), notes: model.candidates.filter { $0.snapshotId == id }, model: model)
}

// After
ForEach(model.snapshotGroups) { group in
    FeedbackSnapshotGroup(snapshot: group.snapshot, title: group.title, notes: group.notes, model: model)
}
```

**Lines 60–76: Use safeAreaBar for a custom control bar (`resizability.md`).**

This is a pinned Send/Save action bar on an iOS 27 target. The reference calls for safeAreaBar on iOS 26+ to provide scroll-edge treatment.

```swift
// Before
.safeAreaInset(edge: .bottom) { /* Send / Save controls */ }

// After
.safeAreaBar(edge: .bottom) { /* Send / Save controls */ }
```

**Lines 26, 64, 67: Extract button actions and business logic from view bodies (`views.md`).**

Keep layout separate from mutation and asynchronous orchestration. Parameterized actions should call a named method; directly pass parameterless methods through action:.

```swift
// Before
Button("Send to Agent") { Task { await model.send() } }

// After
Button("Send to Agent", action: send)
private func send() { Task { await model.send() } }
```

**Lines 18, 26, 31, 34–35, 40, 42, 44, 51, 58, 63–67, 88–90: Specify the containing bundle and extract localizable interface text (`localization.md`).**

Localize package text and fallbacks, with plural resources/grammatical agreement for the pending/new-comment messages. groupTitle currently builds English Now/Proposal/Iteration into a String. Explain count and recipient placeholders to translators.

```swift
// Before
Text("\(model.pendingCount) comments still recording or transcribing stay on the canvas")

// After
Text("^[\(model.pendingCount) comment](inflect: true) still recording or transcribing stay on the canvas", bundle: #bundle)
```

**Lines 17, 62: Centralize spacing and padding in the shared design constants (`design.md`).**

Theme already supplies shared visual constants, but this view adds unrelated literal spacing/padding. The reference explicitly discourages scattered hard-coded spacing.

```swift
// Before
VStack(alignment: .leading, spacing: 20) { /* preview */ }

// After
VStack(alignment: .leading, spacing: Theme.feedbackSectionSpacing) { /* preview */ }
```

### FeedbackKit/FeedbackSnapshotGroup.swift

**Lines 17–19: Choose the expanded layout only for a regular size class (`resizability.md`).**

The compact test routes nil to the spacious HStack. Optional size classes must explicitly equal regular to choose the expanded layout.

```swift
// Before
sizeClass == .compact
    ? AnyLayout(VStackLayout())
    : AnyLayout(HStackLayout())

// After
sizeClass == .regular
    ? AnyLayout(HStackLayout())
    : AnyLayout(VStackLayout())
```

**Lines 17–34: Provide a fitting fallback for the fixed thumbnail and note columns (`design.md; accessibility.md`).**

A 200-point thumbnail and horizontal spacing compete with dynamically sized note text in a narrow regular-width sheet. Size class alone does not account for accessibility text size. Use measured fitting or an accessibility-size vertical arrangement; constrain the preview by available width.

```swift
// Before
let layout = sizeClass == .compact ? AnyLayout(VStackLayout()) : AnyLayout(HStackLayout())
// Thumbnail: .frame(width: 200)

// After
@Environment(\.dynamicTypeSize) private var dynamicTypeSize
// Use ViewThatFits or choose vertical at accessibility sizes;
// constrain thumbnail to available width instead of requiring 200 points.
```

**Lines 37–44: Extract rendering task logic and decode thumbnails off MainActor (`views.md; performance.md`).**

The task mixes view layout with render orchestration and synchronous ImageIO image creation. Move it into an async method/model, offloading decode as well as CompositeRenderer preparation.

```swift
// Before
.task(id: items) {
    let png = try await CompositeRenderer.render(/* ... */)
    thumbnail = CGImageSourceCreateWithData(png as CFData, nil)
        .flatMap { CGImageSourceCreateImageAtIndex($0, 0, nil) }
}

// After
.task(id: items) { await renderThumbnail() }
// renderThumbnail delegates decoding to a worker actor and publishes thumbnail/error.
```

**Lines 26, 39: Specify the containing bundle and extract localizable interface text (`localization.md`).**

Package interface text must resolve in its containing bundle. No localization resources were found in these targets; implicit lookup uses the app main bundle. Add the keys/resources to the target as part of the correction.

```swift
// Before
renderError = "Snapshot is missing"

// After
renderError = String(localized: "Snapshot is missing", bundle: #bundle)
```

**Lines 15, 18–19, 30: Centralize spacing and padding in the shared design constants (`design.md`).**

Theme already supplies shared visual constants, but this view adds unrelated literal spacing/padding. The reference explicitly discourages scattered hard-coded spacing.

```swift
// Before
VStack(alignment: .leading, spacing: 12) { /* snapshot */ }

// After
VStack(alignment: .leading, spacing: Theme.snapshotGroupSpacing) { /* snapshot */ }
```

### T3Kit/MCPClient.swift

**Lines 55, 69, 95: Use modern URL appending and Swift-native replacement (`swift.md`).**

These exact older Foundation spellings are named by the reference.

```swift
// Before
credentials.hostURL.appendingPathComponent("mcp")
text.replacingOccurrences(of: "\r\n", with: "\n")

// After
credentials.hostURL.appending(path: "mcp")
text.replacing("\r\n", with: "\n")
```

### T3Kit/MCPError.swift

**Lines 7–10, 12: Specify the containing bundle and extract localizable interface text (`localization.md`).**

LocalizedError does not translate String literals. Keep server-authored error messages verbatim; localize locally authored fallback descriptions.

```swift
// Before
case .transport: "The connection to T3 Code was interrupted."

// After
case .transport: String(localized: "The connection to T3 Code was interrupted.", bundle: #bundle)
```

### T3Kit/T3Connection.swift

**Lines 10, 30: Specify the containing bundle and extract localizable interface text (`localization.md`).**

Package interface text must resolve in its containing bundle. No localization resources were found in these targets; implicit lookup uses the app main bundle. Add the keys/resources to the target as part of the correction.

```swift
// Before
state = .failed("Could not save the credential in Keychain.")

// After
state = .failed(String(localized: "Could not save the credential in Keychain.", bundle: #bundle))
```

**Lines 42, 47, 55: Prefer Date.now over Date() (`swift.md`).**

Use the reference’s explicit modern date spelling.

```swift
// Before
guard credential.expiresAt > Date() else { /* expired */ }

// After
guard credential.expiresAt > Date.now else { /* expired */ }
```

### T3Kit/T3Credentials.swift

**Lines 3: Give custom value types stored by an observable class Equatable conformance (`data.md`).**

T3Credentials contains only equatable fields (including T3Endpoint), but lacks conformance; equal-value credential assignments cannot use the equality optimization.

```swift
// Before
nonisolated public struct T3Credentials: Codable, Sendable { /* ... */ }

// After
nonisolated public struct T3Credentials: Codable, Sendable, Equatable { /* ... */ }
```

### T3Kit/T3Pairing.swift

**Lines 19, 22, 33, 40, 82: Use modern URL appending and Swift-native replacement (`swift.md`).**

Replace the older path-component and replacement spellings while preserving the well-known endpoint paths.

```swift
// Before
origin.appendingPathComponent(".well-known/t3/environment")
data.base64EncodedString().replacingOccurrences(of: "+", with: "-")

// After
origin.appending(path: ".well-known/t3/environment")
data.base64EncodedString().replacing("+", with: "-")
```

**Lines 39, 52, 59: Prefer Date.now over Date() (`swift.md`).**

Use the reference’s explicit modern date spelling.

```swift
// Before
let started = Date()
guard Date().timeIntervalSince(started) < 60 else { throw T3PairingError.expired }

// After
let started = Date.now
guard Date.now.timeIntervalSince(started) < 60 else { throw T3PairingError.expired }
```

**Lines 50: Specify the containing bundle and extract localizable interface text (`localization.md`).**

Only the locally authored fallback needs localization; preserve remote error_description text as supplied.

```swift
// Before
value("error_description") ?? "T3 Code rejected the authorization request."

// After
value("error_description") ?? String(localized: "T3 Code rejected the authorization request.", bundle: #bundle)
```

### T3Kit/T3PairingError.swift

**Lines 8–12, 14: Specify the containing bundle and extract localizable interface text (`localization.md`).**

Package interface text must resolve in its containing bundle. No localization resources were found in these targets; implicit lookup uses the app main bundle. Add the keys/resources to the target as part of the correction.

```swift
// Before
case .invalidHost: "Enter an HTTPS host, or HTTP on localhost."

// After
case .invalidHost: String(localized: "Enter an HTTPS host, or HTTP on localhost.", bundle: #bundle)
```

### T3Kit/T3PairingView.swift

**Lines 14–84: Extract the oversized pairing body into concern-specific Views (`views.md`).**

The body includes instructions, host, pairing-code normalization, access policy, connection and error states. Separate form sections into their own files.

```swift
// Before
Form { /* instructions, host/code, access, connection status */ }

// After
Form {
    PairingInstructions()
    PairingHostFields(host: $host, code: $code)
    PairingAccessPicker(selection: $accessLevel)
    PairingConnectionSection(/* inputs */)
}
```

**Lines 18–83, 86–92: Specify the containing bundle and extract localizable interface text (`localization.md`).**

Access descriptions are plain String text. All static form text must use this package’s bundle, with translator context for access-policy terminology.

```swift
// Before
Text(accessDescription)

// After
Text(accessDescription)
// Change accessDescription to LocalizedStringResource and return
// LocalizedStringResource("View threads. Sending feedback is unavailable.", bundle: #bundle).
```

### T3Kit/T3ThreadPickerView.swift

**Lines 15–16, 23–25, 55: Precompute filtered and grouped threads outside body (`performance.md`).**

groups, filtered, per-group first/filter and empty-state checks repeatedly rebuild the same search results. Compute a grouped projection when search or threads changes.

```swift
// Before
ForEach(groups, id: \.self) { project in
    ForEach(filtered.filter { ($0.projectId ?? "Other threads") == project }) { thread in /* row */ }
}

// After
ForEach(model.filteredProjectGroups) { group in
    Section(group.title) { ForEach(group.threads) { thread in /* row */ } }
}
```

**Lines 17–58: Extract a thread row and readable empty/loading state (`views.md`).**

The body embeds a long row, formatter-backed recency, status badge, selection, and a one-line overlay with multiple branches. Extract actual View structs in separate files.

```swift
// Before
Button { pick(thread) } label: {
    HStack { /* title, project, recency, status, selection */ }
}

// After
ThreadPickerRow(thread: thread, isSelected: isSelected(thread), onPick: pick)
// ThreadPickerRow.swift owns the row layout.
```

**Lines 60–63: Use modern date formatting and the view environment (`swift.md; localization.md`).**

A new RelativeDateTimeFormatter is created per row per tick, using current locale instead of the view locale. Use relative FormatStyle for live recency.

```swift
// Before
Text(Self.recency(updatedAt, now: context.date))

// After
Text(updatedAt, format: .relative(presentation: .named, unitsStyle: .abbreviated))
```

**Lines 55: Use the standard search empty state (`design.md`).**

The search branch customizes a generic ContentUnavailableView despite searchable already knowing the query.

```swift
// Before
ContentUnavailableView("No matching threads", systemImage: "bubble.left.and.bubble.right", description: Text("Try another thread title or project name."))

// After
ContentUnavailableView.search
```

**Lines 15–16, 21, 24, 30, 38–46, 55–57, 65–70: Specify the containing bundle and extract localizable interface text (`localization.md`).**

Localize locally authored project fallbacks, status labels, loading/error actions and empty-state text. Keep thread/project titles supplied by the service verbatim.

```swift
// Before
case "running", "preparing", "starting": "Running"

// After
case "running", "preparing", "starting":
    String(localized: "Running", bundle: #bundle)
```

**Lines 28, 40: Centralize spacing and padding in the shared design constants (`design.md`).**

Theme already supplies shared visual constants, but this view adds unrelated literal spacing/padding. The reference explicitly discourages scattered hard-coded spacing.

```swift
// Before
VStack(alignment: .leading, spacing: 6) { /* thread */ }

// After
VStack(alignment: .leading, spacing: Theme.threadRowSpacing) { /* thread */ }
```

### T3Kit/T3ThreadService.swift

**Lines 154: Prefer Swift-native string replacement (`swift.md`).**

The reference explicitly replaces replacingOccurrences(of:with:).

```swift
// Before
status?.replacingOccurrences(of: "_", with: " ").capitalized

// After
status?.replacing("_", with: " ").capitalized
```

**Lines 112, 128, 139: Prefer Date.now over Date() (`swift.md`).**

Use the reference’s explicit modern date spelling.

```swift
// Before
MessageAck(messageId: id, acknowledgedAt: Date())

// After
MessageAck(messageId: id, acknowledgedAt: Date.now)
```

**Lines 18, 54, 61, 68, 71, 78, 81–83, 89, 93, 115: Specify the containing bundle and extract localizable interface text (`localization.md`).**

Locally authored transport/validation descriptions reach the UI as String payloads. Localize those and the Untitled thread fallback; leave protocol identifiers and remote-authored messages unchanged.

```swift
// Before
throw .notSent("Attach between 1 and 8 files.")

// After
throw .notSent(String(localized: "Attach between 1 and 8 files.", bundle: #bundle))
```

### VoiceKit/ElevenLabsResponse.swift

**Lines 5, 10–14: Place each type in its own Swift file (`views.md`).**

The file defines ElevenLabsResponse and nested CodingKeys. The reference explicitly includes structs, classes, and enums; preserve qualified names when moving nested types into extensions in separate files; adjust private access only as required for cross-file use.

```swift
// Before
// ElevenLabsResponse.swift
// Definitions: ElevenLabsResponse and nested CodingKeys

// After
// One file per type; retain qualified names and the narrowest valid access.
// Put each nested definition in an extension of its original owner.
```

### DrawspeakCore/Design/Theme.swift

**Lines 45–59: Avoid UIKit colors in SwiftUI (`design.md`).**

Dynamic palette colors are implemented using UIColor(traits:), and the non-UIKit branch always selects light colors. Use named light/dark asset colors; the reference explicitly prefers Color/assets.

```swift
// Before
self.init(uiColor: UIColor { traits in
    // Pick light/dark UIColor.
})

// After
// Asset catalog defines light, dark and high-contrast appearances.
public static let canvas = Color("CanvasBackground", bundle: #bundle)
```

**Lines 4, 64–78: Place each type in its own Swift file (`views.md`).**

The file defines Theme and PaletteBackground. The reference explicitly includes structs, classes, and enums; preserve qualified names when moving nested types into extensions in separate files; adjust private access only as required for cross-file use.

```swift
// Before
// Theme.swift
// Definitions: Theme and PaletteBackground

// After
// One file per type; retain qualified names and the narrowest valid access.
// Put each nested definition in an extension of its original owner.
```

**Lines 69–76: Preserve content identity when changing transparency treatment (`performance.md`).**

The two branches wrap the caller’s content differently. Changing Reduce Transparency recreates the content subtree, which can lose editor/focus state. Keep one content node and condition only the decoration.

```swift
// Before
if reduceTransparency {
    content.background(Theme.surface).shadow(radius: 8)
} else {
    content.glassEffect(.regular)
}

// After
content.background {
    if reduceTransparency {
        RoundedRectangle(cornerRadius: Theme.paletteCornerRadius).fill(Theme.surface)
    } else {
        RoundedRectangle(cornerRadius: Theme.paletteCornerRadius).fill(.clear)
            .glassEffect(.regular, in: .rect(cornerRadius: Theme.paletteCornerRadius))
    }
}
// Keep content itself outside the conditional branches.
```

### DrawspeakCore/Persistence/BlobStore.swift

**Lines 6, 52–54: Place each type in its own Swift file (`views.md`).**

The file defines BlobStore and BlobStoreError. The reference explicitly includes structs, classes, and enums; preserve qualified names when moving nested types into extensions in separate files; adjust private access only as required for cross-file use.

```swift
// Before
// BlobStore.swift
// Definitions: BlobStore and BlobStoreError

// After
// One file per type; retain qualified names and the narrowest valid access.
// Put each nested definition in an extension of its original owner.
```

**Lines 14: Avoid C-style number formatting (`swift.md`).**

Hex encoding is a storage format, so preserve fixed ASCII and two digits rather than using locale-dependent number formatting. A fixed lookup removes String(format:) without changing the digest contract.

```swift
// Before
SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()

// After
let digits = Array("0123456789abcdef".utf8)
return String(decoding: SHA256.hash(data: data).flatMap { byte in
    [digits[Int(byte >> 4)], digits[Int(byte & 0x0f)]]
}, as: UTF8.self)
```

### DrawspeakCore/Persistence/StorageLocations.swift

**Lines 12: Use modern Foundation directory properties (`swift.md`).**

The reference prefers URL’s directory properties over FileManager directory lookup. Creation remains the store’s responsibility (it already creates parent directories).

```swift
// Before
let base = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)

// After
let base = URL.applicationSupportDirectory
```

### DrawspeakCore/Services/ServiceProtocols.swift

**Lines 5, 26, 41, 47–57, 69, 81, 91, 100, 114, 130, 149: Place each type in its own Swift file (`views.md`).**

The file defines VoiceCapturing, CapturedAudio, Transcribing, TranscriptionFailure/Code, OutgoingAttachment, MessageAck, DeliveryFailure, ThreadAttachment, ThreadMessage, ThreadSummary, ThreadService. The reference explicitly includes structs, classes, and enums; preserve qualified names when moving nested types into extensions in separate files; adjust private access only as required for cross-file use.

```swift
// Before
// ServiceProtocols.swift
// Definitions: VoiceCapturing, CapturedAudio, Transcribing, TranscriptionFailure/Code, OutgoingAttachment, MessageAck, DeliveryFailure, ThreadAttachment, ThreadMessage, ThreadSummary, ThreadService

// After
// One file per type; retain qualified names and the narrowest valid access.
// Put each nested definition in an extension of its original owner.
```

### DrawspeakCore/Services/Workspace.swift

**Lines 390–392, 459–464, 724–738, 896–918, 1250–1259: Move bulk disk I/O, hashing and parsing off MainActor (`performance.md; swift.md`).**

Workspace is explicitly MainActor. Import writes/hashes blobs synchronously; Stop reads and copies a complete recording; transcription reads and hashes it before the Task; Pull parses/validates large replies on MainActor. Creating Task later does not offload the preceding work.

```swift
// Before
ref = try blobs.put(Data(contentsOf: fileURL), contentType: contentType)
// Also: try? blobs.data(for: audio) before Task.

// After
let ref = try await blobWorker.storeFile(fileURL, contentType: contentType)
// Worker actor owns file I/O and hashing; apply the result on MainActor.
// Preserve scope/attempt checks and durable-save-before-delete semantics.
```

**Lines 8, 60, 155, 286, 295, 638, 967, 1169, 1219: Place each type in its own Swift file (`views.md`).**

The file defines Workspace plus LoadOutcome, SaveBlocked, ImportTarget, ImportError, VoiceIssue, DraftResume, ReconcileResult, PullReport. Concurrent additions also introduce LiveSession and nested Outcome (lines 768–777). The reference explicitly includes structs, classes, and enums; preserve qualified names when moving nested types into extensions in separate files; adjust private access only as required for cross-file use.

```swift
// Before
// Workspace.swift
// Definitions: Workspace plus LoadOutcome, SaveBlocked, ImportTarget, ImportError, VoiceIssue, DraftResume, ReconcileResult, PullReport

// After
// One file per type; retain qualified names and the narrowest valid access.
// Put each nested definition in an extension of its original owner.
```

**Lines 438: Unwrap the existing snapshot directly rather than search twice and force unwrap (`swift.md`).**

The second lookup is provably nonnil here, but the force unwrap is unnecessary and adds another full scan.

```swift
// Before
if canvas.snapshots.contains(where: { $0.id == id }) {
    return canvas.snapshots.first { $0.id == id }!
}

// After
if let existing = canvas.snapshots.first(where: { $0.id == id }) {
    return existing
}
```

**Lines 1207–1209: Surface errors from a user-initiated refresh (`swift.md`).**

DraftsAndHistoryView.refreshable calls refreshAgentStatus. The try? returns silently on a network error, leaving stale status without explaining refresh failure.

```swift
// Before
guard let status = try? await threads.threadStatus(threadId: thread.threadId) else { return }

// After
do {
    let status = try await threads.threadStatus(threadId: thread.threadId)
    // Apply status.
} catch {
    agentStatusRefreshError = String(localized: "Could not refresh agent status. Try again.", bundle: #bundle)
}
// Display agentStatusRefreshError in the history screen.
```

**Lines 80, 97, 117, 146, 178, 202, 540, 602, 625, 1024–1026, 1106, 1119, 1143, 1234–1244, 1253, 1300, 1313, 1352, 1355: Specify the containing bundle and extract localizable interface text (`localization.md`).**

Locally authored save/open/pull/connection errors, undo names and the seeded First review title are plain English strings. Localize at creation; do not localize protocol fields, batch markers, backup filenames or external text.

```swift
// Before
lastSaveError = "Could not save changes"

// After
lastSaveError = String(localized: "Could not save changes", bundle: #bundle)
```

**Lines 948: Prefer modern date formatting and Swift-native replacement (`swift.md`).**

newBatchId constructs a legacy ISO8601DateFormatter for each batch and uses replacingOccurrences. The timestamp is a protocol identifier, so keep fixed ISO8601/ASCII semantics.

```swift
// Before
ISO8601DateFormatter().string(from: now).replacingOccurrences(of: ":", with: "").prefix(15)

// After
now.formatted(.iso8601).replacing(":", with: "").prefix(15)
```

**Lines 95, 143, 146: Prefer Date.now over Date() (`swift.md`).**

Use the reference’s explicit modern date spelling.

```swift
// Before
Project(name: "Drawspeak", createdAt: Date())

// After
Project(name: "Drawspeak", createdAt: Date.now)
```

**Lines 768–777, 782: Give custom value types stored by an observable class Equatable conformance (`data.md`).**

The newly added LiveSession is stored in observable liveSessions. Every field is equatable, including its Outcome enum, but LiveSession lacks conformance; equal assignments cannot use Observation's equality optimization.

```swift
// Before
struct LiveSession {
    enum Outcome: Equatable { case finished(String), failed(String) }
    // Equatable fields ...
}

// After
struct LiveSession: Equatable {
    // Same fields; move Outcome and LiveSession into their own files.
}
```

### DrawspeakCore/Logic/CanvasLayout.swift

**Lines 50–53, 64: Specify the containing bundle and extract localizable interface text (`localization.md`).**

Proposal/Now are interface labels consumed by views as Strings. Localize the labels where they are created; keep proposal identifiers unchanged.

```swift
// Before
return "Proposal \(trimmed)"

// After
return String(localized: "Proposal \(trimmed)", bundle: #bundle, comment: "Proposal identifier used as a canvas lane title")
```

### DrawspeakCore/Logic/FeedbackManifest.swift

**Lines 4, 5, 14: Place each type in its own Swift file (`views.md`).**

The file defines FeedbackManifest, nested Item, nested SnapshotEntry. The reference explicitly includes structs, classes, and enums; preserve qualified names when moving nested types into extensions in separate files; adjust private access only as required for cross-file use.

```swift
// Before
// FeedbackManifest.swift
// Definitions: FeedbackManifest, nested Item, nested SnapshotEntry

// After
// One file per type; retain qualified names and the narrowest valid access.
// Put each nested definition in an extension of its original owner.
```

### DrawspeakCore/Logic/FeedbackPackage.swift

**Lines 4, 5: Place each type in its own Swift file (`views.md`).**

The file defines FeedbackPackage and nested Group. The reference explicitly includes structs, classes, and enums; preserve qualified names when moving nested types into extensions in separate files; adjust private access only as required for cross-file use.

```swift
// Before
// FeedbackPackage.swift
// Definitions: FeedbackPackage and nested Group

// After
// One file per type; retain qualified names and the narrowest valid access.
// Put each nested definition in an extension of its original owner.
```

### DrawspeakCore/Logic/FeedbackPackageBuilder.swift

**Lines 33: Avoid C-style number formatting while retaining fixed filename semantics (`swift.md`).**

The two-digit filename prefix can be created without String(format:). Keep it ASCII because it is interchange data.

```swift
// Before
String(format: "%02d-%@.png", index + 1, safeFileComponent(snapshot.id))

// After
"\(index + 1 < 10 ? "0" : "")\(index + 1)-\(safeFileComponent(snapshot.id)).png"
```

### DrawspeakCore/Logic/FeedbackScope.swift

**Lines 14, 21–29: Specify the containing bundle and extract localizable interface text (`localization.md`).**

Readiness reasons are interface text subsequently passed into chips, previews and error labels. Localize all locally authored reasons at creation.

```swift
// Before
public static let captureMissingReason = "Preview image is still being created"

// After
public static var captureMissingReason: String {
    String(localized: "Preview image is still being created", bundle: #bundle)
}
```

### DrawspeakCore/Logic/NoteReadiness.swift

**Lines 23–30: Specify the containing bundle and extract localizable interface text (`localization.md`).**

The readiness chip receives label as String, so these literals bypass Text localization. Preserve associated reasons already localized at their origin.

```swift
// Before
case .markOnly: "No comment yet"

// After
case .markOnly: String(localized: "No comment yet", bundle: #bundle)
```

### DrawspeakCore/Logic/ReviewManifest.swift

**Lines 4, 5, 30, 51, 57: Place each type in its own Swift file (`views.md`).**

The file defines ReviewManifest, nested Entry/Check, ManifestIssue, ManifestValidator. The reference explicitly includes structs, classes, and enums; preserve qualified names when moving nested types into extensions in separate files; adjust private access only as required for cross-file use.

```swift
// Before
// ReviewManifest.swift
// Definitions: ReviewManifest, nested Entry/Check, ManifestIssue, ManifestValidator

// After
// One file per type; retain qualified names and the narrowest valid access.
// Put each nested definition in an extension of its original owner.
```

**Lines 78–84, 91–138: Specify the containing bundle and extract localizable interface text (`localization.md`).**

Validation issues are surfaced through Workspace.PullReport. Localize human-facing descriptions; preserve schema/status identifiers and source paths verbatim.

```swift
// Before
fail("Image checksum mismatch")

// After
fail(String(localized: "Image checksum mismatch", bundle: #bundle))
```

### DrawspeakCore/Logic/TextBundleParser.swift

**Lines 16–20: Place each type in its own Swift file (`views.md`).**

The file defines TextBundleParser and nested Bundle. The reference explicitly includes structs, classes, and enums; preserve qualified names when moving nested types into extensions in separate files; adjust private access only as required for cross-file use.

```swift
// Before
// TextBundleParser.swift
// Definitions: TextBundleParser and nested Bundle

// After
// One file per type; retain qualified names and the narrowest valid access.
// Put each nested definition in an extension of its original owner.
```

### DrawspeakCore/Logic/TranscriptMerge.swift

**Lines 4, 16, 25: Place each type in its own Swift file (`views.md`).**

The file defines RecordingScope, TranscriptMergeOutcome, TranscriptMerge. The reference explicitly includes structs, classes, and enums; preserve qualified names when moving nested types into extensions in separate files; adjust private access only as required for cross-file use.

```swift
// Before
// TranscriptMerge.swift
// Definitions: RecordingScope, TranscriptMergeOutcome, TranscriptMerge

// After
// One file per type; retain qualified names and the narrowest valid access.
// Put each nested definition in an extension of its original owner.
```

### DrawspeakCore/Model/AnnotationShape.swift

**Lines 38–45: Specify the containing bundle and extract localizable interface text (`localization.md`).**

Shape-kind names appear in inspector text and accessibility phrases; they are localizable interface text rather than user content.

```swift
// Before
case .ellipse: "Oval"

// After
case .ellipse: String(localized: "Oval", bundle: #bundle)
```

### DrawspeakCore/Model/DOMTarget.swift

**Lines 4, 10, 29, 44, 53: Place each type in its own Swift file (`views.md`).**

The file defines LocatorStrategy, DOMLocator, DOMElementInfo, SelectionMethod, DOMTarget. The reference explicitly includes structs, classes, and enums; preserve qualified names when moving nested types into extensions in separate files; adjust private access only as required for cross-file use.

```swift
// Before
// DOMTarget.swift
// Definitions: LocatorStrategy, DOMLocator, DOMElementInfo, SelectionMethod, DOMTarget

// After
// One file per type; retain qualified names and the narrowest valid access.
// Put each nested definition in an extension of its original owner.
```

### DrawspeakCore/Model/DeliveryReceipt.swift

**Lines 3, 11: Place each type in its own Swift file (`views.md`).**

The file defines DeliveryReceipt and nested Confirmation. The reference explicitly includes structs, classes, and enums; preserve qualified names when moving nested types into extensions in separate files; adjust private access only as required for cross-file use.

```swift
// Before
// DeliveryReceipt.swift
// Definitions: DeliveryReceipt and nested Confirmation

// After
// One file per type; retain qualified names and the narrowest valid access.
// Put each nested definition in an extension of its original owner.
```

### DrawspeakCore/Model/NormalizedGeometry.swift

**Lines 6, 21: Place each type in its own Swift file (`views.md`).**

The file defines NPoint and NRect. The reference explicitly includes structs, classes, and enums; preserve qualified names when moving nested types into extensions in separate files; adjust private access only as required for cross-file use.

```swift
// Before
// NormalizedGeometry.swift
// Definitions: NPoint and NRect

// After
// One file per type; retain qualified names and the narrowest valid access.
// Put each nested definition in an extension of its original owner.
```

### DrawspeakCore/Model/OutboxEntry.swift

**Lines 4, 30: Place each type in its own Swift file (`views.md`).**

The file defines OutboxEntry and DeliveryAttempt. The reference explicitly includes structs, classes, and enums; preserve qualified names when moving nested types into extensions in separate files; adjust private access only as required for cross-file use.

```swift
// Before
// OutboxEntry.swift
// Definitions: OutboxEntry and DeliveryAttempt

// After
// One file per type; retain qualified names and the narrowest valid access.
// Put each nested definition in an extension of its original owner.
```

### DrawspeakCore/Model/Screen.swift

**Lines 5, 22: Place each type in its own Swift file (`views.md`).**

The file defines Screen and WorldPoint. The reference explicitly includes structs, classes, and enums; preserve qualified names when moving nested types into extensions in separate files; adjust private access only as required for cross-file use.

```swift
// Before
// Screen.swift
// Definitions: Screen and WorldPoint

// After
// One file per type; retain qualified names and the narrowest valid access.
// Put each nested definition in an extension of its original owner.
```

### DrawspeakCore/Model/Snapshot.swift

**Lines 84–87: Specify the containing bundle and extract localizable interface text (`localization.md`).**

versionLabel is displayed verbatim by NotesPresentation and views; localize Now and Iteration at creation.

```swift
// Before
case .proposal: "Iteration \(iteration)"

// After
case .proposal: String(localized: "Iteration \(iteration)", bundle: #bundle, comment: "Proposal version number")
```

### VoiceKit/PCMConverter.swift

**Lines 6, 47: Place each type in its own Swift file (`views.md`).**

The concurrently added file declares both PCMConverter and PCMChunker. Keep conversion and chunk accumulation in separate files.

```swift
// Before
// PCMConverter.swift contains PCMConverter and PCMChunker.

// After
// PCMConverter.swift contains PCMConverter.
// PCMChunker.swift contains PCMChunker.
```

### Summary — prioritized top 20

1. **High — MainActor image pipeline:** Offload blob reads, thumbnail decoding and PNG encoding in `FeedbackKit/CompositeRenderer.swift:7–34`; keep ImageRenderer on MainActor.
2. **High — MainActor storage pipeline:** Offload import/audio blob I/O, hashing and Pull parsing in `DrawspeakCore/Services/Workspace.swift:390–392, 724–738, 895–917, 1249–1258`, preserving durability and ownership checks.
3. **High — State initialization:** Remove the declaration initializer for `AddRegionSheet.snapshotId` (`NotesKit/AddRegionSheet.swift:9,19`).
4. **High — Resize state preservation:** Keep one Add Region content identity across size-class changes (`NotesKit/AddRegionSheet.swift:42–47`).
5. **High — Dynamic Type:** Replace Feedback’s fixed 44-point height with a minimum (`FeedbackKit/FeedbackButton.swift:30`).
6. **High — Localization resources:** Add containing-bundle localization throughout NotesKit, FeedbackKit, T3Kit and Core presentation labels; plain String messages currently bypass extraction.
7. **High — Plurals:** Replace manual singular/plural construction and hard-coded comments/snapshots wording in Drafts, delivery results, history and preview.
8. **Medium — Preview recomputation:** Cache derived package, validation and grouping results with explicit invalidation (`FeedbackPreviewModel.swift:21–49`, `FeedbackPreviewSheet.swift:46–48,82–90`).
9. **Medium — Feedback counter cost:** Remove full scope classification and filesystem checks from Feedback button rendering (`FeedbackButton.swift:12–14`).
10. **Medium — Notes list computation:** Precompute sorted snapshot groups and missing-source notes (`NotesListView.swift:16–18,31`).
11. **Medium — Lazy row shape:** Filter empty snapshot sections before ForEach (`NotesListView.swift:16–29`).
12. **Medium — Thread search computation:** Precompute filtered project groups (`T3ThreadPickerView.swift:15–25`).
13. **Medium — Snapshot adaptation:** Explicitly test regular size class and provide a fitting/Dynamic Type fallback for thumbnail/note columns (`FeedbackSnapshotGroup.swift:17–34`).
14. **Medium — Snapshot work:** Cache cropped images and offload preview decode (`SnapshotMarkPreview.swift:27–31`, `FeedbackSnapshotGroup.swift:37–44`).
15. **Medium — Inline editor:** Replace the inspector TextEditor/placeholder overlay with a vertical TextField (`NoteTextEditor.swift:13–25`).
16. **Medium — View composition:** Extract oversized pairing, inspector and feedback bodies, plus AddRegionSheet’s substantial some View helpers, into separate View files.
17. **Medium — Shared palette:** Replace UIColor-based dynamic colors with SwiftUI asset colors and preserve caller content identity when Reduce Transparency changes (`Theme.swift:45–76`).
18. **Medium — Refresh feedback:** Surface user-initiated agent-status refresh failures (`Workspace.swift:1207–1209`).
19. **Medium — Adaptive action bar:** Use safeAreaBar for Send/Save controls (`FeedbackPreviewSheet.swift:60–76`).
20. **Low — Structural and API consistency:** Split files containing multiple types; extract inline actions; centralize spacing; use count(where:), FormatStyle, modern URL/string APIs and Date.now at the cited sites.
