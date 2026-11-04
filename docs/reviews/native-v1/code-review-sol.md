# Drawspeak native v1 — Swift / SwiftUI review

Static review, 2026-11-04. Scope: `App/Drawspeak/**` and the seven modules under `Packages/DrawspeakKit/Sources/**`. No source edits or commits. Builds, tests, simulator, microphone, provider and live T3 checks were not run. Suggested fixes below are illustrative, not applied or compiled.

Method: loaded `/Users/rafalw/.claude/skills/swiftui-pro/SKILL.md` and all eleven requested references. Applied the API, views, data, navigation, design, resizing, accessibility, localization, performance, Swift/concurrency and hygiene checks, using iOS 27 / Swift 6.4 and the package's MainActor defaults. Checked the implemented paths against PRD §§6–8 and ADRs 0004–0006. No deprecated-API or localization finding is asserted without a concrete problem. Canvas touch state is already separated from persisted workspace state; this review does not claim whole-world invalidation on every drawing sample.

Severity follows the requested convention: P0 crash/data loss; P1 wrong behavior/accessibility blocker; P2 quality. Paths below are relative to the repository root. Findings are grouped by file; numbers identify findings, not priority.

## Packages/DrawspeakKit/Sources/DrawspeakCore/Services/Workspace.swift

### F01 — P0 — Failed library loads silently become a new library

**Location:** `Workspace.swift:53` (also `scheduleSave`, lines 69–83).
**Rule:** Preserve persisted work on read/decode errors; surface actionable errors (`swift.md`, PRD §7.2).

`try? await store.load()` collapses a missing file and every I/O/JSON decoding failure into the same empty document. A malformed or incompatible existing library opens as “First review”; the next selection, camera change or background save overwrites the original JSON with that new library. `AppModel.loadError` cannot catch this because `Workspace.load` does not throw.

Before: `(try? await store.load()) ?? LibraryDocument()`.
After: make loading throwing; use `try await store.load() ?? LibraryDocument()` only for a genuinely absent file. Show recovery UI on failure and keep the original file untouched.

### F02 — P0 — Send crosses the network without a durable outbox checkpoint

**Location:** `Workspace.swift:619–624, 660–674`; recovery in `Logic/OutboxRecovery.swift:10–13`.
**Rule:** Persist delivery intent and uncertainty before sending; restart must not enable blind resend (PRD §8, ADR-0005).

Both entry insertion and the transition to Sending use a cancellable 250 ms debounced save. The final upload progress callback merely enqueues a MainActor task; `T3ThreadService.send` can already start its message request before that task runs. If the app dies after acceptance but before the save, disk can contain no batch or an Uploading entry. Recovery turns Uploading into Ready to Send, allowing a duplicate instead of requiring Delivery Unknown reconciliation. A disk write failure also does not prevent the network operation.

Before: `updateOutbox(...); await threads.send(...)`, with asynchronous progress setting `.sending`.
After: use a throwing durable checkpoint before delivery; split upload preparation from message submission, persist `.sending` successfully before that request, then submit exactly once. Recover any state that could have crossed that boundary as Delivery Unknown.

### F03 — P1 — The current connection can send to the wrong host

**Location:** `Workspace.swift:652–667` (same omission in `reconcile:724–725` and `pull:762–768`).
**Rule:** The recipient is the full bound host/thread identity, not just a thread ID (PRD §§7.1, 8; ADR-0005).

Outbox entries and canvases store `ThreadBinding.hostURL`, but delivery uses whichever global `threads` service is currently connected, passing only `threadId`. Pair with host A, bind a canvas, then pair with B: the preview still names A, while its send, status and reconciliation requests go to B. A matching ID sends to the wrong recipient; otherwise the original canvas is unusable without an explanatory host mismatch.

Before: `threads.send(threadId: entry.thread.threadId, ...)`.
After: expose endpoint identity through `ThreadService` and require normalized host/environment equality with the binding before send/read/status. Offer reconnecting to the bound host when mismatched. Apply the same identity check to rebinding, which currently compares only thread IDs at line 144.

