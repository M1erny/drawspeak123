/**
 * The tool's look, from the iPad app's Theme: marks in one red with a white halo, one blue for
 * actions, and calm glass for everything else, so the ink is what stands out. It is dark glass here
 * because it floats over a bright, moving 3D world, not over a pale canvas.
 */
export const INK = "#BD3048";
export const HALO = "rgba(255,255,255,0.92)";
export const ACTION = "#1758BD";
export const OUTLINE = "#4d8dff";
export const LINE_WIDTH = 3;

export const CSS = `
.ds3d-root { position: fixed; inset: 0; z-index: 9000; pointer-events: none; font: 13px/1.4 -apple-system, BlinkMacSystemFont, "Segoe UI Variable Text", "Segoe UI", system-ui, sans-serif; color: #f2f3f5; -webkit-font-smoothing: antialiased; user-select: none; -webkit-user-select: none; }
.ds3d-root * { box-sizing: border-box; }
:where(.ds3d-root) :where(button, textarea, input) { font: inherit; color: inherit; margin: 0; letter-spacing: normal; text-transform: none; box-shadow: none; filter: none; min-height: 0; }
.ds3d-ink { position: absolute; inset: 0; width: 100%; height: 100%; pointer-events: none; }
.ds3d-freeze { position: fixed; pointer-events: none; filter: saturate(0.84) brightness(0.985); transition: opacity 0.16s ease-out; }
body.ds3d-armed canvas { cursor: crosshair !important; }

.ds3d-glass { background: rgba(24, 27, 31, 0.8); -webkit-backdrop-filter: blur(20px) saturate(155%); backdrop-filter: blur(20px) saturate(155%); border: 1px solid rgba(255, 255, 255, 0.13); box-shadow: 0 10px 34px rgba(8, 12, 24, 0.36), inset 0 1px 0 rgba(255, 255, 255, 0.07); pointer-events: auto; }
@media (prefers-reduced-transparency: reduce) { .ds3d-glass { background: #24272b; -webkit-backdrop-filter: none; backdrop-filter: none; } }

.ds3d-ic { display: inline-grid; place-items: center; flex: none; }
.ds3d-ic svg { display: block; }
.ds3d-btn { height: 40px; min-width: 40px; padding: 0 10px; display: inline-flex; align-items: center; justify-content: center; gap: 6px; border: 0; border-radius: 16px; background: transparent; font-weight: 600; white-space: nowrap; cursor: pointer; transition: background 0.12s, opacity 0.12s, transform 0.08s; }
.ds3d-btn:hover { background: rgba(255, 255, 255, 0.11); }
.ds3d-btn:active { transform: scale(0.97); }
.ds3d-btn:focus-visible { outline: 2px solid #95baff; outline-offset: 1px; }
.ds3d-btn[disabled] { opacity: 0.38; cursor: default; background: transparent; }
.ds3d-btn.is-on { background: ${INK}; color: #fff; }
.ds3d-btn.ds3d-primary { background: ${ACTION}; color: #fff; padding: 0 14px; }
.ds3d-btn.ds3d-primary:hover { background: #1f68d6; }
.ds3d-btn.ds3d-primary[disabled] { background: rgba(255, 255, 255, 0.1); }
.ds3d-btn.ds3d-small { height: 32px; min-width: 32px; border-radius: 12px; padding: 0 9px; font-size: 12.5px; }
.ds3d-btn.ds3d-danger:hover { background: rgba(189, 48, 72, 0.55); }
.ds3d-btn .count { font-variant-numeric: tabular-nums; }
.ds3d-root kbd { font: 600 10px/1 ui-monospace, "Cascadia Mono", Consolas, monospace; padding: 3px 5px; border-radius: 5px; background: rgba(255, 255, 255, 0.15); color: rgba(255, 255, 255, 0.88); }

.ds3d-palette { position: fixed; left: 50%; bottom: calc(14px + var(--ds3d-bottom, 0px)); transform: translateX(-50%); display: flex; align-items: center; gap: 2px; padding: 5px; border-radius: 22px; max-width: calc(100vw - 16px); }
.ds3d-sep { width: 1px; height: 22px; margin: 0 4px; background: rgba(255, 255, 255, 0.15); flex: none; }
.ds3d-hint { position: fixed; left: 50%; bottom: calc(72px + var(--ds3d-bottom, 0px)); transform: translateX(-50%); padding: 7px 13px; border-radius: 13px; font-weight: 500; white-space: nowrap; animation: ds3d-rise 0.18s ease-out; max-width: calc(100vw - 24px); overflow: hidden; text-overflow: ellipsis; pointer-events: none; }
.ds3d-hint em { font-style: normal; opacity: 0.66; font-weight: 400; }
.ds3d-toast { position: fixed; left: 50%; bottom: calc(72px + var(--ds3d-bottom, 0px)); transform: translateX(-50%); padding: 9px 14px; border-radius: 13px; font-weight: 500; animation: ds3d-rise 0.18s ease-out; max-width: min(560px, calc(100vw - 24px)); }
.ds3d-toast.warn { background: rgba(120, 28, 44, 0.92); }

.ds3d-pin { position: absolute; left: -15px; top: -15px; width: 30px; height: 30px; padding: 0; display: grid; place-items: center; border: 2px solid #fff; border-radius: 50%; background: ${INK}; color: #fff; font-weight: 700; font-size: 14px; font-variant-numeric: tabular-nums; box-shadow: 0 2px 9px rgba(8, 12, 24, 0.42); pointer-events: auto; cursor: pointer; will-change: transform; transition: opacity 0.15s, background 0.15s; animation: ds3d-pop 0.22s cubic-bezier(0.2, 1.5, 0.4, 1); }
.ds3d-pin:focus-visible { outline: 2px solid #95baff; outline-offset: 2px; }
.ds3d-pin.is-dim { opacity: 0.5; }
.ds3d-pin.is-sent { background: #47505c; }
.ds3d-pin.is-empty { background: #fff; color: ${INK}; border-color: ${INK}; }
.ds3d-pin.is-edge { left: -11px; top: -11px; width: 22px; height: 22px; font-size: 11px; opacity: 0.86; }
.ds3d-pin.is-rec::after { content: ""; position: absolute; inset: -7px; border-radius: 50%; border: 2px solid ${INK}; animation: ds3d-ping 1.15s ease-out infinite; }
.ds3d-chip-label { position: absolute; left: 0; top: 0; padding: 4px 9px; border-radius: 10px; font-weight: 600; white-space: nowrap; will-change: transform; }

.ds3d-bubble { position: absolute; left: 0; top: 0; z-index: 3; width: 330px; max-width: calc(100vw - 24px); padding: 11px; border-radius: 18px; display: flex; flex-direction: column; gap: 9px; will-change: transform; animation: ds3d-fade 0.16s ease-out; }
.ds3d-bubble-head { display: flex; align-items: center; gap: 8px; min-height: 22px; font-weight: 600; }
.ds3d-rec { width: 10px; height: 10px; border-radius: 50%; background: #ff4d67; animation: ds3d-blink 1.15s ease-in-out infinite; flex: none; }
.ds3d-time { font-variant-numeric: tabular-nums; }
.ds3d-level { display: flex; align-items: center; gap: 2px; height: 16px; flex: 1; }
.ds3d-level i { width: 3px; border-radius: 2px; background: rgba(255, 255, 255, 0.78); height: 3px; transition: height 0.08s linear; }
.ds3d-lang { height: 22px; padding: 0 7px; border: 1px solid rgba(255, 255, 255, 0.2); border-radius: 8px; background: transparent; font-size: 11px; font-weight: 700; cursor: pointer; }
.ds3d-lang:hover { background: rgba(255, 255, 255, 0.1); }
.ds3d-text { width: 100%; min-height: 52px; max-height: 148px; resize: none; padding: 8px 10px; border: 1px solid rgba(255, 255, 255, 0.13); border-radius: 12px; background: rgba(0, 0, 0, 0.24); font-size: 14px; line-height: 1.38; outline: none; user-select: text; -webkit-user-select: text; }
.ds3d-text:focus { border-color: #95baff; }
.ds3d-text::placeholder { color: rgba(255, 255, 255, 0.46); }
.ds3d-chain { display: flex; flex-wrap: wrap; align-items: center; gap: 3px; }
.ds3d-link { max-width: 170px; height: 25px; padding: 0 8px; border: 0; border-radius: 8px; background: transparent; color: rgba(255, 255, 255, 0.72); font-size: 12px; font-weight: 500; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; cursor: pointer; }
.ds3d-link:hover { background: rgba(255, 255, 255, 0.11); color: #fff; }
.ds3d-link.is-current { background: rgba(77, 141, 255, 0.28); color: #fff; font-weight: 650; }
.ds3d-link-sep { color: rgba(255, 255, 255, 0.36); font-size: 11px; }
.ds3d-behind { display: flex; flex-wrap: wrap; align-items: center; gap: 3px; font-size: 11.5px; color: rgba(255, 255, 255, 0.55); }
.ds3d-actions { display: flex; align-items: center; justify-content: space-between; gap: 6px; }
.ds3d-note-line { color: rgba(255, 255, 255, 0.72); font-size: 12.5px; }

.ds3d-column { position: fixed; z-index: 2; top: calc(14px + var(--ds3d-top, 0px)); right: calc(14px + var(--ds3d-right, 0px)); max-height: calc(100vh - 28px - var(--ds3d-top, 0px) - var(--ds3d-bottom, 0px)); width: 340px; max-width: calc(100vw - 24px); display: flex; flex-direction: column; border-radius: 20px; overflow: hidden; animation: ds3d-fade 0.16s ease-out; }
.ds3d-column-head { display: flex; align-items: center; justify-content: space-between; padding: 11px 8px 7px 15px; font-size: 15px; font-weight: 650; }
.ds3d-column-list { flex: 1; overflow-y: auto; padding: 2px 8px 10px; display: flex; flex-direction: column; gap: 7px; scrollbar-width: thin; scrollbar-color: rgba(255, 255, 255, 0.24) transparent; }
.ds3d-empty { margin: 26px 18px; text-align: center; color: rgba(255, 255, 255, 0.6); line-height: 1.5; }
.ds3d-card { display: grid; grid-template-columns: 26px 1fr; gap: 8px; padding: 9px; border-radius: 13px; background: rgba(255, 255, 255, 0.06); }
.ds3d-card.is-active { background: rgba(77, 141, 255, 0.18); }
.ds3d-card-pin { width: 24px; height: 24px; display: grid; place-items: center; border-radius: 50%; background: ${INK}; color: #fff; font-size: 12px; font-weight: 700; }
.ds3d-card-pin.is-sent { background: #47505c; }
.ds3d-card-body { min-width: 0; display: flex; flex-direction: column; gap: 6px; }
.ds3d-card img { width: 100%; aspect-ratio: 16 / 9; object-fit: cover; border-radius: 9px; display: block; background: rgba(0, 0, 0, 0.3); cursor: pointer; }
.ds3d-card-text { width: 100%; padding: 6px 8px; border: 1px solid transparent; border-radius: 9px; background: transparent; resize: none; font-size: 13.5px; line-height: 1.36; outline: none; overflow: hidden; user-select: text; -webkit-user-select: text; }
.ds3d-card-text:hover { background: rgba(0, 0, 0, 0.18); }
.ds3d-card-text:focus { background: rgba(0, 0, 0, 0.26); border-color: #95baff; }
.ds3d-card-text::placeholder { color: rgba(255, 255, 255, 0.46); }
.ds3d-card-meta { display: flex; align-items: center; justify-content: space-between; gap: 4px; min-height: 28px; }
.ds3d-card-target { min-width: 0; font-size: 11.5px; color: rgba(255, 255, 255, 0.62); overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.ds3d-card-buttons { display: flex; gap: 1px; flex: none; }
.ds3d-card-buttons .ds3d-btn { height: 28px; min-width: 28px; padding: 0; border-radius: 9px; }
.ds3d-card-buttons svg { width: 16px; height: 16px; }

.ds3d-scrim { position: fixed; inset: 0; z-index: 5; background: rgba(8, 12, 24, 0.42); pointer-events: auto; animation: ds3d-fade 0.14s ease-out; display: grid; place-items: center; padding: 18px; }
.ds3d-sheet { width: min(860px, 100%); max-height: min(92vh, 100%); display: flex; flex-direction: column; border-radius: 22px; overflow: hidden; background: rgba(28, 31, 36, 0.94); animation: ds3d-rise 0.18s ease-out; }
.ds3d-sheet-head { display: flex; align-items: center; justify-content: space-between; gap: 12px; padding: 14px 12px 10px 20px; }
.ds3d-sheet-head h2 { margin: 0; font-size: 18px; font-weight: 680; }
.ds3d-to { color: rgba(255, 255, 255, 0.68); font-size: 12.5px; margin-top: 1px; }
.ds3d-dot { display: inline-block; width: 7px; height: 7px; border-radius: 50%; margin-right: 6px; background: #3ecf8e; vertical-align: 1px; }
.ds3d-dot.off { background: #ff7a8c; }
.ds3d-sheet-body { flex: 1; overflow-y: auto; padding: 0 20px 12px; display: flex; flex-direction: column; gap: 14px; scrollbar-width: thin; scrollbar-color: rgba(255, 255, 255, 0.24) transparent; }
.ds3d-group { display: grid; grid-template-columns: minmax(0, 300px) minmax(0, 1fr); gap: 14px; padding-top: 12px; border-top: 1px solid rgba(255, 255, 255, 0.1); }
.ds3d-group:first-child { border-top: 0; padding-top: 0; }
.ds3d-group img { width: 100%; aspect-ratio: 16 / 10; object-fit: cover; border-radius: 10px; display: block; background: rgba(0, 0, 0, 0.3); }
.ds3d-group h3 { margin: 0 0 6px; font-size: 13px; font-weight: 650; color: rgba(255, 255, 255, 0.76); }
.ds3d-item { display: grid; grid-template-columns: 22px 24px 1fr; gap: 7px; padding: 7px 0; align-items: start; cursor: pointer; }
.ds3d-item input { width: 17px; height: 17px; margin: 3px 0 0; accent-color: ${ACTION}; cursor: pointer; }
.ds3d-item-text { font-size: 13.5px; user-select: text; -webkit-user-select: text; }
.ds3d-item-target { margin-top: 1px; font-size: 11.5px; color: rgba(255, 255, 255, 0.58); }
.ds3d-pending { font-size: 12px; color: rgba(255, 255, 255, 0.55); padding-top: 8px; border-top: 1px solid rgba(255, 255, 255, 0.1); }
.ds3d-sheet-foot { padding: 11px 14px 14px 20px; border-top: 1px solid rgba(255, 255, 255, 0.1); display: flex; flex-direction: column; gap: 9px; background: rgba(255, 255, 255, 0.025); }
.ds3d-direct { display: flex; flex-wrap: wrap; align-items: center; gap: 8px; }
.ds3d-seg { display: inline-flex; padding: 2px; border-radius: 12px; background: rgba(255, 255, 255, 0.08); flex: none; }
.ds3d-seg button { height: 30px; padding: 0 11px; border: 0; border-radius: 10px; background: transparent; font-size: 12.5px; font-weight: 600; cursor: pointer; }
.ds3d-seg button.is-chosen { background: rgba(255, 255, 255, 0.2); }
.ds3d-extra { flex: 1 1 220px; height: 34px; padding: 0 10px; border: 1px solid rgba(255, 255, 255, 0.13); border-radius: 10px; background: rgba(0, 0, 0, 0.22); outline: none; user-select: text; -webkit-user-select: text; }
.ds3d-extra:focus { border-color: #95baff; }
.ds3d-extra::placeholder { color: rgba(255, 255, 255, 0.46); }
.ds3d-foot-row { display: flex; align-items: center; justify-content: space-between; gap: 8px; }
.ds3d-check { display: inline-flex; align-items: center; gap: 6px; color: rgba(255, 255, 255, 0.72); font-size: 12.5px; cursor: pointer; }
.ds3d-check input { accent-color: ${ACTION}; }
.ds3d-foot-buttons { display: flex; gap: 6px; }

.ds3d-run { position: fixed; left: 50%; top: calc(12px + var(--ds3d-top, 0px)); transform: translateX(-50%); z-index: 2; width: min(470px, calc(100vw - 24px)); padding: 10px 10px 10px 14px; border-radius: 17px; display: flex; flex-direction: column; gap: 6px; animation: ds3d-rise 0.18s ease-out; }
.ds3d-run-head { display: flex; align-items: center; gap: 9px; min-height: 32px; font-weight: 650; }
.ds3d-run-title { flex: 1; min-width: 0; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.ds3d-spin { width: 15px; height: 15px; border-radius: 50%; border: 2px solid rgba(255, 255, 255, 0.28); border-top-color: #fff; animation: ds3d-turn 0.8s linear infinite; flex: none; }
.ds3d-run-ok { color: #3ecf8e; display: inline-grid; }
.ds3d-run-bad { color: #ff7a8c; display: inline-grid; }
.ds3d-run-line { color: rgba(255, 255, 255, 0.68); font-size: 12px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; padding-right: 4px; }
.ds3d-run-reply { max-height: 190px; overflow-y: auto; padding-right: 6px; font-size: 13px; white-space: pre-wrap; user-select: text; -webkit-user-select: text; scrollbar-width: thin; scrollbar-color: rgba(255, 255, 255, 0.24) transparent; }
.ds3d-run-files { font-size: 11.5px; color: rgba(255, 255, 255, 0.62); overflow-wrap: anywhere; }

.ds3d-lightbox { max-width: 94vw; max-height: 90vh; border-radius: 12px; box-shadow: 0 18px 60px rgba(0, 0, 0, 0.5); }

@keyframes ds3d-rise { from { opacity: 0; translate: 0 7px; } to { opacity: 1; translate: 0 0; } }
@keyframes ds3d-fade { from { opacity: 0; } to { opacity: 1; } }
@keyframes ds3d-pop { from { scale: 0.3; } to { scale: 1; } }
@keyframes ds3d-ping { 0% { opacity: 0.7; scale: 0.8; } 100% { opacity: 0; scale: 1.5; } }
@keyframes ds3d-blink { 50% { opacity: 0.35; } }
@keyframes ds3d-turn { to { rotate: 360deg; } }
@media (prefers-reduced-motion: reduce) { .ds3d-root *, .ds3d-root *::after { animation-duration: 0.001s !important; animation-iteration-count: 1 !important; transition: none !important; } }
@media (max-width: 720px) {
  .ds3d-btn .ds3d-label { display: none; }
  .ds3d-group { grid-template-columns: 1fr; }
  .ds3d-column { width: min(340px, calc(100vw - 24px)); }
}
`;
