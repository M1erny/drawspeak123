#!/usr/bin/env node
/**
 * What a running 3D world looks like from a view, as a picture: for a coding agent that has just
 * changed it and wants to see the result as the reviewer will.
 *
 *   node hub/look.mjs "<view link>" <picture.png>
 *
 * The link is a comment's "Open this view" link. Pages on this computer only. The browser is headless
 * and silent: nothing reaches the screen, the speakers or the microphone. It prints the page's errors,
 * so a change that broke the world says so.
 */
import { spawn } from "node:child_process";
import { existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, statSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";

const [link, out] = process.argv.slice(2);
const refuse = (message) => {
  console.error(message);
  process.exit(2);
};
if (!link || !out) refuse('Usage: node look.mjs "<view link>" <picture.png>');
let page;
try {
  page = new URL(link);
} catch {
  refuse(`Not a link: ${link}`);
}
if (!["http:", "https:"].includes(page.protocol) || !["localhost", "127.0.0.1", "[::1]"].includes(page.hostname)) refuse("Only pages on this computer can be looked at (localhost).");
// Run by the hub's agent: that project's own pages, not whatever else this computer serves.
const allowed = process.env.DRAWSPEAK_LOOK_ORIGINS?.split(",").filter(Boolean) ?? [];
if (allowed.length > 0 && !allowed.includes(page.origin)) refuse(`Only this project's own pages can be looked at (${allowed.join(", ")}).`);
if (!out.toLowerCase().endsWith(".png")) refuse("The picture's name must end in .png");

const BROWSER = process.env.BROWSER ?? [
  "C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe",
  "C:/Program Files/Microsoft/Edge/Application/msedge.exe",
  "C:/Program Files/Google/Chrome/Application/chrome.exe",
  "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
  "/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge",
  "/usr/bin/google-chrome",
  "/usr/bin/chromium",
  "/usr/bin/microsoft-edge",
].find(existsSync);
if (!BROWSER) refuse("No Chromium browser found: set BROWSER to Edge's or Chrome's executable.");

/** The browser's speech goes straight to the system's voice, past --mute-audio: it gets a stand-in. */
const SILENT_SPEECH = `(() => {
  if (typeof speechSynthesis === "undefined") return;
  speechSynthesis.speak = (u) => setTimeout(() => u.onend?.({ utterance: u }), 30);
  speechSynthesis.cancel = () => {};
  if (navigator.mediaDevices) navigator.mediaDevices.getUserMedia = () => Promise.reject(new Error("no microphone here"));
})();`;
/** The tool has attached, and the app no longer keeps it out of sight (a title screen, say). */
const READY = `!!window.__ds3d?.host?.ready && window.__ds3d.root.style.display !== "none"`;
const WIDTH = 1280;
const HEIGHT = 800;

const sleep = (ms) => new Promise((done) => setTimeout(done, ms));

// Several agents can be at work at once, and each browser here renders in software, which is heavy on
// a computer someone is playing on. So one at a time; a lock left behind by a crash goes stale.
const LOCK = join(tmpdir(), "drawspeak-look.lock");
let locked = false;
for (const until = Date.now() + 60_000; Date.now() < until && !locked; ) {
  try {
    mkdirSync(LOCK);
    locked = true;
  } catch {
    try {
      if (Date.now() - statSync(LOCK).mtimeMs > 130_000) rmSync(LOCK, { recursive: true, force: true });
    } catch {
      // someone else just took it, or just let go
    }
    if (!locked) await sleep(500);
  }
}

const work = mkdtempSync(join(tmpdir(), "drawspeak-look-"));
const browser = spawn(BROWSER, ["--headless=new", "--remote-debugging-port=0", `--user-data-dir=${work}`, "--use-angle=swiftshader", "--enable-unsafe-swiftshader", "--no-first-run", "--hide-scrollbars", "--mute-audio", "--autoplay-policy=no-user-gesture-required", "about:blank"], { windowsHide: true, stdio: "ignore" });

let closeBrowser = () => {};
async function finish(code) {
  closeBrowser();
  await sleep(500);
  browser.kill();
  // Windows keeps the profile's files for a moment after the browser has gone.
  for (let i = 0; i < 12; i++) {
    try {
      rmSync(work, { recursive: true, force: true });
      break;
    } catch {
      await sleep(250);
    }
  }
  if (locked) rmSync(LOCK, { recursive: true, force: true });
  process.exit(code);
}
for (const signal of ["SIGTERM", "SIGINT", "SIGHUP"]) process.on(signal, () => void finish(1));
setTimeout(() => {
  console.error("Gave up after 110 seconds: the page never settled.");
  void finish(1);
}, 110_000).unref();

const errors = [];
try {
  const portFile = join(work, "DevToolsActivePort");
  for (let i = 0; i < 150 && !existsSync(portFile); i++) await sleep(100);
  const [port, endpoint] = readFileSync(portFile, "utf8").trim().split(/\r?\n/);
  const ws = new WebSocket(`ws://127.0.0.1:${port}${endpoint}`);
  await new Promise((ok, fail) => {
    ws.onopen = ok;
    ws.onerror = fail;
  });
  closeBrowser = () => {
    try {
      ws.send(JSON.stringify({ id: 999999, method: "Browser.close" }));
    } catch {
      // already gone
    }
  };
  let next = 0;
  const waiting = new Map();
  ws.onmessage = (event) => {
    const message = JSON.parse(String(event.data));
    if (message.method === "Runtime.exceptionThrown") errors.push(message.params.exceptionDetails.exception?.description ?? message.params.exceptionDetails.text);
    if (message.method === "Runtime.consoleAPICalled" && message.params.type === "error") errors.push(message.params.args.map((a) => a.value ?? a.description).join(" "));
    const pending = waiting.get(message.id);
    if (!pending) return;
    waiting.delete(message.id);
    if (message.error) pending.reject(new Error(message.error.message));
    else pending.resolve(message.result);
  };
  let session;
  const send = (method, params = {}) =>
    new Promise((ok, fail) => {
      const id = ++next;
      waiting.set(id, { resolve: ok, reject: fail });
      ws.send(JSON.stringify({ id, method, params, ...(session ? { sessionId: session } : {}) }));
    });
  const evaluate = async (expression) => {
    const result = await send("Runtime.evaluate", { expression, returnByValue: true, awaitPromise: true });
    if (result.exceptionDetails) throw new Error(result.exceptionDetails.text);
    return result.result.value;
  };

  const { targetId } = await send("Target.createTarget", { url: "about:blank" });
  session = (await send("Target.attachToTarget", { targetId, flatten: true })).sessionId;
  await send("Page.enable");
  await send("Page.addScriptToEvaluateOnNewDocument", { source: SILENT_SPEECH });
  await send("Runtime.enable");
  await send("Emulation.setDeviceMetricsOverride", { width: WIDTH, height: HEIGHT, deviceScaleFactor: 1, mobile: false });
  const opened = await send("Page.navigate", { url: link });
  if (opened.errorText) {
    console.error(`Nothing answers at ${page.origin} (${opened.errorText}). Is the dev server running?`);
    await finish(1);
  }

  // A page that has broken never gets to the tool: stop waiting a while after it has loaded.
  const deadline = Date.now() + 80_000;
  let loadedAt;
  let ready = false;
  while (Date.now() < deadline) {
    ready = Boolean(await evaluate(READY).catch(() => false));
    if (ready) break;
    if (!loadedAt && (await evaluate("document.readyState").catch(() => "")) === "complete") loadedAt = Date.now();
    if (loadedAt && Date.now() - loadedAt > 45_000 && !(await evaluate("!!window.__ds3d").catch(() => false))) break;
    await sleep(250);
  }
  // Just the world and the app's own interface: no tool over it.
  await evaluate(`(() => { const s = document.createElement("style"); s.textContent = ".ds3d-root { display: none !important; }"; document.head.append(s); return true; })()`).catch(() => undefined);
  // A few frames, so that what loaded last is drawn.
  await evaluate(`new Promise((done) => { let n = 0; const tick = () => (++n >= 10 ? done(true) : requestAnimationFrame(tick)); tick(); setTimeout(() => done(true), 6000); })`).catch(() => undefined);
  const shot = await send("Page.captureScreenshot", { format: "png" });
  const target = resolve(out);
  mkdirSync(dirname(target), { recursive: true });
  writeFileSync(target, Buffer.from(shot.data, "base64"));
  console.log(`Saved ${target}${ready ? "" : " (the page did not get ready: it may have broken)"}.`);
  if (errors.length > 0) console.log(`Errors on the page:\n${[...new Set(errors)].slice(0, 8).map((e) => `  ${String(e).slice(0, 300)}`).join("\n")}`);
  else console.log("No errors on the page.");
  await finish(0);
} catch (error) {
  console.error(`Could not look: ${error instanceof Error ? error.message : error}`);
  await finish(1);
}
