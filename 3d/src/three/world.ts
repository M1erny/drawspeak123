import * as THREE from "three";
import { CENTER, MeshBVH, acceleratedRaycast } from "three-mesh-bvh";
import { boundsOf, enclosure, samplePolygon, type Rect } from "../core/geometry.ts";
import { groupChain, rank, type Candidate } from "../core/selection.ts";
import type { Box, NearThing, NoteTarget, Pose, SceneEntity, Vec2, Vec3, Viewer } from "../core/types.ts";

/**
 * From a loop on the screen to things in the world. Rays through the loop say what is there; the
 * ranking (core/selection.ts) says which of it is meant; the ink is then lifted onto the surface it
 * was drawn on, so it stays on the thing as you walk around it.
 *
 * Everything works from a frozen copy of the camera (taken when the pen touched down), never the
 * live one: the world may go on moving.
 */

/** One thing along a ray. */
export interface RayHit {
  /** The thing first, then its parents. */
  chain: SceneEntity[];
  distance: number;
  point: Vec3;
  /** Faces the camera, when known. */
  normal?: Vec3;
  /** The part of the thing that was hit, when it differs from chain[0].bounds (one facing of a product). */
  bounds?: Box;
}

/**
 * What an app can tell about its world. All optional: with none of it, things are named from the
 * scene graph (object.name, object.userData.drawspeak = { label, kind, source, data }).
 */
export interface SceneAdapter {
  /** Things the app picks by its own means along a ray (instanced stock, physics shapes). */
  along?(ray: THREE.Ray, far: number): RayHit[];
  /** A scene hit as a chain. null ignores the hit, undefined names it from the scene graph. */
  describe?(hit: THREE.Intersection): SceneEntity[] | null | undefined;
  /** Objects to leave out of picks, with everything they hold. */
  skip?(object: THREE.Object3D): boolean;
  /** Where a view is, in words. */
  title?(pose: Pose): string;
  /** While a stroke is drawn: stop the player, and whatever else should wait. */
  freeze?(on: boolean): void;
  /** A pen tap that was not a mark: what a click does there. */
  tap?(x: number, y: number): void;
  /** Keep the player's state across a reload, and put it back. */
  /** Something is going on that a reload would break (a window of the game is open): it waits. */
  busy?(): boolean;
  /** What is wrong in the app right now, for an agent looking at its work. */
  problems?(): string[];
  save?(): unknown;
  restore?(state: unknown): void;
  /** A link that opens a view, when the app can. Default: this page with ds3d_view. */
  viewLink?(pose: Pose): string | undefined;
  /** What the world is, and how things get added to it, for the agent. */
  world?: { engine?: string; units?: string; up?: string; notes?: string };
  /** Things worth naming around a place, with their bounds. Default: the named things in the scene. */
  nearby?(point: Vec3): SceneEntity[];
  /** Where the person's own character is, for "next to me". */
  viewer?(): Viewer | undefined;
}

export const toVec3 = (v: THREE.Vector3): Vec3 => [v.x, v.y, v.z];
export const fromVec3 = (v: Vec3, out = new THREE.Vector3()) => out.set(v[0], v[1], v[2]);

export function poseOf(camera: THREE.PerspectiveCamera): Pose {
  return {
    position: [camera.position.x, camera.position.y, camera.position.z],
    quaternion: [camera.quaternion.x, camera.quaternion.y, camera.quaternion.z, camera.quaternion.w],
    fov: camera.fov,
    aspect: camera.aspect,
    near: camera.near,
    far: camera.far,
  };
}

const box = (b: THREE.Box3): Box => ({ min: toVec3(b.min), max: toVec3(b.max) });

const corners = (b: Box): Vec3[] => {
  const [a, c] = [b.min, b.max];
  return [
    [a[0], a[1], a[2]], [c[0], a[1], a[2]], [a[0], c[1], a[2]], [c[0], c[1], a[2]],
    [a[0], a[1], c[2]], [c[0], a[1], c[2]], [a[0], c[1], c[2]], [c[0], c[1], c[2]],
  ];
};

const scratch = new THREE.Vector3();

/** A world point on a screen rectangle, or nothing when it is behind the camera. */
export function toScreen(point: Vec3, camera: THREE.Camera, rect: { left: number; top: number; width: number; height: number }): Vec2 | undefined {
  scratch.set(point[0], point[1], point[2]).applyMatrix4(camera.matrixWorldInverse);
  if (scratch.z >= -1e-4) return undefined;
  scratch.applyMatrix4(camera.projectionMatrix);
  return [rect.left + ((scratch.x + 1) / 2) * rect.width, rect.top + ((1 - scratch.y) / 2) * rect.height];
}

