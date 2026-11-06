import * as THREE from "three";
import { convexHull } from "../core/geometry.ts";
import type { Box, Vec2, Vec3 } from "../core/types.ts";
import { boxOnScreen, toScreen } from "../three/world.ts";
import { HALO, INK, LINE_WIDTH, OUTLINE } from "./styles.ts";

/**
 * Ink over the world, on a 2D canvas on top of the game. Marks live in world space and are projected
 * here every frame, so they keep their width at any distance, like the pins on the iPad's canvas.
 */

/** A path through points, smoothed through the midpoints between them. */
export function tracePath(ctx: CanvasRenderingContext2D, points: Vec2[], closed: boolean) {
  ctx.beginPath();
  const n = points.length;
  if (n === 0) return;
  if (n < 3) {
    ctx.moveTo(points[0][0], points[0][1]);
    for (let i = 1; i < n; i++) ctx.lineTo(points[i][0], points[i][1]);
    if (closed) ctx.closePath();
    return;
  }
  const mid = (a: Vec2, b: Vec2): Vec2 => [(a[0] + b[0]) / 2, (a[1] + b[1]) / 2];
  if (closed) {
    const start = mid(points[n - 1], points[0]);
    ctx.moveTo(start[0], start[1]);
    for (let i = 0; i < n; i++) {
      const m = mid(points[i], points[(i + 1) % n]);
      ctx.quadraticCurveTo(points[i][0], points[i][1], m[0], m[1]);
    }
    ctx.closePath();
  } else {
    ctx.moveTo(points[0][0], points[0][1]);
    for (let i = 1; i < n - 1; i++) {
      const m = mid(points[i], points[i + 1]);
      ctx.quadraticCurveTo(points[i][0], points[i][1], m[0], m[1]);
    }
    ctx.lineTo(points[n - 1][0], points[n - 1][1]);
  }
}

/** The ink's look: a white halo under one red, so it reads on anything. */
export function inkStroke(ctx: CanvasRenderingContext2D, width = LINE_WIDTH, alpha = 1) {
  ctx.lineCap = "round";
  ctx.lineJoin = "round";
  ctx.globalAlpha = alpha * 0.92;
  ctx.strokeStyle = HALO;
  ctx.lineWidth = width + 2.6;
  ctx.stroke();
  ctx.globalAlpha = alpha;
  ctx.strokeStyle = INK;
  ctx.lineWidth = width;
  ctx.stroke();
  ctx.globalAlpha = 1;
}

/** A line with a head at its end: from here to there. */
export function traceLine(ctx: CanvasRenderingContext2D, points: Vec2[], head: number) {
  tracePath(ctx, points, false);
  if (points.length < 2) return;
  const to = points[points.length - 1];
  // Pointing along the last part of the line, not its last jittery step.
  let back = points[0];
  for (let i = points.length - 2; i >= 0; i--) {
    back = points[i];
    if (Math.hypot(to[0] - back[0], to[1] - back[1]) >= head) break;
  }
  const angle = Math.atan2(to[1] - back[1], to[0] - back[0]);
  const length = Math.min(head, Math.hypot(to[0] - back[0], to[1] - back[1]));
  for (const side of [-1, 1]) {
    const wing = angle + Math.PI + side * (Math.PI / 6.5);
    ctx.moveTo(to[0], to[1]);
    ctx.lineTo(to[0] + Math.cos(wing) * length, to[1] + Math.sin(wing) * length);
  }
}

const inCamera = new THREE.Vector3();
const nextInCamera = new THREE.Vector3();
const projected = new THREE.Vector3();

/**
 * World ink as lines on the screen. Points behind the camera are cut off, so walking through a mark
 * draws no lines across the screen. `whole`: nothing was cut, so a closed line may be closed.
 */
