import { spawn, type ChildProcess } from "node:child_process";
import { randomBytes } from "node:crypto";
import { createReadStream, existsSync, mkdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { buildPackage, displayNumbers, manifestOf, messageText, readiness } from "../src/core/package.ts";
import type { AgentDirective, Note, NoteTarget, Pose, Shape, Snapshot, Viewer, WorldMark } from "../src/core/types.ts";
import { gitRevision, here, type Project } from "./data.ts";
import type { HubApi, HubRequest } from "./hub.ts";

/**
 * Marks kept here rather than in a browser, for worlds that cannot do the rest themselves: a Roblox
 * Studio plugin can draw and pick, but has no microphone and cannot read its own screen. So the plugin
 * sends each mark here; the hub takes the picture of the window and asks the desk page (hub/desk.html)
 * to listen; the plugin polls for the words. Sending then builds the same batch as everywhere else.
 */
export interface MarkRequest {
  title?: string;
  shape: Shape;
  pose: Pose;
  world: WorldMark;
  target?: NoteTarget;
  /** Where the person's own character stands, during a test. */
  viewer?: Viewer;
  /** Start listening for this mark. */
  voice?: boolean;
}

interface LiveNote extends Note {
  /** What the desk heard so far, while it listens. */
  live?: string;
}

export type CaptureFn = (out: string) => Promise<{ ok: boolean; width?: number; height?: number; reason?: string; detail?: string }>;

/**
 * A picture of the Roblox window, by hub/capture.ps1. Starting PowerShell takes seconds, too long for
 * a mark to wait with the ink on screen, so one stays running from the moment the plugin first calls.
 */
class CaptureHelper {
  private child?: ChildProcess;
  private buffer = "";
  private waiting: Array<(line: string) => void> = [];

  warm() {
    if (process.platform !== "win32" || this.child) return;
    const child = spawn("powershell.exe", ["-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-File", join(here, "capture.ps1")], { windowsHide: true, stdio: ["pipe", "pipe", "ignore"] });
    this.child = child;
    child.stdout!.setEncoding("utf8").on("data", (chunk: string) => {
      this.buffer += chunk;
      let at: number;
      while ((at = this.buffer.indexOf("\n")) >= 0) {
        const line = this.buffer.slice(0, at).trim();
        this.buffer = this.buffer.slice(at + 1);
        // It says it is ready first; that answers nobody.
        if (line && !line.includes('"ready"')) this.waiting.shift()?.(line);
      }
    });
    const gone = () => {
      if (this.child === child) this.child = undefined;
      for (const resolve of this.waiting.splice(0)) resolve('{"ok":false,"reason":"error"}');
    };
    child.on("exit", gone);
    child.on("error", gone);
  }

  take(out: string): ReturnType<CaptureFn> {
    if (process.platform !== "win32") return Promise.resolve({ ok: false, reason: "windows-only" });
    this.warm();
    return new Promise((resolve) => {
      const timer = setTimeout(() => {
        this.waiting = this.waiting.filter((w) => w !== answer);
        resolve({ ok: false, reason: "timeout" });
      }, 20000);
      const answer = (line: string) => {
        clearTimeout(timer);
        try {
          resolve(JSON.parse(line));
        } catch {
          resolve({ ok: false, reason: "error", detail: line });
        }
      };
      this.waiting.push(answer);
      this.child!.stdin!.write(`${out}\n`);
    });
  }

  stop() {
    this.child?.stdin?.end();
    this.child = undefined;
  }
}

const helper = new CaptureHelper();
export const captureWindow: CaptureFn = (out) => helper.take(out);
export const warmCapture = () => helper.warm();
export const stopCapture = () => helper.stop();

export class LiveMarks {
  private readonly root: string;
  private readonly capture: CaptureFn;
  private readonly state = new Map<string, { notes: LiveNote[]; snapshots: Snapshot[] }>();
  private api?: HubApi;

  constructor(dataDir: string, capture: CaptureFn = captureWindow) {
    this.root = dataDir;
    this.capture = capture;
  }

  private folder(projectId: string) {
    return join(this.root, projectId, "live");
  }

  private of(projectId: string) {
    let state = this.state.get(projectId);
    if (!state) {
      state = { notes: [], snapshots: [] };
      try {
        state = JSON.parse(readFileSync(join(this.folder(projectId), "notes.json"), "utf8")) as { notes: LiveNote[]; snapshots: Snapshot[] };
        // A recording does not survive a restart.
        for (const note of state.notes) {
          delete note.recording;
          delete note.live;
        }
      } catch {
        // nothing saved yet
      }
      this.state.set(projectId, state);
    }
    return state;
  }

  private save(projectId: string) {
    mkdirSync(this.folder(projectId), { recursive: true });
    writeFileSync(join(this.folder(projectId), "notes.json"), JSON.stringify(this.of(projectId)));
  }

  /** Sent marks live on in their batches: here they only stay a while, for the desk's history. */
  private prune(projectId: string) {
    const state = this.of(projectId);
    const old = Date.now() - 7 * 24 * 3600 * 1000;
    state.notes = state.notes.filter((n) => readiness(n) !== "sent" || Date.parse(n.updatedAt) > old);
    for (const snapshot of state.snapshots.slice()) {
      if (!state.notes.some((n) => n.snapshotId === snapshot.id)) {
        state.snapshots = state.snapshots.filter((s) => s !== snapshot);
        rmSync(join(this.folder(projectId), `${snapshot.id}.jpg`), { force: true });
      }
    }
  }

  private view(projectId: string, note: LiveNote) {
    const numbers = displayNumbers(this.of(projectId).notes);
    const working = this.api?.runsOf(projectId).some((run) => run.status === "running" && run.noteIds?.includes(note.id)) ?? false;
    return { ...note, number: numbers.get(note.id) ?? note.ordinal, readiness: readiness(note), working, text: note.recording ? (note.live ?? note.text) : note.text };
  }

  /** The last desk closed: nothing is listening any more. What it had heard stays, and the notes can go on. */
  desksGone(projectId: string) {
    const state = this.of(projectId);
    let changed = false;
    for (const note of state.notes) {
      if (!note.recording) continue;
      changed = true;
      note.recording = undefined;
      const said = note.live?.trim();
      if (said) setText(note, [note.text, said].map((t) => t.trim()).filter(Boolean).join(" "), "voice");
      delete note.live;
    }
    if (changed) this.save(projectId);
  }

  /** Handles a request about marks. True when it was one. */
  async route(request: HubRequest, api: HubApi): Promise<boolean> {
    const { req, parts, project, json, readJson, res } = request;
    this.api = api;
    if (parts[0] === "v1" && parts[1] === "roblox" && req.method === "GET") {
      // Which project a Roblox plugin belongs to, so it needs no settings. A plugin is here: marks will follow.
      if (this.capture === captureWindow) warmCapture();
      const found = [...api.projects.values()].find((p) => p.roblox);
      json(found ? 200 : 404, found ? { id: found.id, title: found.title } : { error: 'No project with "roblox": true in hub/projects.json.' });
      return true;
    }
    if (!project || parts[0] !== "v1" || parts[1] !== "projects") return false;
    const what = parts[3];
    if (what === "runs" && req.method === "GET") {
      json(200, api.runsOf(project.id));
      return true;
    }
    if (what !== "marks") return false;
    const id = parts[4];
    const sub = parts[5];
    const state = this.of(project.id);

    if (req.method === "GET" && !id) {
      json(200, { notes: state.notes.map((n) => this.view(project.id, n)), snapshots: state.snapshots, desks: api.deskCount(project.id) });
      return true;
    }
    if (req.method === "POST" && !id) {
      json(200, await this.create(project, await readJson<MarkRequest>(4 * 1024 * 1024), api));
      return true;
    }
    if (req.method === "POST" && id === "send") {
      json(200, await this.send(project, await readJson<{ noteIds?: string[]; directive?: AgentDirective; newThread?: boolean }>(1024 * 1024), api));
      return true;
    }
    const note = state.notes.find((n) => n.id === id);
    if (!note) {
      json(404, { error: "No such mark." });
      return true;
    }
    if (req.method === "GET" && sub === "image") {
      const file = join(this.folder(project.id), `${note.snapshotId}.jpg`);
      if (!existsSync(file)) {
        json(404, { error: "This mark has no picture." });
        return true;
      }
      res.writeHead(200, { "content-type": "image/jpeg", "cache-control": "no-store", "cross-origin-resource-policy": "same-origin" });
      createReadStream(file).pipe(res);
      return true;
    }
    if (req.method === "GET" && !sub) {
      json(200, this.view(project.id, note));
      return true;
    }
    if (req.method === "POST" && !sub) {
      json(200, this.update(project, note, await readJson<UpdateRequest>(1024 * 1024), api));
      return true;
    }
    return false;
  }

  private async create(project: Project, mark: MarkRequest, api: HubApi) {
    if (!mark.shape?.kind || !Array.isArray(mark.pose?.position) || !Array.isArray(mark.world?.anchor) || !Array.isArray(mark.world?.ink)) throw new Error("A mark needs a shape, a camera and a place in the world.");
    const state = this.of(project.id);
    const now = new Date().toISOString();
    mkdirSync(this.folder(project.id), { recursive: true });
    const snapshotId = randomBytes(6).toString("hex");
    const picture = await this.capture(join(this.folder(project.id), `${snapshotId}.jpg`));
    const snapshot: Snapshot = {
      id: snapshotId,
      title: mark.title ?? project.title,
      pose: mark.pose,
      widthPx: picture.width ?? 0,
      heightPx: picture.height ?? 0,
      takenAt: now,
      viewer: mark.viewer,
    };
    state.snapshots.push(snapshot);
    const note: LiveNote = {
      id: randomBytes(8).toString("hex"),
      ordinal: state.notes.reduce((n, other) => Math.max(n, other.ordinal), 0) + 1,
      snapshotId,
      shape: mark.shape,
      world: mark.world,
      target: mark.target,
      text: "",
      textSource: "none",
      revision: 1,
      createdAt: now,
      updatedAt: now,
    };
    state.notes.push(note);
    const desks = api.deskCount(project.id);
    if (mark.voice && desks > 0) {
      note.recording = "recording";
      api.emit(project.id, "voice", { noteId: note.id, state: "start" });
    }
    this.save(project.id);
    return { ...this.view(project.id, note), picture: picture.ok === true, pictureProblem: picture.ok ? undefined : picture.reason, desks };
  }

  private update(project: Project, note: LiveNote, body: UpdateRequest, api: HubApi) {
    const state = this.of(project.id);
    if (body.discard) {
      if (note.recording) api.emit(project.id, "voice", { noteId: note.id, state: "cancel" });
      state.notes = state.notes.filter((n) => n !== note);
      if (!state.notes.some((n) => n.snapshotId === note.snapshotId)) {
        state.snapshots = state.snapshots.filter((s) => s.id !== note.snapshotId);
        rmSync(join(this.folder(project.id), `${note.snapshotId}.jpg`), { force: true });
      }
      this.save(project.id);
      return { discarded: true };
    }
    if (typeof body.heard === "string") {
      // From the desk, while it listens: words in progress, not yet the comment.
      note.live = body.heard;
    }
    if (body.heardFinal !== undefined) {
      note.recording = undefined;
      const said = body.heardFinal.trim();
      if (said) setText(note, [note.text, said].map((t) => t.trim()).filter(Boolean).join(" "), "voice");
      delete note.live;
    }
    if (body.stop && note.recording) {
      note.recording = "transcribing";
      api.emit(project.id, "voice", { noteId: note.id, state: "stop" });
    }
    if (body.listen && !note.recording && api.deskCount(project.id) > 0) {
      note.recording = "recording";
      api.emit(project.id, "voice", { noteId: note.id, state: "start" });
    }
    if (typeof body.text === "string") {
      if (note.recording) {
        note.recording = undefined;
        delete note.live;
        api.emit(project.id, "voice", { noteId: note.id, state: "cancel" });
      }
      setText(note, body.text, note.textSource === "voice" ? "edited" : "typed");
    }
    if (note.target) {
      if (typeof body.layer === "number") {
        note.target.layer = Math.max(0, Math.min(note.target.layers.length - 1, Math.floor(body.layer)));
        note.target.depth = 0;
      }
      if (typeof body.depth === "number") {
        const chain = note.target.layers[note.target.layer] ?? [];
        note.target.depth = Math.max(0, Math.min(chain.length - 1, Math.floor(body.depth)));
      }
    }
    note.updatedAt = new Date().toISOString();
    this.save(project.id);
    return this.view(project.id, note);
  }

  private async send(project: Project, body: { noteIds?: string[]; directive?: AgentDirective; newThread?: boolean }, api: HubApi) {
    const state = this.of(project.id);
    const ids = new Set(body.noteIds ?? state.notes.filter((n) => readiness(n) === "ready").map((n) => n.id));
    if (ids.size === 0) throw new Error("Nothing to send: a mark needs a comment first.");
    const stamp = new Date().toISOString().replace(/[-:]/g, "").replace("T", "-").slice(0, 15);
    const batchId = `${stamp}-${randomBytes(2).toString("hex")}`;
    const pkg = buildPackage({
      batchId,
      project: { id: project.id, title: project.title },
      notes: state.notes,
      snapshots: state.snapshots,
      noteIds: ids,
      directive: body.directive ?? { mode: "apply", note: "" },
      now: new Date().toISOString(),
      revision: gitRevision(project.cwd),
      world: project.world,
    });
    const files: Array<{ name: string; base64: string }> = [];
    for (const group of pkg.groups) {
      const file = join(this.folder(project.id), `${group.snapshot.id}.jpg`);
      group.cleanFileName = "";
      if (existsSync(file)) files.push({ name: group.compositeFileName, base64: readFileSync(file).toString("base64") });
      else group.compositeFileName = "";
    }
    api.inbox.save(project.id, { batchId, message: messageText(pkg), manifest: manifestOf(pkg), files });
    const run = api.startSend(project, batchId, { noteIds: [...ids], newThread: body.newThread });
    for (const note of state.notes) if (ids.has(note.id)) note.lastSentRevision = note.revision;
    this.prune(project.id);
    this.save(project.id);
    return run;
  }
}

interface UpdateRequest {
  discard?: boolean;
  /** Words in progress, from the desk. */
  heard?: string;
  /** All that was said, from the desk, when listening ends. */
  heardFinal?: string;
  /** Stop listening. */
  stop?: boolean;
  /** Start listening again. */
  listen?: boolean;
  /** Typed text. */
  text?: string;
  depth?: number;
  layer?: number;
}

function setText(note: Note, text: string, source: Note["textSource"]) {
  if (note.text === text) return;
  note.text = text;
  note.textSource = source;
  note.revision += 1;
}
