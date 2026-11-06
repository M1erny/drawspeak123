import * as THREE from "three";
import { boundsOf, distance, simplified } from "./core/geometry.ts";
import { isThisComputer } from "./core/local.ts";
import { displayNumbers, readiness } from "./core/package.ts";
import { PressureDepthTracker, current } from "./core/selection.ts";
import { isClosedLoop, isCurling, isTap, shapeFor } from "./core/stroke.ts";
import type { InputKind, NRect, Note, NoteTarget, PathEnd, Pose, ProjectInfo, RecordingState, Shape, Snapshot, Vec2, Vec3, WorldMark, WorldPlace } from "./core/types.ts";
import { HubClient, type HubProject, type LookRequest, type RunState } from "./hubClient.ts";
import { Store } from "./store.ts";
import { Host } from "./three/host.ts";
import { Picker, boxOnScreen, inkPlane, isSurfaceLike, lineInWorld, lineLength, liftOnto, poseOf, ringOn, toScreen, type InkPlane, type LoopPick, type RayHit, type SceneAdapter } from "./three/world.ts";
import { blobToDataUrl, pinSpot, renderComposite, scaledCopy, toBlob } from "./ui/composite.ts";
import { domTargetFor } from "./ui/domTarget.ts";
import { Overlay } from "./ui/overlay.ts";
import { Bubble, Column, Palette, RunCards, Sheet, Toast, lightbox } from "./ui/panels.ts";
import { CSS } from "./ui/styles.ts";
import { FAILURE_TEXT, Voice } from "./voice/speech.ts";

export interface AttachOptions {
  renderer: THREE.WebGLRenderer;
  /** Taken from the first frame when not given. */
  scene?: THREE.Scene;
  /** The camera of the view. Taken from the frames when not given (the latest perspective camera). */
  camera?: THREE.PerspectiveCamera;
  project: ProjectInfo;
  /** Where the hub listens. */
  hub?: string;
  adapter?: SceneAdapter;
  /** Room to leave for the app's own interface, in pixels. */
  insets?: { top?: number; right?: number; bottom?: number };
  /** While true the tool stays out of sight (a title screen, say). */
  hidden?: () => boolean;
}

interface Stroke {
  pointerId: number;
  kind: InputKind;
  points: Vec2[];
  frame: HTMLCanvasElement;
  camera: THREE.PerspectiveCamera;
  rect: DOMRect;
  startedAt: number;
  pressure: number;
  /** A pen resting in one place: choosing a thing, harder for its parents. */
  press?: { pick: LoopPick; tracker: PressureDepthTracker; at: Vec2 };
  movedAway: boolean;
}

/** What a mark is about, before it knows how it was made. */
type MarkTarget = Omit<NoteTarget, "method" | "pressure">;

/** While an agent is at work, what it saves waits for it to pause this long, or to finish, or to look. */
const AGENT_PAUSE_MS = 6000;
/** And no longer than this in all. */
const AGENT_LONGEST_MS = 45_000;
const LOOK_WIDTH = 1280;
/** A mark's goodbye, when its agent has finished. */
const LEAVE_MS = 1500;
/** The last frame, shown through a reload: see vite-plugin.ts. */
const COVER = "ds3d.cover";
const COVER_WIDTH = 1600;
const SPOT_PIN_LIFT = 24;
const FRAME_MAX_WIDTH = 1920;
const COMPOSITE_WIDTH = 1600;
const PEN_REST_MS = 200;

const newId = () => (crypto.randomUUID ? crypto.randomUUID() : `${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 10)}`);

function loadPreference<T>(name: string, fallback: T): T {
  try {
    const raw = localStorage.getItem(`ds3d.${name}`);
    return raw === null ? fallback : (JSON.parse(raw) as T);
  } catch {
    return fallback;
  }
}
function savePreference(name: string, value: unknown) {
  try {
    localStorage.setItem(`ds3d.${name}`, JSON.stringify(value));
  } catch {
    // private mode: preferences just do not stick
  }
}

function defaultLanguage(): string {
  const saved = loadPreference<string | null>("lang", null);
  if (saved) return saved;
  const languages = navigator.languages?.length ? navigator.languages : [navigator.language || "en-US"];
  return languages.some((language) => language.toLowerCase().startsWith("pl")) ? "pl-PL" : "en-US";
}

/**
 * Drawspeak for a 3D world. Walk around as usual; hold C (or switch on Draw, or just use a pen) and
 * circle something; the world stops for the stroke; the mark stays on the thing; say what should
 * change; do it again elsewhere; Send hands it all to a coding agent.
 */
export class Drawspeak3D {
  readonly host: Host;
  readonly picker: Picker;
  readonly adapter: SceneAdapter;
  readonly project: ProjectInfo;
  readonly hub: HubClient;
  readonly store: Store;
  readonly voice = new Voice();

  notes: Note[] = [];
  snapshots: Snapshot[] = [];
  /** Tool state. */
  armed = false;
  autoVoice = loadPreference("autoVoice", true);
  lang = defaultLanguage();
  showSent = false;
  hubProject?: HubProject;

  readonly root: HTMLElement;
  private readonly overlay: Overlay;
  private readonly pinLayer: HTMLElement;
  private readonly palette: Palette;
  private readonly bubble: Bubble;
  private readonly column: Column;
  private readonly sheet: Sheet;
  private readonly runCards: RunCards;
  private readonly toastBox: Toast;
  private readonly pins = new Map<string, HTMLButtonElement>();
  private readonly occludedNotes = new Set<string>();
  private readonly hiddenWhen?: () => boolean;
  private stroke?: Stroke;
  private keyDownAt = 0;
  private wasArmed = false;
  private usedWhileHeld = false;
  private keyHeld = false;
  /** The note the bubble is about. */
  private activeId?: string;
  private recordingId?: string;
  private recordingBase = "";
  private recordingStart = 0;
  private liveText = "";
  private undoStack: Array<{ add?: string; removed?: Note }> = [];
  private occlusionCursor = 0;
  private occlusionClock = 0;
  private hidden = false;
  private lastDepth = 5;
  private frameCount = 0;
  private readonly cleanups: Array<() => void> = [];
  /** Views taken since this page loaded: only these can be shared by a new mark. */
  private readonly freshSnapshots = new Set<string>();
  private swallowClickUntil = 0;
  /** What a recording had heard when the page went away (an agent's edit reloads it). */
  private heardBeforeReload?: { id: string; text: string };
  /** What agents have asked to see. */
  private looksDue: LookRequest[] = [];
  private framesInSight = 0;
  /** When code first changed and the page has not reloaded yet. */
  private reloadSince = 0;
  private reloadTimer?: ReturnType<typeof setTimeout>;
  /** Runs seen at work on this page, and the comments they were sent for. */
  private readonly runsHere = new Map<string, string[]>();
  /** A mistake in the code as it was last saved, as Vite reported it. */
  private codeError?: string;
  private lastFrameAt = 0;
  private frameTime = 16;
  private plain = false;
  /** Marks whose agent has just finished, and since when. */
  private readonly leaving = new Map<string, number>();
  /** Enter twice, faster than the last words arrive. */
  private sendWhenHeard?: string;
  private covered = true;
  private reloading = false;
  private readonly pageErrors: string[] = [];

