// Checks the Studio plugin without Studio: the Luau analyzer over all of it, then the specs of its
// pure logic. Uses the Luau CLI in ../swing-shop/tools/luau, or LUAU_DIR.
//   node roblox/check.mjs
import { execFileSync } from "node:child_process";
import { existsSync, readdirSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const dir = process.env.LUAU_DIR ?? join(here, "..", "..", "..", "swing-shop", "tools", "luau");
const exe = (name) => join(dir, process.platform === "win32" ? `${name}.exe` : name);
if (!existsSync(exe("luau"))) {
  console.log(`No Luau CLI at ${dir}. Set LUAU_DIR.`);
  process.exit(1);
}

// Roblox's own names are unknown to the CLI; anything else unknown is a real typo.
const ROBLOX_GLOBALS = new Set(["game", "workspace", "script", "plugin", "Enum", "Instance", "Vector3", "Vector2", "CFrame", "Color3", "UDim", "UDim2", "RaycastParams", "OverlapParams", "task", "typeof", "warn", "bit32"]);
const sources = readdirSync(join(here, "src")).map((name) => join(here, "src", name));
let output = "";
try {
  output = execFileSync(exe("luau-analyze"), sources, { encoding: "utf8", stdio: ["ignore", "pipe", "pipe"] });
} catch (error) {
  output = `${error.stdout ?? ""}${error.stderr ?? ""}`;
}
const problems = output.split(/\r?\n/).filter(Boolean).filter((line) => {
  const global = line.match(/Unknown global '([^']+)'/);
  if (global) return !ROBLOX_GLOBALS.has(global[1]);
  if (/Unknown type '[A-Z][A-Za-z0-9]*(\.[A-Za-z0-9]+)?'/.test(line)) return false;
  if (/Unknown require|Cannot require|require/.test(line) && /script|Parent|unsupported path/i.test(line)) return false;
  // Types that hang off Roblox's classes, which the CLI cannot know.
  if (/TypeError/.test(line) && /(Camera|Instance|InputObject|TextButton|TextBox|TextLabel|Highlight|BillboardGui|RemoteFunction|Scene\.|Core\.)/.test(line)) return false;
  return true;
});
if (problems.length > 0) {
  console.log("Analyzer:");
  for (const line of problems) console.log(`  ${line.replace(here, "")}`);
} else console.log("Analyzer: clean");

for (const spec of readdirSync(join(here, "tests")).filter((name) => name.endsWith(".spec.luau"))) {
  console.log(spec);
  execFileSync(exe("luau"), [join(here, "tests", spec)], { stdio: "inherit" });
}
process.exit(problems.length > 0 ? 1 : 0);
