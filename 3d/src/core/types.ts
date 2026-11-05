/**
 * The model of Drawspeak 3D. It follows the iPad app's model (Note, Snapshot, DOMTarget, feedback
 * package), with one change of world: a snapshot is a view from a camera in a 3D place, and a target
 * is a chain of things in a scene instead of a chain of HTML elements.
 */
export type Vec2 = [number, number];
export type Vec3 = [number, number, number];
export type Quat = [number, number, number, number];

/** Normalized snapshot space: (0,0) top-left, (1,1) bottom-right. */
export interface NRect {
  x: number;
  y: number;
  w: number;
  h: number;
}

/** What a mark is on the screen, in normalized snapshot space. */
export type Shape =
  /** A circle: what is inside it, or this area. */
  | { kind: "lasso"; points: Vec2[] }
  /** A line: from here to there, a route or something to move. `via` holds its bends. */
  | { kind: "arrow"; from: Vec2; to: Vec2; via?: Vec2[] }
  /** One spot: "here". */
  | { kind: "point"; at: Vec2 }
  /** One thing chosen by a tap: the geometry is its outline on screen. */
  | { kind: "component"; rect: NRect }
  /** No mark at all: a comment about what is in view, or about the whole experience. */
  | { kind: "view" };

export type InputKind = "pen" | "touch" | "mouse" | "keyboard";

export interface Box {
  min: Vec3;
  max: Vec3;
}

export interface Locator {
  /** adapter: the app's own id. path: names from the scene root. instance: a Roblox Instance path. css-path: an HTML element. */
  strategy: "adapter" | "name" | "path" | "uuid" | "instance" | "css-path";
  value: string;
}

/** One thing in a scene: a product, a shelf, a mesh, a Roblox Instance, a HUD button. */
export interface SceneEntity {
  /** Stable within a session; two hits on one thing have one key. */
  key: string;
  /** What a person calls it. */
  label: string;
  /** product, rack, mesh, Model, Part, html… */
  kind: string;
  locator: Locator;
  /** World-space bounds, when it has any. */
  bounds?: Box;
  /** Where it comes from in the code, as hints for the agent. */
  source?: string[];
  /** Anything else the agent could use (ids, prices, material names). JSON only. */
  data?: Record<string, unknown>;
}

/**
 * What a mark is about, as in the iPad app's ComponentSelection: stacks of things (`layers`, each a
 * hit-to-root chain) and the position on the chosen stack. layers[0] is what the loop holds; further
 * layers are what lies behind it. Depth 0 is the thing itself, higher depths are its parents.
 */
export interface NoteTarget {
  layers: SceneEntity[][];
  layer: number;
  depth: number;
  /** Set when the loop only covers part of something big (a patch of wall), not whole things. */
  partial: boolean;
  /** When the loop holds several things: all of them. layers[0][0] is then a group. */
  members?: SceneEntity[];
  method: InputKind;
  pressure?: number;
}

/** A camera in the world: enough to look from exactly there again. */
export interface Pose {
  position: Vec3;
  quaternion: Quat;
  /** Vertical field of view, degrees. */
  fov: number;
  aspect: number;
  near: number;
  far: number;
}

/** One view of the world, as it was when it was marked. Never changes. */
export interface Snapshot {
  id: string;
  /** Where this is, e.g. the aisle's name. */
  title: string;
  pose: Pose;
  widthPx: number;
  heightPx: number;
  takenAt: string;
  /** A link that opens this very view, when the app can. */
  viewLink?: string;
  /** Where the reviewer's own character stood, for "next to me". */
  viewer?: Viewer;
}

export interface Viewer {
  position: Vec3;
  /** Which way it faced. */
  facing?: Vec3;
}

/** Something near a place, and how far. */
export interface NearThing {
  label: string;
  kind: string;
  distance: number;
  locator: Locator;
}

/** A place in the world, for "put something here" and "change this area". */
export interface WorldPlace {
  /** The middle of the mark, on what it is on. */
  center: Vec3;
  /** Which way that surface faces there. */
  normal: Vec3;
  /** The mark's box in the world, along x, y and z. All zero for a single spot. */
  size: Vec3;
  /** What it is on, when it is a place on something big (a floor, a wall) and not about a whole thing. */
  on?: string;
  /** What stands nearby, nearest first. */
  near: NearThing[];
}

/** One end of a line through the world. */
export interface PathEnd {
  at: Vec3;
  label?: string;
  kind?: string;
  locator?: Locator;
  /** A whole thing (to move, say), rather than a spot on something big. */
  isThing: boolean;
  near: NearThing[];
}

/** A line through the world, for routes, for flows, and for moving things. */
export interface WorldPath {
  /** The line, on what it was drawn on. */
  points: Vec3[];
  length: number;
  /** Drawn along the ground: a way to walk. */
  onGround: boolean;
  from: PathEnd;
  to: PathEnd;
  /** What it passes on the way, in order. */
  through: string[];
}

/** A mark lifted into the world: it stays on the thing as you walk around it. */
export interface WorldMark {
  /** Where the numbered pin stands. */
  anchor: Vec3;
  /** The plane the ink lies on faces this way. */
  normal: Vec3;
  /** The ink, on that plane. */
  ink: Vec3[];
  /** The ink is one closed line. */
  closed?: boolean;
  /** Where it is, as a place. */
  place?: WorldPlace;
  /** Where it goes, for a line. */
  path?: WorldPath;
  /** A mark on the app's own interface, not in the world: it stays where it is on the screen (ink in screen points). */
  screen?: boolean;
}

export type RecordingState = "recording" | "transcribing";

export type TextSource = "none" | "typed" | "voice" | "edited";

/** A comment anchored to one snapshot and one place in the world. */
export interface Note {
  id: string;
  /** Stable number; never derived from an array index. */
  ordinal: number;
  snapshotId: string;
  shape: Shape;
  world: WorldMark;
  target?: NoteTarget;
  text: string;
  textSource: TextSource;
  /** Increments on every text change; sending records the sent revision. */
  revision: number;
  lastSentRevision?: number;
  recording?: RecordingState;
  createdAt: string;
  updatedAt: string;
}

/** What the reviewer wants done with a batch (the iPad app's AgentDirective, in 3D terms). */
export interface AgentDirective {
  mode: "apply" | "replyOnly";
  /** Free text from the reviewer, passed on verbatim. */
  note: string;
}

export interface ProjectInfo {
  id: string;
  title: string;
}

/** The commit the marks were made on, as far as the hub knows. */
export interface RevisionInfo {
  commit?: string;
  dirty?: boolean;
}