/** A box's corners on screen, as far as they are in front of the camera. */
export function boxOnScreen(b: Box, camera: THREE.Camera, rect: { left: number; top: number; width: number; height: number }): { points: Vec2[]; complete: boolean } {
  const points: Vec2[] = [];
  for (const corner of corners(b)) {
    const p = toScreen(corner, camera, rect);
    if (p) points.push(p);
  }
  return { points, complete: points.length === 8 };
}

function screenRectOf(b: Box, camera: THREE.Camera, rect: { left: number; top: number; width: number; height: number }): Rect | undefined {
  const { points, complete } = boxOnScreen(b, camera, rect);
  if (!complete) return undefined; // reaches behind the camera: it cannot be inside a loop
  let minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity;
  for (const [x, y] of points) {
    if (x < minX) minX = x;
    if (y < minY) minY = y;
    if (x > maxX) maxX = x;
    if (y > maxY) maxY = y;
  }
  return { minX, minY, maxX, maxY };
}

/** Not drawn, or nothing to see: rays pass through. */
function isSeeThrough(object: THREE.Object3D): boolean {
  const material = (object as THREE.Mesh).material as THREE.Material | THREE.Material[] | undefined;
  if (!material) return true;
  const first = Array.isArray(material) ? material[0] : material;
  return first.visible === false || first.colorWrite === false || (first.transparent === true && first.opacity < 0.05);
}

function visibleMeshes(root: THREE.Object3D, skip: SceneAdapter["skip"], out: THREE.Object3D[] = []): THREE.Object3D[] {
  if (!root.visible || skip?.(root)) return out;
  const anyObject = root as THREE.Object3D & { isMesh?: boolean; isSprite?: boolean };
  if ((anyObject.isMesh || anyObject.isSprite) && !isSeeThrough(root)) out.push(root);
  for (const child of root.children) visibleMeshes(child, skip, out);
  return out;
}

/** A thing named from the scene graph: the hit object, then its named parents. */
export function chainFromGraph(hit: THREE.Intersection): SceneEntity[] {
  const chain: SceneEntity[] = [];
  const instanced = (hit.object as THREE.InstancedMesh).isInstancedMesh ? hit.instanceId : undefined;
  const names: string[] = [];
  for (let o: THREE.Object3D | null = hit.object; o; o = o.parent) names.unshift(o.name || o.type);
  let index = names.length - 1;
  for (let o: THREE.Object3D | null = hit.object; o; o = o.parent, index--) {
    const about = o.userData?.drawspeak as Partial<SceneEntity> | undefined;
    const isHit = o === hit.object;
    if (!isHit && !o.name && !about) continue;
    if ((o as THREE.Scene).isScene && !about) continue; // every chain would end in it
    const path = names.slice(0, index + 1).join("/");
    const bounds = isHit && instanced !== undefined ? instanceBox(hit.object as THREE.InstancedMesh, instanced) : new THREE.Box3().setFromObject(o);
    const suffix = isHit && instanced !== undefined ? `#${instanced}` : "";
    const name = about?.label ?? (o.name ? o.name + suffix : describeUnnamed(o) + suffix);
    chain.push({
      key: `${o.uuid}${suffix}`,
      label: name,
      kind: about?.kind ?? ((o as THREE.InstancedMesh).isInstancedMesh ? "instance" : o.type.toLowerCase()),
      locator: about?.locator ?? (o.name ? { strategy: "path", value: path + suffix } : { strategy: "uuid", value: o.uuid + suffix }),
      bounds: bounds.isEmpty() ? undefined : box(bounds),
      source: about?.source,
      data: about?.data ?? materialData(o),
    });
    if (isHit && instanced !== undefined) {
      const whole = new THREE.Box3().setFromObject(o);
      chain.push({
        key: o.uuid,
        label: o.name || describeUnnamed(o),
        kind: "mesh",
        locator: o.name ? { strategy: "path", value: path } : { strategy: "uuid", value: o.uuid },
        bounds: whole.isEmpty() ? undefined : box(whole),
        source: about?.source,
      });
    }
  }
  return chain;
}

function describeUnnamed(object: THREE.Object3D): string {
  const geometry = (object as THREE.Mesh).geometry as THREE.BufferGeometry | undefined;
  return geometry ? `${geometry.type.replace(/Geometry$/, "")} ${object.type.toLowerCase()}` : object.type;
}

function materialData(object: THREE.Object3D): Record<string, unknown> | undefined {
  const material = (object as THREE.Mesh).material as THREE.MeshStandardMaterial | THREE.MeshStandardMaterial[] | undefined;
  const first = Array.isArray(material) ? material[0] : material;
  if (!first) return undefined;
  const data: Record<string, unknown> = { material: first.name || first.type };
  if (first.color?.isColor) data.color = `#${first.color.getHexString()}`;
  return data;
}