  constructor(options: AttachOptions) {
    if (!isThisComputer(location.hostname)) throw new Error("Drawspeak 3D only runs on pages served from this computer.");
    this.adapter = options.adapter ?? {};
    this.project = options.project;
    this.hiddenWhen = options.hidden;
    this.hub = new HubClient(options.hub ?? "http://127.0.0.1:8799", options.project.id);
    this.store = new Store(options.project.id);
    this.host = new Host(options.renderer, { scene: options.scene, camera: options.camera });
    this.picker = new Picker(() => this.host.scene, this.adapter);

    if (!document.getElementById("ds3d-style")) {
      const style = document.createElement("style");
      style.id = "ds3d-style";
      style.textContent = CSS;
      document.head.append(style);
    }
    this.root = document.createElement("div");
    this.root.className = "ds3d-root";
    this.root.style.setProperty("--ds3d-top", `${options.insets?.top ?? 0}px`);
    this.root.style.setProperty("--ds3d-right", `${options.insets?.right ?? 0}px`);
    this.root.style.setProperty("--ds3d-bottom", `${options.insets?.bottom ?? 0}px`);
    document.body.append(this.root);
    this.overlay = new Overlay(this.root);
    this.pinLayer = document.createElement("div");
    this.root.append(this.pinLayer);
    this.palette = new Palette(this);
    this.bubble = new Bubble(this);
    this.column = new Column(this);
    this.sheet = new Sheet(this);
    this.runCards = new RunCards(this);
    this.toastBox = new Toast(this.root);

    this.listen(window, "pointerdown", (e) => this.onPointerDown(e as PointerEvent));
    this.listen(window, "pointermove", (e) => this.onPointerMove(e as PointerEvent));
    this.listen(window, "pointerup", (e) => this.onPointerUp(e as PointerEvent));
    this.listen(window, "pointercancel", (e) => this.onPointerCancel(e as PointerEvent));
    this.listen(window, "keydown", (e) => this.onKeyDown(e as KeyboardEvent));
    this.listen(window, "keyup", (e) => this.onKeyUp(e as KeyboardEvent));
    this.listen(window, "click", (e) => this.onClick(e));
    this.listen(window, "blur", () => this.onBlur());
    this.listen(window, "pagehide", () => this.saveForReload());
    this.listen(window, "error", (e) => this.pageErrors.push(String((e as ErrorEvent).message)));
    this.listen(window, "unhandledrejection", (e) => this.pageErrors.push(String((e as PromiseRejectionEvent).reason)));
    this.host.onFrame = () => this.frame();
    this.watchForCodeChanges();

    this.applyViewFromLink();
    void this.loadStored();
    void this.refreshHub();
    this.restoreAfterReload();
    this.palette.render();
  }

  private listen(target: EventTarget, type: string, handler: EventListener) {
    target.addEventListener(type, handler, { capture: true });
    this.cleanups.push(() => target.removeEventListener(type, handler, { capture: true }));
  }

  destroy() {
    this.voice.cancel();
    this.host.destroy();
    for (const cleanup of this.cleanups) cleanup();
    this.root.remove();
    document.body.classList.remove("ds3d-armed");
  }

  // ---------------------------------------------------------------------- the store

  private async loadStored() {
    try {
      const { notes, snapshots } = await this.store.load();
      for (const note of notes) note.shape = currentShape(note.shape);
      const newer = this.notes;
      const newerSnapshots = this.snapshots;
      this.notes = [...notes.filter((n) => !newer.some((m) => m.id === n.id)), ...newer].sort((a, b) => a.ordinal - b.ordinal);
      this.snapshots = [...snapshots.filter((s) => !newerSnapshots.some((m) => m.id === s.id)).sort((a, b) => a.takenAt.localeCompare(b.takenAt)), ...newerSnapshots];
      // Pictures with no marks left are not needed any more.
      for (const snapshot of snapshots) {
        if (!this.notes.some((n) => n.snapshotId === snapshot.id)) {
          this.snapshots = this.snapshots.filter((s) => s.id !== snapshot.id);
          void this.store.deleteSnapshot(snapshot.id);
        }
      }
      const heard = this.heardBeforeReload;
      this.heardBeforeReload = undefined;
      const interrupted = heard && this.noteById(heard.id);
      if (interrupted) this.setText(interrupted, heard.text, "voice");
      this.changed();
    } catch (error) {
      console.warn("[drawspeak3d] could not read saved notes", error);
    }
  }

  private listening = false;

  async refreshHub() {
    const found = await this.hub.project();
    if (found !== "busy") this.hubProject = found;
    // The hub is looked for when it matters: no stream of failed requests while it is not running.
    if (this.hubProject && !this.listening) {
      this.listening = true;
      this.cleanups.push(this.hub.listen({ open: () => void this.refreshHub(), runs: (runs) => this.onRuns(runs), look: (request) => this.onLook(request) }));
    }
    this.palette.render();
    return this.hubProject;
  }

  private onRuns(runs: RunState[]) {
    const before = this.runCards.working;
    this.runCards.update(runs);
    for (const run of runs) {
      if (run.status === "running") this.runsHere.set(run.id, run.noteIds ?? []);
      else if (this.runsHere.delete(run.id)) {
        for (const id of run.noteIds ?? []) {
          // Done: its mark says goodbye. Not done: its mark is still there to send again.
          if (run.status === "done") this.leaving.set(id, performance.now());
          else this.markUnsent(id);
        }
      }
    }
    // The hub came back without it: it restarted, and its agents went with it.
    let lost = false;
    for (const [id, noteIds] of this.runsHere) {
      if (runs.some((run) => run.id === id)) continue;
      this.runsHere.delete(id);
      lost = true;
      for (const noteId of noteIds) this.markUnsent(noteId);
    }
    if (lost) this.toast("The hub restarted and its agents stopped. Your marks are still here, ready to send again.", true);
    // The last agent is done: what it saved can show now.
    if (before > 0 && this.runCards.working === 0 && this.reloadSince > 0) this.reloadWhenFree();
  }

  private markUnsent(id: string) {
    const note = this.noteById(id);
    if (!note) return;
    note.lastSentRevision = undefined;
    this.saveNote(note);
    this.changed();
  }

  /** The model the agent will run on: the reviewer's choice, if it can still be had. */
  get model(): string | undefined {
    const models = this.hubProject?.models ?? [];
    if (models.length === 0) return undefined;
    try {
      const chosen = localStorage.getItem(`ds3d.model.${this.project.id}`);
      if (chosen && models.some((model) => model.id === chosen)) return chosen;
    } catch {
      // storage off: the default
    }
    return this.hubProject?.model;
  }

  setModel(id: string) {
    try {
      localStorage.setItem(`ds3d.model.${this.project.id}`, id);
    } catch {
      // storage off: nothing to keep it in
    }
    this.palette.render();
  }

  /** Can this comment go to an agent right now, from where you stand? */
  canSend(note: Note): boolean {
    const hub = this.hubProject;
    return readiness(note) === "ready" && hub !== undefined && hub.agent.available && hub.agent.problem === undefined && !this.sheet.sending;
  }

  /** Said and done: the open comment goes to the agent, and you keep walking. */
  sendActive(): boolean {
    const note = this.active;
    if (!note || !this.canSend(note)) return false;
    this.activate(undefined);
    // Its pin says so at once; making the pictures takes a moment.
    this.runCards.workingNotes.add(note.id);
    void this.sheet.sendOne(note).then((sent) => {
      if (!sent) this.runCards.workingNotes.delete(note.id);
    });
    return true;
  }

  /**
   * Enter with no comment open: what is waiting goes. One comment goes as it is, several open the window
   * to look them over. Not while the game itself has a use for the key.
   */
  private sendWaiting(): boolean {
    const focus = document.activeElement;
    if (this.active || this.readyCount === 0 || this.adapter.busy?.() || focus instanceof HTMLButtonElement || focus instanceof HTMLAnchorElement) return false;
    const waiting = this.notes.filter((note) => readiness(note) === "ready");
    if (waiting.length > 1) {
      this.openFeedback();
      return true;
    }
    this.activate(waiting[0].id);
    if (this.sendActive()) return true;
    this.activate(undefined);
    return false;
  }

  /** The view a finished agent's first comment was made on. Any move of your own takes you back. */
  seeRun(run: RunState) {
    for (const id of run.noteIds ?? []) {
      const note = this.noteById(id);
      const snapshot = note && this.snapshotOf(note);
      if (snapshot) {
        this.host.setView(snapshot.pose);
        return;
      }
    }
  }

  /** An agent wants to see a view. If what it saved is still waiting, that comes first. */
  private onLook(request: LookRequest) {
    this.looksDue.push(request);
    if (this.reloadSince > 0) this.reloadWhenFree();
    // A tab in the background draws no frames of its own.
    else if (document.hidden) this.answerLooks();
  }

  private answerLooks() {
    for (const request of this.looksDue.splice(0)) void this.answerLook(request);
  }

  private async answerLook({ id, view }: LookRequest) {
    const pose = view ? parsePose(view) : undefined;
    const frame = pose ? this.host.captureFrom(pose) : this.host.captureFrame();
    const problems = [...this.pageErrors.slice(-8), ...(this.adapter.problems?.() ?? []), ...(this.codeError ? [this.codeError] : [])];
    // No answer: it finds another way to look (hub/look.mjs).
    if (!frame) return;
    const blob = await new Promise<Blob | null>((resolve) => scaledCopy(frame, LOOK_WIDTH).toBlob(resolve, "image/png"));
    if (!blob) return;
    await this.hub.answerLook(id, { image: await blobToDataUrl(blob), errors: problems }).catch(() => undefined);
  }

