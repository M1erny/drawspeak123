# Review manifest v1 (proposed app contract)

This is a file contract owned by Review Canvas, not an existing T3 Code endpoint. The iPad app will validate it before importing artifacts. Example values are synthetic; compute real hashes and dimensions for actual exports.

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

Thread attachments can carry this manifest. The current T3 server does not inherently turn a manifest into a version catalog; that parser belongs to the planned app.
