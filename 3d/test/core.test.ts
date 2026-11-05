import { describe, expect, it } from "vitest";
import { convexHull, enclosure, lowDiscrepancyOrder, pointInPolygon, samplePolygon, simplified } from "../src/core/geometry.ts";
import { buildPackage, displayNumbers, lookingAt, manifestOf, messageText, readiness } from "../src/core/package.ts";
import { PressureDepthTracker, commonChain, current, groupChain, rank, selectDepth, selectLayer } from "../src/core/selection.ts";
import { isClosedLoop, isCurling, isTap, isValidShape, kindLabel, linePoints, shapeFor } from "../src/core/stroke.ts";
import type { Note, NoteTarget, SceneEntity, Shape, Snapshot, Vec2, WorldMark } from "../src/core/types.ts";

const circle = (cx: number, cy: number, r: number, n = 40, sweep = Math.PI * 2): Vec2[] =>
  Array.from({ length: n + 1 }, (_, i) => [cx + Math.cos((i / n) * sweep) * r, cy + Math.sin((i / n) * sweep) * r] as Vec2);

/** A hand's line through corners, a point every few pixels. */
const through = (...corners: Vec2[]): Vec2[] => {
  const out: Vec2[] = [corners[0]];
  for (let i = 1; i < corners.length; i++) {
    const [ax, ay] = corners[i - 1];
    const [bx, by] = corners[i];
    const steps = Math.max(1, Math.round(Math.hypot(bx - ax, by - ay) / 4));
    for (let s = 1; s <= steps; s++) out.push([ax + ((bx - ax) * s) / steps, ay + ((by - ay) * s) / steps]);
  }
  return out;
};

describe("strokes: a circle, a line or a tap", () => {
  const W = 1000;
  const H = 800;
  it("a closed circle is a lasso", () => {
    expect(shapeFor(circle(400, 300, 60), W, H)?.kind).toBe("lasso");
  });
  it("an almost closed circle is still a loop (end within 12% of its length)", () => {
    expect(isClosedLoop(circle(400, 300, 100, 40, Math.PI * 2 * 0.92))).toBe(true);
  });
  it("a hasty circle with a wide gap is a loop: it went most of the way round", () => {
    const hasty = circle(400, 300, 100, 40, Math.PI * 2 * 0.8);
    expect(isClosedLoop(hasty)).toBe(true);
    expect(shapeFor(hasty, W, H)?.kind).toBe("lasso");
  });
  it("a U-turn is a line: it came back, but only halfway round", () => {
    const uTurn = through([100, 100], [400, 100], [400, 300], [100, 300]);
    expect(isClosedLoop(uTurn)).toBe(false);
    expect(shapeFor(uTurn, W, H)?.kind).toBe("arrow");
  });
  it("any open stroke is a line from here to there", () => {
    const line = shapeFor([[100, 100], [200, 160], [300, 240]], W, H);
    expect(line).toEqual({ kind: "arrow", from: [0.1, 0.125], to: [0.3, 0.3] });
  });
  it("a straight line has no bends, a bent one keeps them", () => {
    const shaky = through([100, 100], [300, 104], [500, 99], [700, 103]);
    const straight = shapeFor(shaky, W, H);
    expect(straight?.kind === "arrow" && straight.via).toBeUndefined();
    const bent = shapeFor(circle(400, 300, 200, 60, Math.PI / 2), W, H);
    if (bent?.kind !== "arrow") throw new Error("not a line");
    expect(bent.via?.length).toBeGreaterThan(3);
    expect(bent.via?.length).toBeLessThan(26);
    const points = linePoints(bent);
    expect(points[0]).toEqual(bent.from);
    expect(points[points.length - 1]).toEqual(bent.to);
  });
  it("a stroke on its way round shows no arrow head yet, a line does", () => {
    expect(isCurling(circle(400, 300, 100, 40, Math.PI))).toBe(true);
    expect(isCurling(through([100, 100], [500, 110]))).toBe(false);
    expect(isCurling(through([100, 100], [400, 100], [400, 300]))).toBe(false);
  });
  it("a tap or a slip marks nothing by itself", () => {
    const slip: Vec2[] = [[100, 100], [106, 104], [110, 101]];
    expect(isTap(slip)).toBe(true);
    expect(shapeFor(slip, W, H)).toBeNull();
  });
  it("a line needs some length", () => {
    expect(shapeFor([[10, 10], [38, 12]], W, H)).toBeNull();
    expect(shapeFor([[10, 10], [60, 12]], W, H)?.kind).toBe("arrow");
  });
  it("freehand points are thinned, the end stays", () => {
    const points: Vec2[] = [[0, 0], [0.5, 0], [1, 0], [5, 0], [5.2, 0]];
    expect(simplified(points, 2)).toEqual([[0, 0], [5, 0], [5.2, 0]]);
  });
  it("shapes are normalized", () => {
    const shape = shapeFor(circle(500, 400, 100), W, H);
    if (shape?.kind !== "lasso") throw new Error("not a lasso");
    for (const [x, y] of shape.points) {
      expect(x).toBeGreaterThan(0.39);
      expect(x).toBeLessThan(0.61);
      expect(y).toBeGreaterThan(0.37);
      expect(y).toBeLessThan(0.63);
    }
  });
  it("every kind of mark has a word and is valid", () => {
    const shapes: Shape[] = [
      { kind: "lasso", points: [[0, 0], [1, 0], [1, 1]] },
      { kind: "arrow", from: [0, 0], to: [1, 1] },
      { kind: "point", at: [0.5, 0.5] },
      { kind: "component", rect: { x: 0, y: 0, w: 1, h: 1 } },
      { kind: "view" },
    ];
    expect(shapes.map(kindLabel)).toEqual(["Loop", "Line", "Spot", "Thing", "View"]);
    expect(shapes.every(isValidShape)).toBe(true);
  });
});

