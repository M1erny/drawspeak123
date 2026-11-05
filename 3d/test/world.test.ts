import * as THREE from "three";
import { describe, expect, it } from "vitest";
import type { SceneEntity, Vec2, Vec3 } from "../src/core/types.ts";
import { Host } from "../src/three/host.ts";
import { Picker, inkPlane, isSurfaceLike, lineInWorld, lineLength, liftOnto, ringOn, toScreen, type SceneAdapter } from "../src/three/world.ts";
import { projectInk } from "../src/ui/overlay.ts";

const rect = { left: 0, top: 0, width: 1000, height: 600 } as DOMRect;

function camera(position: [number, number, number], lookAt: [number, number, number] = [0, 0, 0]) {
  const c = new THREE.PerspectiveCamera(60, 1000 / 600, 0.1, 100);
  c.position.set(...position);
  c.lookAt(...lookAt);
  c.updateMatrixWorld();
  c.updateProjectionMatrix();
  return c;
}

describe("ink on the screen", () => {
  const square: Vec3[] = [[-1, -1, 0], [1, -1, 0], [1, 1, 0], [-1, 1, 0]];

  it("a loop in front of the camera stays one closed line", () => {
    const { runs, whole } = projectInk(square, true, camera([0, 0, 5]), rect);
    expect(whole).toBe(true);
    expect(runs.length).toBe(1);
    expect(runs[0].length).toBe(5);
  });

  it("walking past a mark: the part behind you is cut, and the rest is not closed across the screen", () => {
    // The camera stands on the square's plane, looking along +X from its middle: two corners are behind it.
    const c = camera([0, 0, 0.01], [10, 0, 0.01]);
    const { runs, whole } = projectInk(square, true, c, rect);
    expect(whole).toBe(false);
    expect(runs.length).toBeGreaterThan(0);
    // Vertex 0 behind the camera, at most two vertices cut: the case that used to close across the cut.
    const c2 = camera([-0.5, -0.5, 0.2], [10, 5, 0.2]);
    const second = projectInk(square, true, c2, rect);
    expect(second.whole).toBe(false);
  });

  it("all of it behind: nothing to draw", () => {
    const { runs, whole } = projectInk(square, true, camera([0, 0, 5], [0, 0, 10]), rect);
    expect(runs).toEqual([]);
    expect(whole).toBe(false);
  });

  it("an open line is never closed", () => {
    const { whole, runs } = projectInk(square, false, camera([0, 0, 5]), rect);
    expect(whole).toBe(false);
    expect(runs[0].length).toBe(4);
  });

  it("toScreen and projectInk agree", () => {
    const c = camera([2, 1, 5]);
    const { runs } = projectInk(square, false, c, rect);
    const direct = toScreen(square[0], c, rect)!;
    expect(runs[0][0][0]).toBeCloseTo(direct[0], 5);
    expect(runs[0][0][1]).toBeCloseTo(direct[1], 5);
  });
});