### F04 — P1 — Reconciliation accepts quoted markers as delivery receipts

**Location:** `Workspace.swift:726–731`.
**Rule:** Sent requires evidence of the actual submitted message (PRD §8, ADR-0005).

Any message whose text contains the marker is treated as the receipt, including an assistant reply quoting the batch or a longer marker sharing its prefix. `markSent` then hides those revisions from the next default package even though this is not proof of the feedback's delivery. The stricter provenance checks in `T3ThreadService.reconcile` are not used by the `ThreadService` protocol/workspace path.

Before: `messages.first { $0.text.contains(marker) }`.
After: reconcile the exact bracketed batch marker against a verified outgoing user message with server provenance, or the server queue's accepted item. Preserve uncertainty when that evidence is unavailable; do not manufacture a receipt from an assistant quotation.

### F05 — P1 — Resuming a draft substitutes current revisions for its frozen content

**Location:** `Workspace.swift:588–595`.
**Rule:** Saved packages must remain reproducible without overwriting newer edits (PRD §7.2, ADR-0004).

Save text A, edit the same note to B, then resume the draft: the existence-only check returns that note ID and Feedback opens with B. The stored A remains in JSON but no UI path restores or previews it while that ID exists. The draft's saved recipient is also ignored when opening the current canvas preview.

Before: `if canvas.notes.contains(where: { $0.id == item.noteId }) { ids.insert(item.noteId) }`.
After: compare the full frozen `BatchItem`; reuse only matching revisions and create copies for changed/deleted notes, or preview the saved items directly. Preserve and display the draft's saved recipient and require an explicit decision if it differs.

### F06 — P1 — Clearing typed text lets a late transcript refill it

**Location:** `Workspace.swift:398`; merge in `Logic/TranscriptMerge.swift:39`.
**Rule:** Late transcripts must not overwrite newer user text edits, including deletion (PRD §6, ADR-0006).

While transcription is pending, type a correction and then delete all text. The setter changes `textSource` from `.typed` to `.none`; the late transcript now passes the merge guard and inserts text the user cleared. Text provenance is being used as the edit-conflict token, but empty text is still a deliberate edit.

Before: `textSource = text.isEmpty ? .none : .typed`.
After: record every user edit as typed, including empty input; preferably capture a text-edit generation at recording start and merge only if no later user edit occurred.

### F07 — P1 — Concurrent transcription requests have no per-recording guard

**Location:** `Workspace.swift:522–541`; trigger in `NotesKit/TranscribeAgainButton.swift:11–13`.
**Rule:** One intentional provider attempt per recording; stale completions cannot replace newer outcomes (ADR-0006, concurrency/data references).

A rapid repeated activation can invoke `transcribe` again before SwiftUI replaces the retry button. The method accepts an already-transcribing recording, starts another paid request and retains neither task nor attempt identity. Two successes can append the same transcript twice; a late failure can change a successful recording back to Failed.

Before: `guard let recording, let audio ...; state = .transcribing; Task { ... }`.
After: synchronously reject an in-flight scope and track an attempt token/task per recording. Apply success/failure only for the active token and disable the action immediately.

### F08 — P0 — Blob-write failure abandons captured audio without recovery

**Location:** `Workspace.swift:479–490`.
**Rule:** Stop must retain audio locally and expose save failures before transcription (PRD §6, ADR-0006; `swift.md` error handling).

`activeRecording` is cleared and `voice.stop()` releases the recorder's file reference before `blobs.putFile` is attempted. A storage error is swallowed; the recording becomes Interrupted with no audio reference. The temporary file is left behind, but neither the note nor recorder can recover it, and a later purge loses the only recording. The UI says no audio was saved rather than offering storage recovery.

Before: `if let ref = try? blobs.putFile(...) { blob = ref }` followed by `.interrupted`.
After: retain the captured file URL in a recoverable pending-save record, handle the error visibly, and offer retry/discard. Release/delete the temporary source only after the blob and its ownership metadata are durably saved.