export function projectInk(ink: Vec3[], closed: boolean, camera: THREE.Camera, rect: { left: number; top: number; width: number; height: number }): { runs: Vec2[][]; whole: boolean } {
  const near = 0.01;
  const runs: Vec2[][] = [];
  let run: Vec2[] = [];
  let cut = false;
  const toScreen = (v: THREE.Vector3): Vec2 => {
    projected.copy(v).applyMatrix4((camera as THREE.PerspectiveCamera).projectionMatrix);
    return [rect.left + ((projected.x + 1) / 2) * rect.width, rect.top + ((1 - projected.y) / 2) * rect.height];
  };
  const count = closed ? ink.length : ink.length - 1;
  for (let i = 0; i < count; i++) {
    const a = ink[i];
    const b = ink[(i + 1) % ink.length];
    inCamera.set(a[0], a[1], a[2]).applyMatrix4(camera.matrixWorldInverse);
    nextInCamera.set(b[0], b[1], b[2]).applyMatrix4(camera.matrixWorldInverse);
    const aIn = inCamera.z < -near;
    const bIn = nextInCamera.z < -near;
    if (!aIn && !bIn) {
      cut = true;
      if (run.length > 1) runs.push(run);
      run = [];
      continue;
    }
    if (aIn && bIn) {
      if (run.length === 0) run.push(toScreen(inCamera));
      run.push(toScreen(nextInCamera));
      continue;
    }
    cut = true;
    const t = (-near - inCamera.z) / (nextInCamera.z - inCamera.z);
    const crossing = inCamera.clone().lerp(nextInCamera, t);
    if (aIn) {
      if (run.length === 0) run.push(toScreen(inCamera));
      run.push(toScreen(crossing));
      runs.push(run);
      run = [];
    } else {
      run = [toScreen(crossing), toScreen(nextInCamera)];
    }
  }
  if (run.length > 1) runs.push(run);
  return { runs, whole: closed && !cut && runs.length === 1 };
}

export class Overlay {
  readonly canvas: HTMLCanvasElement;
  private readonly ctx: CanvasRenderingContext2D;
  private freezeLayer?: HTMLCanvasElement;
  private width = 0;
  private height = 0;

  constructor(parent: HTMLElement) {
    this.canvas = document.createElement("canvas");
    this.canvas.className = "ds3d-ink";
    parent.append(this.canvas);
    this.ctx = this.canvas.getContext("2d")!;
  }

  /** With nothing on it, the canvas leaves the page's layers altogether. */
  setVisible(on: boolean) {
    const display = on ? "" : "none";
    if (this.canvas.style.display !== display) this.canvas.style.display = display;
  }

  /** Call before drawing a frame. */
  begin() {
    const ratio = Math.min(devicePixelRatio || 1, 2);
    const w = innerWidth;
    const h = innerHeight;
    if (w !== this.width || h !== this.height || this.canvas.width !== Math.round(w * ratio)) {
      this.width = w;
      this.height = h;
      this.canvas.width = Math.round(w * ratio);
      this.canvas.height = Math.round(h * ratio);
    }
    this.ctx.setTransform(ratio, 0, 0, ratio, 0, 0);
    this.ctx.clearRect(0, 0, w, h);
  }

  /** The world stops: a copy of the last frame takes the place of the game's canvas. */
  showFreeze(frame: HTMLCanvasElement, over: HTMLCanvasElement) {
    this.hideFreeze(true);
    const rect = over.getBoundingClientRect();
    frame.className = "ds3d-freeze";
    frame.style.left = `${rect.left}px`;
    frame.style.top = `${rect.top}px`;
    frame.style.width = `${rect.width}px`;
    frame.style.height = `${rect.height}px`;
    // Right above the game's canvas, under the game's own interface.
    over.after(frame);
    this.freezeLayer = frame;
  }

  hideFreeze(now = false) {
    const frame = this.freezeLayer;
    this.freezeLayer = undefined;
    if (!frame) return;
    if (now) frame.remove();
    else {
      frame.style.opacity = "0";
      setTimeout(() => frame.remove(), 180);
    }
  }

  /** A stroke being drawn, in screen points: `closing`, a ring where it would close into a circle; `line`, a head on its end. */
  liveStroke(points: Vec2[], closing: boolean, line = false) {
    if (points.length === 0) return;
    const ctx = this.ctx;
    if (points.length === 1) {
      ctx.beginPath();
      ctx.arc(points[0][0], points[0][1], LINE_WIDTH / 2 + 1, 0, Math.PI * 2);
      ctx.fillStyle = INK;
      ctx.fill();
      return;
    }
    if (line) traceLine(ctx, points, 18);
    else tracePath(ctx, points, false);
    inkStroke(ctx);
    if (closing) {
      // The loop is about to close: a ring at the start says so.
      ctx.beginPath();
      ctx.arc(points[0][0], points[0][1], 7, 0, Math.PI * 2);
      ctx.strokeStyle = INK;
      ctx.lineWidth = 2;
      ctx.stroke();
    }
  }

  /** A shape in screen points that does not move with the world (a mark on the game's interface). */
  screenPath(points: Vec2[], closed: boolean, alpha = 1) {
    tracePath(this.ctx, points, closed);
    inkStroke(this.ctx, LINE_WIDTH, alpha);
  }