  /** With Vite and vite-plugin.ts: code changes come here instead of reloading the page at once. */
  private watchForCodeChanges() {
    const hot = import.meta.hot;
    if (!hot) return;
    const alive = () => hot.send("ds3d:alive");
    alive();
    const beat = setInterval(alive, 4000);
    this.cleanups.push(() => clearInterval(beat));
    hot.on("ds3d:change", () => this.codeChanged());
    // A mistake in a save is said here, not over the whole game (styles.ts hides Vite's overlay while the tool is up).
    hot.on("vite:error", (payload: { err?: { message?: string; id?: string } }) => {
      this.codeError = `${payload.err?.id ?? "The last save"}: ${payload.err?.message ?? "does not compile"}`.slice(0, 400);
      if (this.agentsWorking === 0) this.toast(`The last save has a mistake: ${payload.err?.message?.split("\n")[0] ?? ""}`.slice(0, 200), true);
    });
    hot.on("vite:afterUpdate", () => (this.codeError = undefined));
  }

  private codeChanged() {
    this.reloadSince ||= Date.now();
    clearTimeout(this.reloadTimer);
    const waited = Date.now() - this.reloadSince;
    const wait = this.agentsWorking === 0 ? 200 : waited > AGENT_LONGEST_MS ? 0 : AGENT_PAUSE_MS;
    this.reloadTimer = setTimeout(() => this.reloadWhenFree(), wait);
  }

  /** Never under a stroke, words being spoken, or a preview being read. */
  private reloadWhenFree() {
    clearTimeout(this.reloadTimer);
    if (this.stroke || this.recordingNote || this.sheet.open || this.sheet.sending || this.typing() || this.root.querySelector(".ds3d-picture") || this.adapter.busy?.()) {
      this.reloadTimer = setTimeout(() => this.reloadWhenFree(), 400);
      return;
    }
    if (this.reloading) return;
    this.reloading = true;
    // The world stops and the interface melts away behind the last frame; the new page takes it from there.
    const cover = this.saveCover();
    if (cover) {
      const still = document.createElement("img");
      still.src = cover.image;
      still.alt = "";
      const [left, top, width, height] = cover.rect;
      still.style.cssText = `position:fixed;z-index:2147483000;pointer-events:none;object-fit:cover;opacity:0;transition:opacity .16s ease;left:${left}px;top:${top}px;width:${width}px;height:${height}px`;
      document.documentElement.append(still);
      requestAnimationFrame(() => requestAnimationFrame(() => (still.style.opacity = "1")));
    }
    setTimeout(() => location.reload(), cover ? 190 : 0);
  }

  /** Something about the notes changed: panels follow. */
  changed() {
    this.palette.render();
    this.column.render();
    // An open preview stays as it is: what is shown is what gets sent.
  }

  get readyCount(): number {
    return this.notes.filter((n) => readiness(n) === "ready").length;
  }

  get visibleNotes(): Note[] {
    return this.notes.filter((n) => this.showSent || readiness(n) !== "sent");
  }

  /** What stands in the world: the comments still open, and those an agent is working on right now. */
  private get worldNotes(): Note[] {
    const working = this.runCards.workingNotes;
    if (working.size === 0 && this.leaving.size === 0) return this.visibleNotes;
    return this.notes.filter((n) => this.showSent || readiness(n) !== "sent" || working.has(n.id) || this.leaving.has(n.id));
  }

  get numbers(): Map<string, number> {
    return displayNumbers(this.notes, this.showSent);
  }

  /** Agents at work right now. */
  get agentsWorking(): number {
    return this.runCards.working;
  }

  get canUndo(): boolean {
    return this.undoStack.length > 0;
  }

  private saveNote(note: Note) {
    note.updatedAt = new Date().toISOString();
    void this.store.saveNote(note).catch((error) => console.warn("[drawspeak3d] could not save a note", error));
  }

  noteById(id: string): Note | undefined {
    return this.notes.find((n) => n.id === id);
  }

  snapshotOf(note: Note): Snapshot | undefined {
    return this.snapshots.find((s) => s.id === note.snapshotId);
  }

  // ---------------------------------------------------------------------- tools

  setArmed(on: boolean) {
    if (on === this.armed) return;
    this.armed = on;
    document.body.classList.toggle("ds3d-armed", on);
    if (on && document.pointerLockElement) document.exitPointerLock();
    this.palette.render();
  }

  toggleArmed() {
    this.setArmed(!this.armed);
  }

  setAutoVoice(on: boolean) {
    this.autoVoice = on;
    savePreference("autoVoice", on);
    this.palette.render();
  }

  setLanguage(lang: string) {
    this.lang = lang;
    savePreference("lang", lang);
    this.bubble.render();
    // A recording carries on in the new language, keeping what was said.
    const note = this.recordingId ? this.noteById(this.recordingId) : undefined;
    if (note) {
      this.recordingBase = this.mergedText();
      this.liveText = "";
      this.startEngine(note);
    }
  }

  toast(text: string, warn = false) {
    this.toastBox.show(text, warn);
  }

  // ---------------------------------------------------------------------- pointer input

  private isOwnUi(target: EventTarget | null): boolean {
    return target instanceof Element && target.closest(".ds3d-root") !== null;
  }

  private overCanvas(e: PointerEvent): boolean {
    const rect = this.host.rect();
    return e.clientX >= rect.left && e.clientX <= rect.right && e.clientY >= rect.top && e.clientY <= rect.bottom;
  }

  /** The click at the end of a stroke is the stroke's, not the button's it ended on. */
  private onClick(e: Event) {
    if (performance.now() < this.swallowClickUntil && !this.isOwnUi(e.target)) {
      e.stopImmediatePropagation();
      e.preventDefault();
    }
    this.swallowClickUntil = 0;
  }

  private onPointerDown(e: PointerEvent) {
    if (this.hidden || this.isOwnUi(e.target) || this.sheet.open) return;
    if (this.stroke) {
      // A second finger or button during a stroke goes nowhere.
      e.stopImmediatePropagation();
      return;
    }
    const pen = e.pointerType === "pen";
    const onGameCanvas = e.target === this.host.renderer.domElement;
    // A pen on the world always draws (fingers still walk); a pen on the game's buttons presses them.
    // Mouse and fingers draw when Draw is on, anywhere: a mark can be about the game's own interface.
    const draws = pen ? (this.armed || onGameCanvas) && e.button === 0 : this.armed && e.button === 0;
    if (!draws || !this.overCanvas(e) || !this.host.ready) {
      if (this.host.lookingFromView) this.host.setView(null);
      return;
    }
    const frame = this.host.captureFrame();
    if (!frame) return;
    e.stopImmediatePropagation();
    e.preventDefault();
    this.usedWhileHeld = true;
    const camera = new THREE.PerspectiveCamera().copy(this.host.shown, false);
    this.stroke = {
      pointerId: e.pointerId,
      kind: pen ? "pen" : e.pointerType === "touch" ? "touch" : "mouse",
      points: [[e.clientX, e.clientY]],
      frame,
      camera,
      rect: this.host.rect(),
      startedAt: e.timeStamp,
      pressure: e.pressure,
      movedAway: false,
    };
    this.overlay.showFreeze(frame, this.host.renderer.domElement);
    this.adapter.freeze?.(true);
    this.frame();
  }

  private onPointerMove(e: PointerEvent) {
    const stroke = this.stroke;
    if (!stroke || e.pointerId !== stroke.pointerId) return;
    e.stopImmediatePropagation();
    e.preventDefault();
    const events = e.getCoalescedEvents?.() ?? [];
    for (const event of events.length > 0 ? events : [e]) {
      const last = stroke.points[stroke.points.length - 1];
      if (distance(last, [event.clientX, event.clientY]) >= 1) stroke.points.push([event.clientX, event.clientY]);
    }
    stroke.pressure = e.pressure;
    if (!isTap(stroke.points)) {
      stroke.movedAway = true;
      stroke.press = undefined;
    } else if (stroke.kind === "pen" && !stroke.movedAway) {
      this.updatePress(stroke, e);
    }
    this.frame();
  }

  private updatePress(stroke: Stroke, e: PointerEvent) {
    if (e.timeStamp - stroke.startedAt < PEN_REST_MS) return;
    if (!stroke.press) {
      const at: Vec2 = [e.clientX, e.clientY];
      const pick = this.picker.pickPoint(at[0], at[1], stroke.camera, stroke.rect);
      const chain = pick.target?.layers[0] ?? [];
      stroke.press = { pick, at, tracker: new PressureDepthTracker(Math.max(1, chain.length)) };
    }
    stroke.press.tracker.update(e.pressure, e.timeStamp / 1000);
  }

