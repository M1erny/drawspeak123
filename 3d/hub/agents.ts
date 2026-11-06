import { execFile, execFileSync, spawn, type ChildProcess } from "node:child_process";
import { existsSync, readdirSync, statSync } from "node:fs";
import { homedir } from "node:os";
import { isAbsolute, join, relative } from "node:path";
import { fileURLToPath } from "node:url";
import type { Project } from "./data.ts";

/**
 * Running a coding agent on a batch. The agent gets the message on stdin, works in the project's
 * folder, and reports as it goes; the page shows that in its card. Only a person pressing
 * Send to Agent starts one.
 */
export interface AgentJob {
  project: Project;
  /** The batch's folder (pictures, manifest). */
  folder: string;
  message: string;
  /** "apply" may edit files, "replyOnly" may only read. */
  mode: string;
  /** Carry on this conversation. */
  resume?: string;
  /** For the commands it runs (how look.mjs finds the page that is open). */
  env?: Record<string, string>;
  onActivity(line: string): void;
  onChangedFile(path: string): void;
}

export interface AgentResult {
  ok: boolean;
  reply?: string;
  error?: string;
  sessionId?: string;
}

export interface RunningAgent {
  done: Promise<AgentResult>;
  stop(): void;
}

export interface Agent {
  id: string;
  label: string;
  available(): boolean;
  /** Why it cannot run right now, in words a person can act on. Answers at once from what it last learned. */
  problem(): string | undefined;
  start(job: AgentJob): RunningAgent;
}

/**
 * Quick and sharp enough for edits in a world. On a real request (a bench in the store) it had finished
 * saving after 39 seconds, against Opus's 93 and Haiku's 85. DRAWSPEAK_MODEL, or "model" in a project, changes it.
 */
export const DEFAULT_MODEL = "sonnet";

/** The agent's eyes: how a world on a web page looks now, from a view. */
export const LOOK = fileURLToPath(new URL("./look.mjs", import.meta.url)).replace(/\\/g, "/");
const READ_TOOLS = ["Read", "Glob", "Grep"];
const EDIT_TOOLS = ["Edit", "MultiEdit", "Write", "TodoWrite"];

/** The Claude Code command line for a job. */
export function claudeArgs(job: Pick<AgentJob, "project" | "folder" | "mode" | "resume">): string[] {
  const editing = job.mode !== "replyOnly";
  // Roblox has no page to open: its project's note says how to see a result there.
  const looks = editing && !job.project.roblox;
  const bash = editing ? [...job.project.allowedBash, ...(looks ? [`node ${LOOK}`] : [])] : [];
  const tools = [...READ_TOOLS, ...(editing ? EDIT_TOOLS : []), ...bash.map((command) => `Bash(${command}:*)`)];
  const after = `${job.folder.replace(/\\/g, "/")}/after-1.png`;
  const rules = [
    "You are receiving feedback from Drawspeak 3D: a person walked through a running 3D world, marked things and places on screen and said what should change.",
    "Look at the pictures in the batch folder with the Read tool before changing anything. Someone is standing in this world waiting to see the change, so read what you need together, in one step, then make it.",
    looks ? `After changing the world, see it as the reviewer will before you finish: run node ${LOOK} "<the view's Open this view link>" "${after}" (usually a few seconds, and it prints any errors on the page), read that picture and compare it with the reviewer's. If something is not right (in the wrong place, floating or sunk into the floor, in the way, facing the wrong way, or the page broke), fix it and look again, twice at most.` : "",
    bash.length > 0 ? `The only shell commands you can run are these, exactly as written, from the folder you are in, with no cd or anything else around them: ${bash.map((command) => `${command}`).join("; ")}. Git is not among them. Run your checks once, at the end.` : "",
    editing ? "Other agents may be working in this same folder at the same time, on other comments from the same person, and every save reloads the running world. So read a file again right before you edit it, keep your edits small, and never rewrite a whole file that already exists. Leave changes you did not make alone, even if they look unfinished. If something breaks in code you did not touch, say so in your reply rather than fixing it." : "",
    "Do not commit, push, publish, deploy or restart anything.",
    "When you finish, reply in two or three plain sentences, in the language the comments are in: what you changed and anything they should check. It is shown in a small card over the game.",
    job.project.agentNote ?? "",
  ].filter(Boolean).join("\n");
  const args = [
    "-p",
    "--output-format", "stream-json",
    "--verbose",
    "--permission-mode", job.mode === "replyOnly" ? "default" : "acceptEdits",
    "--add-dir", job.folder,
    "--allowedTools", tools.join(","),
    "--append-system-prompt", rules,
  ];
  args.push("--model", process.env.DRAWSPEAK_MODEL ?? job.project.model ?? DEFAULT_MODEL);
  if (job.resume) args.push("--resume", job.resume);
  return args;
}