function instanceBox(mesh: THREE.InstancedMesh, id: number): THREE.Box3 {
  if (!mesh.geometry.boundingBox) mesh.geometry.computeBoundingBox();
  const matrix = new THREE.Matrix4();
  mesh.getMatrixAt(id, matrix);
  matrix.premultiply(mesh.matrixWorld);
  return new THREE.Box3().copy(mesh.geometry.boundingBox!).applyMatrix4(matrix);
}

function worldNormal(hit: THREE.Intersection, ray: THREE.Ray): Vec3 | undefined {
  if (!hit.face) return undefined;
  const n = hit.face.normal.clone();
  const mesh = hit.object as THREE.InstancedMesh;
  if (mesh.isInstancedMesh && hit.instanceId !== undefined) {
    const matrix = new THREE.Matrix4();
    mesh.getMatrixAt(hit.instanceId, matrix);
    matrix.premultiply(mesh.matrixWorld);
    n.transformDirection(matrix);
  } else n.transformDirection(hit.object.matrixWorld);
  if (n.dot(ray.direction) > 0) n.negate();
  return toVec3(n);
}

export interface LoopPick {
  target?: Omit<NoteTarget, "method" | "pressure">;
  /** Where the things meant were hit, nearest first. */
  surface: Array<{ point: Vec3; normal?: Vec3; distance: number }>;
  rays: number;
}

/** Rays per loop, and the time they may take. Early rays cover the whole loop, so stopping short is safe. */
const RAYS = 96;
const BUDGET_MS = 30;
const MAX_LAYERS = 6;
const MAX_HITS_PER_RAY = 6;

/** A mesh with this many triangles gets a tree to search, instead of trying them all on every ray. */
const TREE_FROM = 200;

const treesTried = new WeakSet<THREE.BufferGeometry>();

function treeFor(g: THREE.BufferGeometry | undefined): void {
  if (!g || treesTried.has(g)) return;
  treesTried.add(g);
  const position = g.attributes.position;
  const triangles = position ? (g.index ? g.index.count : position.count) / 3 : 0;
  if (triangles < TREE_FROM) return;
  try {
    // indirect: the geometry itself stays as it is, nothing goes to the graphics card again.
    g.boundsTree = new MeshBVH(g, { indirect: true, strategy: CENTER, targetLeafSize: 8, verbose: false });
  } catch {
    // an ordinary ray works too
  }
}

interface InstanceSpheres {
  /** The pick it was last checked for: once per pick is enough, not once per ray. */
  checked: number;
  version: number;
  count: number;
  matrix: number[];
  /** x, y, z and radius of each instance, in the world. */
  spheres: Float32Array;
}

/**
 * Rays through a whole store, fast enough for a hundred at once between two frames. Big meshes search a
 * tree. Instances are first tried as spheres in one flat array, which takes nanoseconds each, and only the
 * few that a ray touches are looked at properly.
 */
class FastRays {
  private readonly probe = new THREE.Mesh();
  private readonly indexes = new WeakMap<THREE.InstancedMesh, InstanceSpheres>();
  private readonly local = new THREE.Matrix4();
  private readonly hits: THREE.Intersection[] = [];
  private pick = 0;

  constructor() {
    this.probe.raycast = acceleratedRaycast;
  }

  /** A new pick: the world may have changed since the last one. */
  begin() {
    this.pick++;
  }

  private indexOf(mesh: THREE.InstancedMesh): InstanceSpheres {
    const known = this.indexes.get(mesh);
    if (known?.checked === this.pick) return known;
    const matrix = mesh.matrixWorld.elements;
    if (known && known.version === mesh.instanceMatrix.version && known.count === mesh.count && known.matrix.every((n, i) => n === matrix[i])) {
      known.checked = this.pick;
      return known;
    }
    if (!mesh.geometry.boundingSphere) mesh.geometry.computeBoundingSphere();
    const { center, radius } = mesh.geometry.boundingSphere!;
    const spheres = new Float32Array(mesh.count * 4);
    const instances = mesh.instanceMatrix.array;
    const world = mesh.matrixWorld.elements;
    for (let i = 0; i < mesh.count; i++) {
      const at = i * 16;
      // The instance's matrix applied to the sphere's centre, then the mesh's; and the largest scale of the two.
      const lx = instances[at] * center.x + instances[at + 4] * center.y + instances[at + 8] * center.z + instances[at + 12];
      const ly = instances[at + 1] * center.x + instances[at + 5] * center.y + instances[at + 9] * center.z + instances[at + 13];
      const lz = instances[at + 2] * center.x + instances[at + 6] * center.y + instances[at + 10] * center.z + instances[at + 14];
      const sx = instances[at] * instances[at] + instances[at + 1] * instances[at + 1] + instances[at + 2] * instances[at + 2];
      const sy = instances[at + 4] * instances[at + 4] + instances[at + 5] * instances[at + 5] + instances[at + 6] * instances[at + 6];
      const sz = instances[at + 8] * instances[at + 8] + instances[at + 9] * instances[at + 9] + instances[at + 10] * instances[at + 10];
      const to = i * 4;
      spheres[to] = world[0] * lx + world[4] * ly + world[8] * lz + world[12];
      spheres[to + 1] = world[1] * lx + world[5] * ly + world[9] * lz + world[13];
      spheres[to + 2] = world[2] * lx + world[6] * ly + world[10] * lz + world[14];
      spheres[to + 3] = radius * Math.sqrt(Math.max(sx, sy, sz)) * mesh.matrixWorld.getMaxScaleOnAxis();
    }
    const index = { checked: this.pick, version: mesh.instanceMatrix.version, count: mesh.count, matrix: [...matrix], spheres };
    this.indexes.set(mesh, index);
    return index;
  }