  private onPointerUp(e: PointerEvent) {
    const stroke = this.stroke;
    if (!stroke || e.pointerId !== stroke.pointerId) return;
    e.stopImmediatePropagation();
    e.preventDefault();
    this.stroke = undefined;
    this.swallowClickUntil = performance.now() + 500;
    try {
      this.finishStroke(stroke, e);
    } finally {
      this.overlay.hideFreeze();
      this.adapter.freeze?.(false);
      this.afterStroke(stroke);
      this.frame();
    }
  }

  private onPointerCancel(e: PointerEvent) {
    const stroke = this.stroke;
    if (!stroke || e.pointerId !== stroke.pointerId) return;
    this.stroke = undefined;
    this.overlay.hideFreeze(true);
    this.adapter.freeze?.(false);
    this.afterStroke(stroke);
  }

  private afterStroke(stroke: Stroke) {
    // C let go during the stroke, or a finger on a touch screen: back to the game.
    if (this.armed && !this.keyHeld && !this.wasArmed && this.keyDownAt > 0) {
      this.setArmed(false);
      this.keyDownAt = 0;
    }
    if (this.armed && stroke.kind === "touch") this.setArmed(false);
  }

  private finishStroke(stroke: Stroke, e: PointerEvent) {
    const { rect } = stroke;
    const local: Vec2[] = stroke.points.map(([x, y]) => [x - rect.left, y - rect.top]);
    const tap = isTap(stroke.points);
    if (tap && e.timeStamp - stroke.startedAt < 900 && !stroke.press && !this.armed) {
      // A quick touch of the pen that marks nothing is a click in the game.
      this.adapter.tap?.(stroke.points[0][0], stroke.points[0][1]);
      return;
    }
    if (tap) {
      if (stroke.press) stroke.press.tracker.update(0, e.timeStamp / 1000);
      this.commitTap(stroke);
      return;
    }
    const shape = shapeFor(local, rect.width, rect.height);
    if (!shape) return;
    if (shape.kind === "arrow") {
      this.commitLine(stroke, shape);
      return;
    }
    const dom = domTargetFor(stroke.points, this.host.renderer.domElement);
    if (dom) {
      this.commitMark(stroke, shape, { layers: dom.layers, layer: 0, depth: 0, partial: false }, [], true);
      return;
    }
    const pick = this.picker.pickLoop(stroke.points, stroke.camera, rect);
    this.commitMark(stroke, shape, pick.target, pick.surface, false);
  }

  /** A tap (or a pen pressed in one place): the thing under it, or, on a floor or a wall, this spot. */
  private commitTap(stroke: Stroke) {
    const { rect, camera } = stroke;
    const at = stroke.press?.at ?? stroke.points[0];
    const near = 5;
    const dom = domTargetFor([[at[0] - near, at[1] - near], [at[0] + near, at[1] - near], [at[0] + near, at[1] + near], [at[0] - near, at[1] + near]], this.host.renderer.domElement);
    if (dom) {
      const box = dom.layers[0][0].data?.screenRect as [number, number, number, number];
      const onInterface: Shape = { kind: "component", rect: { x: (box[0] - rect.left) / rect.width, y: (box[1] - rect.top) / rect.height, w: box[2] / rect.width, h: box[3] / rect.height } };
      this.commitMark({ ...stroke, points: outlinePoints(onInterface, rect) }, onInterface, { layers: dom.layers, layer: 0, depth: 0, partial: false }, [], true);
      return;
    }
    const pick = stroke.press?.pick ?? this.picker.pickPoint(at[0], at[1], camera, rect);
    const depth = stroke.press?.tracker.commit() ?? 0;
    const target = pick.target ? { ...pick.target, depth: Math.min(depth, pick.target.layers[0].length - 1) } : undefined;
    const entity = target && current(target);
    // A pen pressed harder has climbed to a whole thing, however big.
    if (depth === 0 && isSurfaceLike(entity, camera, rect)) {
      this.commitSpot(stroke, at, target && { ...target, partial: true }, pick.surface);
      return;
    }
    let shape: Shape;
    const onScreen = entity?.bounds ? boxOnScreen(entity.bounds, camera, rect) : undefined;
    if (onScreen?.complete) {
      const b = boundsOf(onScreen.points);
      shape = {
        kind: "component",
        rect: {
          x: Math.max(0, (b.minX - rect.left) / rect.width),
          y: Math.max(0, (b.minY - rect.top) / rect.height),
          w: Math.min(1, (b.maxX - b.minX) / rect.width),
          h: Math.min(1, (b.maxY - b.minY) / rect.height),
        },
      };
    } else {
      const size = 44;
      shape = { kind: "component", rect: { x: (at[0] - rect.left - size / 2) / rect.width, y: (at[1] - rect.top - size / 2) / rect.height, w: size / rect.width, h: size / rect.height } };
    }
    this.commitMark({ ...stroke, points: outlinePoints(shape, rect) }, shape, target, pick.surface, false);
  }

  // ---------------------------------------------------------------------- marks

  /** A circle, or a thing chosen by a tap. */
  private commitMark(stroke: Stroke, shape: Shape, target: MarkTarget | undefined, surface: LoopPick["surface"], onScreen: boolean) {
    const { camera, rect, points, frame } = stroke;
    const onGround = target?.partial === true && isSurfaceLike(current(target), camera, rect);
    const plane = inkPlane(surface, camera, this.lastDepth, onGround);
    if (surface.length > 0) this.lastDepth = surface[Math.floor(surface.length / 2)].distance;
    const inkPoints = shape.kind === "component" ? outlinePoints(shape, rect) : simplified(points, 3);
    // A mark on the app's own interface stays in screen points; the rest goes into the world.
    const ink: Vec3[] = onScreen ? inkPoints.map(([x, y]) => [x, y, 0]) : liftOnto(inkPoints, plane, camera, rect);
    const [spotX, spotY] = pinSpot(shape);
    const spot: Vec2 = [rect.left + spotX * rect.width, rect.top + spotY * rect.height];
    const nearest = nearestIndex(inkPoints, spot);
    const world: WorldMark = {
      anchor: onScreen ? plane.point : (ink[nearest] ?? plane.point),
      normal: plane.normal,
      ink,
      screen: onScreen || undefined,
      closed: true,
      place: onScreen ? undefined : this.placeOf(ink, plane, target),
    };
    this.addNote(shape, this.snapshotFor(poseOf(camera), frame), world, target, stroke);
  }

  /** "Here": one spot on a floor or a wall. Its ring lies on that surface and stays there. */
  private commitSpot(stroke: Stroke, at: Vec2, target: MarkTarget | undefined, surface: LoopPick["surface"]) {
    const { camera, rect, frame } = stroke;
    const plane = inkPlane(surface, camera, this.lastDepth, true);
    if (surface.length > 0) this.lastDepth = surface[0].distance;
    const center = surface[0]?.point ?? plane.point;
    // As wide in the world as a small ring on the screen, at that distance.
    const reach = camera.getWorldPosition(new THREE.Vector3()).distanceTo(new THREE.Vector3(...center));
    const radius = ((2 * Math.tan((camera.fov * Math.PI) / 360) * reach) / rect.height) * 14;
    const world: WorldMark = { anchor: center, normal: plane.normal, ink: ringOn(plane, center, radius), closed: true, place: this.placeOf([center], plane, target) };
    const shape: Shape = { kind: "point", at: [(at[0] - rect.left) / rect.width, (at[1] - rect.top) / rect.height] };
    this.addNote(shape, this.snapshotFor(poseOf(camera), frame), world, target, stroke);
  }

