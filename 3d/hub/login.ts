// Signs Claude Code in on the command line, once:   npm run login
// The desktop app signs in for itself; the hub starts the command-line program, which needs its own.
import { spawnSync } from "node:child_process";
import { childEnvironment, findClaude, startOptions } from "./agents.ts";

const exe = findClaude();
if (!exe) {
  console.log("Claude Code was not found. Install it, or set DRAWSPEAK_CLAUDE to its path.");
  process.exit(1);
}
console.log(`Using ${exe}`);
const start = startOptions(exe, ["auth", "login"]);
const result = spawnSync(start.command, start.args, { stdio: "inherit", env: childEnvironment(process.env), shell: start.shell });
process.exit(result.status ?? 1);