/** What a run has said so far, from Claude Code's stream of JSON lines. */
export class ClaudeStream {
  reply?: string;
  sessionId?: string;
  failure?: string;
  private readonly job: Pick<AgentJob, "project" | "onActivity" | "onChangedFile">;

  constructor(job: Pick<AgentJob, "project" | "onActivity" | "onChangedFile">) {
    this.job = job;
  }

  line(line: string) {
    if (!line.trim()) return;
    let event: { type?: string; subtype?: string; session_id?: string; is_error?: boolean; result?: string; message?: { content?: Array<{ type: string; text?: string; name?: string; input?: Record<string, unknown> }> } };
    try {
      event = JSON.parse(line);
    } catch {
      return; // not a line of the stream
    }
    if (event.session_id) this.sessionId = event.session_id;
    if (event.type === "assistant") {
      for (const block of event.message?.content ?? []) {
        if (block.type === "tool_use" && block.name) {
          const { line: text, file } = describeToolUse(block.name, block.input ?? {}, this.job.project.cwd);
          this.job.onActivity(text);
          if (file) this.job.onChangedFile(file);
        } else if (block.type === "text" && block.text?.trim()) {
          this.job.onActivity(block.text.trim().split("\n")[0].slice(0, 110));
        }
      }
    }
    if (event.type === "result") {
      if (event.is_error) this.failure = event.result ?? event.subtype ?? "The agent reported an error.";
      else this.reply = event.result;
    }
  }
}

/** One line of the agent's stream, as what the person sees. */
export function describeToolUse(name: string, input: Record<string, unknown>, cwd: string): { line: string; file?: string } {
  const path = typeof input.file_path === "string" ? input.file_path : undefined;
  const short = path ? (isAbsolute(path) ? relative(cwd, path).replace(/\\/g, "/") : path) : undefined;
  switch (name) {
    case "Read":
      if (/after-\d+\.png$/.test(short ?? "")) return { line: "Looking at the result" };
      return { line: short?.startsWith("..") ? "Looking at your picture" : `Reading ${short}` };
    case "Edit":
    case "MultiEdit":
      return { line: `Editing ${short}`, file: short };
    case "Write":
      return { line: `Writing ${short}`, file: short };
    case "Grep":
      return { line: `Searching for ${String(input.pattern ?? "").slice(0, 40)}` };
    case "Glob":
      return { line: `Looking for ${String(input.pattern ?? "").slice(0, 40)}` };
    case "Bash":
      return { line: /look\.mjs|store-preview/.test(String(input.command)) ? "Looking at the result" : `Running ${String(input.command ?? "").slice(0, 50)}` };
    case "TodoWrite":
      return { line: "Planning" };
    default:
      return { line: name };
  }
}

