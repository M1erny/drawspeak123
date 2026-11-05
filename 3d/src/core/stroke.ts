import { boundsOf, distance, pathLength, simplified } from "./geometry.ts";
import type { Shape, Vec2 } from "./types.ts";

/**
 * What a finished stroke means. There are no tools to choose between, one gesture says it all:
 *   - a circle: what is inside it, or this area;
 *   - a line: from here to there, a route or something to move;
 *   - a tap: this thing, or this spot (isTap; which of the two takes the world to tell).
 * The thresholds come from the iPad app's StrokeClassifier, in screen points.
 */

/** Marks whose screen bounding box fits in this square are taps or slips. */
export const MINIMUM_MARK_SIZE = 24;
export const MINIMUM_LINE_LENGTH = 32;
/** A loop is closed when its end is within this fraction of the path length, or within CLOSE_DISTANCE, of its start. */
export const CLOSE_FRACTION = 0.12;
export const CLOSE_DISTANCE = 30;
/** Stored freehand points are at least this far apart on screen. */
export const SAMPLE_SPACING = 2;
/** A hasty circle leaves a wider gap, but it turned most of the way round; a U-turn does not. */
const HASTY_GAP = 0.35;
const HASTY_TURN = (250 * Math.PI) / 180;
/** A line this close to straight, as a share of its length, is straight. */
const STRAIGHT_ENOUGH = 0.06;
const MAX_BENDS = 22;

/** How far a stroke turned in all, in radians, ignoring the jitter of a hand. */
function totalTurn(points: Vec2[]): number {
  const coarse = simplified(points, 14);
  let turn = 0;
  for (let i = 2; i < coarse.length; i++) {
    const a = Math.atan2(coarse[i - 1][1] - coarse[i - 2][1], coarse[i - 1][0] - coarse[i - 2][0]);
    const b = Math.atan2(coarse[i][1] - coarse[i - 1][1], coarse[i][0] - coarse[i - 1][0]);
    let step = b - a;
    while (step > Math.PI) step -= Math.PI * 2;
    while (step < -Math.PI) step += Math.PI * 2;
    turn += step;
  }
  return Math.abs(turn);
}

export function isClosedLoop(points: Vec2[]): boolean {
  if (points.length < 3) return false;
  const length = pathLength(points);
  if (length <= 0) return false;
  const gap = distance(points[0], points[points.length - 1]);
  if (gap <= CLOSE_FRACTION * length) return true;
  // Close by, and it really went somewhere and came back: a short straight line is not a loop.
  if (gap <= CLOSE_DISTANCE && length >= gap * 2.2) return true;
  return gap <= HASTY_GAP * length && totalTurn(points) >= HASTY_TURN;
}

/** A stroke on its way round: it may yet become a circle, so it shows no arrow head while it is drawn. */
export function isCurling(points: Vec2[]): boolean {
  return totalTurn(points) > (Math.PI * 2) / 3;
}

/** A stroke that never left a small box: a tap on something, or a slip. */
export function isTap(points: Vec2[]): boolean {
  if (points.length === 0) return false;
  const b = boundsOf(points);
  return b.maxX - b.minX < MINIMUM_MARK_SIZE && b.maxY - b.minY < MINIMUM_MARK_SIZE;
}

/** How far a stroke strays from the straight line between its ends, in points. */
function strayFromChord(points: Vec2[]): number {
  const [ax, ay] = points[0];
  const [bx, by] = points[points.length - 1];
  const length = Math.hypot(bx - ax, by - ay) || 1;
  let most = 0;
  for (const [x, y] of points) most = Math.max(most, Math.abs((bx - ax) * (ay - y) - (ax - x) * (by - ay)) / length);
  return most;
}

/**
 * A stroke as a mark, or nothing when it shows no intent (a tap is for the caller, who can see the world).
 * @param points the stroke on screen, in points, in drawing order
 * @param width the screen's width, in the same points (normalizes the result)
 */
export function shapeFor(points: Vec2[], width: number, height: number): Shape | null {
  if (points.length < 2 || !(width > 0) || !(height > 0) || isTap(points)) return null;
  const normal = (p: Vec2): Vec2 => [p[0] / width, p[1] / height];
  let shape: Shape;
  if (isClosedLoop(points)) {
    shape = { kind: "lasso", points: simplified(points, SAMPLE_SPACING).map(normal) };
  } else {
    const length = pathLength(points);
    if (length < MINIMUM_LINE_LENGTH) return null;
    shape = { kind: "arrow", from: normal(points[0]), to: normal(points[points.length - 1]) };
    if (strayFromChord(points) > STRAIGHT_ENOUGH * length) {
      const bends = simplified(points, Math.max(SAMPLE_SPACING, length / MAX_BENDS)).slice(1, -1);
      shape.via = bends.map(normal);
    }
  }
  return isValidShape(shape) ? shape : null;
}

export function isValidShape(shape: Shape): boolean {
  switch (shape.kind) {
    case "component":
      return shape.rect.w > 0 && shape.rect.h > 0 && shape.rect.w <= 1.5 && shape.rect.h <= 1.5;
    case "lasso":
      return shape.points.length >= 3;
    case "arrow":
      return Math.hypot(shape.to[0] - shape.from[0], shape.to[1] - shape.from[1]) > 0.005 || (shape.via?.length ?? 0) > 0;
    case "point":
    case "view":
      return true;
  }
}

export function kindLabel(shape: Shape): string {
  switch (shape.kind) {
    case "lasso":
      return "Loop";
    case "arrow":
      return "Line";
    case "point":
      return "Spot";
    case "component":
      return "Thing";
    case "view":
      return "View";
  }
}

/** All the screen points of a line, in order. */
export function linePoints(shape: Extract<Shape, { kind: "arrow" }>): Vec2[] {
  return [shape.from, ...(shape.via ?? []), shape.to];
}
