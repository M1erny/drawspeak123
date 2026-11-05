import { chainOf, current } from "./selection.ts";
import { kindLabel } from "./stroke.ts";
import type { AgentDirective, NearThing, Note, NoteTarget, PathEnd, Pose, ProjectInfo, RevisionInfo, SceneEntity, Shape, Snapshot, Vec2, Vec3, WorldPath, WorldPlace } from "./types.ts";

/**
 * The feedback package: gathered notes, grouped by the view they were made on, turned into one
 * message for a coding agent plus a JSON manifest. It follows the iPad app's flow: Feedback (N) →
 * preview → Send to Agent / Save Draft, and its message format, with cameras and world positions
 * where the app has snapshots and HTML components.
 */

export type NoteReadiness = "ready" | "markOnly" | "recording" | "transcribing" | "sent";

export function readiness(note: Note): NoteReadiness {
  if (note.recording === "recording") return "recording";
  if (note.recording === "transcribing") return "transcribing";
  if (note.lastSentRevision === note.revision) return "sent";
  return note.text.trim() ? "ready" : "markOnly";
}

/** Numbers as shown: consecutive by ordinal, sent notes hidden unless asked for. */
export function displayNumbers(notes: Note[], showSent = false, including: Set<string> = new Set()): Map<string, number> {
  const out = new Map<string, number>();
  let n = 0;
  for (const note of notes.slice().sort((a, b) => a.ordinal - b.ordinal)) {
    if (!showSent && readiness(note) === "sent" && !including.has(note.id)) continue;
    out.set(note.id, ++n);
  }
  return out;
}

export interface PackageItem {
  number: number;
  note: Note;
}
export interface PackageGroup {
  snapshot: Snapshot;
  items: PackageItem[];
  /** File name of the annotated picture. */
  compositeFileName: string;
  /** File name of the same view without marks. */
  cleanFileName: string;
}
export interface FeedbackPackage {
  batchId: string;
  project: ProjectInfo;
  groups: PackageGroup[];
  isRepeat: boolean;
  createdAt: string;
  directive: AgentDirective;
  revision?: RevisionInfo;
  /** What the world is, for the agent: engine, units, which way is up. */
  world?: { engine?: string; units?: string; up?: string; notes?: string };
}

export function safeFileComponent(value: string): string {
  return value.replace(/[^A-Za-z0-9_-]/g, "-").slice(0, 48);
}

/** One snapshot appears once with all its marks, ordered by its first note. */
export function buildPackage(options: {
  batchId: string;
  project: ProjectInfo;
  notes: Note[];
  snapshots: Snapshot[];
  noteIds: Set<string>;
  directive: AgentDirective;
  now: string;
  revision?: RevisionInfo;
  world?: FeedbackPackage["world"];
}): FeedbackPackage {
  const { notes, snapshots, noteIds } = options;
  const numbers = displayNumbers(notes, false, noteIds);
  const chosen = notes.filter((n) => noteIds.has(n.id)).sort((a, b) => a.ordinal - b.ordinal);
  const order: string[] = [];
  const bySnapshot = new Map<string, PackageItem[]>();
  for (const note of chosen) {
    if (!bySnapshot.has(note.snapshotId)) {
      order.push(note.snapshotId);
      bySnapshot.set(note.snapshotId, []);
    }
    bySnapshot.get(note.snapshotId)!.push({ number: numbers.get(note.id) ?? note.ordinal, note });
  }
  const groups: PackageGroup[] = [];
  for (const [index, snapshotId] of order.entries()) {
    const snapshot = snapshots.find((s) => s.id === snapshotId);
    if (!snapshot) continue;
    const stem = `${String(index + 1).padStart(2, "0")}-${safeFileComponent(snapshot.id)}`;
    groups.push({ snapshot, items: bySnapshot.get(snapshotId) ?? [], compositeFileName: `${stem}.jpg`, cleanFileName: `${stem}-clean.jpg` });
  }
  return {
    batchId: options.batchId,
    project: options.project,
    groups,
    isRepeat: chosen.some((n) => n.lastSentRevision !== undefined),
    createdAt: options.now,
    directive: options.directive,
    revision: options.revision,
    world: options.world,
  };
}

export const marker = (batchId: string) => `[drawspeak-batch:${batchId}]`;

const round = (v: number, places = 2) => Math.round(v * 10 ** places) / 10 ** places;
export const vec = (v: Vec3) => `(${round(v[0])}, ${round(v[1])}, ${round(v[2])})`;

/** Where a camera looks: a point a little ahead of it. */
export function lookingAt(pose: Pose, distance = 5): Vec3 {
  const [x, y, z, w] = pose.quaternion;
  // The camera looks along -Z: the quaternion applied to (0, 0, -1).
  const fx = -2 * (x * z + w * y);
  const fy = -2 * (y * z - w * x);
  const fz = -(1 - 2 * (x * x + y * y));
  return [pose.position[0] + fx * distance, pose.position[1] + fy * distance, pose.position[2] + fz * distance];
}