/** Claude Code, from the PATH or from the desktop app's own copy. */
export function findClaude(): string | undefined {
  const fromEnv = process.env.DRAWSPEAK_CLAUDE;
  if (fromEnv && existsSync(fromEnv)) return fromEnv;
  try {
    const lines = execFileSync(process.platform === "win32" ? "where" : "which", ["claude"], { encoding: "utf8", stdio: ["ignore", "pipe", "ignore"], windowsHide: true }).split(/\r?\n/).map((l) => l.trim()).filter(Boolean);
    const found = process.platform === "win32" ? (lines.find((l) => /\.exe$/i.test(l)) ?? lines.find((l) => /\.cmd$/i.test(l))) : lines[0];
    if (found) return found;
  } catch {
    // not on the PATH
  }
  const appData = process.env.APPDATA ?? join(homedir(), "AppData", "Roaming");
  const root = join(appData, "Claude", "claude-code");
  if (!existsSync(root)) return undefined;
  const versions = readdirSync(root).sort((a, b) => b.localeCompare(a, undefined, { numeric: true }));
  for (const version of versions) {
    const versionDir = join(root, version);
    if (!statSync(versionDir).isDirectory()) continue;
    for (const build of readdirSync(versionDir)) {
      const exe = join(versionDir, build, process.platform === "win32" ? "claude.exe" : "claude");
      if (existsSync(exe)) return exe;
    }
    const direct = join(versionDir, process.platform === "win32" ? "claude.exe" : "claude");
    if (existsSync(direct)) return direct;
  }
  return undefined;
}

/** npm's claude.cmd can only be started through a shell, which needs every argument quoted. */
export function startOptions(exe: string, args: string[]): { command: string; args: string[]; shell: boolean } {
  if (!/\.cmd$/i.test(exe)) return { command: exe, args, shell: false };
  const quote = (value: string) => `"${value.replace(/"/g, '""').replace(/%/g, "%%").replace(/\r?\n/g, " ")}"`;
  return { command: `"${exe}"`, args: args.map(quote), shell: true };
}

/**
 * The environment for a child Claude Code. A hub started from a terminal passes everything on. A hub
 * started from inside a Claude Code session has that session's settings in its environment, and they
 * would make the child a part of that session: no login of its own, its proxy, its limits.
 */
export function childEnvironment(env: NodeJS.ProcessEnv): NodeJS.ProcessEnv {
  if (env.CLAUDECODE === undefined && env.CLAUDE_CODE_ENTRYPOINT === undefined) return { ...env };
  const clean: NodeJS.ProcessEnv = {};
  for (const [name, value] of Object.entries(env)) {
    if (/^(CLAUDECODE$|CLAUDE_CODE_|CLAUDE_AGENT_SDK_|CLAUDE_EFFORT$|CLAUDE_PID$|CLAUDE_PREVIEW_|ANTHROPIC_BASE_URL$|USE_LOCAL_OAUTH$|USE_STAGING_OAUTH$)/.test(name)) continue;
    clean[name] = value;
  }
  return clean;
}

function killTree(child: ChildProcess) {
  if (!child.pid) return;
  if (process.platform === "win32") {
    try {
      execFileSync("taskkill", ["/pid", String(child.pid), "/T", "/F"], { stdio: "ignore", windowsHide: true });
    } catch {
      // already gone
    }
  } else child.kill("SIGTERM");
}

const NOT_SIGNED_IN = "Claude Code is not signed in on the command line. Run npm run login in drawspeak123/3d, once.";

/** Whether the command line is signed in, asked in the background: it takes a second, and the page should not wait. */
let signedIn: boolean | undefined;
let asking = false;
let askedAt = 0;
function askSignedIn() {
  const exe = findClaude();
  // Once signed in, it stays so; until then, look again soon: they may be signing in right now.
  if (!exe || asking || Date.now() - askedAt < (signedIn ? 600_000 : 4_000)) return;
  asking = true;
  askedAt = Date.now();
  const start = startOptions(exe, ["auth", "status"]);
  execFile(start.command, start.args, { env: childEnvironment(process.env), windowsHide: true, timeout: 20_000, shell: start.shell }, (_error, stdout) => {
    asking = false;
    try {
      signedIn = (JSON.parse(stdout) as { loggedIn?: boolean }).loggedIn === true;
    } catch {
      // an older Claude Code, or something else on stdout: let a run find out
      signedIn = undefined;
    }
  });
}

