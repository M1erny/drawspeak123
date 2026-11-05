import { execFileSync } from "node:child_process";
import { randomBytes } from "node:crypto";
import { existsSync, mkdirSync, readFileSync, readdirSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { dirname, join, resolve, posix } from "node:path";
import { fileURLToPath } from "node:url";

/**
 * Projects and batches on disk. A batch is one plain folder: message.md, manifest.json and the
 * pictures. Any agent can read it, and nothing about it depends on the hub running.
 */
export interface Project {
  id: string;
  title: string;
  cwd: string;
  /** Web pages that may talk to the hub about this project. */
  origins: string[];
  /** Commands the agent may run, beyond reading and editing files. */
  allowedBash: string[];
  /** What the agent should know about this project. */
  agentNote?: string;
  /** Which agent runs: "claude" (default) or "fake" (tests). */
  agent?: string;
  /** The model for this project's agent, instead of its default. */
  model?: string;
  /** Marks from a Roblox Studio plugin belong to this project. */
  roblox?: boolean;
  /** What the world is, for the agent, when the hub builds the batch. */
  world?: { engine?: string; units?: string; up?: string; notes?: string };
}

export const here = dirname(fileURLToPath(import.meta.url));

export function loadProjects(folder = here): Map<string, Project> {
  const out = new Map<string, Project>();
  for (const file of ["projects.json", "projects.local.json"]) {
    const path = join(folder, file);
    if (!existsSync(path)) continue;
    const raw = JSON.parse(readFileSync(path, "utf8")) as Record<string, Partial<Project>>;
    for (const [id, p] of Object.entries(raw)) {
      const merged = { ...out.get(id), ...p, id } as Project;
      merged.cwd = resolve(folder, p.cwd ?? merged.cwd ?? ".");
      merged.title ??= id;
      merged.origins ??= [];
      merged.allowedBash ??= [];
      out.set(id, merged);
    }
  }
  return out;
}

export const defaultDataDir = () => process.env.DRAWSPEAK_DATA ?? join(homedir(), process.env.DRAWSPEAK_DATA_NAME ?? ".drawspeak3d");

/**
 * The key a program without an Origin must show to change anything. Web pages are told apart by their
 * Origin; a program could be anything that can reach this computer's ports, such as a script in a
 * Roblox place during a test. The Studio plugin gets the key when it is installed.
 */
export function hubKey(root: string): string {
  const file = join(root, "key");
  if (existsSync(file)) return readFileSync(file, "utf8").trim();
  mkdirSync(root, { recursive: true });
  const key = randomBytes(24).toString("hex");
  writeFileSync(file, key, { mode: 0o600 });
  return key;
}

const SAFE_ID = /^[A-Za-z0-9][A-Za-z0-9_-]{0,80}$/;
const SAFE_FILE = /^[A-Za-z0-9][A-Za-z0-9_-]{0,80}\.(jpg|jpeg|png|webp)$/;

export class Inbox {
  readonly root: string;

  constructor(root: string) {
    this.root = root;
  }

  folderOf(projectId: string, batchId: string): string {
    if (!SAFE_ID.test(projectId) || !SAFE_ID.test(batchId)) throw new Error("bad id");
    return join(this.root, projectId, "batches", batchId);
  }

  save(projectId: string, batch: { batchId: string; message: string; manifest: unknown; files: Array<{ name: string; dataUrl?: string; base64?: string }> }): string {
    const folder = this.folderOf(projectId, batch.batchId);
    if (typeof batch.message !== "string" || batch.message.length === 0) throw new Error("no message");
    for (const file of batch.files ?? []) if (!SAFE_FILE.test(file.name)) throw new Error(`bad file name: ${file.name}`);
    mkdirSync(folder, { recursive: true });
    writeFileSync(join(folder, "message.md"), batch.message);
    writeFileSync(join(folder, "manifest.json"), JSON.stringify(batch.manifest ?? {}, null, 2));
    for (const file of batch.files ?? []) {
      const base64 = file.base64 ?? file.dataUrl?.slice(file.dataUrl.indexOf(",") + 1);
      if (!base64) throw new Error(`empty file: ${file.name}`);
      writeFileSync(join(folder, file.name), Buffer.from(base64, "base64"));
    }
    return folder;
  }

  list(projectId: string): string[] {
    const folder = join(this.root, projectId, "batches");
    if (!SAFE_ID.test(projectId) || !existsSync(folder)) return [];
    return readdirSync(folder).sort().reverse();
  }

  pictures(projectId: string, batchId: string): string[] {
    return readdirSync(this.folderOf(projectId, batchId)).filter((f) => SAFE_FILE.test(f)).sort();
  }

  message(projectId: string, batchId: string): string {
    return readFileSync(join(this.folderOf(projectId, batchId), "message.md"), "utf8");
  }

  manifest(projectId: string, batchId: string): { directive?: { mode?: string } } {
    return JSON.parse(readFileSync(join(this.folderOf(projectId, batchId), "manifest.json"), "utf8"));
  }

  /** The conversation to carry on, per project. */
  thread(projectId: string): string | undefined {
    try {
      return (JSON.parse(readFileSync(join(this.root, projectId, "thread.json"), "utf8")) as { sessionId?: string }).sessionId;
    } catch {
      return undefined;
    }
  }

  setThread(projectId: string, sessionId: string) {
    mkdirSync(join(this.root, projectId), { recursive: true });
    writeFileSync(join(this.root, projectId, "thread.json"), JSON.stringify({ sessionId }));
  }

  saveRun(projectId: string, batchId: string, run: unknown) {
    writeFileSync(join(this.folderOf(projectId, batchId), "run.json"), JSON.stringify(run, null, 2));
  }

  reply(projectId: string, batchId: string, text: string) {
    writeFileSync(join(this.folderOf(projectId, batchId), "reply.md"), text);
  }
}

/** The commit a project is on, and whether it has changes on top. */
const revisions = new Map<string, { at: number; value: { commit?: string; dirty?: boolean } }>();
export function gitRevision(cwd: string): { commit?: string; dirty?: boolean } {
  const known = revisions.get(cwd);
  if (known && Date.now() - known.at < 5000) return known.value;
  const value = readRevision(cwd);
  revisions.set(cwd, { at: Date.now(), value });
  return value;
}

function readRevision(cwd: string): { commit?: string; dirty?: boolean } {
  try {
    const commit = execFileSync("git", ["-C", cwd, "rev-parse", "--short", "HEAD"], { encoding: "utf8", stdio: ["ignore", "pipe", "ignore"], windowsHide: true }).trim();
    const status = execFileSync("git", ["-C", cwd, "status", "--porcelain"], { encoding: "utf8", stdio: ["ignore", "pipe", "ignore"], windowsHide: true });
    return { commit, dirty: status.trim().length > 0 };
  } catch {
    return {};
  }
}

export function gitChanged(cwd: string): Set<string> {
  try {
    const git = (...args: string[]) => execFileSync("git", ["-C", cwd, ...args], { encoding: "utf8", stdio: ["ignore", "pipe", "ignore"], windowsHide: true });
    // Git names files from the top of the repository; the agent, from the project's folder inside it.
    const folder = git("rev-parse", "--show-prefix").trim();
    return new Set(git("status", "--porcelain").split("\n").filter(Boolean).map((line) => posix.relative(folder, line.slice(3).trim().replace(/^"|"$/g, ""))));
  } catch {
    return new Set();
  }
}