function chainText(target: NoteTarget): string {
  const chain = chainOf(target).slice(target.depth);
  return chain.map((e) => e.label).join(" › ");
}

const nearText = (near: NearThing[]) => near.map((n) => `${n.label} (${round(n.distance, 1)})`).join(", ");

/** The two biggest sides of a box, as words. */
function sizeText(size: Vec3): string {
  const [a, b] = [...size].sort((p, q) => q - p);
  return a < 0.01 ? "" : `, about ${round(a, 1)} × ${round(b, 1)} across`;
}

/** Where a mark is in the world: enough to put something there, or to know what stands around it. */
function worldLines(note: Note): string[] {
  const { place, path, anchor } = note.world;
  if (path) {
    const end = (e: PathEnd) => `${e.label ?? "nothing"}${e.isThing ? " (this thing)" : ""} at ${vec(e.at)}${e.near.length > 0 ? `, near ${nearText(e.near)}` : ""}`;
    const lines = [
      `   From: ${end(path.from)}`,
      `   To: ${end(path.to)}`,
      `   Line: ${round(path.length, 1)} long${path.onGround ? ", along the ground" : ""}, through ${thinned(path.points, 8).map(vec).join(" → ")}`,
    ];
    if (path.through.length > 0) lines.push(`   It passes: ${path.through.join(", ")}`);
    return lines;
  }
  if (place) {
    const lines = [`   Place: ${place.on ? `on ${place.on}, ` : ""}at ${vec(place.center)}${sizeText(place.size)}, facing ${vec(place.normal)}`];
    if (place.near.length > 0) lines.push(`   Near: ${nearText(place.near)}`);
    return lines;
  }
  return note.shape.kind === "view" || note.world.screen ? [] : [`   At ${vec(anchor)} in the world.`];
}

function targetLines(target: NoteTarget): string[] {
  const entity = current(target);
  if (!entity) return [];
  const lines = [`   Target: ${chainText(target)} (${entity.kind}${target.partial ? ", a part of it" : ""}) · ${entity.locator.strategy}: ${entity.locator.value}`];
  if (target.members && target.members.length > 1 && target.depth === 0) lines.push(`   Inside the mark: ${target.members.map((m) => m.label).join(", ")}`);
  const source = entity.source ?? chainOf(target).flatMap((e) => e.source ?? []);
  if (source.length > 0) lines.push(`   Source hints: ${[...new Set(source)].join(", ")}`);
  const behind = target.layers.slice(1).map((chain) => chain[0]?.label).filter(Boolean);
  if (behind.length > 0) lines.push(`   Also in that direction: ${behind.join(", ")}`);
  return lines;
}

function instructionLines(pkg: FeedbackPackage): string[] {
  const lines: string[] = [];
  if (pkg.directive.mode === "replyOnly") {
    lines.push("Instruction: answer the comments in text only. Do not change any files.");
  } else {
    lines.push("Instruction: make these changes in the code. A comment can ask for anything in this world: change a thing, add something new at a place (the coordinates say where), move or remove things, or change how people move through it or how the experience flows. Build new things the way this project builds its world, and put them where they were asked for. The app runs in dev mode with hot reload, so the reviewer sees your edits in the running world as soon as you save. Change what was asked and only that. Do not commit, push, publish or deploy.");
  }
  const note = pkg.directive.note.trim();
  if (note) lines.push(`Additional instruction from the reviewer: ${note}`);
  return lines;
}

/** The message text: brief, numbered comments per view and the batch marker. */
export function messageText(pkg: FeedbackPackage): string {
  const count = pkg.groups.reduce((n, g) => n + g.items.length, 0);
  const lines: string[] = [];
  lines.push(`${marker(pkg.batchId)} Drawspeak 3D feedback for "${pkg.project.title}": ${count} comment${count === 1 ? "" : "s"} on ${pkg.groups.length} view${pkg.groups.length === 1 ? "" : "s"}.`);
  if (pkg.isRepeat) lines.push("Note: this repeats comments that were sent before.");
  lines.push(
    "The reviewer walked through the running 3D world, marked things on screen and said what should change: a circle means this thing or this area, a tap this thing or this spot, a line from here to there (a route, or something to move), and a View comment is about what is in view or about the whole experience. Each image is one view with numbered marks: look at them, they show what was meant. The JSON manifest maps every number to its noteId, the camera, the things inside the mark (from the thing itself up to its parents) and its place in the world. Comment text is transcribed speech, so expect small transcription errors; the mark and the target show what it refers to. \"Here\" and \"there\" in a comment mean the mark's place. Old coordinates apply only to their own view.",
  );
  if (pkg.world) {
    const about = [pkg.world.engine, pkg.world.units && `units: ${pkg.world.units}`, pkg.world.up && `up: ${pkg.world.up}`].filter(Boolean).join(", ");
    if (about) lines.push(`World: ${about}.`);
    if (pkg.world.notes) lines.push(pkg.world.notes);
  }
  if (pkg.revision?.commit) lines.push(`Marked on commit ${pkg.revision.commit}${pkg.revision.dirty ? " with uncommitted changes" : ""}.`);
  lines.push(...instructionLines(pkg));
  for (const [i, group] of pkg.groups.entries()) {
    const { snapshot, compositeFileName } = group;
    lines.push("");
    lines.push(`## View ${i + 1}: ${snapshot.title}`);
    const picture = compositeFileName ? `Image \`${compositeFileName}\` · ` : "";
    lines.push(`${picture}Camera at ${vec(snapshot.pose.position)} looking toward ${vec(lookingAt(snapshot.pose))}, field of view ${round(snapshot.pose.fov, 1)}°`);
    if (snapshot.viewer) lines.push(`The reviewer's own character stands at ${vec(snapshot.viewer.position)}${snapshot.viewer.facing ? `, facing ${vec(snapshot.viewer.facing)}` : ""}: "here" with no mark, or "next to me", means there.`);
    if (snapshot.viewLink) lines.push(`Open this view: ${snapshot.viewLink}`);
    for (const { number, note } of group.items) {
      lines.push(`${number}. [${kindLabel(note.shape)}] ${note.text.trim()}`);
      if (note.target) lines.push(...targetLines(note.target));
      lines.push(...worldLines(note));
    }
  }
  lines.push("");
  lines.push(`Manifest: \`manifest.json\`. Batch: ${marker(pkg.batchId)}`);
  return lines.join("\n");
}