describe("sampling a loop", () => {
  const loop = circle(200, 200, 100);
  it("every sample is inside", () => {
    const points = samplePolygon(loop, 64);
    expect(points.length).toBeGreaterThan(30);
    expect(points.every((p) => pointInPolygon(p, loop))).toBe(true);
  });
  it("an early part of the samples already covers all four quadrants", () => {
    const early = samplePolygon(loop, 96).slice(0, 12);
    const quadrants = new Set(early.map(([x, y]) => `${x > 200}${y > 200}`));
    expect(quadrants.size).toBe(4);
  });
  it("a small loop still gets samples", () => {
    expect(samplePolygon(circle(50, 50, 8), 96).length).toBeGreaterThan(3);
  });
  it("reordering keeps every item once", () => {
    const items = Array.from({ length: 37 }, (_, i) => i);
    expect(lowDiscrepancyOrder(items).slice().sort((a, b) => a - b)).toEqual(items);
  });
  it("enclosure tells inside from outside", () => {
    expect(enclosure({ minX: 180, minY: 180, maxX: 220, maxY: 220 }, loop)).toBe(1);
    expect(enclosure({ minX: 800, minY: 800, maxX: 900, maxY: 900 }, loop)).toBe(0);
    const half = enclosure({ minX: 200, minY: 150, maxX: 400, maxY: 250 }, loop);
    expect(half).toBeGreaterThan(0.2);
    expect(half).toBeLessThan(0.6);
  });
  it("the hull of a box's corners is its outline", () => {
    const hull = convexHull([[0, 0], [10, 0], [10, 10], [0, 10], [5, 5], [2, 3]]);
    expect(hull.length).toBe(4);
  });
});

describe("what a loop is about", () => {
  const c = (key: string, hits: number, enc: number, depth = 5, behind = 0) => ({ key, hits, enclosure: enc, depth, behind });
  it("the carton in the loop beats the rack that fills it", () => {
    const r = rank([c("rack", 60, 0.03), c("milk", 36, 1)], 96);
    expect(r.partial).toBe(false);
    expect(r.members.map((m) => m.key)).toEqual(["milk"]);
    expect(r.others.map((m) => m.key)).toEqual(["rack"]);
  });
  it("a row of products circled together is a group", () => {
    const r = rank([c("rack", 30, 0.05), c("a", 14, 0.95), c("b", 16, 1), c("c", 12, 1), c("d", 14, 0.9)], 96);
    expect(r.members.map((m) => m.key).sort()).toEqual(["a", "b", "c", "d"]);
  });
  it("a character in front of a shelf: the character, not the tins that show around it", () => {
    const r = rank([c("webster", 48, 1, 4), c("tin1", 3, 1, 9), c("tin2", 2, 1, 9), c("rack", 40, 0.04, 9)], 96);
    expect(r.members.map((m) => m.key)).toEqual(["webster"]);
  });
  it("a patch of wall is part of the wall", () => {
    const r = rank([c("wall", 90, 0.01), c("floor", 6, 0.02)], 96);
    expect(r.partial).toBe(true);
    expect(r.members.map((m) => m.key)).toEqual(["wall"]);
  });
  it("a counter with its tall sign sticking out of the loop beats the wall behind it", () => {
    const r = rank([c("walls", 60, 0), c("kiosk", 25, 0.35), c("floor", 10, 0.01)], 96);
    expect(r.members.map((m) => m.key)).toEqual(["kiosk"]);
    expect(r.partial).toBe(true);
  });
  it("a thing half inside still counts when nothing else is", () => {
    const r = rank([c("kiosk", 70, 0.6)], 96);
    expect(r.partial).toBe(false);
    expect(r.members[0].key).toBe("kiosk");
  });
  it("nothing but hidden things: no members, they are offered", () => {
    const r = rank([c("far", 0, 1, 20, 12), c("near", 0, 1, 8, 4)], 96);
    expect(r.members).toEqual([]);
    expect(r.others.map((m) => m.key)).toEqual(["near", "far"]);
  });
});

