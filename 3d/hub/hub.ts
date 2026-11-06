import { randomUUID, timingSafeEqual } from "node:crypto";
import { createReadStream, existsSync } from "node:fs";
import { createServer, type IncomingMessage, type Server, type ServerResponse } from "node:http";
import { basename, extname, join } from "node:path";
import { stripTypeScriptTypes } from "node:module";
import { readFileSync } from "node:fs";
import { LOOK, agentFor, type RunningAgent } from "./agents.ts";
import { Inbox, gitChanged, gitRevision, here, hubKey, type Project } from "./data.ts";
import { LiveMarks, stopCapture, type CaptureFn } from "./live.ts";

/**
 * The hub: a small program on your own computer, between the world you are walking through and the
 * coding agent. It keeps each batch as a folder and runs the agent when you press Send.
 *
 * It can start an agent that edits files, so who may talk to it matters. It only listens on this
 * computer; a web page may only reach it from an origin listed for its project (a browser always
 * says where a page is from, and a site cannot fake that); and a request must name this computer as
 * its host, which stops other sites from reaching it through DNS tricks. A program without an origin
 * (the Roblox Studio plugin) must show the hub's key to change anything: scripts in a Roblox place can
 * reach this computer's ports during a test, and do not have the key.
 */
export interface RunState {
  id: string;
  batchId: string;
  status: "running" | "done" | "failed" | "stopped";
  agent: string;
  startedAt: string;
  endedAt?: string;
  activity: string[];
  reply?: string;
  changed?: string[];
  error?: string;
  noteIds?: string[];
  /** What it was asked, in a few words. */
  about?: string;
  /** Files another agent changed too, while both were at work: worth a look. */
  shared?: string[];
}

/** One agent's run. Several can work on a project at once, in the same folder, so that every edit shows up in the running world. */
interface RunEntry {
  state: RunState;
  agent?: RunningAgent;
  /** The files its agent has changed. */
  files: Set<string>;
  /** Another agent worked at the same time, so the folder's changes are not all its own. */
  alongside: boolean;
  comments: string[];
}

/** Agents at work on one project at a time. Each one uses the person's own Claude plan. */
export const MAX_AGENTS = 3;
const RUNS_KEPT = 12;

/** The words of a batch's comments, from its manifest. */
function commentsOf(manifest: unknown): string[] {
  const { snapshots } = manifest as { snapshots?: Array<{ notes?: Array<{ text?: string }> }> };
  return (snapshots ?? []).flatMap((view) => view.notes ?? []).map((note) => note.text?.trim() ?? "").filter(Boolean);
}

const shortly = (text: string, length: number) => (text.length > length ? `${text.slice(0, length - 1).trimEnd()}…` : text);

export interface HubOptions {
  port?: number;
  projects: Map<string, Project>;
  dataDir: string;
  /** A stand-in for taking a picture of the Roblox window (tests). */
  capture?: CaptureFn;
  /** The key programs without an Origin must show. Default: kept in the data folder. */
  key?: string;
}

/** What other parts of the hub can do. */
export interface HubApi {
  projects: Map<string, Project>;
  inbox: Inbox;
  /** A project's runs, oldest first: those at work, and the last few that finished. */
  runsOf(projectId: string): RunState[];
  /** Starts an agent on a saved batch, alongside any already at work. */
  startSend(project: Project, batchId: string, body: { noteIds?: string[]; newThread?: boolean }): RunState;
  /** An event for the pages listening on a project. */
  emit(projectId: string, event: string, data: unknown): void;
  /** How many desk pages are open for a project: they hold the microphone. */
  deskCount(projectId: string): number;
}

export interface HubRequest {
  req: IncomingMessage;
  res: ServerResponse;
  url: URL;
  project?: Project;
  /** The path's parts. */
  parts: string[];
  json(status: number, body: unknown): void;
  readJson<T>(limit?: number): Promise<T>;
}

const BODY_LIMIT = 96 * 1024 * 1024;
/** How long a page may take to answer. It may have to reload first. */
const LOOK_WAIT_MS = 14_000;
/** A page that is reloading is back in a moment. */
const PAGE_BACK_MS = 3000;
/** What a new conversation is told about the last few that finished. */
const EARLIER_RUNS = 3;
const EARLIER_MS = 30 * 60_000;

export interface Hub {
  server: Server;
  port: number;
  inbox: Inbox;
  /** What an agent shows to get a picture from the page that is open. */
  lookToken: string;
  close(): Promise<void>;
}

