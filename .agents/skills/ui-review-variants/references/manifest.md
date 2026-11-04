# Review manifest v1 (proposed app contract)

This is a file contract owned by Drawspeak, not an existing T3 Code endpoint. The iPad app will validate it before importing artifacts. Example values are synthetic; compute real hashes and dimensions for actual exports.

```json
{
  "schemaVersion": 1,
  "reviewId": "review-checkout",
  "threadId": "target-thread-id",
  "runId": null,
  "status": "ready_for_review",
  "snapshots": [
    {
      "snapshotId": "checkout-current-001",
      "screenId": "checkout-default",
      "role": "baseline",
      "proposalId": null,
      "iteration": 0,
      "parentSnapshotId": null,
      "imagePath": "screens/checkout-current-001.png",
      "sha256": "<actual 64-character lowercase SHA-256>",
      "widthPx": 1440,
      "heightPx": 1024,
      "viewport": {"width": 1440, "height": 1024, "deviceScaleFactor": 1},
      "capturedAt": "2026-11-04T12:00:00Z",
      "prototypePath": null,
      "changeSummary": "Existing checkout captured with fixture data.",
      "addressedNoteIds": []
    },
    {
      "snapshotId": "checkout-a-002",
      "screenId": "checkout-default",
      "role": "proposal",
      "proposalId": "a",
      "iteration": 2,
      "parentSnapshotId": "checkout-a-001",
      "imagePath": "screens/checkout-a-002.png",
      "sha256": "<actual 64-character lowercase SHA-256>",
      "widthPx": 1440,
      "heightPx": 1024,
      "viewport": {"width": 1440, "height": 1024, "deviceScaleFactor": 1},
      "capturedAt": "2026-11-04T12:05:00Z",
      "prototypePath": "prototypes/a/index.html",
      "changeSummary": "Full total shown before the payment action.",
      "addressedNoteIds": ["note-1"]
    }
  ],
  "checks": [{"name": "prototype interaction", "result": "pending", "details": "Not yet checked on a physical iPad."}]
}
```

Validation rules for the future importer: unique snapshot IDs; positive dimensions; matching checksums; matching review/thread binding; role `baseline` or `proposal`; proposal iterations start at 1; references resolve to this manifest or stored prior snapshots; parent belongs to the same proposal and screen. Never replace bytes under an existing snapshot ID. Resolve paths inside the artifact bundle and reject traversal. Missing files or invalid entries remain quarantined with an actionable error; do not silently add partial versions. Allowed status: `ready_for_review`, `partial`, `failed`. Check result: `passed`, `failed`, `pending`, `not_run`.

Drawspeak reads this manifest from the workspace (pointer) or from the reply (inline); T3 Code itself does not parse it.

## HTML artifact extension

For an HTML snapshot add `artifactKind: "html"`, `htmlPath` (or bundled entrypoint), `htmlSha256`, `renderPolicy`, `renderHash` and `stateId`. Preserve `imagePath`/`sha256` as the actual capture of that state. Image-only snapshots use `artifactKind: "image"` and have no DOM target. Source bytes, state, viewport and screenshot form one immutable version.

Use `static-no-script` for the current inspector. A future isolated scripted renderer needs a distinct supported policy identifier; never label its output as verified by the static inspector. Resolve assets inside the bundle and exclude credentials.

A note's `domTarget` references the snapshot and hashes, has a version-local locator (prefer unique data-review-id), human label, hit-to-root chain, depth/layer and normalized capture bounds. Pressure changes parent depth; a separate layer choice selects underneath stacked elements. Never carry a locator into a new iteration as stable identity.

## Bundles in a reply

Drawspeak downloads files from the thread's workspace on the Mac (docs/T3-MCP-CONTRACT.md, "Workspace file access"), so a reply carries one of:

1. **Pointer (default).** `drawspeak_bundle.py --out <review dir>` writes `review-manifest.json` into the review folder and prints:

   ````text
   ```drawspeak-bundle path="/Users/me/Dev/app/output/review/review-manifest.json"
   ```
   ````

   The path is absolute or workspace-relative and must be inside the thread's workspace. Manifest paths (`htmlPath`, `imagePath`) are relative to the manifest. Image entries (`artifactKind: "image"`, `imagePath`, `sha256`) import as image versions. Limits: 40 files per Pull, 10 MiB per file, 2 MiB per HTML.
2. **Inline bundle (small HTML only).** Manifest and HTML as fences in the reply:

`````text
````drawspeak-manifest
{"schemaVersion":1,"reviewId":"review-checkout","threadId":null,"runId":null,"status":"ready_for_review",
 "snapshots":[{"snapshotId":"checkout-a-002","screenId":"checkout-default","screenTitle":"Checkout","role":"proposal",
  "proposalId":"a","iteration":2,"parentSnapshotId":"checkout-a-001","artifactKind":"html",
  "htmlPath":"prototypes/a/index.html","htmlSha256":"<sha256 of the file text>","renderPolicy":"static-no-script",
  "widthPx":780,"heightPx":1688,"viewport":{"width":390,"height":844,"deviceScaleFactor":2},
  "changeSummary":"Total shown on the pay button.","addressedNoteIds":["<noteId>"]}]}
````
````drawspeak-file path="prototypes/a/index.html"
<!doctype html>...
````
`````

   The file text between the fence lines is hashed as UTF-8, without the newline before the closing fence. Paths are relative. Omit `imagePath`/`sha256` (inline images are not readable).

Fallback: when the latest reply has neither, Drawspeak imports the local `.html`/`.png`/`.jpg` files it links (markdown links or absolute paths). `prototypes/a/…` gives proposal `a`, a `baseline/` or `current/` folder gives a baseline, and the file stem names the screen. Each reply is imported once. Use `screenId` values that already exist on the canvas to add iterations next to Now; a new `screenId` creates a new row.