  private rayInstanced(mesh: THREE.InstancedMesh, raycaster: THREE.Raycaster, out: THREE.Intersection[]) {
    const { spheres } = this.indexOf(mesh);
    const { origin, direction } = raycaster.ray;
    const probe = this.probe;
    let ready = false;
    for (let i = 0, at = 0; i < mesh.count; i++, at += 4) {
      const vx = spheres[at] - origin.x;
      const vy = spheres[at + 1] - origin.y;
      const vz = spheres[at + 2] - origin.z;
      const along = vx * direction.x + vy * direction.y + vz * direction.z;
      const r = spheres[at + 3];
      if (along < -r || vx * vx + vy * vy + vz * vz - along * along > r * r) continue;
      if (!ready) {
        probe.geometry = mesh.geometry;
        probe.material = mesh.material;
        ready = true;
      }
      mesh.getMatrixAt(i, this.local);
      probe.matrixWorld.multiplyMatrices(mesh.matrixWorld, this.local);
      probe.raycast(raycaster, this.hits);
      for (const hit of this.hits) {
        hit.instanceId = i;
        hit.object = mesh;
        out.push(hit);
      }
      this.hits.length = 0;
    }
  }

  /** The same answer as raycaster.intersectObjects(meshes, false). */
  intersect(meshes: THREE.Object3D[], raycaster: THREE.Raycaster): THREE.Intersection[] {
    const out: THREE.Intersection[] = [];
    for (const object of meshes) {
      const mesh = object as THREE.InstancedMesh & { isSkinnedMesh?: boolean };
      // What has a way of its own (a shadow that never catches a click, a mesh that bends) keeps it.
      if (mesh.isInstancedMesh && mesh.raycast === THREE.InstancedMesh.prototype.raycast) this.rayInstanced(mesh, raycaster, out);
      else if (mesh.isMesh && !mesh.isSkinnedMesh && !mesh.morphTargetInfluences && mesh.raycast === THREE.Mesh.prototype.raycast) acceleratedRaycast.call(mesh, raycaster, out);
      else object.raycast(raycaster, out);
    }
    return out.sort((a, b) => a.distance - b.distance);
  }
}

export class Picker {
  private readonly raycaster = new THREE.Raycaster();
  private readonly rays = new FastRays();
  private readonly ndc = new THREE.Vector2();
  /** Picking far beyond what can be seen helps nobody. */
  far = 400;
  private readonly getScene: () => THREE.Object3D | undefined;
  private readonly adapter: SceneAdapter;

  constructor(getScene: () => THREE.Object3D | undefined, adapter: SceneAdapter) {
    this.getScene = getScene;
    this.adapter = adapter;
    this.raycaster.layers.enableAll();
  }

  /** Everything along the ray through a screen point, nearest first, each thing once. */
  private along(x: number, y: number, camera: THREE.Camera, rect: DOMRect, meshes: THREE.Object3D[]): RayHit[] {
    this.ndc.set(((x - rect.left) / rect.width) * 2 - 1, -((y - rect.top) / rect.height) * 2 + 1);
    this.raycaster.setFromCamera(this.ndc, camera);
    this.raycaster.far = this.far;
    return this.hitsOnRay(meshes);
  }

  private hitsOnRay(meshes: THREE.Object3D[]): RayHit[] {
    const out: RayHit[] = [];
    const ray = this.raycaster.ray;
    // Nearest first. Naming a thing costs far more than finding it, and a store has dozens of things
    // along one ray: only the nearest few can matter.
    for (const hit of this.rays.intersect(meshes, this.raycaster)) {
      if (out.length >= MAX_HITS_PER_RAY) break;
      const described = this.adapter.describe?.(hit);
      if (described === null) continue;
      const chain = described ?? chainFromGraph(hit);
      if (chain.length === 0) continue;
      out.push({ chain, distance: hit.distance, point: toVec3(hit.point), normal: worldNormal(hit, ray) });
    }
    if (this.adapter.along) out.push(...this.adapter.along(ray, this.far));
    out.sort((a, b) => a.distance - b.distance);
    const seen = new Set<string>();
    return out.filter((h) => {
      const key = h.chain[0].key;
      if (seen.has(key)) return false;
      seen.add(key);
      return true;
    });
  }