  /**
   * Ink lying in the world, seen through a camera. Points behind the camera are cut off, so walking
   * through a mark does not draw lines across the screen.
   */
  worldInk(ink: Vec3[], closed: boolean, camera: THREE.Camera, rect: { left: number; top: number; width: number; height: number }, alpha = 1, arrow = false) {
    if (ink.length < 2) return;
    const { runs, whole } = projectInk(ink, closed, camera, rect);
    const ctx = this.ctx;
    runs.forEach((part, index) => {
      // The head belongs on the line's real end, if that end is in sight.
      if (arrow && index === runs.length - 1) traceLine(ctx, part, 18);
      else tracePath(ctx, whole ? part.slice(0, -1) : part, whole);
      inkStroke(ctx, LINE_WIDTH, alpha);
    });
  }

  /**
   * Light rising from a place where an agent is at work, so that it shows from across the room that something
   * is happening there: a column, rings going up it, and sparks. `fade` goes from 1 to 0 when the work is done.
   */
  beacon(base: Vec3, up: Vec3, radius: number, height: number, camera: THREE.Camera, rect: { left: number; top: number; width: number; height: number }, seconds: number, fade = 1) {
    const ctx = this.ctx;
    const axis = new THREE.Vector3(up[0], up[1], up[2]).normalize();
    const side = new THREE.Vector3(Math.abs(axis.y) > 0.9 ? 1 : 0, Math.abs(axis.y) > 0.9 ? 0 : 1, 0).cross(axis).normalize();
    const other = axis.clone().cross(side);
    const at = (along: number, out: number, angle: number): Vec2 | undefined => {
      const x = base[0] + axis.x * along + (side.x * Math.cos(angle) + other.x * Math.sin(angle)) * out;
      const y = base[1] + axis.y * along + (side.y * Math.cos(angle) + other.y * Math.sin(angle)) * out;
      const z = base[2] + axis.z * along + (side.z * Math.cos(angle) + other.z * Math.sin(angle)) * out;
      return toScreen([x, y, z], camera, rect);
    };
    const ring = (along: number, out: number): Vec2[] | undefined => {
      const points: Vec2[] = [];
      for (let i = 0; i < 28; i++) {
        const point = at(along, out, (i / 28) * Math.PI * 2);
        if (!point) return undefined;
        points.push(point);
      }
      return points;
    };
    const bottom = ring(0, radius);
    const top = ring(height, radius * 0.86);
    if (!bottom || !top) return;
    const middleOf = (points: Vec2[]): Vec2 => [points.reduce((sum, p) => sum + p[0], 0) / points.length, points.reduce((sum, p) => sum + p[1], 0) / points.length];
    const from = middleOf(bottom);
    const to = middleOf(top);
    // The column.
    const hull = convexHull([...bottom, ...top]);
    if (hull.length >= 3) {
      const light = ctx.createLinearGradient(from[0], from[1], to[0], to[1]);
      // Strong enough to read on a bright floor.
      light.addColorStop(0, `rgba(30, 140, 255, ${0.62 * fade})`);
      light.addColorStop(0.5, `rgba(70, 175, 255, ${0.26 * fade})`);
      light.addColorStop(1, "rgba(120, 205, 255, 0)");
      ctx.fillStyle = light;
      ctx.beginPath();
      ctx.moveTo(hull[0][0], hull[0][1]);
      for (let i = 1; i < hull.length; i++) ctx.lineTo(hull[i][0], hull[i][1]);
      ctx.closePath();
      ctx.fill();
    }
    // Rings going up it, and one on the ground that opens out as the work ends.
    ctx.lineJoin = "round";
    const stroke = (points: Vec2[], alpha: number, width: number) => {
      tracePath(ctx, points, true);
      // A dark line under a light one reads on anything, as the ink does.
      ctx.strokeStyle = `rgba(0, 92, 214, ${alpha * 0.85})`;
      ctx.lineWidth = width + 2.2;
      ctx.stroke();
      ctx.strokeStyle = `rgba(214, 240, 255, ${alpha})`;
      ctx.lineWidth = width;
      ctx.stroke();
    };
    const opened = ring(0, radius * (1 + (1 - fade) * 1.1));
    if (opened) stroke(opened, fade, 2.2);
    for (let k = 0; k < 3; k++) {
      const u = (seconds * 0.55 + k / 3) % 1;
      const rising = ring(u * height, radius * (1 - 0.14 * u));
      if (rising) stroke(rising, Math.min(1, u * 8) * (1 - u) ** 1.2 * fade, 1.6);
    }
    // Sparks.
    ctx.fillStyle = "#ffffff";
    for (let i = 0; i < 12; i++) {
      const u = (seconds * (0.3 + (i % 4) * 0.06) + i * 0.17) % 1;
      const out = radius * (0.25 + ((i * 0.37) % 1) * 0.65);
      const spark = at(u * height, out, i * 2.399 + seconds * 0.5);
      if (!spark) continue;
      ctx.globalAlpha = (1 - u) * 0.9 * fade;
      ctx.beginPath();
      ctx.arc(spark[0], spark[1], 1.6 + (1 - u) * 2, 0, Math.PI * 2);
      ctx.fill();
    }
    ctx.globalAlpha = 1;
  }

