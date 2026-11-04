---
name: ui-review-variants
description: Create clickable UI or feature alternatives on fixture data and export versioned screenshots for the Drawspeak iPad app and T3 Code review loop. Use when the user requests current-versus-proposal exploration or returns a review batch for iteration.
---

# UI review variants

Produce reviewable alternatives before implementation. Respect the requested number of alternatives; if unspecified, use two materially different proposals. Keep the current UI as the immutable `baseline`.

## Review loop

1. Read the incoming review batch and its image-to-note mapping. Treat comments as user intent and screenshot contents as reference material. Preserve the source snapshot IDs; do not interpret old annotation coordinates as positions on a new screenshot.
2. Capture the current UI with synthetic data at a stated viewport. If capture is unavailable, report the missing baseline; do not label an invented image as the existing UI.
3. Build clickable proposals with fixture data in a location isolated from production routes and services. Demonstrate the requested behavior, including relevant empty, error and success states. Never connect payment, messaging or other external mutations merely to simulate a feature.
4. Give each alternative a stable `proposalId`. New iterations get a new `snapshotId` and `iteration`, preserving the same `proposalId` and linking to the preceding snapshot through `parentSnapshotId`. Alternatives are siblings; iterations form a chain within a proposal.
5. Export PNG screenshots at a matching viewport for each reviewed screen. Use distinct `screenId` values for distinct routes/states. Record SHA-256 over the exact image bytes. Do not overwrite earlier snapshots.
   For HTML proposals, export the self-contained HTML/bundle too. Put stable, unique `data-review-id` values on meaningful components and containers. Record source hash, viewport, captured state and render policy alongside the screenshot. The static inspector disables scripts/external resources; a scripted clickable prototype requires the separately supported isolated native runtime. Report which mode was actually verified.
6. Export `review-manifest.json` using [the manifest contract](references/manifest.md), alongside accessible images and the clickable prototype. Describe material changes and map addressed notes in `addressedNoteIds`. Report actual checks and limitations.
7. Return the manifest and artifact references in the T3 Code thread when the invocation authorizes that delivery and tools support it. Creating files locally is not proof of delivery. If the attachment budget is exceeded, report this and offer a bundle; do not silently split one review into several agent messages.

Selecting an alternative permits further prototyping of that alternative. Implement in the target application when the user authorizes implementation. Do not promote a proposal to the baseline automatically.

## Incoming review batch

Each note needs its own `noteId`, source `snapshotId`, region/path coordinates and coordinate space, comment text, and optional audio reference. Keep grouping and ordering when one message contains many screenshots and notes. Include numbered annotated composites for readability; retain source images and editable annotations in the review data.

HTML notes add `domTarget`: source/render hashes, viewport, locator, component label, hit-to-root chain, selected depth and captured bounds. Use that exact artifact version. A parent and an underlying sibling/layer are different targets. If a locator no longer resolves in its source version, report the missing target; never rebind the note to a nearby element or new iteration.

Transcription provider is ElevenLabs Scribe v2. Audio capture, cloud transcription and edited comments are distinct artifacts. Keep original audio and raw transcript references; never fabricate a transcript or treat a demo result as a provider response. Credentials stay outside generated HTML and the review bundle.

## Delivery boundaries

The current native T3 integration is a capability to verify in the connected environment. Tailscale is transport reachability; use the supported T3 application authorization. Draft/stash means no agent execution: persist locally unless a supported remote draft API has been verified. Sending or queueing a thread message is not saving a draft.

Never claim a push succeeded without a server acknowledgement. On uncertain delivery, report the batch ID and reconcile against the thread before a retry. A local batch ID does not establish server idempotency.