  /** Makes the trees ahead of time, a little at a time, when nothing else needs doing. */
  warm() {
    const scene = this.getScene();
    if (!scene) return;
    const waiting = new Set<THREE.BufferGeometry>();
    for (const object of visibleMeshes(scene, this.adapter.skip)) {
      const geometry = (object as THREE.Mesh).geometry as THREE.BufferGeometry | undefined;
      if (geometry && !treesTried.has(geometry)) waiting.add(geometry);
    }
    const queue = [...waiting];
    const idle = (work: (deadline: { timeRemaining(): number }) => void) => (typeof requestIdleCallback === "function" ? requestIdleCallback(work, { timeout: 1500 }) : setTimeout(() => work({ timeRemaining: () => 5 }), 50));
    const step = (deadline: { timeRemaining(): number }) => {
      do treeFor(queue.pop());
      while (queue.length > 0 && deadline.timeRemaining() > 3);
      if (queue.length > 0) idle(step);
      else idle(() => this.rehearse(scene));
    };
    if (queue.length > 0) idle(step);
    else idle(() => this.rehearse(scene));
  }

  /** A few rays nobody asked for: the first real pick then finds everything ready, and its code warmed up. */
  private rehearse(scene: THREE.Object3D) {
    const meshes = visibleMeshes(scene, this.adapter.skip);
    const center = new THREE.Box3().setFromObject(scene).getCenter(new THREE.Vector3());
    this.rays.begin();
    this.raycaster.far = this.far;
    for (let i = 0; i < 12; i++) {
      const angle = (i / 12) * Math.PI * 2;
      this.raycaster.set(center, new THREE.Vector3(Math.cos(angle), -0.3, Math.sin(angle)).normalize());
      this.rays.intersect(meshes, this.raycaster);
    }
  }

  /** What is on screen under a point: each thing along the ray, as a chain. */
  pickPoint(x: number, y: number, camera: THREE.Camera, rect: DOMRect): LoopPick {
    const scene = this.getScene();
    const meshes = scene ? visibleMeshes(scene, this.adapter.skip) : [];
    this.rays.begin();
    const hits = this.along(x, y, camera, rect, meshes);
    if (hits.length === 0) return { surface: [], rays: 1 };
    return {
      target: { layers: hits.slice(0, MAX_LAYERS).map((h) => withBounds(h)), layer: 0, depth: 0, partial: false },
      surface: [{ point: hits[0].point, normal: hits[0].normal, distance: hits[0].distance }],
      rays: 1,
    };
  }

  /** What a loop on the screen holds. */
  pickLoop(polygon: Vec2[], camera: THREE.Camera, rect: DOMRect): LoopPick {
    const scene = this.getScene();
    const meshes = scene ? visibleMeshes(scene, this.adapter.skip) : [];
    interface Seen {
      hit: RayHit;
      hits: number;
      behind: number;
      distances: number[];
      surface: Array<{ point: Vec3; normal?: Vec3; distance: number }>;
      bounds?: THREE.Box3;
      /** The parts that were hit, each with its own box and how many rays found it. */
      parts: Map<string, { bounds: Box; hits: number }>;
    }
    for (const object of meshes) treeFor((object as THREE.Mesh).geometry);
    this.rays.begin();
    const stats = new Map<string, Seen>();
    const samples = samplePolygon(polygon, RAYS);
    const start = performance.now();
    let rays = 0;
    for (const [x, y] of samples) {
      if (rays >= 16 && performance.now() - start > BUDGET_MS) break;
      rays++;
      const hits = this.along(x, y, camera, rect, meshes);
      hits.slice(0, 5).forEach((hit, order) => {
        const key = hit.chain[0].key;
        let seen = stats.get(key);
        if (!seen) {
          seen = { hit, hits: 0, behind: 0, distances: [], surface: [], parts: new Map() };
          stats.set(key, seen);
        }
        if (order === 0) {
          seen.hits++;
          seen.surface.push({ point: hit.point, normal: hit.normal, distance: hit.distance });
        } else seen.behind++;
        seen.distances.push(hit.distance);
        // A product with several facings: only the ones under the loop count towards "inside".
        const part = hit.bounds ?? hit.chain[0].bounds;
        if (part) {
          const partBox = new THREE.Box3(fromVec3(part.min), fromVec3(part.max));
          seen.bounds = seen.bounds ? seen.bounds.union(partBox) : partBox;
          const id = `${part.min.join()}|${part.max.join()}`;
          const known = seen.parts.get(id);
          if (known) known.hits++;
          else seen.parts.set(id, { bounds: part, hits: 1 });
        }
      });
    }
    const candidates: Candidate[] = [];
    for (const [key, seen] of stats) {
      const sorted = seen.distances.slice().sort((a, b) => a - b);
      // How much of it is inside: of each part that was hit, by how much of the loop that part fills.
      let inside = 0;
      let weight = 0;
      for (const part of seen.parts.values()) {
        const screen = screenRectOf(part.bounds, camera, rect);
        inside += (screen ? enclosure(screen, polygon) : 0) * part.hits;
        weight += part.hits;
      }
      candidates.push({
        key,
        hits: seen.hits,
        behind: seen.behind,
        depth: sorted[Math.floor(sorted.length / 2)],
        enclosure: weight > 0 ? inside / weight : 0,
      });
    }
    const ranked = rank(candidates, rays);
    if (ranked.members.length === 0) {
      if (ranked.others.length === 0) return { surface: [], rays };
      const hidden = ranked.others.slice(0, MAX_LAYERS).map((c) => withBounds(stats.get(c.key)!.hit));
      return { target: { layers: hidden, layer: 0, depth: 0, partial: false }, surface: [], rays };
    }
    const members = ranked.members.map((m) => stats.get(m.key)!);
    const first = members.length === 1
      ? withBounds(members[0].hit, members[0].bounds)
      : grouped(members.map((m) => ({ hit: m.hit, bounds: m.bounds })));
    const layers = [first, ...ranked.others.slice(0, MAX_LAYERS - 1).map((c) => withBounds(stats.get(c.key)!.hit, stats.get(c.key)!.bounds))];
    const surface = members.flatMap((m) => m.surface).sort((a, b) => a.distance - b.distance);
    return {
      target: {
        layers,
        layer: 0,
        depth: 0,
        partial: ranked.partial,
        members: members.length > 1 ? members.map((m) => withBounds(m.hit, m.bounds)[0]) : undefined,
      },
      surface,
      rays,
    };
  }

