// The hub, from the command line:   npm run hub   (in drawspeak123/3d)
import { agentFor } from "./agents.ts";
import { defaultDataDir, loadProjects } from "./data.ts";
import { startHub } from "./hub.ts";

const projects = loadProjects();
const dataDir = defaultDataDir();
const port = Number(process.env.DRAWSPEAK_PORT ?? 8799);
const hub = await startHub({ port, projects, dataDir });
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