  /** From here to there: a route along the ground, or, starting on a thing, something to move. */
  private commitLine(stroke: Stroke, shape: Extract<Shape, { kind: "arrow" }>) {
    const { camera, rect, points, frame } = stroke;
    const samples = this.picker.alongLine(points, camera, rect);
    const first = samples[0].hit;
    const last = samples[samples.length - 1].hit;
    const thingAt = (hit: RayHit | undefined) => (hit && !isSurfaceLike(hit.chain[0], camera, rect) ? hit : undefined);
    const fromThing = thingAt(first);
    const toThing = thingAt(last);
    const line = lineInWorld(samples, camera, rect, this.lastDepth);
    // A straight line from a thing, or to one, is one move through the air. With bends, its ends stay
    // on their things and go straight to the first point that really is on the ground, not by way of
    // the ground hidden behind the thing.
    const straight = (fromThing !== undefined || toThing !== undefined) && !shape.via;
    let inWorld: Vec3[];
    if (straight) {
      inWorld = [fromThing?.point ?? line.points[0], toThing?.point ?? line.points[line.points.length - 1]];
    } else {
      let start = 0;
      let end = line.points.length - 1;
      if (fromThing) while (start < end && !line.touches[start]) start++;
      if (toThing) while (end > start && !line.touches[end]) end--;
      inWorld = line.points.slice(start, end + 1);
      if (fromThing && inWorld[0] !== fromThing.point) inWorld.unshift(fromThing.point);
      if (toThing && inWorld[inWorld.length - 1] !== toThing.point) inWorld.push(toThing.point);
    }
    // Each thing once, in the order the line meets it, and how often: what it mostly lies on is what it runs along.
    const met = new Map<string, { hit: RayHit; count: number }>();
    for (const { hit } of samples) {
      if (!hit) continue;
      const known = met.get(hit.chain[0].key);
      if (known) known.count++;
      else met.set(hit.chain[0].key, { hit, count: 1 });
    }
    const runsAlong = [...met.values()].sort((a, b) => b.count - a.count)[0]?.hit;
    const passed = new Set([first, last, runsAlong].map((hit) => hit?.chain[0].key));
    const subject = fromThing ?? toThing ?? runsAlong;
    if (subject) this.lastDepth = subject.distance;
    const endOf = (hit: RayHit | undefined, isThing: boolean, at: Vec3): PathEnd => ({
      at,
      label: hit?.chain[0].label,
      kind: hit?.chain[0].kind,
      locator: hit?.chain[0].locator,
      isThing,
      near: this.picker.nearby(at, hit?.chain.map((entity) => entity.key), 3),
    });
    const from = inWorld[0];
    const to = inWorld[inWorld.length - 1];
    const world: WorldMark = {
      anchor: from,
      normal: line.normal,
      ink: inWorld,
      closed: false,
      path: {
        points: inWorld,
        length: lineLength(inWorld),
        onGround: line.onGround && !straight,
        from: endOf(first, fromThing !== undefined, from),
        to: endOf(last, toThing !== undefined, to),
        through: [...new Set([...met.values()].filter(({ hit }) => !passed.has(hit.chain[0].key)).map(({ hit }) => hit.chain[0].label))],
      },
    };
    const target = subject && { layers: [subject.chain], layer: 0, depth: 0, partial: !fromThing && !toThing };
    this.addNote(shape, this.snapshotFor(poseOf(camera), frame), world, target, stroke);
  }

  /** Where a mark is, as a place: its middle, its size, what it lies on and what stands around it. */
  private placeOf(ink: Vec3[], plane: InkPlane, target: MarkTarget | undefined): WorldPlace {
    const sum: Vec3 = [0, 0, 0];
    const min: Vec3 = [Infinity, Infinity, Infinity];
    const max: Vec3 = [-Infinity, -Infinity, -Infinity];
    for (const p of ink) {
      for (let i = 0; i < 3; i++) {
        sum[i] += p[i];
        min[i] = Math.min(min[i], p[i]);
        max[i] = Math.max(max[i], p[i]);
      }
    }
    const count = ink.length;
    const entity = target && current(target);
    const own = target ? [...target.layers[target.layer].map((e) => e.key), ...(target.members ?? []).map((e) => e.key)] : [];
    const center: Vec3 = count > 0 ? [sum[0] / count, sum[1] / count, sum[2] / count] : plane.point;
    return {
      center,
      normal: plane.normal,
      size: count > 0 ? [max[0] - min[0], max[1] - min[1], max[2] - min[2]] : [0, 0, 0],
      on: target?.partial ? entity?.label : undefined,
      near: this.picker.nearby(center, own),
    };
  }

  /** A comment with no mark: about what is in view, or about the whole experience. */
  talkAboutView() {
    if (!this.host.ready || this.stroke) return;
    const frame = this.host.captureFrame();
    if (!frame) return;
    const camera = new THREE.PerspectiveCamera().copy(this.host.shown, false);
    const rect = this.host.rect();
    const plane = inkPlane([], camera, this.lastDepth);
    // Its pin stands in a corner of the view, not in the way of what is talked about.
    const shape: Shape = { kind: "view" };
    const [x, y] = pinSpot(shape);
    const [anchor] = liftOnto([[rect.left + x * rect.width, rect.top + y * rect.height]], plane, camera, rect);
    this.addNote(shape, this.snapshotFor(poseOf(camera), frame), { anchor, normal: plane.normal, ink: [], closed: false }, undefined, { kind: "keyboard", pressure: 0 });
  }

  private addNote(shape: Shape, snapshot: Snapshot, world: WorldMark, target: MarkTarget | undefined, input: { kind: InputKind; pressure: number }) {
    const now = new Date().toISOString();
    const note: Note = {
      id: newId(),
      ordinal: this.notes.reduce((n, other) => Math.max(n, other.ordinal), 0) + 1,
      snapshotId: snapshot.id,
      shape,
      world,
      target: target ? { ...target, method: input.kind, pressure: input.kind === "pen" ? input.pressure : undefined } : undefined,
      text: "",
      textSource: "none",
      revision: 1,
      createdAt: now,
      updatedAt: now,
    };
    this.notes.push(note);
    this.undoStack.push({ add: note.id });
    this.saveNote(note);
    this.changed();
    // A mark means something only with its words.
    this.activate(note.id);
    if (this.autoVoice) this.startRecording(note);
    else this.bubble.focusText();
  }

  /** The view a mark belongs to: a new one, unless the camera has not moved since the last mark. */
  private snapshotFor(pose: Pose, frame: HTMLCanvasElement): Snapshot {
    // The camera has not moved, and this is still the world in that picture (an agent's edit reloads the page).
    const last = this.snapshots[this.snapshots.length - 1];
    if (last && this.freshSnapshots.has(last.id) && Date.now() - Date.parse(last.takenAt) < 120_000 && samePose(last.pose, pose)) return last;
    const stored = scaledCopy(frame, FRAME_MAX_WIDTH);
    const snapshot: Snapshot = {
      id: newId().slice(0, 13),
      title: this.adapter.title?.(pose) ?? document.title ?? this.project.title,
      pose,
      widthPx: stored.width,
      heightPx: stored.height,
      takenAt: new Date().toISOString(),
      viewLink: this.adapter.viewLink ? this.adapter.viewLink(pose) : viewLink(pose),
      viewer: this.adapter.viewer?.(),
    };
    this.snapshots.push(snapshot);
    this.freshSnapshots.add(snapshot.id);
    // After the frame that the pen's last move is waiting for.
    const save = () =>
      void toBlob(stored, 0.92)
        .then((blob) => this.store.saveSnapshot(snapshot, blob))
        .catch((error) => console.warn("[drawspeak3d] could not save a picture", error));
    if (typeof requestIdleCallback === "function") requestIdleCallback(save, { timeout: 250 });
    else setTimeout(save, 30);
    return snapshot;
  }

  activate(id: string | undefined) {
    this.activeId = id;
    this.bubble.render();
    this.column.render();
  }

  get active(): Note | undefined {
    return this.activeId ? this.noteById(this.activeId) : undefined;
  }

  deleteNote(id: string, undoable = true) {
    const note = this.noteById(id);
    if (!note) return;
    if (this.recordingId === id) {
      this.voice.cancel();
      this.recordingId = undefined;
    }
    note.recording = undefined;
    this.notes = this.notes.filter((n) => n.id !== id);
    if (this.activeId === id) this.activeId = undefined;
    if (undoable) this.undoStack.push({ removed: note });
    void this.store.deleteNote(id);
    this.pins.get(id)?.remove();
    this.pins.delete(id);
    this.bubble.render();
    this.changed();
  }

  undo() {
    const step = this.undoStack.pop();
    if (!step) return;
    if (step.add) this.deleteNote(step.add, false);
    if (step.removed) {
      this.notes.push(step.removed);
      this.notes.sort((a, b) => a.ordinal - b.ordinal);
      this.saveNote(step.removed);
    }
    this.changed();
  }

  setText(note: Note, text: string, source: Note["textSource"] = "edited") {
    if (note.text === text) return;
    note.text = text;
    note.textSource = source;
    note.revision += 1;
    this.saveNote(note);
    this.changed();
  }