### F09 — P1 — Undoing a new recording can restore a permanently Recording note

**Location:** `Workspace.swift:415–420`; discard recursion at `495–506`.
**Rule:** Undo must restore usable data and consistent active-recording state (`data.md`, PRD §6).

The Undo action registered by Add Note can call `deleteNote` during capture. `deleteNote` captures the old canvas, then calls `discardRecording`. For an empty note, discard recursively calls `deleteNote` and registers another inverse. The outer call then registers restoration of its stale note containing a `.recording` entry. Redo/restoration can resurrect that entry although `activeRecording` and the recorder are nil. Readiness remains Recording and no Stop action exists for that orphan state until restart.

Before: discard via recursive deletion, then `let removed = canvas.notes[index]` from the pre-discard copy.
After: make capture cleanup and note removal one non-recursive operation; register exactly one inverse using a stopped/interrupted recording state, never a live-capture marker without an active capture.

### F10 — P1 — Failed Pull entries are permanently marked as imported

**Location:** `Workspace.swift:785–786`.
**Rule:** Pull must be recoverable after transient storage/render errors (PRD §8, ADR-0005).

`importManifestEntries` returns a count and reports per-entry failures, but Pull appends the message ID unconditionally. A temporary disk error can prevent an entry from being stored; subsequent Pull skips the entire message, including that missing version. Partial success also blocks retrying the failed subset.

Before: `imported += await importManifestEntries(...); pulledMessageIds.append(message.id)`.
After: track successful snapshot IDs and leave failed entries retryable. Mark the whole message complete only when all eligible entries are stored or explicitly dismissed; existing snapshot IDs already support deduplication.

### F11 — P1 — HTML imported without a capture has no repair path

**Location:** `Workspace.swift:823–827`; `CanvasKit/Views/LiveHTMLLayer.swift:43–44`.
**Rule:** A usable HTML source must be able to recover its capture so feedback can be sent (PRD §§7.1, 8).

Capture failure still imports the HTML with `image == nil`. Later live rendering can succeed, but `markLoaded` only sets a Boolean. No scoped source calls `Workspace.attachCapture` (line 303). Feedback explicitly blocks every selected note without `snapshot.image`, and another Pull skips the message. The user can annotate a functioning HTML card but cannot send those annotations or repair that snapshot through the app.

Before: import without capture; later `markLoaded() { isLoaded = true }`.
After: expose an explicit retry-capture action or persist a capture after a successful render, scoped to the same canvas/snapshot; keep the original source immutable and unblock only after the capture is stored.

## Packages/DrawspeakKit/Sources/HTMLKit/Capture/HTMLCapture.swift

### F12 — P0 — Unchecked manifest viewport values can trap during pixel conversion

**Location:** `HTMLCapture.swift:32–36`; admission in `DrawspeakCore/Logic/ReviewManifest.swift:97`.
**Rule:** Validate external geometry before numeric conversion or allocation (`swift.md`, PRD §8 manifest validation).

Manifest validation checks only positive image dimensions, not viewport dimensions or scale. A valid JSON entry with a tiny hashed HTML file, viewport 390×844 and finite `deviceScaleFactor: 1e308` passes validation. Multiplication overflows to infinity and `Int(...)` traps in `pixelSize`; this is not a thrown error and cannot be handled by Pull's `try?`. Less extreme values can request enormous WebKit/image allocations.

Before: `Int((Double(viewport.width) * scale).rounded())` with an unbounded finite scale.
After: validate bounded viewport dimensions, scale and total pixel count at import and defensively at capture; reject non-finite/out-of-range products before converting to Int or creating the web view.

## Packages/DrawspeakKit/Sources/FeedbackKit/FeedbackPayloadBuilder.swift

### F13 — P1 — HTML feedback omits the exact source it claims to identify

**Location:** `FeedbackPayloadBuilder.swift:12–16`; metadata in `DrawspeakCore/Logic/FeedbackManifest.swift:22–23, 65–66`.
**Rule:** HTML feedback includes DOMTarget plus access to the exact HTML source/bundle (PRD §8).

