/**
 * The tool's look, from the iPad app's Theme: marks in one red with a white halo, one blue for
 * actions, and calm glass for everything else, so the ink is what stands out. It is dark glass here
 * because it floats over a bright, moving 3D world, not over a pale canvas.
 */
export const INK = "#BD3048";
export const HALO = "rgba(255,255,255,0.92)";
export const ACTION = "#1758BD";
export const OUTLINE = "#4d8dff";
export const DONE = "#1f9d6b";
export const LINE_WIDTH = 3;

const EASE = "cubic-bezier(0.22, 0.8, 0.26, 1)";
const SPRING = "cubic-bezier(0.2, 1.5, 0.4, 1)";
// The pointer while drawing: a dot of the ink it is about to leave.
const PEN = `url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='24' height='24'%3E%3Ccircle cx='12' cy='12' r='4.5' fill='%23BD3048' stroke='white' stroke-width='2'/%3E%3C/svg%3E") 12 12, crosshair`;

export const CSS = `
.ds3d-root { position: fixed; inset: 0; z-index: 9000; contain: layout style; pointer-events: none; font: 13px/1.4 -apple-system, BlinkMacSystemFont, "Segoe UI Variable Text", "Segoe UI", system-ui, sans-serif; color: #f2f3f5; -webkit-font-smoothing: antialiased; user-select: none; -webkit-user-select: none; }
.ds3d-root * { box-sizing: border-box; }
:where(.ds3d-root) :where(button, textarea, input) { font: inherit; color: inherit; margin: 0; letter-spacing: normal; text-transform: none; box-shadow: none; filter: none; min-height: 0; }
.ds3d-ink { position: absolute; inset: 0; width: 100%; height: 100%; pointer-events: none; }
.ds3d-freeze { position: fixed; pointer-events: none; filter: saturate(0.84) brightness(0.985); transition: opacity 0.16s ease-out; }
body.ds3d-armed canvas { cursor: ${PEN} !important; }
.ds3d-leaving { animation: ds3d-leave 0.16s ease-in forwards !important; pointer-events: none !important; }

.ds3d-glass { background: rgba(19, 21, 26, 0.8); -webkit-backdrop-filter: blur(24px) saturate(135%); backdrop-filter: blur(24px) saturate(135%); border: 1px solid rgba(255, 255, 255, 0.12); box-shadow: 0 14px 40px rgba(8, 12, 24, 0.32), 0 2px 8px rgba(8, 12, 24, 0.2), inset 0 1px 0 rgba(255, 255, 255, 0.08); pointer-events: auto; }
@media (prefers-reduced-transparency: reduce) { .ds3d-glass { background: #24272b; -webkit-backdrop-filter: none; backdrop-filter: none; } }
/* Big panels are solid: blurring the moving world behind them costs a weak graphics card more than the world does. */
.ds3d-column.ds3d-glass, .ds3d-sheet.ds3d-glass, .ds3d-root.is-plain .ds3d-glass { -webkit-backdrop-filter: none; backdrop-filter: none; background: rgba(24, 26, 31, 0.95); }
vite-error-overlay { display: none !important; }

.ds3d-ic { display: inline-grid; place-items: center; flex: none; }
.ds3d-ic svg { display: block; }
.ds3d-btn { height: 40px; min-width: 40px; padding: 0 10px; display: inline-flex; align-items: center; justify-content: center; gap: 6px; border: 0; border-radius: 16px; background: transparent; font-weight: 600; white-space: nowrap; cursor: pointer; transition: background 0.16s ${EASE}, color 0.16s, opacity 0.16s, box-shadow 0.2s, scale 0.1s; }
.ds3d-btn:hover { background: rgba(255, 255, 255, 0.11); }
.ds3d-btn:active { scale: 0.96; }
.ds3d-btn:focus-visible { outline: 2px solid #95baff; outline-offset: 1px; }
.ds3d-btn[disabled] { opacity: 0.38; cursor: default; background: transparent; }
.ds3d-btn.is-on { background: ${INK}; color: #fff; }
.ds3d-btn.ds3d-primary { background: ${ACTION}; color: #fff; padding: 0 14px; box-shadow: 0 3px 12px rgba(23, 88, 189, 0.42); }
.ds3d-btn.ds3d-primary:hover { background: #1f68d6; }
.ds3d-btn.ds3d-primary[disabled] { background: rgba(255, 255, 255, 0.1); box-shadow: none; }
.ds3d-btn.ds3d-small { height: 32px; min-width: 32px; border-radius: 11px; padding: 0 9px; font-size: 12.5px; }
.ds3d-btn.ds3d-small.ds3d-primary { padding: 0 8px 0 10px; }
.ds3d-btn.ds3d-small svg { width: 17px; height: 17px; }
.ds3d-btn.ds3d-quiet { color: rgba(255, 255, 255, 0.74); }
.ds3d-btn.ds3d-quiet:hover { color: #fff; }
.ds3d-btn.ds3d-danger:hover { background: rgba(189, 48, 72, 0.55); }
.ds3d-btn .count { font-variant-numeric: tabular-nums; }
.ds3d-root kbd { font: 600 10px/1 ui-monospace, "Cascadia Mono", Consolas, monospace; padding: 3px 5px; border-radius: 5px; background: rgba(255, 255, 255, 0.17); color: rgba(255, 255, 255, 0.9); }

.ds3d-palette { position: fixed; left: 50%; bottom: calc(14px + var(--ds3d-bottom, 0px)); transform: translateX(-50%); display: flex; align-items: center; gap: 2px; padding: 5px; border-radius: 22px; max-width: calc(100vw - 16px); animation: ds3d-rise 0.3s ${EASE}; }
.ds3d-sep { width: 1px; height: 22px; margin: 0 4px; background: rgba(255, 255, 255, 0.15); flex: none; }
.ds3d-more { display: grid; grid-template-columns: 0fr; opacity: 0; transition: grid-template-columns 0.2s ${EASE}, opacity 0.16s; }
.ds3d-more.is-open { grid-template-columns: 1fr; opacity: 1; }
.ds3d-more > div { display: flex; align-items: center; gap: 2px; min-width: 0; overflow: hidden; }
.ds3d-hint { position: fixed; left: 50%; bottom: calc(72px + var(--ds3d-bottom, 0px)); transform: translateX(-50%); padding: 8px 14px; border-radius: 14px; font-weight: 500; white-space: nowrap; max-width: calc(100vw - 24px); overflow: hidden; text-overflow: ellipsis; pointer-events: none; opacity: 0; translate: 0 6px; visibility: hidden; transition: opacity 0.18s ${EASE}, translate 0.18s ${EASE}, visibility 0.18s; }
.ds3d-hint.is-on { opacity: 1; translate: 0 0; visibility: visible; }
.ds3d-hint em { font-style: normal; opacity: 0.62; font-weight: 400; }
.ds3d-toast { position: fixed; left: 50%; bottom: calc(72px + var(--ds3d-bottom, 0px)); transform: translateX(-50%); padding: 9px 14px; border-radius: 14px; font-weight: 500; animation: ds3d-rise 0.2s ${EASE}; max-width: min(560px, calc(100vw - 24px)); }
.ds3d-toast.warn { background: rgba(120, 28, 44, 0.92); }

.ds3d-pin { position: absolute; left: -15px; top: -15px; width: 30px; height: 30px; padding: 0; display: grid; place-items: center; border: 2px solid #fff; border-radius: 50%; background: ${INK}; color: #fff; font-weight: 700; font-size: 14px; font-variant-numeric: tabular-nums; box-shadow: 0 2px 9px rgba(8, 12, 24, 0.42); pointer-events: auto; cursor: pointer; will-change: transform; transition: opacity 0.15s, background 0.25s ${EASE}, scale 0.14s ${EASE}; animation: ds3d-pop 0.26s ${SPRING}; }
.ds3d-pin:hover { scale: 1.12; }
.ds3d-pin:focus-visible { outline: 2px solid #95baff; outline-offset: 2px; }
.ds3d-pin.is-dim { opacity: 0.5; }
.ds3d-pin.is-sent { background: #47505c; }
.ds3d-pin.is-working::before { content: ""; position: absolute; inset: -2px; border-radius: 50%; border: 2px solid rgba(189, 48, 72, 0.85); pointer-events: none; animation: ds3d-ring 1.3s ease-out infinite; }
.ds3d-pin.is-done { background: ${DONE}; pointer-events: none; }
.ds3d-pin.is-empty { background: #fff; color: ${INK}; border-color: ${INK}; }
.ds3d-pin.is-edge { left: -11px; top: -11px; width: 22px; height: 22px; font-size: 11px; opacity: 0.86; }
.ds3d-pin.is-rec::after { content: ""; position: absolute; inset: -7px; border-radius: 50%; border: 2px solid ${INK}; animation: ds3d-ping 1.15s ease-out infinite; }
.ds3d-pin.is-rec::before { content: ""; position: absolute; inset: -4px; border-radius: 50%; background: rgba(189, 48, 72, 0.3); scale: calc(1 + var(--level, 0) * 1.1); transition: scale 0.08s linear; pointer-events: none; z-index: -1; }
.ds3d-arrived { position: absolute; left: 0; top: 0; padding: 5px 12px; border-radius: 12px; background: rgba(255, 255, 255, 0.94); color: #1c2430; font-weight: 700; font-size: 13.5px; white-space: nowrap; box-shadow: 0 6px 20px rgba(8, 12, 24, 0.28); pointer-events: none; animation: ds3d-arrive 0.42s ${SPRING}; will-change: transform; }
.ds3d-flight { position: absolute; left: -9px; top: -9px; width: 18px; height: 18px; border-radius: 50%; background: radial-gradient(circle, #fff 0%, #9fd6ff 45%, rgba(120, 190, 255, 0) 72%); pointer-events: none; transition: transform 0.55s ${EASE}, opacity 0.55s ease-in, scale 0.55s ease-in; }
.ds3d-chip-label { position: absolute; left: 0; top: 0; padding: 4px 9px; border-radius: 10px; font-weight: 600; white-space: nowrap; will-change: transform; }

.ds3d-bubble { position: absolute; left: 0; top: 0; z-index: 3; width: 316px; max-width: calc(100vw - 24px); padding: 10px 11px 10px 13px; border-radius: 20px; display: flex; flex-direction: column; gap: 5px; contain: layout style; will-change: transform; animation: ds3d-fade 0.18s ${EASE}; }
.ds3d-bubble-head { display: flex; align-items: center; gap: 8px; min-height: 26px; font-weight: 600; }
.ds3d-bubble-title { font-size: 12.5px; color: rgba(255, 255, 255, 0.66); }
.ds3d-rec { width: 9px; height: 9px; border-radius: 50%; background: #ff4d67; box-shadow: 0 0 0 3px rgba(255, 77, 103, 0.22); animation: ds3d-blink 1.3s ease-in-out infinite; flex: none; }
.ds3d-time { font-variant-numeric: tabular-nums; font-size: 12.5px; color: rgba(255, 255, 255, 0.78); }
.ds3d-level { display: flex; align-items: center; gap: 2px; height: 16px; flex: 1; }
.ds3d-level i { width: 3px; height: 16px; border-radius: 2px; background: rgba(255, 255, 255, 0.72); transform: scaleY(0.19); transition: transform 0.08s linear; }
.ds3d-lang { height: 22px; padding: 0 7px; border: 1px solid rgba(255, 255, 255, 0.18); border-radius: 8px; background: transparent; font-size: 10.5px; font-weight: 700; color: rgba(255, 255, 255, 0.8); cursor: pointer; transition: background 0.14s; }
.ds3d-lang:hover { background: rgba(255, 255, 255, 0.1); }
.ds3d-text { width: 100%; min-height: 46px; max-height: 148px; resize: none; padding: 3px 0 4px; border: 0; border-radius: 0; background: transparent; font-size: 15px; line-height: 1.36; font-weight: 500; outline: none; user-select: text; -webkit-user-select: text; scrollbar-width: thin; scrollbar-color: rgba(255, 255, 255, 0.24) transparent; }
.ds3d-text::placeholder { color: rgba(255, 255, 255, 0.46); font-weight: 400; }
.ds3d-bubble-foot { display: flex; align-items: center; justify-content: space-between; gap: 8px; min-height: 32px; }
.ds3d-about-box { min-width: 0; flex: 0 1 auto; }
.ds3d-about { max-width: 100%; height: 26px; padding: 0 5px 0 9px; display: inline-flex; align-items: center; gap: 1px; border: 0; border-radius: 9px; background: rgba(77, 141, 255, 0.2); color: #e6eeff; font-size: 12px; font-weight: 600; cursor: pointer; transition: background 0.14s; }
.ds3d-about:hover { background: rgba(77, 141, 255, 0.34); }
.ds3d-about.is-still { padding-right: 9px; cursor: default; background: rgba(255, 255, 255, 0.09); color: rgba(255, 255, 255, 0.78); }
.ds3d-about-name { min-width: 0; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.ds3d-about .ds3d-ic svg { width: 14px; height: 14px; transition: rotate 0.16s ${EASE}; }
.ds3d-about.is-open .ds3d-ic svg { rotate: 90deg; }
.ds3d-actions { display: flex; align-items: center; gap: 1px; flex: none; }
.ds3d-actions .ds3d-primary { margin-left: 5px; }
.ds3d-choices { display: flex; flex-direction: column; gap: 3px; padding-top: 5px; border-top: 1px solid rgba(255, 255, 255, 0.09); animation: ds3d-fade 0.14s ease-out; }
.ds3d-chain { display: flex; flex-wrap: wrap; align-items: center; gap: 2px; }
.ds3d-link { max-width: 170px; height: 25px; padding: 0 8px; border: 0; border-radius: 8px; background: transparent; color: rgba(255, 255, 255, 0.72); font-size: 12px; font-weight: 500; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; cursor: pointer; transition: background 0.12s, color 0.12s; }
.ds3d-link:hover { background: rgba(255, 255, 255, 0.11); color: #fff; }
.ds3d-link.is-current { background: rgba(77, 141, 255, 0.28); color: #fff; font-weight: 650; }
.ds3d-link-sep { color: rgba(255, 255, 255, 0.36); font-size: 11px; }
.ds3d-behind { display: flex; flex-wrap: wrap; align-items: center; gap: 2px; font-size: 11.5px; color: rgba(255, 255, 255, 0.55); }
.ds3d-note-line { color: rgba(255, 255, 255, 0.72); font-size: 12.5px; }

.ds3d-column { position: fixed; z-index: 2; top: calc(14px + var(--ds3d-top, 0px)); right: calc(14px + var(--ds3d-right, 0px)); max-height: calc(100vh - 28px - var(--ds3d-top, 0px) - var(--ds3d-bottom, 0px)); width: 340px; max-width: calc(100vw - 24px); display: flex; flex-direction: column; border-radius: 22px; overflow: hidden; animation: ds3d-slide 0.22s ${EASE}; }
.ds3d-column-head { display: flex; align-items: center; justify-content: space-between; padding: 11px 8px 7px 15px; font-size: 15px; font-weight: 650; }
.ds3d-column-list { flex: 1; overflow-y: auto; padding: 2px 8px 10px; display: flex; flex-direction: column; gap: 7px; scrollbar-width: thin; scrollbar-color: rgba(255, 255, 255, 0.24) transparent; }
.ds3d-empty { margin: 26px 18px; text-align: center; color: rgba(255, 255, 255, 0.6); line-height: 1.5; }
.ds3d-card { display: grid; grid-template-columns: 26px 1fr; gap: 8px; padding: 9px; border-radius: 14px; background: rgba(255, 255, 255, 0.055); transition: background 0.16s; }
.ds3d-card:hover { background: rgba(255, 255, 255, 0.085); }
.ds3d-card.is-active { background: rgba(77, 141, 255, 0.18); }
.ds3d-card-pin { width: 24px; height: 24px; display: grid; place-items: center; border-radius: 50%; background: ${INK}; color: #fff; font-size: 12px; font-weight: 700; }
.ds3d-card-pin.is-sent { background: #47505c; }
.ds3d-card-body { min-width: 0; display: flex; flex-direction: column; gap: 6px; }
.ds3d-card img { width: 100%; aspect-ratio: 16 / 9; object-fit: cover; border-radius: 10px; display: block; background: rgba(0, 0, 0, 0.3); cursor: pointer; transition: opacity 0.14s; }
.ds3d-card img:hover { opacity: 0.88; }
.ds3d-card-text { width: 100%; padding: 6px 8px; border: 1px solid transparent; border-radius: 9px; background: transparent; resize: none; font-size: 13.5px; line-height: 1.36; outline: none; overflow: hidden; user-select: text; -webkit-user-select: text; transition: background 0.14s; }
.ds3d-card-text:hover { background: rgba(0, 0, 0, 0.18); }
.ds3d-card-text:focus { background: rgba(0, 0, 0, 0.26); border-color: #95baff; }
.ds3d-card-text::placeholder { color: rgba(255, 255, 255, 0.46); }
.ds3d-card-meta { display: flex; align-items: center; justify-content: space-between; gap: 4px; min-height: 28px; }
.ds3d-card-target { min-width: 0; font-size: 11.5px; color: rgba(255, 255, 255, 0.62); overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.ds3d-card-buttons { display: flex; gap: 1px; flex: none; }
.ds3d-card-buttons .ds3d-btn { height: 28px; min-width: 28px; padding: 0 5px; border-radius: 9px; }
.ds3d-card-buttons svg { width: 16px; height: 16px; }

.ds3d-history-title { margin: 8px 2px 0; font-size: 11.5px; font-weight: 650; letter-spacing: 0.02em; color: rgba(255, 255, 255, 0.5); }
.ds3d-history-row { display: flex; align-items: center; gap: 7px; min-height: 34px; padding: 2px 4px 2px 8px; border-radius: 11px; background: rgba(255, 255, 255, 0.045); }
.ds3d-history-ok { width: 16px; height: 16px; display: inline-grid; place-items: center; flex: none; border-radius: 50%; background: ${DONE}; color: #fff; }
.ds3d-history-off { width: 16px; height: 16px; display: inline-grid; place-items: center; flex: none; color: rgba(255, 255, 255, 0.45); }
.ds3d-history-ok svg, .ds3d-history-off svg { width: 11px; height: 11px; stroke-width: 3; }
.ds3d-history-text { flex: 1; min-width: 0; font-size: 12.5px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.ds3d-scrim { position: fixed; inset: 0; z-index: 5; background: rgba(8, 12, 24, 0.46); pointer-events: auto; animation: ds3d-fade 0.16s ease-out; display: grid; place-items: center; padding: 18px; }
.ds3d-sheet { width: min(860px, 100%); max-height: min(92vh, 100%); display: flex; flex-direction: column; border-radius: 24px; overflow: hidden; background: rgba(26, 29, 34, 0.94); animation: ds3d-sheet 0.24s ${EASE}; }
.ds3d-sheet-head { display: flex; align-items: center; justify-content: space-between; gap: 12px; padding: 16px 12px 10px 22px; }
.ds3d-sheet-head h2 { margin: 0; font-size: 18px; font-weight: 680; }
.ds3d-to { color: rgba(255, 255, 255, 0.68); font-size: 12.5px; margin-top: 2px; }
.ds3d-dot { display: inline-block; width: 7px; height: 7px; border-radius: 50%; margin-right: 6px; background: #3ecf8e; vertical-align: 1px; }
.ds3d-dot.off { background: #ff7a8c; }
.ds3d-sheet-body { flex: 1; overflow-y: auto; padding: 0 22px 12px; display: flex; flex-direction: column; gap: 14px; scrollbar-width: thin; scrollbar-color: rgba(255, 255, 255, 0.24) transparent; }
.ds3d-group { display: grid; grid-template-columns: minmax(0, 300px) minmax(0, 1fr); gap: 16px; padding-top: 14px; border-top: 1px solid rgba(255, 255, 255, 0.09); }
.ds3d-group:first-child { border-top: 0; padding-top: 0; }
.ds3d-group img { width: 100%; aspect-ratio: 16 / 10; object-fit: cover; border-radius: 12px; display: block; background: rgba(0, 0, 0, 0.3); box-shadow: 0 0 0 1px rgba(255, 255, 255, 0.08); }
.ds3d-group h3 { margin: 0 0 4px; font-size: 12.5px; font-weight: 650; color: rgba(255, 255, 255, 0.62); }
.ds3d-item { display: grid; grid-template-columns: 22px 24px 1fr; gap: 7px; margin: 0 -6px; padding: 7px 6px; border-radius: 10px; align-items: start; cursor: pointer; transition: background 0.12s; }
.ds3d-item:hover { background: rgba(255, 255, 255, 0.05); }
.ds3d-item input { width: 17px; height: 17px; margin: 3px 0 0; accent-color: ${ACTION}; cursor: pointer; }
.ds3d-item-text { font-size: 14px; user-select: text; -webkit-user-select: text; }
.ds3d-item-target { margin-top: 1px; font-size: 11.5px; color: rgba(255, 255, 255, 0.56); }
.ds3d-pending { font-size: 12px; color: rgba(255, 255, 255, 0.55); padding-top: 8px; border-top: 1px solid rgba(255, 255, 255, 0.09); }
.ds3d-sheet-foot { padding: 12px 14px 14px 22px; border-top: 1px solid rgba(255, 255, 255, 0.09); display: flex; flex-direction: column; gap: 10px; background: rgba(255, 255, 255, 0.022); }
.ds3d-direct { display: flex; flex-wrap: wrap; align-items: center; gap: 8px; }
.ds3d-seg { display: inline-flex; padding: 2px; border-radius: 12px; background: rgba(255, 255, 255, 0.08); flex: none; }
.ds3d-seg button { height: 30px; padding: 0 11px; border: 0; border-radius: 10px; background: transparent; font-size: 12.5px; font-weight: 600; cursor: pointer; transition: background 0.14s; }
.ds3d-seg button.is-chosen { background: rgba(255, 255, 255, 0.2); }
.ds3d-extra { flex: 1 1 220px; height: 34px; padding: 0 11px; border: 1px solid rgba(255, 255, 255, 0.12); border-radius: 11px; background: rgba(0, 0, 0, 0.22); outline: none; user-select: text; -webkit-user-select: text; transition: border-color 0.14s; }
.ds3d-extra:focus { border-color: #95baff; }
.ds3d-extra::placeholder { color: rgba(255, 255, 255, 0.46); }
.ds3d-foot-row { display: flex; align-items: center; justify-content: space-between; gap: 8px; }
.ds3d-check { display: inline-flex; align-items: center; gap: 6px; color: rgba(255, 255, 255, 0.72); font-size: 12.5px; cursor: pointer; }
.ds3d-check input { accent-color: ${ACTION}; }
.ds3d-foot-buttons { display: flex; gap: 6px; }

.ds3d-runs { position: fixed; left: 50%; top: calc(12px + var(--ds3d-top, 0px)); transform: translateX(-50%); z-index: 2; width: min(440px, calc(100vw - 24px)); max-height: calc(100vh - 150px - var(--ds3d-top, 0px)); overflow-y: auto; scrollbar-width: none; display: flex; flex-direction: column; gap: 6px; pointer-events: none; }
.ds3d-run { position: relative; flex: none; overflow: hidden; contain: layout style; pointer-events: auto; padding: 8px 8px 9px 14px; border-radius: 18px; display: flex; flex-direction: column; gap: 3px; animation: ds3d-drop 0.26s ${EASE}; }
.ds3d-run-head { display: flex; align-items: center; gap: 9px; min-height: 32px; font-weight: 600; }
.ds3d-run-title { flex: 1; min-width: 0; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.ds3d-run-clock { flex: none; }
.ds3d-spin { width: 15px; height: 15px; border-radius: 50%; border: 2px solid rgba(255, 255, 255, 0.24); border-top-color: #fff; animation: ds3d-turn 0.8s linear infinite; flex: none; }
.ds3d-run-ok { width: 20px; height: 20px; border-radius: 50%; background: ${DONE}; color: #fff; display: inline-grid; place-items: center; flex: none; animation: ds3d-pop 0.3s ${SPRING}; }
.ds3d-run-ok svg { width: 14px; height: 14px; stroke-width: 2.6; }
.ds3d-run-bad { color: #ff7a8c; display: inline-grid; flex: none; }
.ds3d-run-line { color: rgba(255, 255, 255, 0.62); font-size: 12px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; padding: 0 6px 0 24px; }
.ds3d-run-reply { max-height: 190px; overflow-y: auto; padding: 0 8px 2px 29px; font-size: 13px; line-height: 1.42; color: rgba(255, 255, 255, 0.88); white-space: pre-wrap; user-select: text; -webkit-user-select: text; scrollbar-width: thin; scrollbar-color: rgba(255, 255, 255, 0.24) transparent; }
.ds3d-run-files { align-self: flex-start; margin: 1px 0 0 29px; padding: 0; border: 0; background: transparent; font-size: 11.5px; color: rgba(255, 255, 255, 0.5); text-align: left; overflow-wrap: anywhere; cursor: pointer; transition: color 0.12s; }
.ds3d-run-files:hover { color: rgba(255, 255, 255, 0.8); }
.ds3d-run-shared { padding-left: 29px; font-size: 12px; color: #ffd28a; }
.ds3d-run.is-folded { padding-top: 5px; padding-bottom: 5px; }
.ds3d-run.is-folded > .ds3d-run-head { cursor: pointer; }
.ds3d-run.is-folded > :not(.ds3d-run-head) { display: none; }
.ds3d-runs.is-many .ds3d-run.is-working .ds3d-run-line { display: none; }
.ds3d-runs.is-many .ds3d-run.is-working { padding-top: 5px; padding-bottom: 5px; }
.ds3d-run-model { flex: none; font-size: 11.5px; font-weight: 500; color: rgba(255, 255, 255, 0.55); }
.ds3d-run-going { position: absolute; left: 0; bottom: 0; width: 40%; height: 2px; background: linear-gradient(90deg, transparent, rgba(120, 170, 255, 0.95), transparent); animation: ds3d-going 1.5s ${EASE} infinite; }
.ds3d-model { padding: 0 6px 0 10px; font-size: 12.5px; font-weight: 500; color: rgba(255, 255, 255, 0.74); }
.ds3d-model:hover { color: #fff; }
.ds3d-model .ds3d-ic svg { width: 14px; height: 14px; rotate: -90deg; transition: rotate 0.16s ${EASE}; }
.ds3d-model.is-open .ds3d-ic svg { rotate: 90deg; }
.ds3d-menu { position: fixed; display: flex; flex-direction: column; width: 244px; padding: 5px; border-radius: 16px; animation: ds3d-rise 0.16s ${EASE}; }
.ds3d-menu-item { display: flex; flex-direction: column; align-items: flex-start; gap: 1px; padding: 7px 10px; border: 0; border-radius: 11px; background: transparent; text-align: left; cursor: pointer; transition: background 0.12s; }
.ds3d-menu-item:hover { background: rgba(255, 255, 255, 0.1); }
.ds3d-menu-item.is-on { background: rgba(77, 141, 255, 0.24); }
.ds3d-menu-name { font-weight: 600; }
.ds3d-menu-hint { font-size: 11.5px; color: rgba(255, 255, 255, 0.6); }

.ds3d-lightbox { max-width: 94vw; max-height: 90vh; border-radius: 14px; box-shadow: 0 18px 60px rgba(0, 0, 0, 0.5); animation: ds3d-sheet 0.22s ${EASE}; }

@keyframes ds3d-rise { from { opacity: 0; translate: 0 8px; } to { opacity: 1; translate: 0 0; } }
@keyframes ds3d-drop { from { opacity: 0; translate: 0 -10px; } to { opacity: 1; translate: 0 0; } }
@keyframes ds3d-slide { from { opacity: 0; translate: 14px 0; } to { opacity: 1; translate: 0 0; } }
@keyframes ds3d-sheet { from { opacity: 0; translate: 0 10px; scale: 0.985; } to { opacity: 1; translate: 0 0; scale: 1; } }
@keyframes ds3d-fade { from { opacity: 0; } to { opacity: 1; } }
@keyframes ds3d-leave { to { opacity: 0; } }
@keyframes ds3d-pop { from { scale: 0.3; } to { scale: 1; } }
@keyframes ds3d-ping { 0% { opacity: 0.7; scale: 0.8; } 100% { opacity: 0; scale: 1.5; } }
@keyframes ds3d-blink { 50% { opacity: 0.4; } }
.ds3d-arrived { display: flex; align-items: center; gap: 6px; }
.ds3d-arrived-arrow { display: none; width: 20px; height: 20px; margin-left: -6px; border-radius: 50%; background: ${DONE}; color: #fff; place-items: center; }
.ds3d-arrived-arrow svg { width: 15px; height: 15px; stroke-width: 3.2; }
.ds3d-arrived.is-away .ds3d-arrived-arrow { display: inline-grid; }
@keyframes ds3d-arrive { from { opacity: 0; translate: 0 10px; scale: 0.7; } to { opacity: 1; translate: 0 0; scale: 1; } }
@keyframes ds3d-ring { from { opacity: 0.85; scale: 1; } to { opacity: 0; scale: 1.7; } }
@keyframes ds3d-turn { to { rotate: 360deg; } }
@keyframes ds3d-going { from { translate: -100% 0; } to { translate: 250% 0; } }
@media (prefers-reduced-motion: reduce) { .ds3d-root *, .ds3d-root *::after { animation-duration: 0.001s !important; animation-iteration-count: 1 !important; transition: none !important; } }
@media (max-width: 720px) {
  .ds3d-btn .ds3d-label { display: none; }
  .ds3d-group { grid-template-columns: 1fr; }
  .ds3d-column { width: min(340px, calc(100vw - 24px)); }
}
`;