const entity = (key: string, kind = "mesh"): SceneEntity => ({ key, label: key, kind, locator: { strategy: "name", value: key } });

describe("chains and depth, as with HTML components", () => {
  it("groups climb to what their members share", () => {
    const store = entity("store");
    const aisle = entity("dairy", "aisle");
    const a = entity("milk", "product");
    const b = entity("kefir", "product");
    const chains = [[a, aisle, store], [b, aisle, store]];
    expect(commonChain(chains).map((e) => e.key)).toEqual(["dairy", "store"]);
    const chain = groupChain([a, b], chains);
    expect(chain[0].kind).toBe("group");
    expect(chain[0].label).toBe("2 × products in dairy");
    expect(chain.slice(1).map((e) => e.key)).toEqual(["dairy", "store"]);
  });
  it("depth stays on the chain; a new layer starts at its own hit", () => {
    let target: NoteTarget = { layers: [[entity("a"), entity("b")], [entity("x"), entity("y"), entity("z")]], layer: 0, depth: 0, partial: false, method: "mouse" };
    target = selectDepth(target, 9);
    expect(current(target)?.key).toBe("b");
    target = selectLayer(target, 1);
    expect(target.depth).toBe(0);
    expect(current(target)?.key).toBe("x");
  });
});

describe("pressure, as on the iPad", () => {
  it("harder climbs the chain, jitter around a threshold does not flip it", () => {
    const t = new PressureDepthTracker(3);
    expect(t.update(0.2, 0)).toBe(0);
    expect(t.update(0.35, 0.05)).toBe(0); // threshold 1/3 + band/2
    expect(t.update(0.36, 0.1)).toBe(1);
    expect(t.update(0.32, 0.15)).toBe(1); // inside the band: stays
    expect(t.update(0.3, 0.2)).toBe(0);
  });
  it("lifting the pen keeps the depth that was held", () => {
    const t = new PressureDepthTracker(4);
    t.update(0.6, 0);
    t.update(0.6, 0.2);
    t.update(0.6, 0.4);
    expect(t.depth).toBe(2);
    // The pen lifts: force falls fast, but no lower depth was held long enough.
    t.update(0.1, 0.45);
    t.update(0.02, 0.5);
    expect(t.commit()).toBe(2);
  });
});

const pose = { position: [1, 2, 3] as [number, number, number], quaternion: [0, 0, 0, 1] as [number, number, number, number], fov: 62, aspect: 1.6, near: 0.1, far: 200 };
const snapshot = (id: string, title: string): Snapshot => ({ id, title, pose, widthPx: 1600, heightPx: 1000, takenAt: "2026-11-05T10:00:00.000Z" });
const note = (ordinal: number, snapshotId: string, text: string, extra: Partial<Note> = {}): Note => ({
  id: `n${ordinal}`,
  ordinal,
  snapshotId,
  shape: { kind: "lasso", points: [[0.1, 0.1], [0.2, 0.1], [0.2, 0.2]] },
  world: { anchor: [1, 1, 1], normal: [0, 0, 1], ink: [[0, 0, 0], [1, 0, 0], [1, 1, 0]] },
  text,
  textSource: text ? "voice" : "none",
  revision: 1,
  createdAt: "2026-11-05T10:00:00.000Z",
  updatedAt: "2026-11-05T10:00:00.000Z",
  ...extra,
});