/** At most `count` points of a line, spread along it, its two ends among them. */
function thinned<T>(points: T[], count: number): T[] {
  if (points.length <= count) return points;
  return Array.from({ length: count }, (_, i) => points[Math.round((i * (points.length - 1)) / (count - 1))]);
}
const rounded = (values: number[], places: number) => values.map((v) => round(v, places));

function shapeJson(shape: Shape): Shape {
  switch (shape.kind) {
    case "lasso":
      return { kind: shape.kind, points: thinned(shape.points, 48).map((p) => rounded(p, 4) as Vec2) };
    case "arrow":
      return { ...shape, via: shape.via && thinned(shape.via, 24).map((p) => rounded(p, 4) as Vec2) };
    default:
      return shape;
  }
}

function placeJson(place: WorldPlace | undefined) {
  return place && { ...place, center: rounded(place.center, 3), normal: rounded(place.normal, 3), size: rounded(place.size, 3), near: place.near.map(nearJson) };
}

function nearJson(near: NearThing) {
  return { ...near, distance: round(near.distance, 2) };
}

function pathJson(path: WorldPath | undefined) {
  if (!path) return undefined;
  const end = (e: PathEnd) => ({ ...e, at: rounded(e.at, 3), near: e.near.map(nearJson) });
  return { ...path, points: thinned(path.points, 32).map((p) => rounded(p, 3)), length: round(path.length, 2), from: end(path.from), to: end(path.to) };
}

function entityJson(e: SceneEntity) {
  return { label: e.label, kind: e.kind, locator: e.locator, bounds: e.bounds, source: e.source, data: e.data };
}

/** The JSON manifest attached to every message. */
export function manifestOf(pkg: FeedbackPackage) {
  return {
    schema: "drawspeak3d.feedback.v1",
    batchId: pkg.batchId,
    title: pkg.project.title,
    projectId: pkg.project.id,
    createdAt: pkg.createdAt,
    isRepeat: pkg.isRepeat,
    directive: pkg.directive,
    revision: pkg.revision,
    world: pkg.world,
    coordinateSpace: "shapes: normalized snapshot space, (0,0) top-left, (1,1) bottom-right. anchor, ink, place, path, bounds, camera, viewer: world units.",
    snapshots: pkg.groups.map((group) => ({
      snapshotId: group.snapshot.id,
      title: group.snapshot.title,
      camera: group.snapshot.pose,
      viewLink: group.snapshot.viewLink,
      viewer: group.snapshot.viewer,
      takenAt: group.snapshot.takenAt,
      widthPx: group.snapshot.widthPx,
      heightPx: group.snapshot.heightPx,
      compositeFileName: group.compositeFileName || undefined,
      cleanFileName: group.cleanFileName || undefined,
      notes: group.items.map(({ number, note }) => ({
        number,
        noteId: note.id,
        revision: note.revision,
        text: note.text.trim(),
        shape: shapeJson(note.shape),
        anchor: rounded(note.world.anchor, 3),
        ink: thinned(note.world.ink, 32).map((p) => rounded(p, 3)),
        place: placeJson(note.world.place),
        path: pathJson(note.world.path),
        target: note.target && {
          selected: current(note.target) && entityJson(current(note.target)!),
          chain: chainOf(note.target).map(entityJson),
          depth: note.target.depth,
          layer: note.target.layer,
          partial: note.target.partial,
          members: note.target.members?.map(entityJson),
          behind: note.target.layers.slice(1).map((chain) => chain[0] && entityJson(chain[0])),
          method: note.target.method,
          pressure: note.target.pressure,
        },
      })),
    })),
  };
}