Attachments contain annotated PNGs and JSON only. The manifest provides source hashes but neither source bytes nor a retrievable source reference. For manually imported HTML, T3 has never received the file, so the agent gets component locators/hashes it cannot resolve against the exact reviewed document. This breaks the native HTML feedback loop even when delivery succeeds.

Before: append one PNG per group, then the manifest.
After: attach the selected snapshots' immutable HTML sources, or include a recipient-supported bundle/retrievable exact source reference. Recalculate attachment limits and block with an actionable explanation when the selected package cannot fit; keep one message.

## App/Drawspeak/Canvas/CanvasScreen.swift

### F14 — P1 — A card's accessible Add Region action loses its source snapshot

**Location:** `CanvasScreen.swift:38`; default selection in `NotesKit/AddRegionSheet.swift:79`.
**Rule:** Accessible alternatives must target the same subject as the visual action (`accessibility.md`, PRD §6).

SnapshotCard invokes `addRegion(snapshot.id)`, but the app discards that ID and opens a generic sheet. The sheet selects the first snapshot in the canvas, even when VoiceOver's action came from a different card/version. Accepting its defaults creates the note on the wrong immutable source.

Before: `onAddRegion: { _ in sheet = .addRegion }`.
After: carry the snapshot ID in the sheet route and initialize AddRegionSheet from it. Keep the generic menu action as a separate path with a user-chosen/default source.

## App/Drawspeak/Import/ImportCoordinator.swift

### F15 — P2 — Oversized imports are fully read on the main actor before rejection

**Location:** `ImportCoordinator.swift:12–20, 36`.
**Rule:** Keep blocking file I/O and unbounded allocation off the UI actor (`performance.md`, `swift.md`).

`read` is async but explicitly MainActor-isolated and performs synchronous `Data(contentsOf:)` before checking 2/10 MiB limits. Selecting a very large local or file-provider image/HTML allocates and reads the entire file while the interface cannot respond, although the file will be rejected. The async signature does not move this work off MainActor under this package/toolchain configuration.

Before: main-actor `Data(contentsOf: url)` followed by a byte-count guard.
After: coordinate provider access and read through a dedicated I/O executor while retaining the security scope; check metadata first and enforce a bounded streaming read to cover inaccurate/changing sizes. Return only validated bytes to MainActor.

## Prioritized top 15

1. **P0 / F01:** Preserve the existing library when loading/decoding fails — `Workspace.swift:53`.
2. **P0 / F02:** Durably checkpoint Sending before the message request — `Workspace.swift:619–674`.
3. **P0 / F12:** Reject viewport values that overflow or exhaust capture memory — `HTMLCapture.swift:32–36`.
4. **P0 / F08:** Retain recoverable audio when blob persistence fails — `Workspace.swift:479–490`.
5. **P1 / F03:** Enforce the bound T3 host/environment for every thread operation — `Workspace.swift:652–667`.
6. **P1 / F04:** Require actual outgoing-message evidence during reconciliation — `Workspace.swift:726–731`.
7. **P1 / F05:** Restore the draft's frozen revisions and recipient — `Workspace.swift:588–595`.
8. **P1 / F06:** Preserve deliberate text deletion against late transcripts — `Workspace.swift:398`.
9. **P1 / F09:** Prevent Undo from restoring orphan Recording states — `Workspace.swift:415–420`.
10. **P1 / F07:** Deduplicate transcription attempts and reject stale completions — `Workspace.swift:522–541`.
11. **P1 / F13:** Include retrievable exact HTML sources in feedback — `FeedbackPayloadBuilder.swift:12–16`.
12. **P1 / F10:** Keep failed Pull entries retryable — `Workspace.swift:785–786`.
13. **P1 / F11:** Provide capture recovery for imported HTML — `Workspace.swift:823–827`.
14. **P1 / F14:** Keep the selected card's snapshot in accessible Add Region — `CanvasScreen.swift:38`.
15. **P2 / F15:** Bound imports before reading and move file I/O off MainActor — `ImportCoordinator.swift:15`.