describe("the feedback package", () => {
  const project = { id: "shop", title: "Shop" };
  const milk = { ...entity("milk", "product"), label: "Mleko 2%", source: ["client/world/products.ts"] };
  const target = { layers: [[milk, { ...entity("dairy", "aisle"), label: "Nabiał" }], [entity("rack")]], layer: 0, depth: 0, partial: false, method: "pen" as const, pressure: 0.4 };
  const notes = [note(1, "s1", "Większe, proszę", { target }), note(2, "s2", "Za ciemno"), note(3, "s1", "Tutaj też"), note(4, "s1", ""), note(5, "s2", "wysłane", { lastSentRevision: 1 })];
  const snapshots = [snapshot("s1", "Nabiał"), snapshot("s2", "Kasa")];

  it("readiness: a mark without text waits, sent notes stay out", () => {
    expect(notes.map(readiness)).toEqual(["ready", "ready", "ready", "markOnly", "sent"]);
    expect(readiness(note(9, "s1", "x", { recording: "recording" }))).toBe("recording");
  });
  it("numbers are consecutive, sent notes hidden", () => {
    const numbers = displayNumbers(notes);
    expect([...numbers.values()]).toEqual([1, 2, 3, 4]);
    expect(numbers.has("n5")).toBe(false);
  });
  it("one view appears once with all its marks, ordered by its first note", () => {
    const pkg = buildPackage({ batchId: "b1", project, notes, snapshots, noteIds: new Set(["n1", "n2", "n3"]), directive: { mode: "apply", note: "" }, now: "2026-11-05T10:00:00.000Z" });
    expect(pkg.groups.map((g) => g.snapshot.id)).toEqual(["s1", "s2"]);
    expect(pkg.groups[0].items.map((i) => i.number)).toEqual([1, 3]);
    expect(pkg.groups[0].compositeFileName).toBe("01-s1.jpg");
    expect(pkg.isRepeat).toBe(false);
  });
  it("the message carries the marker, the instruction, targets, and the place in the world", () => {
    const pkg = buildPackage({ batchId: "b1", project, notes, snapshots, noteIds: new Set(["n1"]), directive: { mode: "apply", note: "Tylko kolory" }, now: "2026-11-05T10:00:00.000Z", revision: { commit: "abc123", dirty: true } });
    const text = messageText(pkg);
    expect(text.split("\n")[0]).toBe('[drawspeak-batch:b1] Drawspeak 3D feedback for "Shop": 1 comment on 1 view.');
    expect(text).toContain("Instruction: make these changes");
    expect(text).toContain("Additional instruction from the reviewer: Tylko kolory");
    expect(text).toContain("Marked on commit abc123 with uncommitted changes.");
    expect(text).toContain("1. [Loop] Większe, proszę");
    expect(text).toContain("Target: Mleko 2% › Nabiał (product)");
    expect(text).toContain("Source hints: client/world/products.ts");
    expect(text).toContain("Also in that direction: rack");
  });
  it("reply only says so; sent notes make a repeat", () => {
    const pkg = buildPackage({ batchId: "b2", project, notes, snapshots, noteIds: new Set(["n5"]), directive: { mode: "replyOnly", note: "" }, now: "2026-11-05T10:00:00.000Z" });
    expect(pkg.isRepeat).toBe(true);
    const text = messageText(pkg);
    expect(text).toContain("Note: this repeats comments");
    expect(text).toContain("Do not change any files.");
  });
  it("the manifest maps numbers to notes, cameras and chains", () => {
    const pkg = buildPackage({ batchId: "b1", project, notes, snapshots, noteIds: new Set(["n1"]), directive: { mode: "apply", note: "" }, now: "2026-11-05T10:00:00.000Z" });
    const manifest = manifestOf(pkg);
    expect(manifest.schema).toBe("drawspeak3d.feedback.v1");
    const item = manifest.snapshots[0].notes[0];
    expect(item.number).toBe(1);
    expect(item.target?.selected?.label).toBe("Mleko 2%");
    expect(item.target?.chain.map((e) => e.label)).toEqual(["Mleko 2%", "Nabiał"]);
    expect(item.target?.behind[0]?.label).toBe("rack");
    expect(manifest.snapshots[0].camera.fov).toBe(62);
    expect(JSON.parse(JSON.stringify(manifest)).batchId).toBe("b1");
  });

  const shelf = { label: "Rack 7", kind: "rack", distance: 1.345, locator: { strategy: "adapter" as const, value: "rack:7" } };
  const about = (extra: Partial<Note>, snapshots2 = snapshots) => {
    const notes2 = [note(1, "s1", "Tu", extra)];
    return buildPackage({ batchId: "b3", project, notes: notes2, snapshots: snapshots2, noteIds: new Set(["n1"]), directive: { mode: "apply", note: "" }, now: "2026-11-05T10:00:00.000Z" });
  };
  const here: WorldMark = { anchor: [2, 0, 3], normal: [0, 1, 0], ink: [[2, 0, 3]], place: { center: [2.004, 0, 3], normal: [0, 1, 0], size: [2.41, 0, 1.12], on: "Floor", near: [shelf] } };
  const route: WorldMark = {
    anchor: [0, 0, 0],
    normal: [0, 1, 0],
    ink: [[0, 0, 0], [4, 0, 1], [8, 0, 2]],
    path: {
      points: [[0, 0, 0], [4, 0, 1], [8, 0, 2]],
      length: 8.246,
      onGround: true,
      from: { at: [0, 0, 0], label: "Floor", kind: "mesh", isThing: false, near: [shelf] },
      to: { at: [8, 0, 2], label: "Crate", kind: "mesh", locator: { strategy: "name", value: "Crate" }, isThing: true, near: [] },
      through: ["Webster"],
    },
  };
  it("a place says where it is, on what, how big and what stands near", () => {
    const text = messageText(about({ shape: { kind: "lasso", points: [[0.1, 0.1], [0.2, 0.1], [0.2, 0.2]] }, world: here }));
    expect(text).toContain("Place: on Floor, at (2, 0, 3), about 2.4 × 1.1 across, facing (0, 1, 0)");
    expect(text).toContain("Near: Rack 7 (1.3)");
    expect(text).not.toContain("   At (");
  });
  it("a single spot has no size", () => {
    const spot: WorldMark = { ...here, place: { ...here.place!, size: [0, 0, 0] } };
    const text = messageText(about({ shape: { kind: "point", at: [0.5, 0.5] }, world: spot }));
    expect(text).toContain("1. [Spot] Tu");
    expect(text).toContain("Place: on Floor, at (2, 0, 3), facing (0, 1, 0)");
  });
  it("a line says where from, where to, how far, and what it passes", () => {
    const text = messageText(about({ shape: { kind: "arrow", from: [0.1, 0.8], to: [0.7, 0.5] }, world: route }));
    expect(text).toContain("1. [Line] Tu");
    expect(text).toContain("From: Floor at (0, 0, 0), near Rack 7 (1.3)");
    expect(text).toContain("To: Crate (this thing) at (8, 0, 2)");
    expect(text).toContain("Line: 8.2 long, along the ground, through (0, 0, 0) → (4, 0, 1) → (8, 0, 2)");
    expect(text).toContain("It passes: Webster");
  });
  it("a long line in the message keeps its two ends", () => {
    const points = Array.from({ length: 24 }, (_, i): [number, number, number] => [i, 0, 0]);
    const long: WorldMark = { ...route, ink: points, path: { ...route.path!, points } };
    const text = messageText(about({ shape: { kind: "arrow", from: [0.1, 0.8], to: [0.7, 0.5] }, world: long }));
    expect(text).toContain("through (0, 0, 0) → ");
    expect(text).toContain(" → (23, 0, 0)");
  });
  it("a comment on the whole view names no place, and says where the reviewer stands", () => {
    const pkg = about({ shape: { kind: "view" }, world: { anchor: [0, 1, 0], normal: [0, 0, 1], ink: [] } }, [{ ...snapshot("s1", "Nabiał"), viewer: { position: [4, 0, 5], facing: [0, 0, -1] } }, snapshot("s2", "Kasa")]);
    const text = messageText(pkg);
    expect(text).toContain("1. [View] Tu");
    expect(text).toContain("own character stands at (4, 0, 5), facing (0, 0, -1)");
    expect(text).not.toContain("Place:");
    expect(text).not.toContain("   At (");
    expect(manifestOf(pkg).snapshots[0].viewer?.position).toEqual([4, 0, 5]);
  });
  it("the instruction says adding, moving and changing the flow are all fair", () => {
    const text = messageText(about({}));
    expect(text).toContain("add something new at a place");
    expect(text).toContain("how the experience flows");
    expect(text).toContain("line from here to there");
  });
  it("the manifest carries place and path, rounded", () => {
    const placed = manifestOf(about({ world: here })).snapshots[0].notes[0];
    expect(placed.place?.center).toEqual([2.004, 0, 3]);
    expect(placed.place?.near[0].distance).toBe(1.35);
    const line = manifestOf(about({ shape: { kind: "arrow", from: [0.1, 0.8], to: [0.7, 0.5] }, world: route })).snapshots[0].notes[0];
    expect(line.path?.length).toBe(8.25);
    expect(line.path?.to.isThing).toBe(true);
    expect(line.path?.points.length).toBe(3);
    expect(JSON.parse(JSON.stringify(line)).shape.kind).toBe("arrow");
  });
  it("a camera with no turn looks along -Z", () => {
    expect(lookingAt(pose, 5)).toEqual([1, 2, -2]);
  });
});