  /** What is first under a line on the screen, at up to `count` points along it, its two ends always among them. */
  alongLine(points: Vec2[], camera: THREE.Camera, rect: DOMRect, count = 24): LineSample[] {
    this.rays.begin();
    const scene = this.getScene();
    const meshes = scene ? visibleMeshes(scene, this.adapter.skip) : [];
    const n = Math.max(2, Math.min(count, points.length));
    const out: LineSample[] = [];
    for (let i = 0; i < n; i++) {
      const at = points[Math.round((i * (points.length - 1)) / (n - 1))];
      const first = this.along(at[0], at[1], camera, rect, meshes)[0];
      out.push({ at, hit: first && { ...first, chain: withBounds(first) } });
    }
    return out;
  }

  /** What stands around a place, nearest first, leaving out the given things (what it is on, what it is about). */
  nearby(point: Vec3, leaveOut: string[] = [], count = 5): NearThing[] {
    const things = this.adapter.nearby ? this.adapter.nearby(point) : this.namedThings();
    const here = fromVec3(point);
    const out: NearThing[] = [];
    const found = new THREE.Box3();
    for (const thing of things) {
      if (!thing.bounds || leaveOut.includes(thing.key)) continue;
      const { min, max } = thing.bounds;
      // The ground under a place is not something near it.
      const flat = max[1] - min[1] < 0.1 * Math.min(max[0] - min[0], max[2] - min[2]);
      if (flat && point[0] >= min[0] && point[0] <= max[0] && point[2] >= min[2] && point[2] <= max[2]) continue;
      found.set(fromVec3(min), fromVec3(max));
      out.push({ label: thing.label, kind: thing.kind, locator: thing.locator, distance: found.distanceToPoint(here) });
    }
    return out.sort((a, b) => a.distance - b.distance).slice(0, count);
  }

  /** The things of a scene with a name of their own. A named group is one thing, not its parts. */
  private namedThings(): SceneEntity[] {
    const scene = this.getScene();
    const out: SceneEntity[] = [];
    if (!scene) return out;
    const start = performance.now();
    const visit = (object: THREE.Object3D, path: string) => {
      if (!object.visible || this.adapter.skip?.(object) || performance.now() - start > 40) return;
      const here = path ? `${path}/${object.name || object.type}` : object.name || object.type;
      const about = object.userData?.drawspeak as Partial<SceneEntity> | undefined;
      if (object !== scene && (about || object.name)) {
        const b = new THREE.Box3().setFromObject(object);
        if (!b.isEmpty()) {
          out.push({
            key: object.uuid,
            label: about?.label ?? object.name,
            kind: about?.kind ?? ((object as THREE.Group).isGroup ? "group" : object.type.toLowerCase()),
            locator: about?.locator ?? { strategy: "path", value: here },
            bounds: box(b),
          });
          return;
        }
      }
      for (const child of object.children) visit(child, here);
    };
    visit(scene, "");
    return out;
  }