  setTarget(note: Note, target: NoteTarget) {
    note.target = target;
    this.saveNote(note);
    this.bubble.render();
    this.column.render();
  }

  clearSent() {
    for (const note of this.notes.filter((n) => readiness(n) === "sent")) this.deleteNote(note.id, false);
  }

  /** Marks as handed over. */
  markSent(noteIds: Iterable<string>) {
    for (const id of noteIds) {
      const note = this.noteById(id);
      if (note) {
        note.lastSentRevision = note.revision;
        this.saveNote(note);
      }
    }
    this.changed();
  }

  /** Looks from the view a note was made on. Any move of your own takes you back. */
  lookFrom(note: Note) {
    const snapshot = this.snapshotOf(note);
    if (snapshot) this.host.setView(snapshot.pose);
    this.activate(note.id);
  }

  /** A view's picture. It is written just after the mark, so it may take a moment to be there. */
  async pictureOf(snapshotId: string): Promise<Blob | undefined> {
    for (let tries = 0; tries < 16; tries++) {
      const image = await this.store.image(snapshotId);
      if (image) return image;
      await new Promise((resolve) => setTimeout(resolve, 250));
    }
    return undefined;
  }

  async showPicture(note: Note) {
    const image = await this.pictureOf(note.snapshotId);
    if (!image) return;
    const number = this.numbers.get(note.id) ?? note.ordinal;
    const canvas = await renderComposite(image, [{ number, note }], COMPOSITE_WIDTH);
    lightbox(this.root, canvas.toDataURL("image/jpeg", 0.92));
  }

  // ---------------------------------------------------------------------- voice

  startRecording(note: Note) {
    this.finishRecording();
    this.recordingId = note.id;
    this.recordingBase = note.text;
    this.recordingStart = performance.now();
    this.liveText = "";
    this.setRecording(note, "recording");
    this.activate(note.id);
    this.startEngine(note);
  }

  private startEngine(note: Note) {
    this.voice.start(this.lang, {
      onText: (text) => {
        if (this.recordingId !== note.id) return;
        this.liveText = text;
        this.bubble.liveText(this.mergedText());
      },
      onLevel: (level) => this.bubble.level(level),
      onSilence: () => {
        if (this.recordingId === note.id) void this.stopRecording();
      },
      onFailure: (reason) => {
        if (this.recordingId !== note.id) return;
        this.recordingId = undefined;
        this.setRecording(note, undefined);
        this.bubble.problem(FAILURE_TEXT[reason]);
        this.bubble.focusText();
      },
    });
  }

  get recordingNote(): Note | undefined {
    return this.recordingId ? this.noteById(this.recordingId) : undefined;
  }

  get recordingSeconds(): number {
    return (performance.now() - this.recordingStart) / 1000;
  }

  private mergedText(): string {
    return [this.recordingBase, this.liveText].map((t) => t.trim()).filter(Boolean).join(" ");
  }

  private setRecording(note: Note, state: RecordingState | undefined) {
    note.recording = state;
    this.bubble.render();
    this.changed();
  }

  /** Stop: what was said becomes the comment. The recording's own note, whatever has happened since. */
  async stopRecording() {
    const note = this.recordingNote;
    if (!note || note.recording === "transcribing") return;
    this.setRecording(note, "transcribing");
    const base = this.recordingBase;
    const said = await this.voice.stop();
    if (this.recordingId !== note.id) return;
    this.recordingId = undefined;
    const text = [base, said || this.liveText].map((t) => t.trim()).filter(Boolean).join(" ");
    this.setRecording(note, undefined);
    if (text && this.noteById(note.id)) this.setText(note, text, "voice");
    // The hub may have come up after the page did.
    if (!this.hubProject) await this.refreshHub();
    this.bubble.render();
    const sendNow = this.sendWhenHeard === note.id;
    this.sendWhenHeard = undefined;
    if (sendNow && this.sendActive()) return;
    if (note.text.trim()) this.bubble.closeSoon();
    else this.bubble.focusText();
  }

  /** A recording ends at once when another begins: what was heard so far stays. */
  private finishRecording() {
    const note = this.recordingNote;
    if (!note) return;
    const text = this.mergedText();
    this.voice.cancel();
    this.recordingId = undefined;
    note.recording = undefined;
    if (text) this.setText(note, text, "voice");
  }

  /** Typing takes over from the voice. */
  typingStarted(note: Note, text: string) {
    if (this.recordingId === note.id) {
      this.voice.cancel();
      this.recordingId = undefined;
      note.recording = undefined;
      this.bubble.render();
    }
    this.setText(note, text, note.textSource === "voice" ? "edited" : "typed");
  }

  /** Discard: the recording goes, and with it a mark that has nothing else. It can come back with Undo. */
  discard(note: Note) {
    if (this.recordingId === note.id) {
      this.voice.cancel();
      this.recordingId = undefined;
      note.recording = undefined;
    }
    if (!note.text.trim()) this.deleteNote(note.id);
    this.activate(undefined);
    this.changed();
  }

  // ---------------------------------------------------------------------- keys

  private typing(): boolean {
    const el = document.activeElement;
    return el instanceof HTMLInputElement || el instanceof HTMLTextAreaElement || (el instanceof HTMLElement && el.isContentEditable);
  }

  private onKeyDown(e: KeyboardEvent) {
    if (this.hidden) return;
    if (e.code === "Escape") {
      const picture = this.root.querySelector(".ds3d-picture");
      if (picture) picture.remove();
      else if (this.sheet.open) this.sheet.close();
      else if (this.recordingNote) this.discard(this.recordingNote);
      else if (this.active) this.activate(undefined);
      else if (this.column.open) this.column.toggle();
      else if (this.armed) this.setArmed(false);
      else return;
      if (document.activeElement instanceof HTMLElement && this.isOwnUi(document.activeElement)) document.activeElement.blur();
      e.stopImmediatePropagation();
      e.preventDefault();
      return;
    }
    // C still held from before a text field took the focus: its repeats are not typing.
    if (e.code === "KeyC" && e.repeat && this.keyHeld) {
      e.stopImmediatePropagation();
      e.preventDefault();
      return;
    }
    if (this.typing()) return;
    if (this.sheet.open) {
      if (e.code === "Enter" && !(document.activeElement instanceof HTMLButtonElement)) {
        e.stopImmediatePropagation();
        e.preventDefault();
        this.sheet.sendChosen();
      }
      return;
    }
    if (e.code === "KeyT" && !e.ctrlKey && !e.metaKey && !e.altKey) {
      e.stopImmediatePropagation();
      if (!e.repeat) this.talkAboutView();
      return;
    }
    if (e.code === "KeyC" && !e.ctrlKey && !e.metaKey && !e.altKey) {
      e.stopImmediatePropagation();
      if (e.repeat) return;
      this.keyDownAt = performance.now();
      this.keyHeld = true;
      this.wasArmed = this.armed;
      this.usedWhileHeld = false;
      this.setArmed(true);
      return;
    }
    if (e.code === "Enter" && this.recordingNote) {
      e.stopImmediatePropagation();
      e.preventDefault();
      if (e.repeat) return;
      // A second Enter while the last words are still coming sends them when they are in.
      if (this.recordingNote.recording === "transcribing") this.sendWhenHeard = this.recordingNote.id;
      else void this.stopRecording();
      return;
    }
    if (e.code === "Enter" && !e.repeat && (this.sendActive() || this.sendWaiting())) {
      e.stopImmediatePropagation();
      e.preventDefault();
      return;
    }
    if ((e.code === "BracketLeft" || e.code === "BracketRight") && this.active?.target) {
      e.stopImmediatePropagation();
      this.bubble.climb(e.code === "BracketRight" ? 1 : -1);
      return;
    }
    if ((e.ctrlKey || e.metaKey) && e.code === "KeyZ" && this.armed) {
      e.stopImmediatePropagation();
      e.preventDefault();
      this.undo();
      return;
    }
    if (this.host.lookingFromView && !e.ctrlKey && !e.metaKey) this.host.setView(null);
  }

  private onKeyUp(e: KeyboardEvent) {
    if (e.code !== "KeyC" || !this.keyHeld) return;
    e.stopImmediatePropagation();
    this.keyHeld = false;
    const quick = performance.now() - this.keyDownAt < 260 && !this.usedWhileHeld;
    if (quick && this.recordingNote) {
      // While you speak, a tap means you are done.
      this.setArmed(this.wasArmed);
      this.keyDownAt = 0;
      void this.stopRecording();
    } else if (quick) {
      // A tap switches Draw on or off and leaves it so.
      this.setArmed(!this.wasArmed);
      this.wasArmed = this.armed;
      this.keyDownAt = 0;
    } else if (!this.stroke) {
      // Held and used: letting go ends it, unless it was on before.
      this.setArmed(this.wasArmed);
      this.keyDownAt = 0;
    }
  }

