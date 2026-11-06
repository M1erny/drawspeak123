#!/usr/bin/env node
/**
 * Adds a game to the hub, so that Drawspeak can be used on it:
 *
 *   npm run add-game -- ../my-game http://localhost:5173
 *
 * It goes in hub/projects.local.json, which git ignores. The checks the agent may run are taken from the
 * game's package.json. Then restart the hub and add this to the game, on Vite or anything else:
 *
 *   <script src="http://127.0.0.1:8799/attach.js" data-project="my-game"></script>
 */
import { existsSync, readFileSync, writeFileSync } from "node:fs";
import { basename, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const [folderArg, originArg, idArg] = process.argv.slice(2);
if (!folderArg) {
  console.error("Usage: npm run add-game -- <the game's folder> [the page's address, http://localhost:5173] [a name for it]");
  process.exit(2);
}
const folder = resolve(folderArg);
if (!existsSync(folder)) {
  console.error(`There is no folder ${folder}`);
  process.exit(2);
}
const origin = new URL(originArg ?? "http://localhost:5173").origin;
const id = (idArg ?? basename(folder)).replace(/[^A-Za-z0-9_-]/g, "-");
const file = fileURLToPath(new URL("./projects.local.json", import.meta.url));
const projects = existsSync(file) ? JSON.parse(readFileSync(file, "utf8")) : {};

let scripts = {};
try {
  scripts = JSON.parse(readFileSync(resolve(folder, "package.json"), "utf8")).scripts ?? {};
} catch {
  // not a Node project: no checks to run
}
const allowedBash = ["typecheck", "test", "lint"].filter((name) => scripts[name]).map((name) => (name === "test" ? "npm test" : `npm run ${name}`));

projects[id] = { ...projects[id], title: projects[id]?.title ?? id, cwd: folder.split("\\").join("/"), origins: [origin], allowedBash };
writeFileSync(file, `${JSON.stringify(projects, null, 2)}\n`);

console.log(`${id} is in ${file}, at ${origin}, and its agent may run: ${allowedBash.join(", ") || "nothing but its look"}.

Restart the hub, build the tool if you haven't (npm run build:attach), and add this before the game's own scripts:

    <script src="http://127.0.0.1:8799/attach.js" data-project="${id}"></script>

Things are named from the scene graph: object.name, or object.userData.drawspeak = { label, kind, source }.
It only ever runs on a page served from this computer.`);
