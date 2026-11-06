// The hub, from the command line:   npm run hub   (in drawspeak123/3d)
import { agentFor } from "./agents.ts";
import { defaultDataDir, loadProjects } from "./data.ts";
import { startHub } from "./hub.ts";

const projects = loadProjects();
const dataDir = defaultDataDir();
const port = Number(process.env.DRAWSPEAK_PORT ?? 8799);
const hub = await startHub({ port, projects, dataDir });
// An agent nobody can see or stop is the last thing anyone wants: they go when the hub goes.
process.on("exit", () => hub.stopAgents());
for (const signal of ["SIGINT", "SIGTERM", "SIGHUP", "SIGBREAK"] as const) process.on(signal, () => process.exit(0));
// One bad request or one odd line from an agent must not take everyone's work down with it.
process.on("uncaughtException", (error) => console.error("[hub]", error));
process.on("unhandledRejection", (error) => console.error("[hub]", error));
console.log(`Drawspeak 3D hub: http://127.0.0.1:${hub.port}`);
console.log(`Desk (voice for Roblox): http://127.0.0.1:${hub.port}/desk`);
console.log(`Batches are kept in ${dataDir}`);
for (const project of projects.values()) {
  const agent = agentFor(project);
  agent.problem(); // start finding out
  console.log(`  ${project.id}: ${project.cwd} -> ${agent.label}${agent.available() ? "" : " (not found)"}`);
}
setTimeout(() => {
  const problem = [...projects.values()].map((project) => agentFor(project).problem()).find(Boolean);
  if (problem) console.log(`\n! ${problem}\n  Until then, Save Draft and Copy prompt work.`);
}, 6000);
