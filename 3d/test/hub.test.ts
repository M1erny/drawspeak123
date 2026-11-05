import { mkdtempSync, readFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { ClaudeStream, LOOK, childEnvironment, claudeArgs, describeToolUse, startOptions } from "../hub/agents.ts";
import type { Project } from "../hub/data.ts";
import { startHub, type Hub } from "../hub/hub.ts";

process.env.DRAWSPEAK_AGENT = "fake";
process.env.DRAWSPEAK_FAKE_MS = "20";

const PAGE = "http://localhost:5180";
const project: Project = { id: "shop", title: "Shop", cwd: process.cwd(), origins: [PAGE], allowedBash: ["npm test"], agentNote: "A note." };
let hub: Hub;
let dir: string;
let base: string;

const pixel = "data:image/jpeg;base64,/9j/4AAQ";
const batch = (batchId: string, extra: object = {}) => ({ batchId, message: "1. [Loop] Większe\n", manifest: { directive: { mode: "apply" } }, files: [{ name: "01-a.jpg", dataUrl: pixel }], ...extra });
const post = (path: string, body: unknown, headers: Record<string, string> = { origin: PAGE }) =>
  fetch(`${base}${path}`, { method: "POST", headers: { "content-type": "application/json", ...headers }, body: JSON.stringify(body) });

async function runDone(id: string) {
  for (let i = 0; i < 100; i++) {
    const response = await fetch(`${base}/v1/projects/${id}/events`);
    const reader = response.body!.getReader();
    const { value } = await reader.read();
    await reader.cancel();
    const data = JSON.parse(/data: (.*)/.exec(new TextDecoder().decode(value))![1]);
    if (data && data.status !== "running") return data;
    await new Promise((r) => setTimeout(r, 25));
  }
  throw new Error("the run did not finish");
}

beforeAll(async () => {
  dir = mkdtempSync(join(tmpdir(), "ds3d-hub-"));
  hub = await startHub({ projects: new Map([["shop", project]]), dataDir: dir });
  base = `http://127.0.0.1:${hub.port}`;
});
afterAll(async () => {
  await hub.close();
  rmSync(dir, { recursive: true, force: true });
});

describe("who may talk to the hub", () => {
  it("the project's page may, with its origin echoed", async () => {
    const r = await fetch(`${base}/v1/projects/shop`, { headers: { origin: PAGE } });
    expect(r.status).toBe(200);
    expect(r.headers.get("access-control-allow-origin")).toBe(PAGE);
    expect((await r.json()).agent.id).toBe("fake");
  });
  it("another site may not, and cannot start the agent", async () => {
    const save = await post("/v1/projects/shop/batches", batch("evil1"), { origin: "https://evil.example" });
    expect(save.status).toBe(403);
    const read = await fetch(`${base}/v1/projects/shop`, { headers: { origin: "https://evil.example" } });
    expect(read.status).toBe(403);
    const send = await post("/v1/projects/shop/batches/evil1/send", {}, { origin: "https://evil.example" });
    expect(send.status).toBe(403);
  });
  it("a preflight from another site gets nothing", async () => {
    const r = await fetch(`${base}/v1/projects/shop/batches`, { method: "OPTIONS", headers: { origin: "https://evil.example", "access-control-request-method": "POST" } });
    expect(r.status).toBe(403);
    expect(r.headers.get("access-control-allow-origin")).toBeNull();
  });
  it("a request naming another host is refused (DNS rebinding)", async () => {
    const http = await import("node:http");
    const status = await new Promise<number>((resolve) => {
      const req = http.request({ host: "127.0.0.1", port: hub.port, path: "/v1/projects/shop", headers: { host: "evil.example" } }, (res) => resolve(res.statusCode!));
      req.end();
    });
    expect(status).toBe(403);
  });
  it("a program without an origin needs the key", async () => {
    const r = await post("/v1/projects/shop/batches", batch("nokey"), {});
    expect(r.status).toBe(401);
    expect((await post("/v1/projects/shop/batches/nokey/send", {}, {})).status).toBe(401);
    const key = readFileSync(join(dir, "key"), "utf8").trim();
    expect((await post("/v1/projects/shop/batches", batch("withkey"), { "x-drawspeak-key": key })).status).toBe(200);
  });
  it("another site's image tag gets nothing, and cannot pass for a desk", async () => {
    const r = await fetch(`${base}/v1/projects/shop/events?desk=1`, { headers: { "sec-fetch-site": "cross-site", "sec-fetch-mode": "no-cors" } });
    expect(r.status).toBe(403);
    const attach = await fetch(`${base}/attach.js`, { headers: { "sec-fetch-site": "cross-site", "sec-fetch-mode": "no-cors" } });
    expect(attach.status).not.toBe(403);
  });
  it("a plain form post cannot reach it: only JSON is read", async () => {
    const r = await fetch(`${base}/v1/projects/shop/batches`, { method: "POST", headers: { origin: PAGE, "content-type": "text/plain" }, body: "{}" });
    expect(r.status).toBe(415);
  });
});

describe("batches", () => {
  it("a batch becomes a folder", async () => {
    const r = await post("/v1/projects/shop/batches", batch("b1"));
    expect(r.status).toBe(200);
    const { folder, messageFile } = await r.json();
    expect(readFileSync(messageFile, "utf8")).toContain("Większe");
    expect(JSON.parse(readFileSync(join(folder, "manifest.json"), "utf8")).directive.mode).toBe("apply");
    expect(readFileSync(join(folder, "01-a.jpg")).length).toBeGreaterThan(0);
    expect((await (await fetch(`${base}/v1/projects/shop/batches`)).json()).batches).toContain("b1");
  });
  it("names cannot climb out of the folder", async () => {
    expect((await post("/v1/projects/shop/batches", batch("..\\..\\evil"))).status).toBe(400);
    expect((await post("/v1/projects/shop/batches", batch("b2", { files: [{ name: "..\\evil.jpg", dataUrl: pixel }] }))).status).toBe(400);
    expect((await post("/v1/projects/shop/batches", batch("b3", { files: [{ name: "run.exe", dataUrl: pixel }] }))).status).toBe(400);
  });
  it("an unknown project is an error", async () => {
    expect((await post("/v1/projects/nope/batches", batch("b4"))).status).toBe(404);
  });
});

describe("the agent", () => {
  it("runs on Send, reports, and remembers the conversation", async () => {
    await post("/v1/projects/shop/batches", batch("r1"));
    const r = await post("/v1/projects/shop/batches/r1/send", { noteIds: ["n1"] });
    expect(r.status).toBe(200);
    expect((await r.json()).status).toBe("running");
    const done = await runDone("shop");
    expect(done.status).toBe("done");
    expect(done.reply).toContain("1 comment");
    expect(done.changed).toContain("client/world/products.ts");
    expect(done.activity.length).toBeGreaterThan(0);
    expect(hub.inbox.thread("shop")).toBe("fake-session");
    expect(readFileSync(join(hub.inbox.folderOf("shop", "r1"), "reply.md"), "utf8")).toContain("Stand-in");
  });
  it("one run at a time", async () => {
    await post("/v1/projects/shop/batches", batch("r2"));
    await post("/v1/projects/shop/batches/r2/send", {});
    const second = await post("/v1/projects/shop/batches/r2/send", {});
    expect(second.status).toBe(409);
    await runDone("shop");
  });
  it("can be stopped", async () => {
    await post("/v1/projects/shop/batches", batch("r3"));
    await post("/v1/projects/shop/batches/r3/send", {});
    expect(await (await post("/v1/projects/shop/stop", {})).json()).toEqual({ stopped: true });
    expect((await runDone("shop")).status).toBe("stopped");
  });
  it("Claude Code gets what it needs and no more", () => {
    expect(LOOK).toMatch(/\/hub\/look\.mjs$/);
    const edit = claudeArgs({ project, folder: "C:/batch", mode: "apply" });
    expect(edit).toContain("-p");
    expect(edit[edit.indexOf("--permission-mode") + 1]).toBe("acceptEdits");
    expect(edit[edit.indexOf("--add-dir") + 1]).toBe("C:/batch");
    const tools = edit[edit.indexOf("--allowedTools") + 1];
    expect(tools).toContain("Edit");
    expect(tools).toContain("Bash(npm test:*)");
    expect(edit).not.toContain("--dangerously-skip-permissions");
    expect(edit.join(" ")).toContain("Do not commit, push, publish, deploy");
    expect(edit).not.toContain("--resume");
    // It can look at what it did, and is told to.
    expect(tools).toMatch(/Bash\(node \S*\/hub\/look\.mjs:\*\)/);
    expect(edit[edit.indexOf("--append-system-prompt") + 1]).toContain("C:/batch/after-1.png");
    const roblox = claudeArgs({ project: { ...project, roblox: true }, folder: "C:/batch", mode: "apply" });
    expect(roblox[roblox.indexOf("--allowedTools") + 1]).not.toContain("look.mjs");
    const reply = claudeArgs({ project, folder: "C:/batch", mode: "replyOnly", resume: "abc" });
    const replyTools = reply[reply.indexOf("--allowedTools") + 1];
    expect(replyTools).not.toContain("Edit");
    expect(replyTools).not.toContain("Bash");
    expect(reply[reply.indexOf("--append-system-prompt") + 1]).not.toContain("look.mjs");
    expect(reply[reply.indexOf("--resume") + 1]).toBe("abc");
  });
  it("Claude Code's stream becomes activity, changed files and a reply", () => {
    const activity: string[] = [];
    const changed: string[] = [];
    const stream = new ClaudeStream({ project, onActivity: (line) => activity.push(line), onChangedFile: (file) => changed.push(file) });
    stream.line(JSON.stringify({ type: "system", subtype: "init", session_id: "s1" }));
    stream.line(JSON.stringify({ type: "assistant", session_id: "s1", message: { content: [{ type: "text", text: "Looking.\nMore." }, { type: "tool_use", name: "Read", input: { file_path: "C:/data/01.jpg" } }] } }));
    stream.line(JSON.stringify({ type: "assistant", session_id: "s1", message: { content: [{ type: "tool_use", name: "Edit", input: { file_path: `${process.cwd()}/a/b.ts` } }] } }));
    stream.line("not json");
    stream.line("");
    stream.line(JSON.stringify({ type: "result", subtype: "success", session_id: "s1", is_error: false, result: "Done, one file." }));
    expect(activity).toEqual(["Looking.", "Looking at your picture", "Editing a/b.ts"]);
    expect(changed).toEqual(["a/b.ts"]);
    expect(stream.reply).toBe("Done, one file.");
    expect(stream.sessionId).toBe("s1");
    expect(stream.failure).toBeUndefined();
    const failing = new ClaudeStream({ project, onActivity: () => {}, onChangedFile: () => {} });
    failing.line(JSON.stringify({ type: "result", is_error: true, result: "Not logged in · Please run /login" }));
    expect(failing.failure).toContain("Not logged in");
    expect(failing.reply).toBeUndefined();
  });
  it("Claude Code installed with npm is started through a shell, quoted", () => {
    expect(startOptions("C:/x/claude.exe", ["-p", "a b"])).toEqual({ command: "C:/x/claude.exe", args: ["-p", "a b"], shell: false });
    const viaCmd = startOptions("C:/Program Files/claude.cmd", ["--append-system-prompt", 'say "hi" 100%\nnext']);
    expect(viaCmd.shell).toBe(true);
    expect(viaCmd.command).toBe('"C:/Program Files/claude.cmd"');
    expect(viaCmd.args[1]).toBe('"say ""hi"" 100%% next"');
  });
  it("a hub started from inside a Claude Code session does not pass that session on", () => {
    const nested = childEnvironment({ CLAUDECODE: "1", CLAUDE_CODE_SIMPLE: "1", CLAUDE_CODE_ENTRYPOINT: "x", ANTHROPIC_BASE_URL: "http://proxy", PATH: "p", HOME: "h" });
    expect(nested).toEqual({ PATH: "p", HOME: "h" });
    // From a terminal, what the person has set stays.
    const plain = childEnvironment({ ANTHROPIC_BASE_URL: "http://mine", CLAUDE_CODE_OAUTH_TOKEN: "t", PATH: "p" });
    expect(plain.ANTHROPIC_BASE_URL).toBe("http://mine");
    expect(plain.CLAUDE_CODE_OAUTH_TOKEN).toBe("t");
  });
  it("its tools read as plain words", () => {
    expect(describeToolUse("Edit", { file_path: `${process.cwd()}/client/a.ts` }, process.cwd())).toEqual({ line: "Editing client/a.ts", file: "client/a.ts" });
    expect(describeToolUse("Read", { file_path: "C:/elsewhere/01.jpg" }, process.cwd()).line).toBe("Looking at your picture");
  });
});