  /** Is something standing between the camera and this point? */
  occluded(point: Vec3, camera: THREE.Camera): boolean {
    const scene = this.getScene();
    if (!scene) return false;
    const origin = new THREE.Vector3().setFromMatrixPosition(camera.matrixWorld);
    const to = fromVec3(point);
    const length = origin.distanceTo(to);
    if (length < 0.5) return false;
    this.raycaster.set(origin, to.sub(origin).normalize());
    this.raycaster.camera = camera;
    this.raycaster.far = Math.max(0, length - 0.35);
    this.rays.begin();
    const hit = this.hitsOnRay(visibleMeshes(scene, this.adapter.skip))[0];
    return hit !== undefined && hit.distance < length - 0.35;
  }
}

/** A hit's chain, its first entity with the bounds that were actually hit. */
function withBounds(hit: RayHit, bounds?: THREE.Box3): SceneEntity[] {
  const part = bounds ? box(bounds) : (hit.bounds ?? hit.chain[0].bounds);
  return [{ ...hit.chain[0], bounds: part }, ...hit.chain.slice(1)];
}

function grouped(members: Array<{ hit: RayHit; bounds?: THREE.Box3 }>): SceneEntity[] {
  const chains = members.map((m) => withBounds(m.hit, m.bounds));
  const chain = groupChain(chains.map((c) => c[0]), chains);
  const union = new THREE.Box3();
  for (const c of chains) {
    const b = c[0].bounds;
    if (b) union.union(new THREE.Box3(fromVec3(b.min), fromVec3(b.max)));
  }
  chain[0].bounds = union.isEmpty() ? undefined : box(union);
  return chain;
}

/**
 * A thing this big on the screen is a surface rather than a thing: a mark on it is about a place on
 * it. So is what reaches behind the camera, what has no size of its own, and something wide and flat
 * (a floor, a wall) seen whole from afar.
 */
export function isSurfaceLike(entity: SceneEntity | undefined, camera: THREE.Camera, rect: { left: number; top: number; width: number; height: number }): boolean {
  if (!entity?.bounds) return true;
  const { points, complete } = boxOnScreen(entity.bounds, camera, rect);
  if (!complete) return true;
  const b = boundsOf(points);
  const across = (b.maxX - b.minX) / rect.width;
  const high = (b.maxY - b.minY) / rect.height;
  if (across * high > 0.4) return true;
  const { min, max } = entity.bounds;
  const [, middle, thin] = [max[0] - min[0], max[1] - min[1], max[2] - min[2]].sort((p, q) => q - p);
  return thin < middle * 0.12 && Math.max(across, high) > 0.3;
}

export interface InkPlane {
  point: Vec3;
  normal: Vec3;
}

/** What is first under one point of a line on the screen. */
export interface LineSample {
  at: Vec2;
  hit?: RayHit;
}

/** A line on the screen, as a line in the world. */
export interface LineInWorld {
  points: Vec3[];
  /** For each point: it really is on what shows there on the screen, not on ground hidden behind it. */
  touches: boolean[];
  onGround: boolean;
  normal: Vec3;
}

/** The height most of these hits on level surfaces share, when they do share one (not a flight of stairs). */
function levelOf(flat: RayHit[]): number | undefined {
  const heights = flat.map((hit) => hit.point[1]).sort((a, b) => a - b);
  const distances = flat.map((hit) => hit.distance).sort((a, b) => a - b);
  const middle = heights[Math.floor(heights.length / 2)];
  const tolerance = distances[Math.floor(distances.length / 2)] * 0.02;
  return heights.filter((y) => Math.abs(y - middle) <= tolerance).length >= heights.length * 0.7 ? middle : undefined;
}

/**
 * A line drawn mostly over level ground lies on that ground, passing behind what stands in the way:
 * a way to walk. Any other line follows what it crosses.
 */