  private onBlur() {
    this.keyHeld = false;
    if (this.stroke) {
      this.overlay.hideFreeze(true);
      this.adapter.freeze?.(false);
      this.stroke = undefined;
    }
    if (this.keyDownAt > 0) {
      this.setArmed(this.wasArmed);
      this.keyDownAt = 0;
    }
  }

  // ---------------------------------------------------------------------- every frame

  private frame() {
    this.frameCount++;
    const hidden = this.hiddenWhen?.() ?? false;
    if (hidden !== this.hidden) {
      this.hidden = hidden;
      this.root.style.display = hidden ? "none" : "";
      if (hidden) this.setArmed(false);
    }
    if (this.covered && (hidden ? this.frameCount > 45 : this.host.ready && this.framesInSight > 5)) this.showWorld();
    if (hidden || !this.host.ready) return;
    // An agent's look, once the world has settled after a reload, and not in the middle of this frame.
    this.framesInSight++;
    if (this.framesInSight === 20) this.picker.warm();
    if (this.framesInSight === 30) this.palette.greet();
    // A graphics card that struggles gets plain panels: blurring the world behind them is the costliest thing here.
    const frameAt = performance.now();
    if (this.lastFrameAt > 0) this.frameTime += (Math.min(frameAt - this.lastFrameAt, 100) - this.frameTime) * 0.02;
    this.lastFrameAt = frameAt;
    if (!this.plain && this.framesInSight > 180 && this.frameTime > 24) {
      this.plain = true;
      this.root.classList.add("is-plain");
    }
    if (this.looksDue.length > 0 && this.framesInSight > 8 && this.reloadSince === 0) setTimeout(() => this.answerLooks(), 0);
    const now = performance.now();
    for (const [id, since] of this.leaving) if (now - since > LEAVE_MS) this.leaving.delete(id);
    const stroke = this.stroke;
    const camera = stroke?.camera ?? this.host.shown;
    const rect = stroke?.rect ?? this.host.rect();
    const numbers = this.numbers;
    const active = this.active;
    const inWorld = this.worldNotes;
    const working = this.runCards.workingNotes;
    this.overlay.setVisible(stroke !== undefined || inWorld.length > 0 || active !== undefined);
    this.overlay.begin();
    for (const note of inWorld) {
      const since = this.leaving.get(note.id);
      const alpha = since !== undefined ? 0.8 * (1 - (now - since) / LEAVE_MS) : this.occludedNotes.has(note.id) ? 0.26 : working.has(note.id) ? 0.6 : 1;
      if (note.world.screen) {
        this.overlay.screenPath(note.world.ink.map(([x, y]): Vec2 => [x, y]), note.world.closed ?? true, alpha);
        continue;
      }
      this.overlay.worldInk(note.world.ink, note.world.closed ?? false, camera, rect, alpha, note.shape.kind === "arrow");
      if (note !== active && note.target && !note.target.partial && isEdgeOn(note.world.anchor, note.world.normal, camera)) {
        const bounds = current(note.target)?.bounds;
        if (bounds) this.overlay.outline(bounds, camera, rect, 0.55 * alpha);
      }
    }
    if (active?.target) {
      const entity = current(active.target);
      // A loop on part of something big needs no outline of the whole of it.
      if (entity?.bounds && !(active.target.partial && active.target.depth === 0 && active.target.layer === 0)) this.overlay.outline(entity.bounds, camera, rect);
      const box = entity?.data?.screenRect as [number, number, number, number] | undefined;
      if (box) this.overlay.screenOutline(box[0], box[1], box[2], box[3]);
    }
    if (stroke) this.drawLive(stroke, camera, rect);
    this.placePins(numbers, camera, rect);
    this.placeBubble(camera, rect);
    this.bubble.tick();
    this.runCards.tick();
    this.checkOcclusion(camera);
  }

  private drawLive(stroke: Stroke, camera: THREE.Camera, rect: DOMRect) {
    // It shows what it will mean: closing into a circle, or a line with a head.
    const going = stroke.points.length > 8 && !isTap(stroke.points);
    const closing = going && isClosedLoop(stroke.points);
    this.overlay.liveStroke(stroke.points, closing, going && !closing && !isCurling(stroke.points));
    const press = stroke.press;
    const target = press?.pick.target;
    if (press && target) {
      const chain = target.layers[0];
      const entity = chain[Math.min(press.tracker.depth, chain.length - 1)];
      if (entity?.bounds) this.overlay.outline(entity.bounds, camera, rect);
      this.palette.pressLabel(entity ? `${entity.label} · ${press.tracker.depth + 1}/${chain.length}` : undefined, press.at);
    } else this.palette.pressLabel(undefined);
  }

  private placePins(numbers: Map<string, number>, camera: THREE.Camera, rect: DOMRect) {
    const seen = new Set<string>();
    const working = this.runCards.workingNotes;
    for (const note of this.worldNotes) {
      seen.add(note.id);
      let pin = this.pins.get(note.id);
      if (!pin) {
        pin = document.createElement("button");
        pin.className = "ds3d-pin";
        pin.setAttribute("aria-label", `Comment ${numbers.get(note.id) ?? ""}`);
        const id = note.id;
        pin.addEventListener("click", () => {
          this.activate(this.activeId === id ? undefined : id);
        });
        this.pinLayer.append(pin);
        this.pins.set(note.id, pin);
      }
      const since = this.leaving.get(note.id);
      const label = since !== undefined ? "✓" : String(numbers.get(note.id) ?? note.ordinal);
      if (pin.textContent !== label) pin.textContent = label;
      pin.classList.toggle("is-done", since !== undefined);
      if (since !== undefined) pin.style.opacity = String(Math.max(0, 1 - ((performance.now() - since) / LEAVE_MS) ** 3));
      else if (pin.style.opacity) pin.style.opacity = "";
      let at: Vec2 | undefined;
      let edge = false;
      if (note.world.screen) {
        const spot = pinSpot(note.shape);
        at = [Math.max(rect.left + 16, Math.min(rect.right - 16, rect.left + spot[0] * rect.width)), Math.max(rect.top + 16, Math.min(rect.bottom - 16, rect.top + spot[1] * rect.height))];
      } else {
        at = toScreen(note.world.anchor, camera, rect);
        const margin = 20;
        if (!at || at[0] < rect.left + margin || at[0] > rect.right - margin || at[1] < rect.top + margin || at[1] > rect.bottom - margin) {
          at = edgePoint(note.world.anchor, camera, rect, margin);
          edge = true;
        }
      }
      if (!at) {
        pin.style.display = "none";
        continue;
      }
      // A spot's pin stands over its ring, like a pin on a map, and leaves it in sight.
      if (note.shape.kind === "point" && !edge) at = [at[0], at[1] - SPOT_PIN_LIFT];
      pin.style.display = "";
      pin.style.transform = `translate(${at[0].toFixed(1)}px, ${at[1].toFixed(1)}px)`;
      const state = readiness(note);
      pin.classList.toggle("is-edge", edge);
      pin.classList.toggle("is-dim", this.occludedNotes.has(note.id) && !edge);
      pin.classList.toggle("is-working", working.has(note.id) && since === undefined);
      pin.classList.toggle("is-sent", state === "sent" && !working.has(note.id) && since === undefined);
      pin.classList.toggle("is-empty", state === "markOnly");
      pin.classList.toggle("is-rec", state === "recording");
    }
    for (const [id, pin] of this.pins) {
      if (!seen.has(id)) {
        pin.remove();
        this.pins.delete(id);
      }
    }
  }

  private placeBubble(camera: THREE.Camera, rect: DOMRect) {
    const note = this.active;
    if (!note || !this.bubble.visible) return;
    let at: Vec2 | undefined;
    if (note.world.screen) {
      const spot = pinSpot(note.shape);
      at = [rect.left + spot[0] * rect.width, rect.top + spot[1] * rect.height];
    } else at = toScreen(note.world.anchor, camera, rect);
    this.bubble.place(at);
  }

