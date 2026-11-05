import type { NoteTarget, SceneEntity } from "./types.ts";

/**
 * What a loop drawn on a 3D view is about.
 *
 * A loop on a screen is a cone in the world: everything in it, near and far. Rays sampled inside the
 * loop say what is visible there; the question is which of those things the person means. Someone who
 * circles a carton of milk on a shelf has a rack behind it filling most of the loop, but the carton
 * is what lies inside: so whole things inside the loop beat big things that merely show through it.
 */
export interface Candidate {
  key: string;
  /** Rays that hit this first. */
  hits: number;
  /** Rays that hit this behind something else. */
  behind: number;
  /** How much of it (its box on screen) lies inside the loop, 0…1. */
  enclosure: number;
  /** Median distance from the camera. */
  depth: number;
}

export interface Ranked {
  /** What the loop is about: one thing, or several alike. */
  members: Candidate[];
  /** The loop only covers part of something: no whole thing is inside. */
  partial: boolean;
  /** What else is there, nearest first: visible around the members, or hidden behind them. */
  others: Candidate[];
}

/** Below this much inside the loop, a thing is not "circled", only seen through the loop. */
const WHOLE = 0.5;
/** Others join the best one when they score at least this share of it (a row of products, circled together). */
const ALIKE = 0.45;
/** Not whole, but this much of it inside and this much of the loop on it: it is the subject (a counter, with its tall sign sticking out). */
const MOSTLY_ABOUT = 0.15;
const ENOUGH_OF_THE_LOOP = 0.08;

export function score(candidate: Candidate, totalRays: number): number {
  return Math.sqrt(candidate.hits / Math.max(1, totalRays)) * candidate.enclosure * candidate.enclosure;
}

export function rank(candidates: Candidate[], totalRays: number): Ranked {
  const seen = candidates.filter((c) => c.hits > 0);
  if (seen.length === 0) {
    const hidden = candidates.filter((c) => c.behind > 0).sort((a, b) => a.depth - b.depth);
    return { members: [], partial: false, others: hidden };
  }
  const ranked = seen.slice().sort((a, b) => score(b, totalRays) - score(a, totalRays) || b.hits - a.hits);
  const best = ranked[0];
  let members: Candidate[];
  let partial = false;
  if (best.enclosure < WHOLE) {
    // No whole thing inside: the loop is on something bigger. A thing with a real part inside the loop
    // is what it is on; failing that, what fills it (a patch of wall).
    const subject = best.enclosure >= MOSTLY_ABOUT && best.hits / Math.max(1, totalRays) >= ENOUGH_OF_THE_LOOP;
    members = [subject ? best : seen.slice().sort((a, b) => b.hits - a.hits)[0]];
    partial = true;
  } else {
    const bar = score(best, totalRays) * ALIKE;
    members = ranked.filter((c) => c.enclosure >= WHOLE && score(c, totalRays) >= bar);
  }
  const chosen = new Set(members.map((m) => m.key));
  const others = candidates.filter((c) => !chosen.has(c.key)).sort((a, b) => a.depth - b.depth);
  return { members, partial, others };
}

/** The common ancestors of several chains (each hit-to-root), nearest first. */
export function commonChain(chains: SceneEntity[][]): SceneEntity[] {
  if (chains.length === 0) return [];
  const [first, ...rest] = chains;
  return first.filter((entity) => rest.every((chain) => chain.some((other) => other.key === entity.key)));
}

/** A group's own chain: the group, then what its members share. */
export function groupChain(members: SceneEntity[], chains: SceneEntity[][], label?: string): SceneEntity[] {
  const shared = commonChain(chains);
  const kinds = new Set(members.map((m) => m.kind));
  const name = label ?? `${members.length} × ${kinds.size === 1 ? plural(members[0].kind) : "things"}`;
  const group: SceneEntity = {
    key: `group:${members.map((m) => m.key).sort().join(",")}`,
    label: shared.length > 0 ? `${name} in ${shared[0].label}` : name,
    kind: "group",
    locator: { strategy: "adapter", value: members.map((m) => m.locator.value).join(", ") },
    data: { members: members.map((m) => m.label) },
  };
  return [group, ...shared];
}

function plural(kind: string): string {
  return kind.endsWith("s") ? kind : `${kind}s`;
}

/** The thing a target points at now. */
export function current(target: Pick<NoteTarget, "layers" | "layer" | "depth">): SceneEntity | undefined {
  return target.layers[target.layer]?.[target.depth];
}

export function chainOf(target: Pick<NoteTarget, "layers" | "layer">): SceneEntity[] {
  return target.layers[target.layer] ?? [];
}

export function selectDepth(target: NoteTarget, depth: number): NoteTarget {
  const chain = chainOf(target);
  return { ...target, depth: Math.min(Math.max(depth, 0), Math.max(chain.length - 1, 0)) };
}

/** A different layer starts at its own hit element; parents follow from there. */
export function selectLayer(target: NoteTarget, layer: number): NoteTarget {
  return { ...target, layer: Math.min(Math.max(layer, 0), Math.max(target.layers.length - 1, 0)), depth: 0 };
}

/**
 * Maps Pencil force to a depth on a chain: 0 is the hit element, levels - 1 the root. A port of the
 * iPad app's PressureDepthTracker: thresholds evenly spaced over 0…1, a hysteresis band against
 * jitter, and a release commits the last depth held for stableInterval (the falling force while
 * lifting the pen does not snap back to the top element).
 */
export class PressureDepthTracker {
  readonly levels: number;
  readonly band: number;
  readonly stableInterval: number;
  depth = 0;
  stableDepth = 0;
  force = 0;
  private depthSince?: number;

  constructor(levels: number, band = 0.04, stableInterval = 0.12) {
    this.levels = Math.max(1, levels);
    this.band = Math.max(0, band);
    this.stableInterval = Math.max(0, stableInterval);
  }

  threshold(level: number): number {
    return level / this.levels;
  }

  /** One normalized force sample and its time in seconds; returns the live depth. */
  update(rawForce: number, time: number): number {
    if (!Number.isFinite(rawForce) || !Number.isFinite(time)) return this.depth;
    const force = Math.min(Math.max(rawForce, 0), 1);
    this.force = force;
    const since = this.depthSince ?? time;
    if (time - since >= this.stableInterval) this.stableDepth = this.depth;
    let next = this.depth;
    while (next < this.levels - 1 && force > this.threshold(next + 1) + this.band / 2) next++;
    while (next > 0 && force < this.threshold(next) - this.band / 2) next--;
    if (next !== this.depth || this.depthSince === undefined) {
      this.depth = next;
      this.depthSince = time;
    }
    if (this.stableInterval === 0) this.stableDepth = this.depth;
    return this.depth;
  }

  /** The depth to confirm when the pen lifts. */
  commit(): number {
    return this.stableDepth;
  }
}
