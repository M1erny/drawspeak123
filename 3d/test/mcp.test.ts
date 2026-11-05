import { spawn } from "node:child_process";
import { existsSync, mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { Inbox } from "../hub/data.ts";

/** The real server over its real pipe, on a throwaway inbox. */
let dir: string;
let child: ReturnType<typeof spawn>;
let buffer = "";
const waiting = new Map<number, (message: Record<string, unknown>) => void>();
let next = 1;

function call(method: string, params: unknown = {}): Promise<Record<string, any>> {
  const id = next++;
  return new Promise((resolve) => {
    waiting.set(id, resolve);
    child.stdin!.write(`${JSON.stringify({ jsonrpc: "2.0", id, method, params })}\n`);
  });
}

beforeAll(() => {
  dir = mkdtempSync(join(tmpdir(), "ds3d-mcp-"));
  new Inbox(dir).save("shop", {
    batchId: "b1",
    message: "[drawspeak-batch:b1] Drawspeak 3D feedback\n1. [Loop] Większe\n",
    manifest: { schema: "drawspeak3d.feedback.v1" },
    files: [{ name: "01-a.jpg", base64: "/9j/4AAQ" }, { name: "01-a-clean.jpg", base64: "/9j/4AAQ" }],
  });
  child = spawn(process.execPath, [join(process.cwd(), "hub", "mcp.ts")], { env: { ...process.env, DRAWSPEAK_DATA: dir }, stdio: ["pipe", "pipe", "ignore"] });
  child.stdout!.setEncoding("utf8").on("data", (chunk: string) => {
    buffer += chunk;
    let at: number;
    while ((at = buffer.indexOf("\n")) >= 0) {
      const message = JSON.parse(buffer.slice(0, at));
      buffer = buffer.slice(at + 1);
      waiting.get(message.id)?.(message);
      waiting.delete(message.id);
    }
  });
});
afterAll(() => {
  child.kill();
  rmSync(dir, { recursive: true, force: true });
});

describe("feedback over MCP", () => {
  it("says hello and lists its tools", async () => {
    const hello = await call("initialize", { protocolVersion: "2025-06-18", capabilities: {}, clientInfo: { name: "test", version: "1" } });
    expect(hello.result.serverInfo.name).toBe("drawspeak3d");
    const { result } = await call("tools/list");
    expect(result.tools.map((t: { name: string }) => t.name)).toEqual(["list_feedback", "get_feedback", "reply_to_feedback"]);
  });
  it("lists batches, and gives the message, the manifest and the marked picture only", async () => {
    const list = await call("tools/call", { name: "list_feedback", arguments: {} });
    expect(list.result.content[0].text).toContain("shop b1: [drawspeak-batch:b1]");
    const batch = await call("tools/call", { name: "get_feedback", arguments: { project: "shop", batchId: "b1" } });
    expect(batch.result.content[0].text).toContain("Większe");
    expect(batch.result.content[0].text).toContain("drawspeak3d.feedback.v1");
    const images = batch.result.content.filter((c: { type: string }) => c.type === "image");
    expect(images.length).toBe(1);
    expect(images[0].mimeType).toBe("image/jpeg");
  });
  it("a reply marks it answered", async () => {
    await call("tools/call", { name: "reply_to_feedback", arguments: { project: "shop", batchId: "b1", text: "Zrobione." } });
    expect(existsSync(join(dir, "shop", "batches", "b1", "reply.md"))).toBe(true);
    const list = await call("tools/call", { name: "list_feedback", arguments: {} });
    expect(list.result.content[0].text).toContain("(answered)");
  });
  it("names cannot climb out of the inbox", async () => {
    const r = await call("tools/call", { name: "get_feedback", arguments: { project: "..", batchId: "..\\..\\secret" } });
    expect(r.result.isError).toBe(true);
  });
});
