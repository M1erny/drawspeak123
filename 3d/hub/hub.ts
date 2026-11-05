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
}

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
  runOf(projectId: string): RunState | undefined;
  /** Starts the agent on a saved batch. */
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

export interface Hub {
  server: Server;
  port: number;
  inbox: Inbox;
  close(): Promise<void>;
}

export async function startHub(options: HubOptions): Promise<Hub> {
  const inbox = new Inbox(options.dataDir);
  const runs = new Map<string, { state: RunState; agent?: RunningAgent }>();
  const listeners = new Map<string, Set<ServerResponse>>();
  const desks = new Map<string, Set<ServerResponse>>();
  const live = new LiveMarks(options.dataDir, options.capture);
  const key = Buffer.from(options.key ?? hubKey(options.dataDir));
  let actualPort = options.port ?? 0;

  const emit = (projectId: string, event: string, data: unknown) => {
    const line = `event: ${event}\ndata: ${JSON.stringify(data)}\n\n`;
    for (const res of listeners.get(projectId) ?? []) res.write(line);
  };
  const broadcast = (projectId: string) => emit(projectId, "run", runs.get(projectId)?.state ?? null);

  const api: HubApi = {
    projects: options.projects,
    inbox,
    runOf: (projectId) => runs.get(projectId)?.state,
    startSend: (project, batchId, body) => {
      if (runs.get(project.id)?.state.status === "running") throw Object.assign(new Error("The agent is still working on the last batch."), { status: 409 });
      const message = inbox.message(project.id, batchId);
      const manifest = inbox.manifest(project.id, batchId);
      const state: RunState = { id: randomUUID(), batchId, status: "running", agent: agentFor(project).label, startedAt: new Date().toISOString(), activity: [], noteIds: body.noteIds };
      runs.set(project.id, { state });
      try {
        startRun(project, batchId, message, manifest.directive?.mode ?? "apply", body.newThread ? undefined : inbox.thread(project.id), state);
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
        res.write(`event: run\ndata: ${JSON.stringify(runs.get(project.id)?.state ?? null)}\n\n`);
        const set = listeners.get(project.id) ?? new Set();
        listeners.set(project.id, set);
        set.add(res);
        const desk = url.searchParams.has("desk") ? (desks.get(project.id) ?? new Set<ServerResponse>()) : undefined;
        if (desk) {
          desks.set(project.id, desk);
          desk.add(res);
        }
        const beat = setInterval(() => res.write(": still here\n\n"), 25_000);
        req.on("close", () => {
          clearInterval(beat);
          set.delete(res);
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
      if (req.method === "POST" && what === "stop") {
        const current = runs.get(project.id);
        if (current?.state.status === "running") {
          current.agent?.stop();
          json(200, { stopped: true });
        } else json(200, { stopped: false });
        return;
      }
      json(404, { error: "Nothing here." });
    } catch (error) {
      const status = (error as { status?: number }).status ?? 400;
      json(status, { error: error instanceof Error ? error.message : String(error) });
    }
  }

  function startRun(project: Project, batchId: string, message: string, mode: string, resume: string | undefined, state: RunState) {
    const entry = runs.get(project.id)!;
    const before = gitChanged(project.cwd);
    const files = new Set<string>();
    const folder = inbox.folderOf(project.id, batchId);
    const agent = agentFor(project);
    let stopped = false;
    const start = (resumeFrom: string | undefined) =>
      agent.start({
        project,
        folder,
        message: `${message}\n\nThe batch is in ${folder} (manifest.json and these pictures: ${inbox.pictures(project.id, batchId).filter((f) => !f.includes("-clean")).join(", ")}).`,
        mode,
        resume: resumeFrom,
        onActivity: (line) => {
          state.activity.push(line);
          if (state.activity.length > 40) state.activity.shift();
          broadcast(project.id);
        },
        onChangedFile: (file) => files.add(file),
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
      for (const file of gitChanged(project.cwd)) if (!before.has(file)) files.add(file);
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
    close: () =>
      new Promise((resolve) => {
        for (const set of listeners.values()) for (const res of set) res.end();
        for (const { agent } of runs.values()) agent?.stop();
        stopCapture();
        server.close(() => resolve());
        server.closeAllConnections();
      }),
  };
}