export async function startHub(options: HubOptions): Promise<Hub> {
  const inbox = new Inbox(options.dataDir);
  const runs = new Map<string, RunEntry[]>();
  const listeners = new Map<string, Set<ServerResponse>>();
  const desks = new Map<string, Set<ServerResponse>>();
  const live = new LiveMarks(options.dataDir, options.capture);
  const key = Buffer.from(options.key ?? hubKey(options.dataDir));
  const lookToken = randomUUID();
  const looks = new Map<string, (answer: unknown) => void>();
  /** The pages with the tool on them, as against desks. */
  const pages = new Map<string, Set<ServerResponse>>();
  let actualPort = options.port ?? 0;

  const emit = (projectId: string, event: string, data: unknown) => {
    const line = `event: ${event}\ndata: ${JSON.stringify(data)}\n\n`;
    for (const res of listeners.get(projectId) ?? []) res.write(line);
  };
  const runsOf = (projectId: string) => (runs.get(projectId) ?? []).map((entry) => entry.state);
  const atWork = (projectId: string) => (runs.get(projectId) ?? []).filter((entry) => entry.state.status === "running");
  const broadcast = (projectId: string) => emit(projectId, "runs", runsOf(projectId));

  const api: HubApi = {
    projects: options.projects,
    inbox,
    runsOf,
    startSend: (project, batchId, body) => {
      const others = atWork(project.id);
      if (others.some((entry) => entry.state.batchId === batchId)) throw Object.assign(new Error("An agent is already working on these comments."), { status: 409 });
      if (others.length >= MAX_AGENTS) throw Object.assign(new Error(`${MAX_AGENTS} agents are already working here. Wait for one to finish, or stop one.`), { status: 409 });
      const message = inbox.message(project.id, batchId);
      const manifest = inbox.manifest(project.id, batchId);
      const comments = commentsOf(manifest);
      const about = comments[0] ? `${shortly(comments[0], 60)}${comments.length > 1 ? ` +${comments.length - 1}` : ""}` : undefined;
      const state: RunState = { id: randomUUID(), batchId, status: "running", agent: agentFor(project).label, startedAt: new Date().toISOString(), activity: [], noteIds: body.noteIds, about };
      const entry: RunEntry = { state, files: new Set(), alongside: others.length > 0, comments };
      for (const other of others) other.alongside = true;
      const list = runs.get(project.id) ?? [];
      runs.set(project.id, list);
      list.push(entry);
      while (list.length > RUNS_KEPT) {
        const old = list.findIndex((run) => run.state.status !== "running");
        if (old < 0) break;
        list.splice(old, 1);
      }
      try {
        // One conversation cannot be carried on in two places at once.
        const resume = body.newThread || others.length > 0 ? undefined : inbox.thread(project.id);
        const nearby = others.flatMap((other) => other.comments).slice(0, 8).map((comment) => shortly(comment, 120));
        // A new conversation starts light, but "make it bigger" should still mean something.
        const earlier = resume
          ? []
          : runsOf(project.id)
              .filter((run) => run.status === "done" && run.reply && Date.now() - Date.parse(run.endedAt ?? run.startedAt) < EARLIER_MS)
              .slice(-EARLIER_RUNS)
              .map((run) => `"${shortly(run.about ?? "", 90)}": ${shortly(run.reply ?? "", 240)}`);
        startRun(project, batchId, earlier.length > 0 ? [message, "", "Earlier in this session, for context (all of it is done):", ...earlier.map((line) => `- ${line}`)].join("\n") : message, manifest.directive?.mode ?? "apply", resume, entry, nearby);
      } catch (error) {
        // It never started: say so, and do not stay "running" for ever.
        state.status = "failed";
        state.endedAt = new Date().toISOString();
        state.error = error instanceof Error ? error.message : String(error);
      }
      broadcast(project.id);
      return state;
    },
    emit,
    deskCount: (projectId) => desks.get(projectId)?.size ?? 0,
  };

  const allOrigins = () => new Set([...options.projects.values()].flatMap((p) => p.origins));
  const selfOrigins = () => [`http://127.0.0.1:${actualPort}`, `http://localhost:${actualPort}`];

  const server = createServer((req, res) => {
    void handle(req, res).catch((error) => {
      console.error("[hub]", error);
      if (!res.headersSent) res.writeHead(500, { "content-type": "application/json" });
      res.end(JSON.stringify({ error: "The hub hit an error." }));
    });
  });

  async function handle(req: IncomingMessage, res: ServerResponse) {
    // DNS rebinding: a site whose name points here would send its own name as the host.
    const host = (req.headers.host ?? "").toLowerCase();
    if (!/^(127\.0\.0\.1|localhost|\[::1\])(:\d+)?$/.test(host)) {
      res.writeHead(403).end();
      return;
    }
    const url = new URL(req.url ?? "/", `http://${host}`);
    // A page on another site can still make its browser ask for things (an image tag, say), with no
    // Origin: that is no business of the hub's. Only attach.js is meant for that, and a link to the desk.
    if (!req.headers.origin && req.headers["sec-fetch-site"] === "cross-site" && url.pathname !== "/attach.js" && !(url.pathname === "/desk" && req.headers["sec-fetch-mode"] === "navigate")) {
      res.writeHead(403).end();
      return;
    }
    const parts = url.pathname.split("/").filter(Boolean).map(decodeURIComponent);
    const projectId = parts[0] === "v1" && parts[1] === "projects" ? parts[2] : undefined;
    const project = projectId ? options.projects.get(projectId) : undefined;

    const origin = req.headers.origin;
    if (origin) {
      const allowed = selfOrigins().includes(origin) || (project ? project.origins.includes(origin) : allOrigins().has(origin));
      if (!allowed) {
        res.writeHead(403, { "content-type": "application/json" }).end(JSON.stringify({ error: `${origin} may not use this hub. Add it to the project's origins in hub/projects.json.` }));
        return;
      }
      res.setHeader("access-control-allow-origin", origin);
      res.setHeader("vary", "origin");
    }
    if (req.method === "OPTIONS") {
      res.writeHead(204, { "access-control-allow-methods": "GET, POST", "access-control-allow-headers": "content-type", "access-control-max-age": "600" }).end();
      return;
    }
    if (!origin && req.method !== "GET") {
      const shown = Buffer.from(String(req.headers["x-drawspeak-key"] ?? ""));
      if (shown.length !== key.length || !timingSafeEqual(shown, key)) {
        res.writeHead(401, { "content-type": "application/json" }).end(JSON.stringify({ error: "This needs the hub's key. For the Roblox plugin: npm run roblox:install, in drawspeak123/3d." }));
        return;
      }
    }

    const json = (status: number, body: unknown) => {
      res.writeHead(status, { "content-type": "application/json; charset=utf-8" }).end(JSON.stringify(body));
    };
    const readJson = async <T>(limit = BODY_LIMIT): Promise<T> => {
      // A page cannot send this content type across origins without asking first.
      if (!(req.headers["content-type"] ?? "").includes("application/json")) throw Object.assign(new Error("Send JSON."), { status: 415 });
      const chunks: Buffer[] = [];
      let size = 0;
      for await (const chunk of req as AsyncIterable<Buffer>) {
        size += chunk.length;
        if (size > limit) throw Object.assign(new Error("Too large."), { status: 413 });
        chunks.push(chunk);
      }
      return JSON.parse(Buffer.concat(chunks).toString("utf8")) as T;
    };

    try {
      if (req.method === "GET" && parts.length === 0) {
        json(200, { name: "drawspeak3d hub", projects: [...options.projects.values()].map((p) => ({ id: p.id, title: p.title })) });
        return;
      }
      if (req.method === "GET" && url.pathname === "/attach.js") {
        const file = join(here, "..", "dist", "attach.js");
        if (!existsSync(file)) {
          json(404, { error: "Not built: npm run build:attach" });
          return;
        }
        res.writeHead(200, { "content-type": "text/javascript; charset=utf-8", "cross-origin-resource-policy": "cross-origin", "cache-control": "no-store" });
        createReadStream(file).pipe(res);
        return;
      }
      if (req.method === "GET" && url.pathname === "/desk") {
        res.writeHead(200, { "content-type": "text/html; charset=utf-8", "cache-control": "no-store" });
        createReadStream(join(here, "desk.html")).pipe(res);
        return;
      }
      if (req.method === "GET" && url.pathname === "/desk/speech.js") {
        // The same speech code as in the browser tool, types stripped.
        const source = readFileSync(join(here, "..", "src", "voice", "speech.ts"), "utf8");
        res.writeHead(200, { "content-type": "text/javascript; charset=utf-8", "cache-control": "no-store" });
        res.end(stripTypeScriptTypes(source));
        return;
      }
      if (await live.route({ req, res, url, project, parts, json, readJson }, api)) return;
      if (projectId === undefined) {
        json(404, { error: "Nothing here." });
        return;
      }
      if (!project) {
        json(404, { error: `No project "${projectId}" in hub/projects.json.` });
        return;
      }
      const [, , , what, batchId, action] = parts;

      if (req.method === "GET" && what === undefined) {
        const agent = agentFor(project);
        json(200, { id: project.id, title: project.title, folder: basename(project.cwd), revision: gitRevision(project.cwd), agent: { id: agent.id, label: agent.label, available: agent.available(), problem: agent.problem() } });
        return;
      }
      if (req.method === "GET" && what === "events") {
        res.writeHead(200, { "content-type": "text/event-stream", "cache-control": "no-store", connection: "keep-alive" });
        res.write(`event: runs\ndata: ${JSON.stringify(runsOf(project.id))}\n\n`);
        const set = listeners.get(project.id) ?? new Set();
        listeners.set(project.id, set);
        set.add(res);
        const page = url.searchParams.has("page") ? (pages.get(project.id) ?? new Set<ServerResponse>()) : undefined;
        if (page) {
          pages.set(project.id, page);
          page.add(res);
        }
        const desk = url.searchParams.has("desk") ? (desks.get(project.id) ?? new Set<ServerResponse>()) : undefined;
        if (desk) {
          desks.set(project.id, desk);
          desk.add(res);
        }
        const beat = setInterval(() => res.write(": still here\n\n"), 25_000);
        req.on("close", () => {
          clearInterval(beat);
          set.delete(res);
          page?.delete(res);
          if (desk?.delete(res) && desk.size === 0) live.desksGone(project.id);
        });
        return;
      }
      if (req.method === "GET" && what === "batches" && !batchId) {
        json(200, { batches: inbox.list(project.id) });
        return;
      }
      if (req.method === "GET" && what === "batches" && batchId && !action) {
        json(200, { batchId, message: inbox.message(project.id, batchId), manifest: inbox.manifest(project.id, batchId), pictures: inbox.pictures(project.id, batchId) });
        return;
      }
      if (req.method === "POST" && what === "batches" && !batchId) {
        const batch = await readJson<{ batchId: string; message: string; manifest: unknown; files: Array<{ name: string; dataUrl?: string; base64?: string }> }>();
        const folder = inbox.save(project.id, batch);
        json(200, { batchId: batch.batchId, folder, messageFile: join(folder, "message.md"), look: LOOK });
        return;
      }
      if (req.method === "POST" && what === "batches" && batchId && action === "send") {
        const body = await readJson<{ noteIds?: string[]; newThread?: boolean }>(1024 * 1024);
        json(200, api.startSend(project, batchId, body));
        return;
      }
      // An agent asks for a picture of a view; a page that is open draws it on the real graphics card.
      if (req.method === "GET" && what === "look") {
        const shown = Buffer.from(String(req.headers["x-drawspeak-look"] ?? ""));
        const token = Buffer.from(lookToken);
        if (shown.length !== token.length || !timingSafeEqual(shown, token)) {
          json(403, { error: "Only an agent of this hub can ask for that." });
          return;
        }
        for (const until = Date.now() + PAGE_BACK_MS; !pages.get(project.id)?.size && Date.now() < until; ) await new Promise((wait) => setTimeout(wait, 150));
        if (!pages.get(project.id)?.size) {
          json(404, { error: "No page is open." });
          return;
        }
        const id = randomUUID();
        const answer = await new Promise<unknown>((resolve) => {
          const timer = setTimeout(() => {
            looks.delete(id);
            resolve(undefined);
          }, LOOK_WAIT_MS);
          looks.set(id, (given) => {
            clearTimeout(timer);
            looks.delete(id);
            resolve(given);
          });
          emit(project.id, "look", { id, view: url.searchParams.get("view") ?? undefined });
        });
        if (answer) json(200, answer);
        else json(504, { error: "The open page did not answer." });
        return;
      }
      if (req.method === "POST" && what === "look" && batchId) {
        const answer = await readJson<{ image?: string; errors?: string[] }>();
        looks.get(batchId)?.(answer);
        json(200, { ok: true });
        return;
      }
      if (req.method === "POST" && what === "stop") {
        // One agent, by its run's id; with no id, all of them.
        const { runId } = await readJson<{ runId?: string }>(1024);
        const stopping = atWork(project.id).filter((entry) => !runId || entry.state.id === runId);
        for (const entry of stopping) entry.agent?.stop();
        json(200, { stopped: stopping.length > 0 });
        return;
      }
      json(404, { error: "Nothing here." });
    } catch (error) {
      const status = (error as { status?: number }).status ?? 400;
      json(status, { error: error instanceof Error ? error.message : String(error) });
    }
  }

  /** Two agents changed the same file while both were at work: each one's card says so. */
  function noteShared(projectId: string, entry: RunEntry, file: string) {
    for (const other of runs.get(projectId) ?? []) {
      if (other === entry || !other.files.has(file)) continue;
      const overlapped = other.state.status === "running" || Date.parse(other.state.endedAt ?? "") > Date.parse(entry.state.startedAt);
      if (!overlapped) continue;
      for (const run of [entry.state, other.state]) if (!run.shared?.includes(file)) run.shared = [...(run.shared ?? []), file];
    }
  }

  function startRun(project: Project, batchId: string, message: string, mode: string, resume: string | undefined, entry: RunEntry, nearby: string[]) {
    const { state, files } = entry;
    const before = gitChanged(project.cwd);
    const folder = inbox.folderOf(project.id, batchId);
    const agent = agentFor(project);
    let stopped = false;
    const start = (resumeFrom: string | undefined) =>
      agent.start({
        project,
        folder,
        message: `${message}\n\nThe batch is in ${folder} (manifest.json and these pictures: ${inbox.pictures(project.id, batchId).filter((f) => !f.includes("-clean")).join(", ")}).${nearby.length > 0 ? `\n\nOther agents are at work in this folder right now, on these comments, so leave those to them: ${nearby.map((comment) => `"${comment}"`).join("; ")}.` : ""}`,
        mode,
        resume: resumeFrom,
        env: { DRAWSPEAK_HUB: `http://127.0.0.1:${actualPort}`, DRAWSPEAK_PROJECT: project.id, DRAWSPEAK_LOOK_TOKEN: lookToken },
        onActivity: (line) => {
          state.activity.push(line);
          if (state.activity.length > 40) state.activity.shift();
          broadcast(project.id);
        },
        onChangedFile: (file) => {
          files.add(file);
          noteShared(project.id, entry, file);
        },
      });
    const running = start(resume);
    entry.agent = {
      done: running.done,
      stop: () => {
        stopped = true;
        running.stop();
      },
    };
    void (async () => {
      let result = await running.done;
      // A conversation that cannot be carried on (too old, from another machine): start a new one.
      if (!result.ok && resume && !stopped && /conversation|session/i.test(result.error ?? "")) {
        state.activity.push("Starting a new conversation");
        broadcast(project.id);
        const again = start(undefined);
        entry.agent = { done: again.done, stop: () => ((stopped = true), again.stop()) };
        result = await again.done;
      }
      // What else changed in the folder is its doing only if it worked alone.
      if (!entry.alongside) for (const file of gitChanged(project.cwd)) if (!before.has(file)) files.add(file);
      state.status = stopped ? "stopped" : result.ok ? "done" : "failed";
      state.endedAt = new Date().toISOString();
      state.reply = result.reply;
      state.error = stopped ? undefined : result.error;
      state.changed = [...files].filter((f) => extname(f) !== "" || f.includes("/")).sort();
      // Only a conversation that went somewhere is worth carrying on.
      if (result.ok && result.sessionId) inbox.setThread(project.id, result.sessionId);
      inbox.saveRun(project.id, batchId, state);
      if (result.reply) inbox.reply(project.id, batchId, result.reply);
      broadcast(project.id);
    })();
  }

  await new Promise<void>((resolve, reject) => {
    server.once("error", reject);
    server.listen(options.port ?? 0, "127.0.0.1", () => resolve());
  });
  const address = server.address();
  actualPort = typeof address === "object" && address ? address.port : 0;
  return {
    server,
    port: actualPort,
    inbox,
    lookToken,
    close: () =>
      new Promise((resolve) => {
        for (const set of listeners.values()) for (const res of set) res.end();
        for (const list of runs.values()) for (const { agent } of list) agent?.stop();
        stopCapture();
        server.close(() => resolve());
        server.closeAllConnections();
      }),
  };
}
