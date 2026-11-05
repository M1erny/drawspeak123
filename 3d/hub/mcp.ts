// Drawspeak 3D as an MCP server, for an agent session that is already open, so it can pull feedback
// itself instead of being started by the hub. Press Save Draft in the tool, then ask the agent to look:
//   claude mcp add drawspeak3d -- node C:/Users/Tomek/Projects/drawspeak123/3d/hub/mcp.ts
// It only reads the inbox folders and writes replies next to them. Speaks JSON-RPC on stdin and stdout.
import { existsSync, readFileSync, readdirSync } from "node:fs";
import { join } from "node:path";
import { createInterface } from "node:readline";
import { Inbox, defaultDataDir } from "./data.ts";

const inbox = new Inbox(defaultDataDir());

function projects(): string[] {
  return existsSync(inbox.root) ? readdirSync(inbox.root).filter((name) => existsSync(join(inbox.root, name, "batches"))) : [];
}

const TOOLS = [
  {
    name: "list_feedback",
    description: "List Drawspeak 3D feedback batches: a person walked through a running 3D world, circled things and said what should change. Newest first; says which ones an agent has already answered.",
    inputSchema: { type: "object", properties: { project: { type: "string", description: "Only this project" } } },
  },
  {
    name: "get_feedback",
    description: "Read one batch: its message, its JSON manifest, and its annotated pictures (views of the world with numbered marks).",
    inputSchema: { type: "object", required: ["project", "batchId"], properties: { project: { type: "string" }, batchId: { type: "string" } } },
  },
  {
    name: "reply_to_feedback",
    description: "Leave your answer next to a batch, so it counts as answered.",
    inputSchema: { type: "object", required: ["project", "batchId", "text"], properties: { project: { type: "string" }, batchId: { type: "string" }, text: { type: "string" } } },
  },
];

function callTool(name: string, args: Record<string, string>) {
  switch (name) {
    case "list_feedback": {
      const lines: string[] = [];
      for (const project of args.project ? [args.project] : projects()) {
        for (const batchId of inbox.list(project).slice(0, 20)) {
          const answered = existsSync(join(inbox.folderOf(project, batchId), "reply.md"));
          const first = inbox.message(project, batchId).split("\n")[0];
          lines.push(`${project} ${batchId}${answered ? " (answered)" : ""}: ${first}`);
        }
      }
      return { content: [{ type: "text", text: lines.join("\n") || "No feedback yet." }] };
    }
    case "get_feedback": {
      const folder = inbox.folderOf(args.project, args.batchId);
      const content: Array<Record<string, string>> = [
        { type: "text", text: `${inbox.message(args.project, args.batchId)}\n\nFolder: ${folder}\n\nManifest:\n${readFileSync(join(folder, "manifest.json"), "utf8")}` },
      ];
      for (const picture of inbox.pictures(args.project, args.batchId)) {
        if (picture.includes("-clean")) continue;
        content.push({ type: "image", data: readFileSync(join(folder, picture)).toString("base64"), mimeType: picture.endsWith(".png") ? "image/png" : "image/jpeg" });
      }
      return { content };
    }
    case "reply_to_feedback":
      inbox.reply(args.project, args.batchId, args.text);
      return { content: [{ type: "text", text: "Saved." }] };
    default:
      throw new Error(`No tool ${name}`);
  }
}

const send = (message: unknown) => process.stdout.write(`${JSON.stringify(message)}\n`);

const lines = createInterface({ input: process.stdin });
lines.on("line", (line) => {
  if (!line.trim()) return;
  let request: { id?: number | string; method: string; params?: { name?: string; arguments?: Record<string, string>; protocolVersion?: string } };
  try {
    request = JSON.parse(line);
  } catch {
    return;
  }
  const { id, method, params } = request;
  const reply = (result: unknown) => id !== undefined && send({ jsonrpc: "2.0", id, result });
  const fail = (code: number, message: string) => id !== undefined && send({ jsonrpc: "2.0", id, error: { code, message } });
  try {
    if (method === "initialize") reply({ protocolVersion: params?.protocolVersion ?? "2025-06-18", capabilities: { tools: {} }, serverInfo: { name: "drawspeak3d", version: "0.1.0" } });
    else if (method === "ping") reply({});
    else if (method === "tools/list") reply({ tools: TOOLS });
    else if (method === "tools/call") reply(callTool(params?.name ?? "", params?.arguments ?? {}));
    else if (!method.startsWith("notifications/")) fail(-32601, `No method ${method}`);
  } catch (error) {
    if (method === "tools/call") reply({ isError: true, content: [{ type: "text", text: error instanceof Error ? error.message : String(error) }] });
    else fail(-32603, String(error));
  }
});
