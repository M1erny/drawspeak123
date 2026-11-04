# Native v2: Apple design review and copy audit

Reviewer: Claude Opus 5.5, `apple-design` skill (full procedure, five lenses plus design-craft lens).
Inputs: the 13 screenshots in this folder (iPad Pro 13", iPadOS 27, windowed mode: the resize grabber is visible bottom-right), the v1 report (`../native-v1/hig-review-opus.md`), and the SwiftUI sources in `App/Drawspeak/**` and `Packages/DrawspeakKit/Sources/{CanvasKit,NotesKit,FeedbackKit,T3Kit}/**` (read-only).
HIG files opened and cited: `toolbars.md`, `sheets.md`, `popovers.md`, `panels.md`, `modality.md`, `writing.md`, `menus.md`, `buttons.md`, `icons.md`, `liquid-glass.md`, `layout.md`, `designing-for-ipados.md`, `apple-pencil-and-scribble.md`, `settings.md`, `onboarding.md`, `feedback.md`, `dark-mode.md`, `design-principles.md`, `accessibility.md`, `color.md`, `typography.md`.

Limits:
- `light-threads.png` shows the thread picker in its loading state, not the pairing form. I reviewed the pairing form from `T3PairingView.swift` only.
- There is no screenshot of the recording state, the component chooser, a delivery result, or compact width. I reviewed those from code.
- Text on Liquid Glass has no fixed background, so I cannot compute its contrast. I computed ratios only for opaque surfaces from the hex values in `Theme.swift`.

---

## Summary

**Rating: Needs work.** No accessibility failure is Critical, but several High convention breaks support the owner's verdict.

The thesis is clear and good: a red mark and a numbered pin on an unchanged screenshot, plus a voice comment, sent to an agent. That signature still works. The canvas cards, the #BD3048 mark (white pin label 5.7:1) and the pins are the best part of the app.

Everything around the signature looks like a web app built with glass:
- **Five custom floating glass surfaces** (title, actions, Feedback, tools, zoom), plus banners, a recording bar and a floating inspector. A standard toolbar would do the same job.
- **Two different surfaces for comments**: a Comments sheet and a floating card that covers a third of the canvas, most of it empty glass.
- **Nine sheets with four dismissal patterns**, mostly with large titles.
- **Too much copy.** The visible Settings footers alone are 101 words. The pairing form has 174 words of prose. The Feedback sheet gives three separate explanations for one missing thread ("Choose Thread…", "→ No recipient", "Connect this canvas to a T3 thread to send").

Apple's own test is Simplicity: "every element earning its place" (`design-principles.md › Simplicity`). Many elements here fail it.

### What v1 fixed, and what is still wrong

| v1 item | State in v2 |
| --- | --- |
| 1 Inspector preview fills the card | Fixed: cropped 180 pt preview, editor under the header, Delete in More. **New problem:** the card now fills the full window height even when its content is short, so about 650 pt of empty glass covers Proposal B (`light-inspector.png`). |
| 2 Feedback rows under the action bar | Fixed: no overlap. **Still wrong:** the thumbnail and the rows are not side by side. `FeedbackSnapshotGroup.swift:17` chooses the layout from `horizontalSizeClass`, which is `.compact` inside a form sheet. The block reason now sits below Save Draft, not next to the disabled Send. |
| 3, 4 Dark Feedback contrast; mark color | Fixed: `actionFill` #1758BD (white 6.6:1) and `annotation` #BD3048. |
| 5 Feedback without a thread | "To / Choose Thread…" was added, but the same fact is now stated three times (see F-4). |
| 6 Send prominent | Fixed, but the button sits in the body as a small centered glass pill and not in the sheet toolbar. |
| 7 Add Region confirm | A toolbar confirm was added, but it is an unlabeled blue "+". The sheet is still a bottom sheet with detents on iPad. |
| 8 Inspector covers Proposal B | Not fixed. `keepMarkClearOfInspector` moves only the focused mark. The overlay still hides a full lane. |
| 9 Window controls | Not verified and still at risk: a custom palette sits in the top-leading corner of a windowed app. |
| 10 Consistent dismissal | Not fixed: four patterns (see F-9). |
| 12 Tool icons | Pen fixed. Component (`square.on.square.dashed`) still reads as "duplicate". |
| Pluralization | Fixed in `CanvasRow` only. `"\(n) comments"` is still hard-coded in five places (see the copy audit). |

---

## 1. Copy audit

Rules (`writing.md`):
- "Check each word to be sure it needs to be there. If you can use fewer words, do so." (› Be clear)
- "Describe what it does when turned on, and people can infer the opposite." (› Keep settings labels clear and simple)
- "Avoid using *we* altogether." (› Use possessive pronouns sparingly)
- "Consistency builds familiarity." (› Build language patterns)
- `menus.md`: "Remove articles … from menu-item labels."

Footers stay only where they prevent an error or disclose cost or privacy.

**Target vocabulary.** Use one word for each concept, everywhere:
- **Screen**: a row on the canvas.
- **Now**: the current design.
- **Proposal A/B**: a design option.
- **Version N**: an entry in a lane's history.
- **Comment**: a mark and its text.
- **Thread**: the T3 target.

Drop these words from the visible UI: *snapshot, capture, revision, iteration, region* (as a noun for a comment), *package, recipient, agent, element, layer*. The app currently uses five words (snapshot, capture, version, revision, iteration) for one thing.

Paths: `App/` means `App/Drawspeak/`, `Kit/` means `Packages/DrawspeakKit/Sources/`.

### Canvas chrome and canvas

| Screen | Current text | Location | Proposed |
| --- | --- | --- | --- |
| Title palette | "Choose Thread" (blue CTA, always visible) | `App/Canvas/ThreadLabel.swift:22` | Remove from chrome. Show the bound thread as `.navigationSubtitle`. Put "Choose Thread…" in the title menu. |
| Title palette | "No canvas" | `App/Canvas/CanvasTitlePalette.swift:17` | Remove (unreachable). |
| Add menu | "Import Image or HTML…" | `App/Canvas/CanvasActionsPalette.swift:13` | "Import…" |
| Add menu | "Pull Versions from Thread" | `CanvasActionsPalette.swift:14` | "Pull from Thread" (the empty state already uses this) |
| Add menu | "Add Region Without Drawing…" | `CanvasActionsPalette.swift:17` | Remove. It already exists as a card accessibility action (`Kit/CanvasKit/Views/SnapshotCard.swift:69`). |
| Toolbar | "Drafts and Sent" (a11y) | `CanvasActionsPalette.swift:36` | "History" (moves to the More menu) |
| Primary button | "Feedback" + count chip | `Kit/FeedbackKit/FeedbackButton.swift:17-19` | "Send" with `paperplane` and `.badge(count)` |
| Primary button | waveform + pending count chip | `FeedbackButton.swift:21-24` | Remove. Show pending items in the Send popover. |
| Zoom palette | "Fit All" | `Kit/CanvasKit/Views/ZoomControls.swift:32` | Remove. "64%" becomes a menu: Zoom In, Zoom Out, Zoom to Fit, Actual Size. |
| Tool palette | Tool-name overlay ("Region") shown 1.5 s after every change | `Kit/CanvasKit/Views/ToolPalette.swift:50-57` | Remove. The toolbar shows the selected state, `.help` covers pointer users, and VoiceOver reads the label. |
| Lane header | "Iteration 1 ⌄" (a menu with one choice) | `Kit/CanvasKit/Views/VersionMenu.swift:37`, `Kit/CanvasKit/Logic/CanvasLabels.swift:8` | Hide when the lane has one version. Otherwise "Version 2", with the menu on the lane title. |
| Lane header | "Revision N" | `CanvasLabels.swift:10` | "Version N" |
| Version menu | "Returned capture" | `VersionMenu.swift:66` | "New from Agent" |
| Version menu | "No change summary supplied" | `VersionMenu.swift:25` | Remove the Changes section when there is no summary. |
| Version menu | "Addressed comments: #1, #2" | `VersionMenu.swift:27` | "Addresses 1, 2" |
| Lane header | "Try" / "Done" (text + `hand.tap`) | `Kit/CanvasKit/Views/LaneHeader.swift:30` | Icon only (`hand.tap`), a11y "Try Prototype". Active state: `xmark`, a11y "Done". |
| Canvas banner | "Interacting — tap Done to annotate" + second "Done" | `Kit/CanvasKit/Views/CanvasView.swift:101-102` | Remove. The lane header control is enough, and two Done buttons compete. |
| Status hint | "Circle an area or drag across a larger region." | `Kit/CanvasKit/Models/CanvasInteraction.swift:169` | "Draw a larger area" |
| Status hint | "The HTML is still loading. Try again in a moment." | `CanvasInteraction.swift:194, 318` | "Still loading" |
| Status hint | "Could not inspect the HTML. Try again." / "No component at this point." | `CanvasInteraction.swift:221, 325` | "Can't read this HTML" / "No component here" |
| Status hint | "Images have no components. Draw a region instead." | `CanvasInteraction.swift:290` | "Images have no components" |
| Status hint | "Could not read the HTML. Select the component again." | `CanvasInteraction.swift:357` | "Can't read this HTML" |
| Banner | "Preparing \(file)…" | `App/Canvas/CanvasScreen.swift:233` | Remove. The Add button already shows a spinner. |
| Banner | "Added \(versionLabel) of \(title)" | `CanvasScreen.swift:251` | "Added to \(title)" |
| Banner | "Added N version(s) from the thread" / "No new versions in the thread" / "Pull found problems" | `App/Canvas/CanvasBanner.swift:19-23` | "Added N versions" (inflected) / "No new versions" / "Couldn't pull N versions" |
| Empty canvas | "Nothing to review yet" | `App/Canvas/EmptyCanvasView.swift:11` | "No Screens" (title style, like the other empty states) |
| Empty canvas | "Import a screenshot or an HTML mockup, or pull the versions an agent returned in this canvas's thread." (20 words) | `EmptyCanvasView.swift:13` | Remove. The two buttons say it. |
| Empty canvas | "Import Image or HTML…" | `EmptyCanvasView.swift:15` | "Import…" |
| Missing file | "Source file is missing" + "Expected … file: X. Comments stay with this version. Import the original file again to review it." | `Kit/CanvasKit/Views/MissingSourceCard.swift:11-13` | "File Missing" + "Import \(name) again." |
| Import error | "The HTML asks for a viewport Drawspeak cannot render (max 4096 × 4096 pt, scale 0.5–4)." | `App/Import/ImportFailure.swift:14` | "This HTML's viewport is too large." |
| Import error | "Drawspeak imports PNG, JPEG, WebP and self-contained HTML." | `ImportFailure.swift:15` | "Use PNG, JPEG, WebP or HTML." |
| Component chooser | "Select Component" | `Kit/CanvasKit/Views/ComponentChooser.swift:16` | Remove. The chain list is self-evident. |
| Component chooser | "Element: X" / "Parent 1: X" | `CanvasLabels.swift:40` | "X", with depth shown by indentation |
| Component chooser | "Top layer: X" / "Underneath 1: X" | `CanvasLabels.swift:45` | "X" |
| Component chip | "X · element, 3 parents" / "X · parent 1 of 3" | `CanvasLabels.swift:34-35` | "X" |
| Component chooser | "Comment on \(label)" | `ComponentChooser.swift:55` | "Comment" |
| Component chooser | "Child" / "Parent" (text buttons) | `ComponentChooser.swift:42-46` | `chevron.down` / `chevron.up`, icon only, with a11y labels |

### Note inspector, recording, comments list

| Screen | Current text | Location | Proposed |
| --- | --- | --- | --- |
| Inspector | "Comment 1" | `Kit/NotesKit/NoteInspectorContent.swift:18` | Remove. The pin already shows "1". |
| Inspector | "Region · Checkout · Now" | `NoteInspectorContent.swift:20` | "Checkout · Now" (drop `kindLabel`) as the group header |
| Inspector | "Ready" chip | `NoteInspectorContent.swift:37`, `Kit/DrawspeakCore/Logic/NoteReadiness.swift:25` | Remove when ready. Show only Recording, Transcribing or File Missing, as a symbol with a short label. |
| Inspector | Placeholder "Say or type what should change" | `Kit/NotesKit/NoteTextEditor.swift:15` | "Comment" |
| Inspector | "Saved" / "Saving…" | `NoteTextEditor.swift:26` | Remove. Autosave is expected. Show only `lastSaveError`. |
| Inspector | "Record Voice" | `NoteInspectorContent.swift:47` | Icon-only `mic` button inside the comment row, a11y "Record" |
| Inspector | "Recording — use Stop or Discard above" | `NoteInspectorContent.swift:57` | Remove. It is also wrong: `RecordingBar` is at the bottom of the screen, not above. |
| Inspector | "Show Source on Canvas" | `NoteInspectorContent.swift:65` | Remove. Make the preview tappable, a11y "Show on Canvas". |
| Inspector | "Comment Unavailable" / "This comment may have been deleted." | `Kit/NotesKit/NoteInspector.swift:26` | Remove. Clear the selection. |
| Recording bar | "REC" | `Kit/NotesKit/RecordingStatus.swift:15` | Remove. The red dot and timer say it. |
| Recording bar | "Comment \(n)" | `RecordingStatus.swift:16` | Remove. The recording ring on the pin and the selected row say it. |
| Recording bar | "Stop" / "Discard" | `Kit/NotesKit/RecordingActions.swift:9, 13` | Red `stop.fill` icon; Discard goes into the row's ⋯ menu (Undo also covers it). |
| Recording row | "Transcribed" | `Kit/NotesKit/RecordingRow.swift:20` | Remove. Show only the duration. |
| Recording row | "Raw Transcript" | `RecordingRow.swift:22` | "Transcript" (in the ⋯ menu) |
| Recording row | "Append Transcript" | `RecordingRow.swift:25` | "Add to Comment" |
| Recording row | "Recording ended early; audio kept" / "…; no audio was saved" | `RecordingRow.swift:37` | "Interrupted" / "Recording lost" |
| Recording row | "Audio Saved" | `RecordingRow.swift:40` | Remove. Keep the "Transcribe Again" button. |
| Recording row | "The audio could not be stored yet. It is kept on this iPad." + "Try Saving Again" | `RecordingRow.swift:43-44` | "Couldn't save audio" + "Retry" |
| Recording row | "May be charged again" | `RecordingRow.swift:34` | Keep, because it prevents a cost surprise: "May be billed again" |
| Failure text | "Transcription was interrupted. Audio is saved." / "Transcription failed. Audio is saved." | `Kit/NotesKit/NotesPresentation.swift:24-25` | "Interrupted" / "Transcription failed" (Retry is next to it) |
| Failure text | "Add an ElevenLabs key in Settings" | `NotesPresentation.swift:19` | Button "Add API Key…" that opens Settings (`writing.md`: "provide a direct link or button") |
| Mic notice | "Microphone Access Is Off" + "Microphone access is off. You can type your comment, or allow access in Settings." | `Kit/NotesKit/VoicePermissionNotice.swift:17-20` | "Microphone Off", no body, buttons "Open Settings" and close (xmark) |
| Mic notice | "The microphone is unavailable. You can type your comment, or try recording again later." | `VoicePermissionNotice.swift:21` | Remove the body. Title "Microphone Unavailable". |
| Comments | "Comments" title + "Done" | `App/Canvas/CanvasScreen.swift:168, 171` | Inspector column titled "Comments", no Done |
| Comments | Second section header line "N comments" | `Kit/NotesKit/NotesListView.swift:27` | Remove. |
| Comments | "Missing Source" | `NotesListView.swift:33` | "File Missing" |
| Comments | "No Comments Yet" + "Mark a region on the canvas, or use Add Region, then say or type what should change." | `NotesListView.swift:42` | "No Comments" + "Draw on a screen to comment." |
| Comments row | "No comment yet" | `Kit/NotesKit/NoteListRow.swift:13`, `NoteReadiness.swift:27` | "No Text" (secondary) |
| Comments row | Trailing `scope` icon on every row | `NoteListRow.swift:23` | Remove. The whole row is the button. |

### Feedback (Send), history

| Screen | Current text | Location | Proposed |
| --- | --- | --- | --- |
| Feedback | Large title "Feedback" | `Kit/FeedbackKit/FeedbackPreviewSheet.swift:58` | Inline title "Send Feedback" in the popover |
| Feedback | "1 comment · 1 snapshot → No recipient" | `FeedbackPreviewSheet.swift:31` | Remove. The "To" row and the rows say it. |
| Feedback | "Draft Saved" + "Saved as draft · N comment(s). Nothing was sent." + "Back to Canvas" | `FeedbackPreviewSheet.swift:34-36` | Dismiss and show the banner "Draft Saved" (or drop drafts, see F-14) |
| Feedback | "N comments still recording or transcribing stay on the canvas" | `FeedbackPreviewSheet.swift:40` | "N still transcribing" (inflected) |
| Feedback | "N new comments are ready — Add" | `FeedbackPreviewSheet.swift:42` | "Add N New" (inflected; today it reads "1 new comments") |
| Feedback | "Includes comments already sent (N)" | `FeedbackPreviewSheet.swift:44` | Remove. Mark the row with a `paperplane` symbol. |
| Feedback | "No Ready Comments" + "Add text to a comment on the canvas." | `FeedbackPreviewSheet.swift:51` | "Nothing to Send" |
| Feedback | "Preparing feedback…" | `FeedbackPreviewSheet.swift:63` | Remove. The Send button shows a progress indicator (`buttons.md › Mobile`). |
| Feedback | "Send to Agent" | `FeedbackPreviewSheet.swift:64` | "Send" (`.confirmationAction`) |
| Feedback | Group title "Checkout · a · Iteration 1" (shows the raw proposal ID) | `FeedbackPreviewSheet.swift:90` | **Bug.** Use `NotesPresentation.sourceLabel`: "Checkout · Proposal A · Version 1". |
| Feedback | "Rendering snapshot…" | `Kit/FeedbackKit/FeedbackSnapshotGroup.swift:26` | `ProgressView()` with no label |
| Feedback | "Select at least one comment." | `Kit/FeedbackKit/FeedbackPreviewModel.swift:44` | Remove. The disabled Send button says it. |
| Feedback | "Comment N: reason — deselect to send the rest" | `FeedbackPreviewModel.swift:45`, `Kit/FeedbackKit/FeedbackNoteRow.swift:13` | Reason only, on the row: "Not ready" / "File missing" |
| Feedback | "Connect this canvas to a T3 thread to send" | `FeedbackPreviewModel.swift:47` | Remove. Send opens the thread picker. |
| Feedback | "Connect to T3 Code to send. You can save a draft." | `FeedbackPreviewModel.swift:48` | Remove. Send opens pairing. |
| Feedback | "Comment is not ready" / "Capture image is missing" / "Canvas is missing" | `FeedbackPreviewModel.swift:35, 39-40` | "Not ready" / "Image missing" / remove |
| Feedback | "Mark is not valid" / "Snapshot is missing" / "Component target does not match this version" / "Source file is missing" / "Preview image is still being created" | `Kit/DrawspeakCore/Logic/FeedbackScope.swift:14, 21-29` | "Invalid mark" / "Screen missing" / "Component changed" / "File missing" / "Preparing…" |
| Feedback | "Comments changed while previewing. Reopen Feedback to save the current revisions." | `FeedbackPreviewModel.swift:82` | "Comments changed. Reopen to update." |
| Feedback | Limit errors (16 to 27 words each) | `Kit/FeedbackKit/FeedbackLimitError.swift:13-19` | "Select comments on up to N screens." / "Too many attachments (N of 8). Deselect comments on N screens." / "HTML missing." / "Message too long. Deselect some comments." / "Image missing." / "Couldn't render image." |
| Result | "Sent to X · N comments · 14:31" | `Kit/FeedbackKit/FeedbackDeliveryResult.swift:13` | Title "Sent", detail "14:31" (inflect if a count stays) |
| Result | "Delivered to T3 Code. The agent's work status is shown separately." | `FeedbackDeliveryResult.swift:14` | Remove. |
| Result | "We don't know if the message arrived" | `FeedbackDeliveryResult.swift:19` | "Delivery not confirmed" (`writing.md`: avoid *we*) |
| Result | "Back to Canvas" | `FeedbackDeliveryResult.swift:28` | Remove. Use the standard Close. |
| Result | "No message found. Sending again might duplicate delivery if the thread check was wrong." / "Could not check the thread. Try again when connected." | `FeedbackPreviewModel.swift:102` | "Not found in thread. Sending again may duplicate it." / "Can't reach thread." |
| Delivery state | "Delivery Unknown" | `Kit/FeedbackKit/DeliveryState+Feedback.swift:10` | "Not Confirmed" |
| History | "Drafts & History" | `Kit/FeedbackKit/DraftsAndHistoryView.swift:48` | "History" |
| History | "No Drafts or Sent Feedback" + "Save a feedback package as a draft or send it to an agent to see it here." | `DraftsAndHistoryView.swift:26-27` | "No Feedback Sent", no description |
| History | "Review Restored Draft" | `DraftsAndHistoryView.swift:21` | "Review" |
| History | "N comment(s) changed since the draft; the draft's text was restored as new comments." / "The recipient has changed since this draft was saved. Review the current recipient before sending." | `DraftsAndHistoryView.swift:59, 62` | "Some comments changed since this draft." / "Thread changed." |
| History row | Row headline = last 12 characters of the batch ID | `Kit/FeedbackKit/FeedbackHistoryRow.swift:12` | The send date and time. Never show internal IDs (Lens 5). |
| History row | "\(n) comments · thread" | `FeedbackHistoryRow.swift:13` | Inflect, or drop the count |
| History row | "If a previous delivery was uncertain, sending again might duplicate it if the thread check was wrong." | `FeedbackHistoryRow.swift:21` | "May send twice." |
| History row | "No message found. A resend may duplicate delivery…" / "Could not check the thread. Reconnect and try again." / "Open the draft again to rebuild" | `FeedbackHistoryRow.swift:39, 50` | Same short forms as Result / "Open draft to resend" |

### Settings, pairing, threads, canvases, import, add region, recovery

| Screen | Current text | Location | Proposed |
| --- | --- | --- | --- |
| Settings | Header "Voice Comments" | `App/Settings/SettingsView.swift:23` | "Voice" |
| Settings | "Start Voice After Selection" | `SettingsView.swift:16` | "Record After Marking" |
| Settings | "Speech Language" / "Detect Automatically" | `SettingsView.swift:17`, `App/App/TranscriptionLanguage.swift:12` | "Language" / "Automatic" |
| Settings | Footer "When on, marking a region or choosing a component starts recording. Opening an older comment never does." (17 words) | `SettingsView.swift:25` | Remove. The label says it (`writing.md`: describe only the on state). |
| Settings | Footer "Speech is transcribed by ElevenLabs Scribe v2 after you tap Stop. The key stays in this iPad's Keychain. Audio leaves the device only for transcription; usage is billed to your ElevenLabs account." (32 words) | `App/Settings/ElevenLabsKeySection.swift:40` | "Audio is sent to ElevenLabs for transcription and billed to your account." (12 words, kept for privacy and cost) |
| Settings | "ElevenLabs Key" + seal "Saved" | `ElevenLabsKeySection.swift:15-16` | "API Key" + "Saved" (no seal; secondary text) |
| Settings | Footer "Your finger moves the canvas unless this is on. With it on, use two fingers to move and zoom." (19 words) | `SettingsView.swift:35` | "Use two fingers to pan and zoom." (7) |
| Settings | Footer "Drawspeak reaches T3 Code over your tailnet and signs in with a pairing code. Sending feedback starts or steers the agent in the canvas's thread." (25 words) | `App/Settings/T3ConnectionSection.swift:32` | Remove. |
| Settings | Status "Pairing expired — connect again" | `T3ConnectionSection.swift:53` | "Expired" |
| Settings | "Pair Again…" / "Connect to T3 Code…" | `T3ConnectionSection.swift:27` | "Connect…" |
| Settings | "Drawspeak is licensed under the Apache License 2.0." | `SettingsView.swift:42` | Remove, or a "Licenses" row that links out |
| Pairing | Header "Get a pairing code" + body "Keep T3 Code open and make sure this iPad can reach your Mac." | `Kit/T3Kit/T3PairingView.swift:18, 21` | Remove. |
| Pairing | Footer "On your Mac: T3 Code › Settings › Sharing & access › Create pairing link › Show code" | `T3PairingView.swift:23` | Keep as the single footer: "On your Mac: Settings › Sharing & access › Create pairing link." |
| Pairing | Header "T3 Code"; "Pairing code" / "12-character code" | `T3PairingView.swift:25, 37-38` | Remove the header; "Code" / "XXXXXXXXXXXX" |
| Pairing | "Choose access" + "Access level" + 5 options + per-option description + footer "Full access is selected because new T3 threads default to full access. Threads created … You can revoke access on your Mac." (about 70 words) | `T3PairingView.swift:52-63, 86-93` | Remove from the form. Default to full access. If needed, put it in one "Access" row with a menu and no description (`settings.md`: "Minimize the number of settings"). |
| Pairing | "Enter a host and a 12-character pairing code to connect." | `T3PairingView.swift:73` | Remove. The disabled Connect button says it. |
| Pairing | "Connecting to T3 Code" | `T3PairingView.swift:77` | Progress shown in the Connect button |
| Pairing | "Pairing expired. Create a new code on your Mac." | `T3PairingView.swift:80` | "Code expired. Create a new one." |
| Pairing | "To revoke access, remove Drawspeak (iPad) in T3 Code › Settings › Sharing & access." | `T3PairingView.swift:82` | Remove. |
| Pairing | Title "Connect to T3" (inner) vs "Connect to T3 Code" (outer) | `T3PairingView.swift:83`, `App/Canvas/ThreadBindingSheet.swift:30`, `T3ConnectionSection.swift:37` | One title: "Connect to T3 Code". Remove the inner `NavigationStack`. |
| Threads | "Choose a thread" (inner, sentence case) vs "Choose Thread" (outer) | `Kit/T3Kit/T3ThreadPickerView.swift:57`, `ThreadBindingSheet.swift:30` | "Choose Thread". Remove the inner `NavigationStack`. |
| Threads | "Loading threads" | `T3ThreadPickerView.swift:55` | `ProgressView()` with no label |
| Threads | "No threads" / "No matching threads" + "Try another thread title or project name." | `T3ThreadPickerView.swift:55` | "No Threads" / `ContentUnavailableView.search` |
| Threads | "Search threads or projects" | `T3ThreadPickerView.swift:56` | Default prompt "Search" |
| Threads | "Try again" / "Other threads" | `T3ThreadPickerView.swift:21, 15` | "Try Again" / "Other" |
| Threads | Row: title / project / recency / status chip (4 lines) | `T3ThreadPickerView.swift:29-41` | Title, plus one secondary line "Project · 2h ago". Status only when Running. |
| Threads | Alert "This canvas already sent feedback to another thread" + "A canvas belongs to one thread. Create a new canvas for the other thread." | `ThreadBindingSheet.swift:37, 40` | "Thread Can't Change" + "Create a new canvas for another thread." |
| Canvases | Row "No thread" | `App/Canvas/CanvasRow.swift:13` | Omit when there is no thread. |
| Canvases | Delete message "Its versions, comments and drafts are removed from this iPad. Messages already sent stay in the T3 thread." | `App/Canvas/CanvasListSheet.swift:71` | "Sent feedback stays in the thread." |
| Import | "Size  W × H px" | `App/Import/ImportTargetSheet.swift:17` | Remove. |
| Import | "Scripts in this HTML do not run. Drawspeak shows it as a static mockup." | `ImportTargetSheet.swift:19` | "Scripts won't run." |
| Import | "New Screen" / "Screen title" / "Add as New Screen" | `ImportTargetSheet.swift:24-26` | "New Screen" / "Title" / "Add" |
| Import | "New Now Version" / "Next Iteration of Proposal A" / "New Proposal B" | `App/Import/ScreenTargetSection.swift:12, 16, 20` | "Update Now" / "Add to Proposal A" / "New Proposal B" |
| Add Region | "Source" / "Snapshot" / "Choose a snapshot" / value "Checkout · Now · checkout-now.png" | `Kit/NotesKit/AddRegionSheet.swift:30-34` | No header / "Screen" / "Choose" / "Checkout · Now" (no file name) |
| Add Region | "Region in Percent" | `AddRegionSheet.swift:57` | "Position" |
| Add Region | Shape options "Region" / "Oval" | `AddRegionSheet.swift:65-66` | "Rectangle" / "Oval" |
| Add Region | "Use a non-empty region within the snapshot bounds." | `AddRegionSheet.swift:68` | "Keep the area inside the screen." |
| Add Region | "Source Preview" | `AddRegionSheet.swift:71` | Remove the header. |
| Add Region | "No Snapshots" + "Import a snapshot before adding a region." | `AddRegionSheet.swift:77` | "No Screens" |
| Recovery | "Your reviews could not be opened" | `App/App/LibraryRecoveryView.swift:13` | "Can't Open Library" |
| Recovery | "Drawspeak has not changed the saved file. \(error)" | `LibraryRecoveryView.swift:15` | "\(error) The file is unchanged." |
| Recovery | "Start with an Empty Library…" / "Start Empty Library" | `LibraryRecoveryView.swift:20, 24` | "Start Over…" / "Start Over" |

**Effect.** Visible prose on the screens captured or covered here falls from about 560 words to about 150, a cut of roughly 70%:
- Settings footers: 101 → 19.
- Pairing form: 174 → about 15.
- Feedback with no thread: 31 → 4.
- Inspector chrome: 13 words of labels → 2.

VoiceOver hints (`.accessibilityHint`) can stay descriptive, but cut them to one short sentence each. For example, `FeedbackButton.swift:35` → "Reviews comments before sending."

---

## 2. Design findings by screen

Severity follows the brief: **P0** is the owner-visible convention break, **P1** is real friction or a High HIG miss, **P2** is polish.

### Main canvas (`light-canvas.png`, `dark-canvas.png`, `light-component.png`)

**F-1 · P0 · Custom floating palettes instead of a native toolbar.**
- **What.** `CanvasChrome` draws four glass capsules: top-leading title and thread, top-trailing actions, bottom-center tools, bottom-leading zoom. It adds a fifth filled button for Feedback, and `CanvasSidePanels` stacks banners, a mic notice and a recording bar above the tools. That is five functional groups plus a separate prominent button at the top, and the chrome is split between both edges of the window.
- **Why.**
  - `toolbars.md › Item groupings`: "Minimize the number of groups … aim for a maximum of three."
  - `toolbars.md › Best practices`: "Prefer using standard components in a toolbar."
  - `liquid-glass.md › Where the material belongs`: "If you apply it to a custom control, limit it to the most important functional elements."
  - In windowed mode (the resize grabber is visible), a custom top-leading palette also has to avoid the window controls. The system toolbar does this for you.
  - The bottom-center palette sits where the writing hand rests: `apple-pencil-and-scribble.md › Best practices`: "Avoid placing controls in locations that may be obscured by either hand."
- **Recommendation (definite): move to a native `.toolbar` at the top, Freeform-style.**
  - Wrap the canvas in `NavigationSplitView` (sidebar = Canvases, hidden by default) and give the detail view:
    - `.navigationTitle(canvas.title)`
    - `.navigationSubtitle(thread?.displayName ?? "")`
    - `.navigationBarTitleDisplayMode(.inline)`
    - `.toolbarRole(.editor)`
    - `.toolbarTitleMenu { Rename…; Choose Thread…; Pull from Thread }`
  - **Leading:** system sidebar toggle, then the title with its title menu. The custom grid icon and the "Choose Thread" chip go away.
  - **Center:** `ToolbarItemGroup(placement: .secondaryAction)` with five `Toggle(tool.title, systemImage:, isOn:)` items using `.toggleStyle(.button)`. Toolbar toggles get the system selected state, hover and Large Content Viewer, which the custom 44 pt buttons lack. Then `ToolbarSpacer(.fixed)` and Undo/Redo. Use `.toolbar(id:)` so people can customize the center items (`toolbars.md › Best practices`: iPad customization).
  - **Trailing:** `Menu("Add", systemImage: "plus")` (Import…, Pull from Thread); `Button("Comments", systemImage: "text.bubble")`, which toggles the inspector (`toolbars.md`: "buttons that open nearby inspectors" belong on the trailing edge); `Menu("More", systemImage: "ellipsis")` (History, Settings ⌘,). Then a separate `ToolbarItem(placement: .primaryAction)` with `Button("Send", systemImage: "paperplane")`, `.buttonStyle(.glassProminent)` and `.badge(readyCount)`. That is the only tinted control (`toolbars.md`: one `.prominent` action, trailing).
  - **Bottom:** keep one small bottom-leading glass pill, "64%", as a `Menu` (Zoom In ⌘=, Zoom Out ⌘-, Zoom to Fit ⌘0, Actual Size). This is the only custom glass left. It sits away from the writing hand, and pinch handles most zooming. Delete `CanvasTitlePalette`, `CanvasActionsPalette`, the bottom `ToolPalette` placement and `ZoomControls`.
  - Keep `ToolPalette` only as the Pencil Pro squeeze palette near the tip. That use is correct (`apple-pencil-and-scribble.md › Squeeze`: "display it close to Apple Pencil Pro").
  - Replace the hard-coded `overlayInsets` and `fitAll` insets (88, 96 and 110 pt in `CanvasScreen.swift:36, 200, 213`) with the safe area.

**F-2 · P1 · Tinted controls everywhere.**
- **What.** Seven tinted items compete with the one action that matters: Choose Thread, Feedback (filled), Fit All, Iteration 1 ⌄ (×2), Try, and the blue "+" in Add Region.
- **Why.** `liquid-glass.md › Color on glass`: "Keep brand color off most controls and save it for primary actions and status indicators." `toolbars.md`: "Reduce the use of toolbar backgrounds and tinted controls."
- **Fix.** Only Send uses `Theme.actionFill`. Lane menus, Try and zoom use `Theme.ink` or `.primary`. Selected tools use the system selected state.

**F-3 · P1 · Lane headers carry chrome text inside the content.**
- **What.** "Now", "Proposal A", "Iteration 1 ⌄", "Proposal B", "Iteration 1 ⌄" and "Try" make six labels and three controls for three cards. The "Checkout" screen title (x≈114) is not aligned with the "Now" lane label (x≈73).
- **Why.** `layout.md › Visual hierarchy`: "Align elements to make them easier to scan." The version menu is a menu with one choice, which is noise.
- **Fix.**
  - Put the menu on the lane title ("Proposal A ⌄"), and show it only when there is more than one version or a Promote action.
  - Make Try icon-only.
  - Align `ScreenTitleChip` to the first lane's leading edge.
  - Remove the duplicate "Interacting — tap Done to annotate" banner (`CanvasView.swift:101`).

**F-4 · P2 · Glass in the content layer.**
- **What.** `EmptyCanvasView.swift:23` puts a `ContentUnavailableView` on `.paletteBackground()`, which is glass.
- **Why.** `liquid-glass.md`: "Don't use Liquid Glass in the content layer."
- **Fix.** No background. Center it on `Theme.canvas`.

**F-5 · P2 · Icons.**
- **Component tool.** `square.on.square.dashed` (`CanvasTool.swift:30`) reads as Duplicate. Use `cursorarrow.and.square.on.square.dashed`, or `hand.point.up.left` if that is not available in the deployment SF Symbols (check in the SF Symbols app).
- **Canvases.** `square.grid.2x2` → the system sidebar toggle.
- **History.** `tray.full` reads as Inbox. Use `clock.arrow.circlepath` (in the More menu anyway).
- **Inspector More.** `ellipsis.circle` → `ellipsis`. `toolbars.md › Actions`: "Borders (like outlined circle symbols) aren't necessary." `icons.md › Standard icons`: More = `ellipsis`.

**F-6 · P2 · Dark canvas.** The chrome adapts correctly. The white screenshot cards glow on #181B1F, but do not dim them: review fidelity matters more than `dark-mode.md › Soften the color of white backgrounds`. Keep the current shadow and add a 0.5 pt `Color.white.opacity(0.08)` stroke so the card edge reads.

### Note inspector (`light-inspector.png`, `dark-inspector.png`)

**F-7 · P0 · Floating glass card instead of an inspector.**
- **What.** The card is 360 pt wide and about 1,180 pt tall. It hides all of Proposal B, and about 55% of its height is empty glass, with the blurred blue Pay button of Proposal B smeared through it (both appearances).
- **Inside the card:**
  - The header repeats the number: pin "1" and "Comment 1".
  - The subtitle uses jargon: "Region · Checkout · Now".
  - The "Ready" chip and the "Saved" caption add no information.
  - "Record Voice" and "Show Source on Canvas" are drawn in `Theme.ink` (`NoteInspectorContent.swift:69` applies `.foregroundStyle(Theme.ink)` to the whole stack), so they read as labels, not buttons.
- **Why.**
  - `panels.md › Best practices`: an inspector "displays the details of the currently selected item," and on iPad the platform answer is a split-view pane.
  - `liquid-glass.md`: glass on a large text surface over busy content blurs the hierarchy.
  - `layout.md`: "Differentiate controls from content."
- **Recommendation (definite): use SwiftUI `.inspector`, not a floating card, and merge it with the Comments sheet.**
  - `NavigationSplitView { … } detail: { CanvasView … .inspector(isPresented: $showsComments) { CommentsInspector(…) .inspectorColumnWidth(min: 300, ideal: 340, max: 420) } }`
  - In regular width the column sits beside the canvas, so nothing is covered. Anchor the camera to the leading edge so the canvas does not jump when the column opens, and delete `keepMarkClearOfInspector`. In compact width the system turns the inspector into a sheet; add `.presentationDetents([.medium, .large])` there.
  - **Content:** one `List` of all comments, grouped by "Screen · Version" headers. Each row is collapsed to pin + first line. The selected comment (tapped pin or newly drawn mark) expands in place to:
    - a `TextEditor` with placeholder "Comment" (Scribble works; keep it stationary while writing, `apple-pencil-and-scribble.md › Scribble`);
    - an icon-only mic button;
    - the 120 pt cropped mark preview, tappable for Show on Canvas;
    - an `ellipsis` menu with Transcript, Add to Comment, Transcribe Again and Delete Comment.
  - Drawing a mark opens the inspector and selects the new row.
  - Remove the Comments sheet (`CanvasSheet.notes`) and `NoteInspector`'s card chrome.
- **Rejected: a popover anchored to the pin.** It covers the screenshot under review, and the next Pencil touch dismisses it. Popovers are for "a small amount of information" (`popovers.md`).

**F-8 · P1 · Recording state is loud and split across three places.** (No screenshot; from code.)
- **What.**
  - A bottom glass bar shows a red pulsing dot, "REC", "Comment 1", the timer, a 36 pt level bar, a blue prominent "Stop" and a bordered "Discard" (`RecordingBar`, `RecordingStatus`, `RecordingActions`).
  - The inspector shows "Recording — use Stop or Discard above", which points the wrong way.
  - The pin has a pulsing ring.
  - Stop is tinted blue next to a red recording dot, so the colors give two meanings.
- **Fix (minimal native look, as in Voice Memos and Messages dictation).**
  - While recording, the mic button in the selected inspector row becomes a capsule: `[● red dot] [live waveform] [0:07] [■]`.
  - Live waveform: `Image(systemName: "waveform").symbolEffect(.variableColor.iterative, isActive: !reduceMotion)`, or a `Canvas` drawn from `voice.level`.
  - Timer: `.monospacedDigit()`.
  - Stop: `Button("Stop", systemImage: "stop.fill")`, `.labelStyle(.iconOnly)`, `.tint(.red)`, keyboard Space.
  - Discard: in the row's ⋯ menu, and Undo covers it too.
  - Keep the pin ring on the canvas (it already respects Reduce Motion).
  - Delete `RecordingBar` from `CanvasSidePanels` and the "Recording — …" label.
  - Post one `AccessibilityNotification.Announcement("Recording")` on start.

### Feedback / Send (`light-feedback.png`, `dark-feedback.png`)

**F-9 · P0 · The send flow is a large-title sheet with its actions in the body.**
- **What.**
  - The large title "Feedback" takes about 90 pt.
  - The "To / Choose Thread…" row floats on the grouped background with no list styling.
  - The summary line repeats "No recipient".
  - The 95 pt thumbnail sits off-center in a 200 pt frame.
  - The custom square checkbox is a macOS idiom.
  - "Send to Agent" (disabled) and "Save Draft" are two stacked centered pills in the body, followed by a third explanation.
- **Why.**
  - `sheets.md › Mobile`: "the Cancel button belongs on the leading edge of the top toolbar … the Done button belongs on the trailing edge."
  - `buttons.md › Mobile`: put the activity indicator in the button.
  - `writing.md › Be clear`.
  - `feedback.md`: "Show people when a command can't be carried out and help them understand why." One reason, next to the control.
- **Fix (definite).**
  - Present it as a `.popover` anchored to the toolbar Send button on regular width, with `.presentationCompactAdaptation(.sheet)`, about 420×560. This matches the iPad share popover and keeps the canvas in view.
  - `NavigationStack` with inline title "Send Feedback"; `ToolbarItem(.cancellationAction) { Button(role: .close) }`; `ToolbarItem(.confirmationAction) { Button("Send") }`, with progress shown inside the button while sending.
  - Body: a `List` with a "To" row that is a `NavigationLink` or a menu showing the thread name, or "Choose Thread…".
  - Below that, one `Section` for each "Screen · Version", each with a thumbnail and rows. Rows use selection with `checkmark.circle.fill` / `circle`, or `List(selection:)` in edit mode. A row that cannot be sent shows its reason in secondary text and is excluded automatically.
  - With no thread, Send stays enabled and opens the thread picker (pairing first if needed), then returns. That deletes all three no-thread explanations.
  - Lay out the thumbnail and the rows with `ViewThatFits` or a container-width threshold, not `horizontalSizeClass` (`FeedbackSnapshotGroup.swift:17`).
  - After sending, show the result in the same popover ("Sent ✓ 14:31") and close it automatically after 1 s, or let Close dismiss it. Remove "Back to Canvas".
  - If drafts survive (see F-14), "Save Draft" is a `ToolbarItem(.secondaryAction)`, not a body button.
  - **Dark:** the white thumbnail glows against the near-black sheet. Give it a hairline border.
  - **Contrast (estimate):** the footer is system secondary label on the grouped background, about 3.3:1, below 4.5:1 for 13 pt. It is removed anyway.

**F-10 · P1 · Wrong group title.** `FeedbackPreviewSheet.swift:90` builds "Checkout · a · Iteration 1" from the raw `proposalId`, while every other screen says "Proposal A". Reuse `NotesPresentation.sourceLabel`.

### History (`light-history.png`)

**F-11 · P1 · Empty state drawn as a list card.**
- **What.** The empty state is a `ContentUnavailableView` inside a `List` row, so it renders as a white card at the top and not centered. The title "Drafts & History" is large. Rows use a batch-ID fragment as their headline (`FeedbackHistoryRow.swift:12`).
- **Why.** `writing.md › Provide clear next steps on any blank screens`. Lens 5: "Names come from what people control and recognize, not from how the system is built."
- **Fix.** `List { … }.overlay { if isEmpty { ContentUnavailableView("No Feedback Sent", systemImage: "paperplane") } }`. Use the inline title "History". Use the date as the headline. Open it from the More menu as a fitted form sheet: `.presentationSizing(.form.fitted(horizontal: false, vertical: true))`.

### Comments sheet (`light-notes.png`)

**F-12 · P1 · Wrong container for one row.**
- **What.** A 590×670 form sheet with a large title and a Done button shows one row, and covers the canvas you navigate to. Each row has a "Ready" chip and a blue `scope` decoration.
- **Why.** `sheets.md › Best practices`: "Use a nonmodal view when you want to present supplementary items that affect the main task in the parent view." `modality.md`: "Present content modally only when there's a clear benefit."
- **Fix.** Merge it into the `.inspector` (F-7).

### Settings (`light-settings.png`)

**F-13 · P1 · Footers explain what the labels already say.**
- **What.** 101 words of footers. "T3 Code" is cut off at the bottom of the sheet. The large title takes about 90 pt.
- **Why.** `writing.md › Keep settings labels clear and simple`. `settings.md`: "Minimize the number of settings you offer."
- **Fix.**
  - Apply the copy audit.
  - Use the inline title.
  - Dismiss with `Button(role: .close)` leading (see F-15).
  - Order the sections by frequency: Voice, Apple Pencil, Transcription, T3 Code, About.
  - Settings opens from the More menu and ⌘, (keep the shortcut).

### Threads and pairing (`light-threads.png`, code)

**F-14 · P1 · Pairing is a long form.**
- **What.**
  - About 174 words of prose and a five-level access picker with a per-level description.
  - The Connect button is in the body.
  - There are nested `NavigationStack`s: `ThreadBindingSheet` wraps `T3PairingView` and `T3ThreadPickerView`, which each create their own. The visible title comes from the inner one, so the screenshot reads "Choose a thread" in sentence case while every other title uses title case.
- **Why.** `onboarding.md`: "Postpone nonessential setup flows … provide reasonable default settings." `settings.md`: minimize settings. `writing.md`: apply capitalization consistently.
- **Fix.**
  - Remove the inner `NavigationStack`s.
  - Pairing becomes one `Form` with two fields (Host, Code) and the single footer path. Connect goes in `.confirmationAction`, with progress in the button. Remove the access picker, or reduce it to one menu row.
  - Thread rows: title plus "Project · 2h ago".
  - Better still (P2, judgment): accept the T3 "pairing link" as a universal link or QR code (camera via `DataScannerViewController`), so nobody types a 12-character code.

### Sheets in general (all modal screenshots)

**F-15 · P1 · Four dismissal patterns and a large title on almost every sheet.**

| Sheet | Leading | Trailing | Title |
| --- | --- | --- | --- |
| Feedback | xmark (`.close`) | none | large |
| History | xmark | none | large |
| Settings | none | "Done" text | large |
| Comments | none | "Done" text | large |
| Canvases | "+" | "Done" | large |
| Thread picker | "Cancel" text | none | inline |
| Pairing | "Cancel" text | none | inline |
| Add Region | xmark | blue "+" | inline |
| Import | "Cancel" | none | inline |

- **Why.** `toolbars.md › Navigation`: "Use the standard Back and Close buttons … consistently implement it throughout your app." `sheets.md › Mobile`: Cancel leading, Done trailing.
- **Fix.**
  - **Browse sheets** (History, Settings): `ToolbarItem(placement: .cancellationAction) { Button(role: .close) { dismiss() } }`, and nothing trailing.
  - **Task sheets** (Send, Pairing, Thread picker, Import, Add Region): `role: .close` leading plus a labeled `.confirmationAction` trailing ("Send", "Connect", "Add").
  - Use `.navigationBarTitleDisplayMode(.inline)` on every sheet.
  - Canvases moves to the sidebar, so its "+" goes into the sidebar's toolbar.

### Add Region (`light-addRegion.png`)

**F-16 · P1 · An iPad bottom sheet with an ambiguous confirm.**
- **What.** `.presentationDetents([.medium, .large])` together with `.presentationSizing(.form)` gives a bottom-anchored sheet with a grabber. "Source Preview" is cut off at the bottom edge, and the canvas's blue Pay button smears through the translucent rows. The confirm is a blue "+" icon.
- **Why.** `sheets.md › Mobile`: "Prefer using the page or form sheet presentation styles in an iPadOS app." `buttons.md › Content`: "Consider using text when a short label communicates more clearly than an icon."
- **Fix.** On regular width, drop the detents so it is a centered form sheet. Confirm with `Button("Add")` in `.confirmationAction`. Apply the copy audit.
- **P2 (judgment).** Move this flow off the "+" menu. The card's accessibility action "Add Region…" (`SnapshotCard.swift:69`) is the right entry point. Make that action create a full-screen comment directly ("Comment on Screen"), and keep the stepper form only as "Adjust Area…" in the comment's ⋯ menu.

### Product simplification (affects several screens)

**F-17 · P2 (owner decision) · Drop Drafts.** Unsent comments already persist on the canvas, so they are the draft. Removing "Save Draft", the Drafts section, resume notices and restored-draft logic removes one primary-level button, one screen section and about 60 words. History becomes Sent only. This applies `design-principles.md › Simplicity`: "Include just what's necessary."

### Cross-cutting

**F-18 · P1 · Capitalization is mixed.** These strings use sentence case: "Choose a thread", "Try again", "Get a pairing code", "Choose access", "Access level", "Full access", "Nothing to review yet", "Your reviews could not be opened", "Source file is missing", "Loading threads", "No threads", "Other threads", "Pairing code". The rest of the app uses title style. `menus.md`, `buttons.md`: use title-style capitalization for buttons, menu items and titles. Fix them with the audit.

**F-19 · P1 · Pluralization.** These still produce "1 comments" or "1 new comments":
- `FeedbackHistoryRow.swift:13`
- `FeedbackDeliveryResult.swift:13`
- `FeedbackPreviewSheet.swift:40, 42, 44`

Use `^[\(n) comment](inflect: true)` everywhere, as `CanvasRow` already does.

**F-20 · P2 · Large text.** The custom palette buttons (`PaletteIconButton`, `ToolButton`) do not get the Large Content Viewer that bar items get at accessibility sizes. The native toolbar in F-1 fixes this. Until then, add `.accessibilityShowsLargeContentViewer()`. `LaneHeader`'s `.fixedSize()` titles do not wrap; this is acceptable because they are canvas-scaled labels, but check them at AX5.

---

## 3. Target layout

### Main canvas, regular width, inspector closed

```text
┌──────────────────────────────────────────────────────────────────────────────────────────┐
│ ◧  First review ⌄             ( ✋  ⬚  ↗  ✎  ⌖ ┆ ↶  ↷ )              ( +  💬  ⋯ )  (➤ Send ¹)│
│    Checkout redesign             center group (.secondaryAction,       trailing   prominent │
│    ↑ title menu + subtitle       customizable)                          group      .glass-  │
│      (thread, only when bound)                                                     Prominent│
│ ┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄ scroll edge effect ┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄ │
│                                                                                          │
│   Checkout                                                                               │
│   Now                    Proposal A ⌄                 Proposal B ⌄   ☝︎                   │
│   ┌──────────────┐       ┌──────────────┐             ┌──────────────┐                   │
│   │   Checkout   │       │   Checkout   │             │   Checkout   │                   │
│   │   Item 1     │       │   Item 1     │             │   Keyboard   │                   │
│   │   …          │       │   …          │             │   …          │                   │
│   │ ①┏━━━━━━━━┓  │       │  [ Pay 129 ] │             │  [ Pay 129 ] │                   │
│   │  ┃  Pay   ┃  │       │              │             │              │                   │
│   └──────────────┘       └──────────────┘             └──────────────┘                   │
│                                                                                          │
│ (64% ⌄)   ← only remaining custom glass; Menu: Zoom In / Zoom Out / Zoom to Fit / 100%   │
└──────────────────────────────────────────────────────────────────────────────────────────┘
 ◧ = system sidebar toggle (Canvases)     + = Import… / Pull from Thread
 💬 = toggles Comments inspector         ⋯ = History, Settings (⌘,)
 Tools: Hand V · Rectangle R · Arrow A · Pen P · Component C     Lane menus shown only with >1 version
 Tinted: Send only. Everything else monochrome.
```

### Note inspector open, comment 1 selected and recording

```text
┌─────────────────────────────────────────────────────────────┬────────────────────────────────┐
│ ◧ First review ⌄    ( tools ┆ ↶ ↷ )        ( + ⋯ )(➤ Send ¹) │ Comments                    💬 │
│ ┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄ ├────────────────────────────────┤
│                                                             │ CHECKOUT · NOW                 │
│   canvas keeps its leading anchor; the column takes width,  │ ① The pay button should     ⋯  │
│   it does not cover a lane                                  │   show the total.|             │
│                                                             │   ┌──────────────────────────┐ │
│   ┌────────┐   ┌────────┐                                   │   │   ┏━━━━━━━━━━━┓  (tap =   │ │
│   │        │   │        │                                   │   │   ┃    Pay    ┃  show on  │ │
│   │ ①◯━━━┓ │   │        │   ◯ = pulsing ring while          │   │   ┗━━━━━━━━━━━┛  canvas)  │ │
│   │  ┃Pay┃ │   │        │       recording (Reduce Motion:    │   └──────────────────────────┘ │
│   └────────┘   └────────┘       static)                     │   ( ● ▁▃▅▂▆▃  0:07       ■ )   │
│                                                             │     red dot, live level,  red  │
│                                                             │     timer                 stop │
│                                                             │ ② Item list is too dense       │
│                                                             │ PROPOSAL A · VERSION 2         │
│ (64% ⌄)                                                     │ ③ Total should be bold         │
└─────────────────────────────────────────────────────────────┴────────────────────────────────┘
 Collapsed rows: pin + first line. Selected row expands: editor (placeholder "Comment"), 120 pt preview,
 mic ↔ recording capsule, ⋯ = Transcript · Add to Comment · Transcribe Again · Delete Comment.
 Status shown only when not ready: 🎙 Recording · ◌ Transcribing · ⚠︎ File Missing.
 No "Comment 1", no "Region", no "Ready", no "Saved", no "Show Source on Canvas", no bottom recording bar.
 Compact width: the same view as a sheet with .medium/.large detents.
```

### Send popover (from the toolbar Send button)

```text
                                                        (➤ Send ¹)
                                                             ▲
                                        ┌────────────────────────────────────┐
                                        │ ⓧ        Send Feedback       Send  │  ← .close / .confirmationAction
                                        ├────────────────────────────────────┤
                                        │ To                Checkout fix  ›  │  ← "Choose Thread…" if unbound
                                        ├────────────────────────────────────┤
                                        │ CHECKOUT · NOW                     │
                                        │ ┌────┐ ◉ ① The pay button should…  │
                                        │ │ ▢▢ │ ◉ ② Item list is too dense  │
                                        │ └────┘                             │
                                        │ CHECKOUT · PROPOSAL A · VERSION 2  │
                                        │ ┌────┐ ○ ③ Total should be bold    │
                                        │ └────┘     Transcribing            │  ← reason in secondary text
                                        └────────────────────────────────────┘
```

---

## 4. Prioritized fix list (top 15)

1. **P0 · Native toolbar.** Replace the four custom palettes and the Feedback button with `.toolbar` + `.toolbarRole(.editor)`:
   - Leading: sidebar toggle and title menu.
   - Center: tool toggles, Undo and Redo.
   - Trailing: Add, Comments, More, then the prominent "Send" with `.badge`.
   - Keep only a "64% ⌄" zoom menu pill bottom-leading (F-1).
2. **P0 · `.inspector` for comments.** Replace the floating glass card and the Comments sheet with one trailing "Comments" column. The selected comment expands in place, and the canvas is never covered (F-7, F-12).
3. **P0 · Apply the copy audit.** It cuts about 70% of visible prose:
   - Delete every explanatory footer except the ElevenLabs privacy and billing line.
   - Delete "Saved", "Ready", "Comment N", "REC" and the Feedback summary line.
   - Use one vocabulary: Screen / Now / Proposal / Version / Comment / Thread (§1).
4. **P0 · Send as a popover from the toolbar button.**
   - Inline title, Close leading, "Send" trailing with progress in the button.
   - A "To" row and grouped rows with system selection.
   - Without a thread, Send opens the picker. No explanatory text (F-9).
5. **P1 · Recording inside the comment row.** A red dot, live level, a monospaced timer and a red Stop. Remove `RecordingBar`, "REC", "Comment N", the blue Stop and the wrong "use Stop or Discard above" label (F-8).
6. **P1 · One dismissal pattern.** `Button(role: .close)` leading on every sheet; a labeled `.confirmationAction` trailing on task sheets; inline titles everywhere; no "Back to Canvas" or "Done" body buttons (F-15).
7. **P1 · Canvases in a hidden `NavigationSplitView` sidebar.** The thread goes into `.navigationSubtitle`, and "Choose Thread…" into the title menu. Remove the permanent blue "Choose Thread" chip and the grid icon (F-1).
8. **P1 · Color budget.** Only Send is tinted. Version menus, Try, zoom and thread are monochrome (F-2).
9. **P1 · Lane headers.** The menu sits on the lane title and shows only when a lane has more than one version. Try is icon-only. Align the screen title with the first lane. Remove the "Interacting — tap Done" banner (F-3).
10. **P1 · Fix the two copy bugs.** "Checkout · a · Iteration 1" in the Feedback group title (F-10), and the batch ID used as the History row headline (F-11).
11. **P1 · Pairing and thread picker.**
    - Remove the nested `NavigationStack`s.
    - Pairing form: Host, Code and one footer; Connect in the toolbar; access picker removed or reduced to one row.
    - Thread rows on two lines (F-14).
12. **P1 · Sheet sizing.**
    - Add Region: centered form, no detents on iPad, confirm "Add".
    - History and Settings: fitted form sheets.
    - Empty states centered with `.overlay` (F-11, F-13, F-16).
13. **P1 · Title-style capitalization and `inflect: true` pluralization everywhere.** Remove "we" ("We don't know if the message arrived" → "Delivery not confirmed") (F-18, F-19).
14. **P2 · Icons and glass.**
    - Component tool: `cursorarrow.and.square.on.square.dashed`.
    - `ellipsis` instead of `ellipsis.circle`; History `clock.arrow.circlepath`.
    - No glass behind `EmptyCanvasView`.
    - Remove the 1.5 s tool-name overlay (F-4, F-5).
15. **P2 · Simplify the model (owner decision).**
    - Drop Drafts: unsent comments are the draft, and History shows Sent only.
    - Take "Add Region Without Drawing…" off the "+" menu in favor of the existing card accessibility action, with a full-screen comment as the default (F-16, F-17).

## What works, keep it

- The annotation signature: an unchanged screenshot, a fixed #BD3048 mark with a white halo, and a numbered pin (white label 5.7:1) in both appearances.
- 44 pt targets, single-key tool shortcuts, ⌘Z / ⇧⌘Z / ⌘0 / ⌘, and Space to stop recording.
- The Reduce Transparency fallbacks (`PaletteBackground`, `CanvasPaletteBackground`) and the Reduce Motion handling in `RecordingRing` and `RecordingStatus`.
- The squeeze palette placed at the Pencil tip.
- Delete confirmations with `confirmationDialog`, and Undo for deleted comments.
- The fixed `actionFill` (#1758BD, white label 6.6:1) for the one prominent action.
- Light-mode secondary text #556171 on #F5F6F8 at 5.8:1.
- `ContentUnavailableView` used for empty states (wording aside).
