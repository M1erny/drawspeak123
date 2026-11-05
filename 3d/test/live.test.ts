import { existsSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import type { Project } from "../hub/data.ts";
import { startHub, type Hub } from "../hub/hub.ts";

process.env.DRAWSPEAK_AGENT = "fake";
process.env.DRAWSPEAK_FAKE_MS = "15";

/** Marks as a Studio plugin sends them: no Origin header, the hub takes the picture and holds the words. */
const project: Project = { id: "place", title: "Place", cwd: process.cwd(), origins: [], allowedBash: [], roblox: true, world: { engine: "Roblox", units: "studs", up: "Y" } };
let hub: Hub;
let dir: string;
let base: string;
let pictureWorks = true;

const KEY = "the-hubs-key";
const post = async (path: string, body: unknown, headers: Record<string, string> = { "x-drawspeak-key": KEY }) => {
  const r = await fetch(`${base}/v1/projects/place${path}`, { method: "POST", headers: { "content-type": "application/json", ...headers }, body: JSON.stringify(body) });
  return { status: r.status, body: await r.json() };
};
const get = async (path: string) => (await fetch(`${base}/v1/projects/place${path}`)).json();

const pose = { position: [10, 5, 2], quaternion: [0, 0, 0, 1], fov: 70, aspect: 1.6, near: 0.1, far: 2000 };
const entity = (label: string, kind = "Model") => ({ key: label, label, kind, locator: { strategy: "instance", value: `Workspace.Store.${label}` } });
const mark = (extra: object = {}) => ({
  title: "Store",
  shape: { kind: "lasso", points: [[0.1, 0.1], [0.3, 0.1], [0.2, 0.3]] },
  pose,
  world: { anchor: [1, 2, 3], normal: [0, 0, 1], ink: [[1, 2, 3], [2, 2, 3], [2, 3, 3]], closed: true },
  target: { layers: [[entity("Part1", "Part"), entity("Milk"), entity("Dairy", "Folder")], [entity("Rack")]], layer: 0, depth: 1, partial: false, method: "mouse" },
  voice: true,
  ...extra,
});

beforeAll(async () => {
  dir = mkdtempSync(join(tmpdir(), "ds3d-live-"));
  hub = await startHub({
    projects: new Map([["place", project]]),
    dataDir: dir,
    key: KEY,
    capture: async (out) => {
      if (!pictureWorks) return { ok: false, reason: "no-window" };
      writeFileSync(out, Buffer.from("/9j/4AAQ", "base64"));
      return { ok: true, width: 1600, height: 900 };
    },
  });
  base = `http://127.0.0.1:${hub.port}`;
});
afterAll(async () => {
  await hub.close();
  rmSync(dir, { recursive: true, force: true });
});

describe("marks from a Studio plugin", () => {
  it("a program without the hub's key can read, not change", async () => {
    expect((await post("/marks", mark(), {})).status).toBe(401);
    expect((await post("/marks/send", {}, { "x-drawspeak-key": "wrong" })).status).toBe(401);
    expect((await post("/stop", {}, {})).status).toBe(401);
    expect((await fetch(`${base}/v1/projects/place/marks`)).status).toBe(200);
  });

  it("a mark with no place in the world is refused", async () => {
    const { status } = await post("/marks", { shape: { kind: "lasso" } });
    expect(status).toBe(400);
  });

  it("the plugin finds its project without settings", async () => {
    const r = await (await fetch(`${base}/v1/roblox`)).json();
    expect(r.id).toBe("place");
  });

  it("a mark gets a number and a picture; with no desk open, nobody listens", async () => {
    const { status, body } = await post("/marks", mark());
    expect(status).toBe(200);
    expect(body.number).toBe(1);
    expect(body.picture).toBe(true);
    expect(body.desks).toBe(0);
    expect(body.recording).toBeUndefined();
    expect(body.readiness).toBe("markOnly");
    const image = await fetch(`${base}/v1/projects/place/marks/${body.id}/image`);
    expect(image.status).toBe(200);
    expect(image.headers.get("content-type")).toBe("image/jpeg");
  });

  it("typing makes it ready, and climbing the chain is remembered", async () => {
    const { notes } = await get("/marks");
    const id = notes[0].id;
    const typed = await post(`/marks/${id}`, { text: "Większe mleko" });
    expect(typed.body.text).toBe("Większe mleko");
    expect(typed.body.readiness).toBe("ready");
    const up = await post(`/marks/${id}`, { depth: 2 });
    expect(up.body.target.depth).toBe(2);
    const tooFar = await post(`/marks/${id}`, { depth: 99 });
    expect(tooFar.body.target.depth).toBe(2);
    const other = await post(`/marks/${id}`, { layer: 1 });
    expect(other.body.target.layer).toBe(1);
    expect(other.body.target.depth).toBe(0);
    await post(`/marks/${id}`, { layer: 0 });
    await post(`/marks/${id}`, { depth: 1 });
  });

  it("with a desk open: it listens, words arrive while spoken, Stop ends it", async () => {
    const events = await fetch(`${base}/v1/projects/place/events?desk=1`);
    const reader = events.body!.getReader();
    const decoder = new TextDecoder();
    let heard = "";
    const until = async (text: string) => {
      for (let i = 0; i < 40 && !heard.includes(text); i++) heard += decoder.decode((await reader.read()).value);
      return heard.includes(text);
    };
    await until("event: run");
    const { body } = await post("/marks", mark());
    expect(body.desks).toBe(1);
    expect(body.recording).toBe("recording");
    expect(await until('"state":"start"')).toBe(true);

    await post(`/marks/${body.id}`, { heard: "Zmień to" });
    expect((await get(`/marks/${body.id}`)).text).toBe("Zmień to");
    expect((await get(`/marks/${body.id}`)).readiness).toBe("recording");

    await post(`/marks/${body.id}`, { stop: true });
    expect(await until('"state":"stop"')).toBe(true);
    const done = await post(`/marks/${body.id}`, { heardFinal: "Zmień to na czerwono" });
    expect(done.body.text).toBe("Zmień to na czerwono");
    expect(done.body.recording).toBeUndefined();
    expect(done.body.readiness).toBe("ready");
    await reader.cancel();
    // The desk is gone: nobody listens any more.
    await new Promise((r) => setTimeout(r, 30));
    expect((await post("/marks", mark())).body.desks).toBe(0);
  });

  it("the desk closing mid-sentence keeps what it heard, and frees the note", async () => {
    const events = await fetch(`${base}/v1/projects/place/events?desk=1`);
    const reader = events.body!.getReader();
    await reader.read();
    const { body } = await post("/marks", mark());
    expect(body.recording).toBe("recording");
    await post(`/marks/${body.id}`, { heard: "Tylko połowa" });
    await reader.cancel();
    let note = await get(`/marks/${body.id}`);
    for (let i = 0; i < 40 && note.recording; i++) {
      await new Promise((r) => setTimeout(r, 25));
      note = await get(`/marks/${body.id}`);
    }
    expect(note.recording).toBeUndefined();
    expect(note.text).toBe("Tylko połowa");
    expect(note.readiness).toBe("ready");
    await post(`/marks/${body.id}`, { discard: true });
  });

  it("no picture is no reason to lose the mark", async () => {
    pictureWorks = false;
    const { body } = await post("/marks", mark());
    expect(body.picture).toBe(false);
    expect(body.pictureProblem).toBe("no-window");
    const image = await fetch(`${base}/v1/projects/place/marks/${body.id}/image`);
    expect(image.status).toBe(404);
    await post(`/marks/${body.id}`, { text: "Bez obrazka" });
    pictureWorks = true;
  });

  it("Discard removes a mark and its picture", async () => {
    const { body } = await post("/marks", mark());
    expect((await post(`/marks/${body.id}`, { discard: true })).body.discarded).toBe(true);
    expect(existsSync(join(dir, "place", "live", `${body.snapshotId}.jpg`))).toBe(false);
    expect((await fetch(`${base}/v1/projects/place/marks/${body.id}`)).status).toBe(404);
  });

  it("Send builds the same batch as the browser, runs the agent, and the marks leave the world", async () => {
    const sent = await post("/marks/send", { directive: { mode: "apply", note: "Tylko kolory" } });
    expect(sent.status).toBe(200);
    expect(sent.body.status).toBe("running");
    const folder = hub.inbox.folderOf("place", sent.body.batchId);
    const message = readFileSync(join(folder, "message.md"), "utf8");
    expect(message).toContain("Drawspeak 3D feedback");
    expect(message).toContain("Większe mleko");
    expect(message).toContain("Target: Milk › Dairy (Model)");
    expect(message).toContain("instance: Workspace.Store.Milk");
    expect(message).toContain("Also in that direction: Rack");
    expect(message).toContain("World: Roblox, units: studs");
    expect(message).toContain("Additional instruction from the reviewer: Tylko kolory");
    const manifest = JSON.parse(readFileSync(join(folder, "manifest.json"), "utf8"));
    expect(manifest.world.engine).toBe("Roblox");
    expect(manifest.snapshots[0].camera.fov).toBe(70);
    expect(manifest.snapshots[0].cleanFileName).toBeUndefined();
    // The mark without a picture says so, and still goes.
    const noPicture = manifest.snapshots.find((s: { compositeFileName?: string }) => s.compositeFileName === undefined);
    expect(noPicture.notes[0].text).toBe("Bez obrazka");

    for (let i = 0; i < 100; i++) {
      const runs = await get("/runs");
      if (runs.every((run: { status: string }) => run.status !== "running")) {
        expect(runs[runs.length - 1].status).toBe("done");
        break;
      }
      await new Promise((r) => setTimeout(r, 20));
    }
    const { notes } = await get("/marks");
    expect(notes.filter((n: { readiness: string }) => n.readiness === "ready")).toEqual([]);
  });

  it("a place, a route and a comment on the whole view go through, with where the player stands", async () => {
    const near = [{ label: "Kiosk", kind: "Model", distance: 4.2, locator: { strategy: "instance", value: "Workspace.Store.Kiosk" } }];
    const spot = await post("/marks", mark({
      shape: { kind: "point", at: [0.4, 0.8] },
      viewer: { position: [9, 3, 1], facing: [0, 0, -1] },
      world: { anchor: [1, 0, 3], normal: [0, 1, 0], ink: [[1, 0, 3], [2, 0, 3]], closed: true, place: { center: [1, 0, 3], normal: [0, 1, 0], size: [0, 0, 0], on: "Floor", near } },
    }));
    await post(`/marks/${spot.body.id}`, { text: "Postaw tu ławkę" });
    const route = await post("/marks", mark({
      shape: { kind: "arrow", from: [0.1, 0.8], to: [0.7, 0.7] },
      world: {
        anchor: [0, 0, 0],
        normal: [0, 1, 0],
        ink: [[0, 0, 0], [8, 0, 2]],
        closed: false,
        path: { points: [[0, 0, 0], [8, 0, 2]], length: 8.25, onGround: true, from: { at: [0, 0, 0], label: "Floor", kind: "Part", isThing: false, near }, to: { at: [8, 0, 2], label: "Floor", kind: "Part", isThing: false, near: [] }, through: [] },
      },
    }));
    await post(`/marks/${route.body.id}`, { text: "Tędy niech idą klienci" });
    const view = await post("/marks", mark({ shape: { kind: "view" }, target: undefined, world: { anchor: [0, 1, 0], normal: [0, 0, 1], ink: [], closed: false } }));
    await post(`/marks/${view.body.id}`, { text: "Za pusto tutaj" });

    const sent = await post("/marks/send", { noteIds: [spot.body.id, route.body.id, view.body.id] });
    expect(sent.status).toBe(200);
    const folder = hub.inbox.folderOf("place", sent.body.batchId);
    const message = readFileSync(join(folder, "message.md"), "utf8");
    expect(message).toContain("[Spot] Postaw tu ławkę");
    expect(message).toContain("Place: on Floor, at (1, 0, 3)");
    expect(message).toContain("Near: Kiosk (4.2)");
    expect(message).toContain("own character stands at (9, 3, 1)");
    expect(message).toContain("[Line] Tędy niech idą klienci");
    expect(message).toContain("From: Floor at (0, 0, 0), near Kiosk (4.2)");
    expect(message).toContain("Line: 8.3 long, along the ground");
    expect(message).toContain("[View] Za pusto tutaj");
    const manifest = JSON.parse(readFileSync(join(folder, "manifest.json"), "utf8"));
    expect(manifest.snapshots[0].viewer.position).toEqual([9, 3, 1]);
    expect(manifest.snapshots[1].notes[0].path.length).toBe(8.25);
    // The agent runs in the background: let it finish before the next test.
    await new Promise((resolve) => setTimeout(resolve, 80));
  });

  it("nothing ready, nothing sent", async () => {
    const r = await post("/marks/send", {});
    expect(r.status).toBe(400);
    expect(r.body.error).toContain("needs a comment");
  });

  it("marks survive the hub restarting", async () => {
    const again = await startHub({ projects: new Map([["place", project]]), dataDir: dir, key: KEY, capture: async () => ({ ok: false, reason: "no-window" }) });
    const { notes } = await (await fetch(`http://127.0.0.1:${again.port}/v1/projects/place/marks`)).json();
    expect(notes.length).toBeGreaterThan(0);
    await again.close();
  });

  it("the desk page and its speech code are served", async () => {
    const page = await fetch(`${base}/desk`);
    expect(page.status).toBe(200);
    expect(await page.text()).toContain("Turn on the microphone");
    const speech = await fetch(`${base}/desk/speech.js`);
    expect(speech.headers.get("content-type")).toContain("javascript");
    const code = await speech.text();
    expect(code).toContain("class Voice");
    expect(code).not.toContain("interface VoiceEvents");
  });
});