export const claudeAgent: Agent = {
  id: "claude",
  label: "Claude Code",
  available: () => findClaude() !== undefined,
  problem() {
    askSignedIn();
    return signedIn === false ? NOT_SIGNED_IN : undefined;
  },
  start(job) {
    const exe = findClaude();
    if (!exe) return { done: Promise.resolve({ ok: false, error: "Claude Code was not found." }), stop() {} };
    const start = startOptions(exe, claudeArgs(job));
    // look.mjs opens only this project's own pages.
    const env = { ...childEnvironment(process.env), DRAWSPEAK_LOOK_ORIGINS: job.project.origins.join(","), ...job.env };
    const child = spawn(start.command, start.args, { cwd: job.project.cwd, env, stdio: ["pipe", "pipe", "pipe"], windowsHide: true, shell: start.shell });
    child.stdin!.end(job.message);
    let buffer = "";
    let stderr = "";
    const stream = new ClaudeStream(job);
    child.stdout!.setEncoding("utf8").on("data", (chunk: string) => {
      buffer += chunk;
      let at: number;
      while ((at = buffer.indexOf("\n")) >= 0) {
        stream.line(buffer.slice(0, at));
        buffer = buffer.slice(at + 1);
      }
    });
    child.stderr!.setEncoding("utf8").on("data", (chunk: string) => {
      stderr = (stderr + chunk).slice(-2000);
    });
    const done = new Promise<AgentResult>((resolve) => {
      child.on("error", (error) => resolve({ ok: false, error: error.message }));
      child.on("close", (code) => {
        stream.line(buffer);
        const error = stream.failure ?? (code !== 0 && stream.reply === undefined ? stderr.trim().slice(-400) || `Claude Code ended with code ${code}.` : undefined);
        // The desktop app signs in for itself; the command line needs its own login, once.
        if (error && /not logged in|\/login/i.test(error)) {
          signedIn = false;
          resolve({ ok: false, error: NOT_SIGNED_IN });
        } else if (error) resolve({ ok: false, error, sessionId: stream.sessionId });
        else resolve({ ok: true, reply: stream.reply, sessionId: stream.sessionId });
      });
    });
    return { done, stop: () => killTree(child) };
  },
};

/** A stand-in for tests: no model, no cost, changes nothing. */
export const fakeAgent: Agent = {
  id: "fake",
  label: "Fake agent",
  available: () => true,
  problem: () => undefined,
  start(job) {
    let stopped: ((result: AgentResult) => void) | undefined;
    const timers: Array<ReturnType<typeof setTimeout>> = [];
    const delay = Number(process.env.DRAWSPEAK_FAKE_MS ?? 300);
    const done = new Promise<AgentResult>((resolve) => {
      stopped = resolve;
      timers.push(setTimeout(() => job.onActivity("Looking at your picture"), delay));
      let saw = Promise.resolve("");
      timers.push(setTimeout(() => {
        job.onActivity("Editing client/world/products.ts");
        job.onChangedFile("client/world/products.ts");
        const link = /Open this view: (\S+)/.exec(job.message)?.[1];
        if (process.env.DRAWSPEAK_FAKE_LOOK && link) {
          job.onActivity("Looking at the result");
          saw = new Promise((seen) => {
            execFile(process.execPath, [fileURLToPath(new URL("./look.mjs", import.meta.url)), link, join(job.folder, "after-1.png")], { env: { ...process.env, ...job.env }, windowsHide: true }, (_error, stdout) => seen(` ${stdout.trim().split("\n")[0]}`));
          });
        }
      }, delay * 2));
      timers.push(setTimeout(() => {
        void saw.then((looked) => resolve({ ok: true, reply: `Stand-in reply. I got ${(job.message.match(/^\d+\. \[/gm) ?? []).length} comment(s).${job.resume ? " Carried on." : ""}${job.message.includes("Other agents are at work") ? " Knows about the others." : ""}${job.message.includes("Earlier in this session") ? " Knows what came before." : ""}${looked}`, sessionId: "fake-session" }));
      }, delay * 3));
    });
    return {
      done,
      stop() {
        timers.forEach(clearTimeout);
        stopped?.({ ok: false, error: "stopped" });
      },
    };
  },
};

export function agentFor(project: Project): Agent {
  const id = process.env.DRAWSPEAK_AGENT ?? project.agent ?? "claude";
  return id === "fake" ? fakeAgent : claudeAgent;
}