describe("ink lifted onto a surface", () => {
  it("lies on the surface it was drawn on, and comes back to the same screen points", () => {
    const c = camera([0, 1, 6], [0, 1, 0]);
    const plane = inkPlane([{ point: [0, 1, 0], normal: [0, 0, 1], distance: 6 }, { point: [0.5, 1, 0], normal: [0, 0, 1], distance: 6 }], c, 5);
    expect(plane.normal).toEqual([0, 0, 1]);
    const points: Array<[number, number]> = [[400, 250], [600, 250], [500, 400]];
    const lifted = liftOnto(points, plane, c, rect);
    for (const p of lifted) expect(p[2]).toBeCloseTo(0, 5);
    points.forEach((p, i) => {
      const back = toScreen(lifted[i], c, rect)!;
      expect(back[0]).toBeCloseTo(p[0], 3);
      expect(back[1]).toBeCloseTo(p[1], 3);
    });
  });

  it("a surface seen nearly edge-on gets a plane facing the camera, or ink would stretch away", () => {
    const c = camera([0, 1, 6], [0, 1, 0]);
    const plane = inkPlane([{ point: [0, 1, 0], normal: [1, 0, 0], distance: 6 }], c, 5);
    expect(plane.normal[2]).toBeCloseTo(1, 5);
  });

  it("surfaces that disagree (a bottle) get a plane facing the camera", () => {
    const c = camera([0, 1, 6], [0, 1, 0]);
    const plane = inkPlane([{ point: [0, 1, 0], normal: [0.9, 0, 0.43], distance: 6 }, { point: [0, 1, 0], normal: [-0.9, 0, 0.43], distance: 6 }], c, 5);
    expect(plane.normal[2]).toBeCloseTo(1, 5);
  });

  it("nothing hit: a plane at the last distance", () => {
    const c = camera([0, 0, 6], [0, 0, 0]);
    const plane = inkPlane([], c, 4);
    expect(plane.point[2]).toBeCloseTo(2, 5);
  });
});

/** A renderer that only remembers where the camera was when it was asked to draw. */
function fakeRenderer() {
  const seen: { position?: THREE.Vector3; fov?: number } = {};
  const renderer = {
    domElement: { getBoundingClientRect: () => rect },
    render(_scene: THREE.Scene, c: THREE.PerspectiveCamera) {
      c.updateWorldMatrix(true, false);
      seen.position = new THREE.Vector3().setFromMatrixPosition(c.matrixWorld);
      seen.fov = c.fov;
    },
  };
  return { renderer: renderer as unknown as THREE.WebGLRenderer, seen };
}

describe("looking from a saved view", () => {
  const pose = { position: [1, 2, 3] as Vec3, quaternion: [0, 0, 0, 1] as [number, number, number, number], fov: 40, aspect: 1.6, near: 0.1, far: 100 };

  it("the frame is drawn from the view, and the app's camera comes back untouched", () => {
    const { renderer, seen } = fakeRenderer();
    const c = camera([10, 0, 0]);
    const host = new Host(renderer, { camera: c });
    host.setView(pose, 0);
    renderer.render(new THREE.Scene(), c);
    expect(seen.position!.toArray()).toEqual([1, 2, 3]);
    expect(seen.fov).toBe(40);
    expect(c.position.toArray()).toEqual([10, 0, 0]);
    expect(c.fov).toBe(60);
    expect(host.shown.position.toArray()).toEqual([1, 2, 3]);
  });

  it("a camera that hangs from something goes to the same place in the world", () => {
    const { renderer, seen } = fakeRenderer();
    const rig = new THREE.Group();
    rig.position.set(100, 0, 0);
    rig.rotation.y = Math.PI / 2;
    const c = new THREE.PerspectiveCamera(60, 1.6, 0.1, 100);
    rig.add(c);
    c.position.set(0, 0, 5);
    rig.updateMatrixWorld(true);
    const host = new Host(renderer, { camera: c });
    host.setView(pose, 0);
    renderer.render(new THREE.Scene(), c);
    expect(seen.position!.x).toBeCloseTo(1, 5);
    expect(seen.position!.y).toBeCloseTo(2, 5);
    expect(seen.position!.z).toBeCloseTo(3, 5);
    expect(host.shown.quaternion.w).toBeCloseTo(1, 5);
    expect(c.position.toArray()).toEqual([0, 0, 5]);
  });

  it("what is shown is a world camera, for a camera that hangs from something too", () => {
    const { renderer } = fakeRenderer();
    const rig = new THREE.Group();
    rig.position.set(100, 0, 0);
    const c = new THREE.PerspectiveCamera(60, 1.6, 0.1, 100);
    c.position.set(0, 0, 5);
    rig.add(c);
    rig.updateMatrixWorld(true);
    const host = new Host(renderer, { camera: c });
    renderer.render(new THREE.Scene(), c);
    expect(host.shown.position.toArray()).toEqual([100, 0, 5]);
  });

  it("a bug in the tool's frame does not stop the game's loop", () => {
    const { renderer } = fakeRenderer();
    const c = camera([0, 0, 5]);
    const host = new Host(renderer, { camera: c });
    host.onFrame = () => {
      throw new Error("a bug");
    };
    const log = console.error;
    console.error = () => {};
    expect(() => renderer.render(new THREE.Scene(), c)).not.toThrow();
    console.error = log;
  });

  it("letting go glides back to the app's camera", () => {
    const { renderer, seen } = fakeRenderer();
    const c = camera([10, 0, 0]);
    const host = new Host(renderer, { camera: c });
    host.setView(pose, 0);
    renderer.render(new THREE.Scene(), c);
    host.setView(null, 0);
    expect(host.lookingFromView).toBe(false);
    renderer.render(new THREE.Scene(), c);
    expect(seen.position!.x).toBeCloseTo(10, 5);
  });
});