export function lineInWorld(samples: LineSample[], camera: THREE.Camera, rect: DOMRect, fallbackDistance: number): LineInWorld {
  const hits = samples.flatMap((sample) => (sample.hit ? [sample.hit] : []));
  const flat = hits.filter((hit) => hit.normal && hit.normal[1] > 0.8);
  const onGround = flat.length >= 2 && flat.length * 2 >= hits.length;
  const level = onGround ? levelOf(flat) : undefined;
  const ground = level !== undefined ? new THREE.Plane(new THREE.Vector3(0, 1, 0), -level) : undefined;
  // Near the horizon the ground runs away to nowhere.
  const farthest = Math.max(0, ...flat.map((hit) => hit.distance)) * 3;
  const eye = new THREE.Vector3().setFromMatrixPosition(camera.matrixWorld);
  const raycaster = new THREE.Raycaster();
  const ndc = new THREE.Vector2();
  const found = new THREE.Vector3();
  const seen = new THREE.Vector3();
  let reach = hits[0]?.distance ?? fallbackDistance;
  const points: Vec3[] = [];
  const touches: boolean[] = [];
  for (const { at, hit } of samples) {
    ndc.set(((at[0] - rect.left) / rect.width) * 2 - 1, -((at[1] - rect.top) / rect.height) * 2 + 1);
    raycaster.setFromCamera(ndc, camera);
    const on = ground && raycaster.ray.intersectPlane(ground, found);
    let point: Vec3;
    if (on && on.distanceTo(eye) < farthest) point = toVec3(on);
    else if (hit) {
      reach = hit.distance;
      point = hit.point;
    } else point = toVec3(raycaster.ray.at(reach, found));
    points.push(point);
    touches.push(hit !== undefined && fromVec3(hit.point, seen).distanceTo(fromVec3(point, found)) < hit.distance * 0.02);
  }
  return { points, touches, onGround, normal: ground ? [0, 1, 0] : inkPlane([], camera, reach).normal };
}

/** A ring on a plane, for a single spot. */
export function ringOn(plane: InkPlane, center: Vec3, radius: number, count = 20): Vec3[] {
  const normal = fromVec3(plane.normal).normalize();
  const side = new THREE.Vector3(Math.abs(normal.y) > 0.9 ? 1 : 0, Math.abs(normal.y) > 0.9 ? 0 : 1, 0).cross(normal).normalize();
  const other = normal.clone().cross(side);
  const middle = fromVec3(center);
  return Array.from({ length: count }, (_, i) => {
    const a = (i / count) * Math.PI * 2;
    return toVec3(middle.clone().addScaledVector(side, Math.cos(a) * radius).addScaledVector(other, Math.sin(a) * radius));
  });
}

export function lineLength(points: Vec3[]): number {
  let length = 0;
  for (let i = 1; i < points.length; i++) length += Math.hypot(points[i][0] - points[i - 1][0], points[i][1] - points[i - 1][1], points[i][2] - points[i - 1][2]);
  return length;
}

/**
 * The plane to lay the ink on: through the middle of what was hit, along its surface when that is one
 * surface, facing the camera when it is not (a bottle, a character), or when the surface is seen so
 * nearly edge-on that ink on it would stretch far away. A place on the ground is the exception
 * (`onGround`): seen at a shallow angle from afar, a mark on it should still lie on it.
 */
export function inkPlane(surface: LoopPick["surface"], camera: THREE.Camera, fallbackDistance: number, onGround = false): InkPlane {
  const forward = new THREE.Vector3(0, 0, -1).transformDirection(camera.matrixWorld);
  const eye = new THREE.Vector3().setFromMatrixPosition(camera.matrixWorld);
  const facing: Vec3 = [-forward.x, -forward.y, -forward.z];
  if (surface.length === 0) {
    return { point: toVec3(eye.clone().addScaledVector(forward, fallbackDistance)), normal: facing };
  }
  const middle = surface.slice().sort((a, b) => a.distance - b.distance)[Math.floor(surface.length / 2)];
  const sum = new THREE.Vector3();
  let counted = 0;
  for (const s of surface) {
    if (s.normal) {
      sum.add(fromVec3(s.normal));
      counted++;
    }
  }
  if (counted > 0 && sum.length() / counted > 0.8) {
    const normal = sum.normalize();
    const toEye = eye.clone().sub(fromVec3(middle.point)).normalize();
    if (normal.dot(toEye) > (onGround && normal.y > 0.8 ? 0.05 : 0.3)) return { point: middle.point, normal: toVec3(normal) };
  }
  return { point: middle.point, normal: facing };
}

/** Screen points onto a plane. A point whose ray misses it stays at the plane's distance. */
export function liftOnto(points: Vec2[], plane: InkPlane, camera: THREE.Camera, rect: DOMRect): Vec3[] {
  const raycaster = new THREE.Raycaster();
  const ndc = new THREE.Vector2();
  const three = new THREE.Plane().setFromNormalAndCoplanarPoint(fromVec3(plane.normal), fromVec3(plane.point));
  const eye = new THREE.Vector3().setFromMatrixPosition(camera.matrixWorld);
  const reach = eye.distanceTo(fromVec3(plane.point));
  const hit = new THREE.Vector3();
  return points.map(([x, y]) => {
    ndc.set(((x - rect.left) / rect.width) * 2 - 1, -((y - rect.top) / rect.height) * 2 + 1);
    raycaster.setFromCamera(ndc, camera);
    const on = raycaster.ray.intersectPlane(three, hit);
    if (on && on.distanceTo(eye) < reach * 3) return toVec3(on);
    return toVec3(raycaster.ray.at(reach, hit));
  });
}
