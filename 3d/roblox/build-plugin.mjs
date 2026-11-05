// Builds the Studio plugin into one file:
//   node roblox/build-plugin.mjs             -> dist/Drawspeak3D.rbxmx
//   node roblox/build-plugin.mjs --install   -> also puts it in Studio's local Plugins folder
// Studio loads it the next time it starts or opens a place. To remove it, delete that one file.
import { randomBytes } from "node:crypto";
import { copyFileSync, existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
// The hub's key goes into the plugin: game code cannot read a plugin's source, and needs it to change anything.
const dataDir = process.env.DRAWSPEAK_DATA ?? join(homedir(), process.env.DRAWSPEAK_DATA_NAME ?? ".drawspeak3d");
const keyFile = join(dataDir, "key");
if (!existsSync(keyFile)) {
  mkdirSync(dataDir, { recursive: true });
  writeFileSync(keyFile, randomBytes(24).toString("hex"), { mode: 0o600 });
}
const key = readFileSync(keyFile, "utf8").trim();
const source = (name) => readFileSync(join(here, "src", name), "utf8").replaceAll("__DRAWSPEAK_KEY__", key);
const cdata = (text) => `<![CDATA[${text.replaceAll("]]>", "]]]]><![CDATA[>")}]]>`;
let referent = 0;
const item = (className, name, text, children = "") =>
  `<Item class="${className}" referent="RBX${referent++}"><Properties><string name="Name">${name}</string><ProtectedString name="Source">${cdata(text)}</ProtectedString></Properties>${children}</Item>`;

const xml =
  `<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">` +
  `<External>null</External><External>nil</External>` +
  item("Script", "Drawspeak3D", source("Main.server.luau"), item("ModuleScript", "Core", source("Core.luau")) + item("ModuleScript", "Scene", source("Scene.luau"))) +
  `</roblox>`;

const out = join(here, "..", "dist", "Drawspeak3D.rbxmx");
mkdirSync(dirname(out), { recursive: true });
writeFileSync(out, xml);
console.log(`Built ${out}`);

if (process.argv.includes("--install")) {
  const local = process.env.LOCALAPPDATA ?? join(homedir(), "AppData", "Local");
  const plugins = join(local, "Roblox", "Plugins");
  if (!existsSync(join(local, "Roblox"))) throw new Error(`Roblox Studio is not installed here (no ${join(local, "Roblox")})`);
  mkdirSync(plugins, { recursive: true });
  const target = join(plugins, "Drawspeak3D.rbxmx");
  copyFileSync(out, target);
  console.log(`Installed ${target}`);
}