describe("places and routes in a room", () => {
  const material = new THREE.MeshBasicMaterial();
  const solid = (name: string, size: Vec3, at: Vec3) => {
    const mesh = new THREE.Mesh(new THREE.BoxGeometry(...size), material);
    mesh.name = name;
    mesh.position.set(...at);
    return mesh;
  };
  function room(extra: THREE.Object3D[] = [], adapter: SceneAdapter = {}) {
    const scene = new THREE.Scene();
    scene.add(solid("Floor", [40, 0.2, 40], [0, -0.1, 0]), solid("Table", [2, 1, 1], [3, 0.5, 0]), solid("Crate", [1, 1, 1], [-4, 0.5, -3]), ...extra);
    scene.updateMatrixWorld(true);
    return { scene, picker: new Picker(() => scene, adapter) };
  }
  const view = camera([0, 6, 10]);
  /** A line on the screen through world points, a point every few pixels. */
  const drawn = (from: Vec3, to: Vec3, c = view): Vec2[] => {
    const a = toScreen(from, c, rect)!;
    const b = toScreen(to, c, rect)!;
    return Array.from({ length: 41 }, (_, i): Vec2 => [a[0] + ((b[0] - a[0]) * i) / 40, a[1] + ((b[1] - a[1]) * i) / 40]);
  };

  it("what is along a line: 24 points at most, the two ends always among them", () => {
    const { picker } = room();
    const points = drawn([-3, 0, 5], [3, 0, 5]);
    const samples = picker.alongLine(points, view, rect);
    expect(samples.length).toBe(24);
    expect(samples[0].at).toEqual(points[0]);
    expect(samples[23].at).toEqual(points[40]);
    expect(samples.every((s) => s.hit?.chain[0].label === "Floor")).toBe(true);
    expect(picker.alongLine([points[0], points[40]], view, rect).length).toBe(2);
  });

  it("along a line, one facing of a product has its own box, as in a circle", () => {
    const product: SceneEntity = { key: "milk", label: "Milk", kind: "product", locator: { strategy: "adapter", value: "product:1" } };
    const bounds = { min: [0, 0, 0] as Vec3, max: [1, 1, 1] as Vec3 };
    const { picker } = room([], { along: () => [{ chain: [product], distance: 1, point: [0, 0, 0], normal: [0, 0, 1], bounds }] });
    const samples = picker.alongLine([[300, 300], [320, 300]], view, rect);
    expect(samples[0].hit?.chain[0].label).toBe("Milk");
    expect(samples[0].hit?.chain[0].bounds).toEqual(bounds);
  });

  it("a line over the floor lies on the floor, where it was drawn", () => {
    const { picker } = room();
    const samples = picker.alongLine(drawn([-3, 0, 5], [3, 0, 5]), view, rect);
    const line = lineInWorld(samples, view, rect, 5);
    expect(line.onGround).toBe(true);
    expect(line.normal).toEqual([0, 1, 0]);
    for (const p of line.points) {
      expect(p[1]).toBeCloseTo(0, 5);
      expect(p[2]).toBeCloseTo(5, 3);
    }
    expect(line.points[0][0]).toBeCloseTo(-3, 3);
    expect(line.points[23][0]).toBeCloseTo(3, 3);
    expect(lineLength(line.points)).toBeCloseTo(6, 3);
  });

  it("a route passing a table stays on the floor, behind it", () => {
    const { picker } = room();
    const samples = picker.alongLine(drawn([3, 0, 7], [3, 0, -8]), view, rect);
    expect(samples.some((s) => s.hit?.chain[0].label === "Table")).toBe(true);
    const line = lineInWorld(samples, view, rect, 5);
    expect(line.onGround).toBe(true);
    for (const p of line.points) expect(p[1]).toBeCloseTo(0, 5);
    // Where the table shows on the screen, the point on the floor is hidden behind it.
    samples.forEach((sample, i) => expect(line.touches[i]).toBe(sample.hit?.chain[0].label === "Floor"));
  });

  it("a line across a wall follows the wall", () => {
    const { picker } = room([solid("Wall", [40, 8, 0.2], [0, 4, -5])]);
    const samples = picker.alongLine(drawn([-3, 3, -4.9], [3, 3, -4.9]), view, rect);
    const line = lineInWorld(samples, view, rect, 5);
    expect(line.onGround).toBe(false);
    for (const p of line.points) {
      expect(p[2]).toBeCloseTo(-4.9, 3);
      expect(p[1]).toBeCloseTo(3, 3);
    }
  });

  it("a line up the stairs climbs them, it is not flattened onto one level", () => {
    const steps = Array.from({ length: 8 }, (_, i) => solid(`Step ${i}`, [6, 0.2 * (i + 1), 1], [0, 0.1 * (i + 1), 3 - i]));
    const { picker } = room(steps);
    const samples = picker.alongLine(drawn([0, 0.2, 3], [0, 1.6, -4]), view, rect);
    const line = lineInWorld(samples, view, rect, 5);
    expect(line.onGround).toBe(true);
    const heights = line.points.map((p) => p[1]);
    expect(Math.max(...heights) - Math.min(...heights)).toBeGreaterThan(1);
  });

  it("a line in thin air stays at the last distance known, it has no ground", () => {
    const { picker } = room();
    const up = camera([0, 6, 10], [0, 40, 10]);
    const samples = picker.alongLine([[300, 200], [700, 200]], up, rect);
    expect(samples.every((s) => s.hit === undefined)).toBe(true);
    const line = lineInWorld(samples, up, rect, 5);
    expect(line.onGround).toBe(false);
    for (const p of line.points) expect(new THREE.Vector3(...p).distanceTo(new THREE.Vector3(0, 6, 10))).toBeCloseTo(5, 3);
  });

  it("what is near a place: nearest first, without what it lies on", () => {
    const { scene, picker } = room();
    const floor = scene.getObjectByName("Floor")!;
    const near = picker.nearby([3, 0, 2], [floor.uuid]);
    expect(near.map((n) => n.label)).toEqual(["Table", "Crate"]);
    expect(near[0].distance).toBeCloseTo(1.5, 5);
    expect(near[0].locator.value).toContain("Table");
    expect(picker.nearby([3, 0, 2], [floor.uuid], 1).length).toBe(1);
  });

  it("the ground under a place is not near it; a rug beside it is", () => {
    const { picker } = room([solid("Rug", [2, 0.02, 2], [-8, 0.01, 8])]);
    expect(picker.nearby([3, 0, 2]).map((n) => n.label)).toEqual(["Table", "Crate", "Rug"]);
    expect(picker.nearby([-8, 0, 8]).map((n) => n.label)).not.toContain("Rug");
  });

  it("a named group is one thing, not its parts", () => {
    const group = new THREE.Group();
    group.name = "Kiosk";
    group.add(solid("Counter", [1, 1, 1], [8, 0.5, 8]), solid("Sign", [1, 1, 0.1], [8, 2, 8]));
    const { scene, picker } = room([group]);
    const floor = scene.getObjectByName("Floor")!;
    const labels = picker.nearby([8, 0, 6], [floor.uuid]).map((n) => n.label);
    expect(labels).toContain("Kiosk");
    expect(labels).not.toContain("Counter");
  });

  it("an app can say what is worth naming", () => {
    const stand: SceneEntity = { key: "stand", label: "Stand", kind: "prop", locator: { strategy: "adapter", value: "stand:1" }, bounds: { min: [0, 0, 0], max: [1, 1, 1] } };
    const { picker } = room([], { nearby: () => [stand] });
    expect(picker.nearby([3, 0, 0]).map((n) => n.label)).toEqual(["Stand"]);
  });

  it("a floor and a wall are surfaces, a table and a small sign are things", () => {
    const { scene } = room();
    const entity = (name: string): SceneEntity => {
      const b = new THREE.Box3().setFromObject(scene.getObjectByName(name)!);
      return { key: name, label: name, kind: "mesh", locator: { strategy: "name", value: name }, bounds: { min: [b.min.x, b.min.y, b.min.z], max: [b.max.x, b.max.y, b.max.z] } };
    };
    expect(isSurfaceLike(entity("Floor"), view, rect)).toBe(true);
    expect(isSurfaceLike(entity("Table"), view, rect)).toBe(false);
    expect(isSurfaceLike(undefined, view, rect)).toBe(true);
    const flat = (min: Vec3, max: Vec3): SceneEntity => ({ key: "f", label: "f", kind: "mesh", locator: { strategy: "name", value: "f" }, bounds: { min, max } });
    expect(isSurfaceLike(flat([-10, 0, -5], [10, 6, -4.8]), view, rect)).toBe(true);
    expect(isSurfaceLike(flat([-0.3, 1, -1], [0.3, 1.3, -0.98]), view, rect)).toBe(false);
    // Standing on it, part of it behind the camera.
    expect(isSurfaceLike(flat([-1, 0, -1], [1, 1, 20]), view, rect)).toBe(true);
  });

  it("a ring lies on its surface, at its radius", () => {
    const ring = ringOn({ point: [2, 0, 3], normal: [0, 1, 0] }, [2, 0, 3], 0.5);
    expect(ring.length).toBe(20);
    for (const p of ring) {
      expect(p[1]).toBeCloseTo(0, 6);
      expect(Math.hypot(p[0] - 2, p[2] - 3)).toBeCloseTo(0.5, 6);
    }
    for (const p of ringOn({ point: [0, 1, 0], normal: [0, 0, 1] }, [0, 1, 0], 0.5)) {
      expect(p[2]).toBeCloseTo(0, 6);
      expect(Math.hypot(p[0], p[1] - 1)).toBeCloseTo(0.5, 6);
    }
  });

  it("a mark far off on the floor still lies on the floor; a circle around a counter does not lie on its top", () => {
    const low = camera([0, 1.6, 0], [0, 0, -20]);
    const far = inkPlane([{ point: [0, 0, -20], normal: [0, 1, 0], distance: 20 }], low, 5, true);
    expect(far.normal).toEqual([0, 1, 0]);
    const top = inkPlane([{ point: [0, 1, -20], normal: [0, 1, 0], distance: 20 }], low, 5);
    expect(top.normal[1]).toBeLessThan(0.5);
    const edgeOn = inkPlane([{ point: [2, 1.6, -20], normal: [-1, 0, 0], distance: 20 }], low, 5);
    expect(edgeOn.normal[0]).not.toBe(-1);
  });
});