  /** One mark at a time, a few times a second: is it behind something now? */
  private checkOcclusion(camera: THREE.Camera) {
    const now = performance.now();
    if (now - this.occlusionClock < 180) return;
    this.occlusionClock = now;
    const notes = this.worldNotes;
    if (notes.length === 0) return;
    this.occlusionCursor = (this.occlusionCursor + 1) % notes.length;
    const note = notes[this.occlusionCursor];
    if (note.world.screen) return;
    if (this.picker.occluded(note.world.anchor, camera)) this.occludedNotes.add(note.id);
    else this.occludedNotes.delete(note.id);
  }

  // ---------------------------------------------------------------------- feedback

  openFeedback() {
    if (this.recordingNote) void this.stopRecording();
    this.sheet.show();
  }

  toggleColumn() {
    this.column.toggle();
  }

  worldInfo() {
    return this.adapter.world ?? { engine: `three.js r${THREE.REVISION}`, up: "Y" };
  }

  // ---------------------------------------------------------------------- views and reloads

  private applyViewFromLink() {
    const raw = new URLSearchParams(location.search).get("ds3d_view");
    const pose = raw ? parsePose(raw) : undefined;
    if (pose) this.host.setView(pose, 0);
  }

  /**
   * The last frame with its marks, for the moment the page is gone: vite-plugin.ts puts it up before the
   * new page has anything to show, and it melts into the new world when that is ready.
   */
  private saveCover(): { image: string; rect: number[] } | undefined {
    if (this.hidden || !this.host.ready) return undefined;
    try {
      const frame = this.host.captureFrame();
      if (!frame) return undefined;
      const rect = this.host.rect();
      const scale = frame.width / rect.width;
      const page = frame.getContext("2d")!;
      const ink = this.overlay.canvas;
      if (ink.width > 0 && ink.style.display !== "none") {
        const inkScale = ink.width / innerWidth;
        page.drawImage(ink, rect.left * inkScale, rect.top * inkScale, rect.width * inkScale, rect.height * inkScale, 0, 0, frame.width, frame.height);
      }
      for (const pin of this.pins.values()) {
        if (pin.style.display === "none") continue;
        const box = pin.getBoundingClientRect();
        const x = (box.left + box.width / 2 - rect.left) * scale;
        const y = (box.top + box.height / 2 - rect.top) * scale;
        page.beginPath();
        page.arc(x, y, (box.width / 2) * scale, 0, Math.PI * 2);
        page.fillStyle = getComputedStyle(pin).backgroundColor;
        page.fill();
        page.lineWidth = 2 * scale;
        page.strokeStyle = "#fff";
        page.stroke();
        page.fillStyle = "#fff";
        page.font = `700 ${14 * scale}px system-ui, sans-serif`;
        page.textAlign = "center";
        page.textBaseline = "middle";
        page.fillText(pin.textContent ?? "", x, y);
      }
      const cover = { image: scaledCopy(frame, COVER_WIDTH).toDataURL("image/jpeg", 0.82), rect: [rect.left, rect.top, rect.width, rect.height] };
      sessionStorage.setItem(COVER, JSON.stringify({ at: Date.now(), ...cover }));
      return cover;
    } catch {
      // too big or not allowed: the reload just shows
      return undefined;
    }
  }

  private showWorld() {
    this.covered = false;
    const cover = document.getElementById("ds3d-cover");
    if (!cover) return;
    cover.style.opacity = "0";
    setTimeout(() => cover.remove(), 700);
  }

  private saveForReload() {
    if (!this.reloading) this.saveCover();
    try {
      const speaking = this.recordingNote;
      const heard = speaking && this.mergedText() ? { id: speaking.id, text: this.mergedText() } : undefined;
      sessionStorage.setItem(`ds3d.resume.${this.project.id}`, JSON.stringify({ state: this.adapter.save?.(), pose: this.host.ready ? this.host.shownPose : undefined, at: Date.now(), column: this.column.open, heard, looks: this.looksDue }));
    } catch {
      // too big or not allowed: the reload just starts fresh
    }
  }

  private restoreAfterReload() {
    try {
      const raw = sessionStorage.getItem(`ds3d.resume.${this.project.id}`);
      if (!raw) return;
      sessionStorage.removeItem(`ds3d.resume.${this.project.id}`);
      const saved = JSON.parse(raw) as { state?: unknown; pose?: Pose; at: number; column?: boolean; heard?: { id: string; text: string }; looks?: LookRequest[] };
      // A reload a moment ago (an agent's edit), not a visit tomorrow.
      if (Date.now() - saved.at > 120_000) return;
      this.heardBeforeReload = saved.heard;
      this.looksDue = saved.looks ?? [];
      if (saved.state !== undefined) this.adapter.restore?.(saved.state);
      else if (saved.pose) this.host.startFrom(saved.pose);
      if (saved.column) this.column.toggle();
    } catch {
      // nothing to restore
    }
  }
}

/** Is a mark's plane seen so nearly from the side that its ink is a sliver? */
function isEdgeOn(point: Vec3, normal: Vec3, camera: THREE.Camera): boolean {
  const eye = camera.matrixWorld.elements;
  const dx = eye[12] - point[0];
  const dy = eye[13] - point[1];
  const dz = eye[14] - point[2];
  const length = Math.hypot(dx, dy, dz) || 1;
  return Math.abs((dx * normal[0] + dy * normal[1] + dz * normal[2]) / length) < 0.3;
}

function samePose(a: Pose, b: Pose): boolean {
  const close = (p: number[], q: number[], eps: number) => p.every((v, i) => Math.abs(v - q[i]) < eps);
  return close(a.position, b.position, 1e-3) && close(a.quaternion, b.quaternion, 1e-3) && Math.abs(a.fov - b.fov) < 0.01;
}

function nearestIndex(points: Vec2[], to: Vec2): number {
  let best = 0;
  let bestDistance = Infinity;
  points.forEach((p, i) => {
    const d = distance(p, to);
    if (d < bestDistance) {
      bestDistance = d;
      best = i;
    }
  });
  return best;
}

/** A mark saved when a drag still meant a rectangle and a free line had a kind of its own. */
function currentShape(saved: Shape): Shape {
  const old = saved as unknown as { kind: string; rect?: NRect; points?: Vec2[] };
  if (old.kind === "region" && old.rect) return { kind: "component", rect: old.rect };
  if (old.kind === "stroke" && old.points && old.points.length > 1) return { kind: "arrow", from: old.points[0], to: old.points[old.points.length - 1], via: old.points.slice(1, -1) };
  return saved;
}

function outlinePoints(shape: Shape, rect: DOMRect): Vec2[] {
  if (shape.kind !== "component") return [];
  const x = rect.left + shape.rect.x * rect.width;
  const y = rect.top + shape.rect.y * rect.height;
  const w = shape.rect.w * rect.width;
  const h = shape.rect.h * rect.height;
  return [[x, y], [x + w, y], [x + w, y + h], [x, y + h]];
}

/** Toward a point that is off screen: where on the edge of the screen to show it. */
function edgePoint(point: Vec3, camera: THREE.Camera, rect: DOMRect, margin: number): Vec2 | undefined {
  const v = new THREE.Vector3(point[0], point[1], point[2]).applyMatrix4(camera.matrixWorldInverse);
  let dx = v.x;
  let dy = -v.y;
  if (v.z < 0) {
    v.applyMatrix4((camera as THREE.PerspectiveCamera).projectionMatrix);
    dx = v.x * rect.width;
    dy = -v.y * rect.height;
  } else if (Math.abs(dx) + Math.abs(dy) < 1e-3) dy = 1;
  const cx = rect.left + rect.width / 2;
  const cy = rect.top + rect.height / 2;
  const halfW = rect.width / 2 - margin;
  const halfH = rect.height / 2 - margin;
  const scale = Math.min(halfW / Math.max(1e-6, Math.abs(dx)), halfH / Math.max(1e-6, Math.abs(dy)));
  return [cx + dx * scale, cy + dy * scale];
}

const short = (v: number) => Math.round(v * 1000) / 1000;

export function viewLink(pose: Pose): string {
  const url = new URL(location.href);
  url.searchParams.set("ds3d_view", [...pose.position, ...pose.quaternion, pose.fov].map(short).join(","));
  return url.toString();
}

export function parsePose(raw: string): Pose | undefined {
  const v = raw.split(",").map(Number);
  if (v.length !== 8 || v.some((n) => !Number.isFinite(n))) return undefined;
  return { position: [v[0], v[1], v[2]], quaternion: [v[3], v[4], v[5], v[6]], fov: v[7], aspect: innerWidth / innerHeight, near: 0.1, far: 1000 };
}

