# Native v1 — HIG visual review (Claude Opus 5.5, apple-design)

Input: 13 simulator screenshots in this folder (iPad Pro 13", iOS 27). Rating: critical issues on secondary surfaces; the canvas signature (red mark + numbered pin on an unchanged screenshot) works.

## Top 12

1. P0 Inspector: preview fills the card; text editor, Show Source, Record Voice and Delete are below the fold. Crop the preview to the mark (~180 pt), put the editor right under the header, move Delete into a More menu, cap the card to the available height.
2. P0 Feedback preview: note rows and the Send block reason sit under the glass action bar. Thumbnail and rows side by side; reason next to the buttons; no nested glass on the inset.
3. P1 Dark mode Feedback button: white on #95BAFF is 1.9:1. Use a fixed #1758BD fill.
4. P1 Dark mode marks and pins: #FF8598 on white screenshots is 2.2:1. Marks/pins/composites use fixed #BD3048 with a white halo (apple-pencil-and-scribble › Custom drawing).
5. P1 Feedback without a thread is a dead end: add a "To" row with "Choose Thread…" and an inline reason under the disabled Send.
6. P1 Send placement and tint: Send to Agent prominent; Save Draft secondary in Theme.action, not system blue.
7. P1 Add Region: primary action off-screen at the medium detent; add a toolbar confirm and cap the preview at ~260 pt.
8. P1 Inspector covers Proposal B and its clipped stroke reads as a mark on B: reframe the camera on open.
9. P1 (verify) Custom top-leading palette vs iPadOS window controls in windowed mode.
10. P2 Consistent sheet dismissal (Close role / Cancel + confirm); separate "+" from "Done"; no grabber on fixed sheets.
11. P2 Palette geometry: center-aligned top row (44 pt), capsule/concentric corners, tool palette centered on the window.
12. P2 Tool icons (lasso for rectangle, pen reads as "A", component reads as sparkle), glass title chip in the content layer, one-choice "Now · Revision 1" menu.

Other P2: thread label should invite the action ("Choose Thread" in action color with a symbol); demo mark should cover the Pay button; dark-mode card edge; inspector title "Comment 1" instead of "Region"; Ready chip symbol; Comments sheet as non-modal/inspector; History: Done trailing, one combined empty state, "Sent" instead of "Sent / Outbox"; pairing form labels and order, disabled Connect state, default access level; thread rows show recency and the bound thread instead of identical "Completed" chips; pluralization ("1 comments"); Settings Save Key affordance; undo/redo disabled appearance.

What works: calm chrome around the annotation signature; 44 pt targets and keyboard shortcuts; Reduce Transparency fallback; light-mode contrast (mark 5.3:1, pin 5.7:1, Feedback 8.1:1); ContentUnavailableView copy; placement of Feedback, version menus and Fit All.