  /** Which way an agent is at work, when that's out of sight: at the edge of the screen, with a ring going out. */
  pointer(at: Vec2, angle: number, seconds: number, fade = 1) {
    const ctx = this.ctx;
    const u = (seconds * 1.1) % 1;
    ctx.save();
    ctx.translate(at[0], at[1]);
    ctx.globalAlpha = (1 - u) * 0.8 * fade;
    ctx.strokeStyle = "rgb(40, 150, 255)";
    ctx.lineWidth = 2.6;
    ctx.beginPath();
    ctx.arc(0, 0, 16 + u * 22, 0, Math.PI * 2);
    ctx.stroke();
    ctx.globalAlpha = fade;
    ctx.fillStyle = "rgb(16, 112, 240)";
    ctx.beginPath();
    ctx.arc(0, 0, 16, 0, Math.PI * 2);
    ctx.fill();
    ctx.strokeStyle = "rgba(255, 255, 255, 0.95)";
    ctx.lineWidth = 2;
    ctx.stroke();
    ctx.rotate(angle);
    ctx.lineWidth = 3;
    ctx.lineCap = "round";
    ctx.lineJoin = "round";
    ctx.strokeStyle = "#ffffff";
    ctx.beginPath();
    ctx.moveTo(-3.5, -6.5);
    ctx.lineTo(3.5, 0);
    ctx.lineTo(-3.5, 6.5);
    ctx.stroke();
    ctx.restore();
  }

  /** Light running along a line an agent is working on. */
  flow(ink: Vec3[], camera: THREE.Camera, rect: { left: number; top: number; width: number; height: number }, seconds: number, fade = 1) {
    if (ink.length < 2) return;
    const ctx = this.ctx;
    const { runs } = projectInk(ink, false, camera, rect);
    ctx.save();
    ctx.lineCap = "round";
    ctx.setLineDash([2, 24]);
    ctx.lineDashOffset = -seconds * 80;
    for (const run of runs) {
      tracePath(ctx, run, false);
      ctx.strokeStyle = `rgba(0, 110, 235, ${fade})`;
      ctx.lineWidth = 10;
      ctx.stroke();
      ctx.strokeStyle = `rgba(255, 255, 255, ${fade})`;
      ctx.lineWidth = 5;
      ctx.stroke();
    }
    ctx.restore();
  }

  /** The outline of a thing, in the blue of a chosen component. */
  outline(bounds: Box, camera: THREE.Camera, rect: { left: number; top: number; width: number; height: number }, alpha = 1) {
    const { points, complete } = boxOnScreen(bounds, camera, rect);
    if (!complete) return;
    const hull = convexHull(points);
    if (hull.length < 3) return;
    const ctx = this.ctx;
    ctx.beginPath();
    ctx.moveTo(hull[0][0], hull[0][1]);
    for (let i = 1; i < hull.length; i++) ctx.lineTo(hull[i][0], hull[i][1]);
    ctx.closePath();
    ctx.lineJoin = "round";
    ctx.globalAlpha = alpha * 0.12;
    ctx.fillStyle = OUTLINE;
    ctx.fill();
    ctx.globalAlpha = alpha;
    ctx.strokeStyle = OUTLINE;
    ctx.lineWidth = 2;
    ctx.stroke();
    ctx.globalAlpha = 1;
  }

  /** An HTML element's outline, on screen. */
  screenOutline(x: number, y: number, w: number, h: number) {
    const ctx = this.ctx;
    ctx.beginPath();
    ctx.roundRect(x, y, w, h, 8);
    ctx.globalAlpha = 0.12;
    ctx.fillStyle = OUTLINE;
    ctx.fill();
    ctx.globalAlpha = 1;
    ctx.strokeStyle = OUTLINE;
    ctx.lineWidth = 2;
    ctx.stroke();
  }
}
