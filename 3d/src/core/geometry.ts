import type { NRect, Vec2 } from "./types.ts";

/** Plain 2D geometry on screen points. */

export function distance(a: Vec2, b: Vec2): number {
  return Math.hypot(b[0] - a[0], b[1] - a[1]);
}

export function pathLength(points: Vec2[]): number {
  let total = 0;
  for (let i = 1; i < points.length; i++) total += distance(points[i - 1], points[i]);
  return total;
}

export interface Rect {
  minX: number;
  minY: number;
  maxX: number;
  maxY: number;
}

export function boundsOf(points: Vec2[]): Rect {
  let minX = Infinity;
  let minY = Infinity;
  let maxX = -Infinity;
  let maxY = -Infinity;
  for (const [x, y] of points) {
    if (x < minX) minX = x;
    if (y < minY) minY = y;
    if (x > maxX) maxX = x;
    if (y > maxY) maxY = y;
  }
  return { minX, minY, maxX, maxY };
}

export function rectOf(points: Vec2[]): NRect {
  const b = boundsOf(points);
  return { x: b.minX, y: b.minY, w: b.maxX - b.minX, h: b.maxY - b.minY };
}

/** Drops points closer than `spacing` to the last kept one; keeps the end point. */
export function simplified(points: Vec2[], spacing: number): Vec2[] {
  if (points.length === 0) return [];
  const kept: Vec2[] = [points[0]];
  for (let i = 1; i < points.length; i++) {
    if (distance(points[i], kept[kept.length - 1]) >= spacing) kept.push(points[i]);
  }
  const last = points[points.length - 1];
  const end = kept[kept.length - 1];
  if (end[0] !== last[0] || end[1] !== last[1]) kept.push(last);
  return kept;
}

/** Even-odd rule; the polygon closes itself. */
export function pointInPolygon(point: Vec2, polygon: Vec2[]): boolean {
  const [x, y] = point;
  let inside = false;
  for (let i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
    const [xi, yi] = polygon[i];
    const [xj, yj] = polygon[j];
    if (yi > y !== yj > y && x < ((xj - xi) * (y - yi)) / (yj - yi) + xi) inside = !inside;
  }
  return inside;
}

export function polygonCentroid(polygon: Vec2[]): Vec2 {
  let area = 0;
  let cx = 0;
  let cy = 0;
  for (let i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
    const cross = polygon[j][0] * polygon[i][1] - polygon[i][0] * polygon[j][1];
    area += cross;
    cx += (polygon[j][0] + polygon[i][0]) * cross;
    cy += (polygon[j][1] + polygon[i][1]) * cross;
  }
  if (Math.abs(area) < 1e-6) {
    const b = boundsOf(polygon);
    return [(b.minX + b.maxX) / 2, (b.minY + b.maxY) / 2];
  }
  return [cx / (3 * area), cy / (3 * area)];
}

/**
 * Points inside a polygon on an even grid, about `target` of them, in an order that covers the whole
 * shape early: a pick that runs out of time still has a fair picture of what the loop holds.
 */
export function samplePolygon(polygon: Vec2[], target = 96): Vec2[] {
  const b = boundsOf(polygon);
  const width = b.maxX - b.minX;
  const height = b.maxY - b.minY;
  if (!(width > 0) || !(height > 0)) return [];
  // The grid over the box, denser to make up for the part of the box outside the loop.
  let step = Math.max(2, Math.sqrt((width * height) / (target * 1.3)));
  let points: Vec2[] = [];
  for (let attempt = 0; attempt < 5; attempt++) {
    points = [];
    for (let y = b.minY + step / 2; y < b.maxY; y += step) {
      for (let x = b.minX + step / 2; x < b.maxX; x += step) {
        if (pointInPolygon([x, y], polygon)) points.push([x, y]);
      }
    }
    if (points.length >= target * 0.6 || step <= 2) break;
    step = Math.max(2, step * 0.72);
  }
  if (points.length === 0) points = [polygonCentroid(polygon)];
  return lowDiscrepancyOrder(points).slice(0, Math.ceil(target * 1.5));
}

/** Reorders a list so that any prefix is spread over all of it (bit-reversed indices). */
export function lowDiscrepancyOrder<T>(items: T[]): T[] {
  const n = items.length;
  if (n < 3) return items.slice();
  let bits = 0;
  while (1 << bits < n) bits++;
  const out: T[] = [];
  for (let i = 0; i < 1 << bits; i++) {
    let reversed = 0;
    for (let b = 0; b < bits; b++) if (i & (1 << b)) reversed |= 1 << (bits - 1 - b);
    if (reversed < n) out.push(items[reversed]);
  }
  return out;
}

/** How much of a screen rectangle lies inside the polygon (0…1), by a small grid over it. */
export function enclosure(rect: Rect, polygon: Vec2[], cells = 7): number {
  const width = rect.maxX - rect.minX;
  const height = rect.maxY - rect.minY;
  if (!(width >= 0) || !(height >= 0)) return 0;
  let inside = 0;
  for (let j = 0; j < cells; j++) {
    for (let i = 0; i < cells; i++) {
      if (pointInPolygon([rect.minX + (width * (i + 0.5)) / cells, rect.minY + (height * (j + 0.5)) / cells], polygon)) inside++;
    }
  }
  return inside / (cells * cells);
}

/** Convex hull, counter-clockwise (monotone chain). */
export function convexHull(points: Vec2[]): Vec2[] {
  const sorted = points.slice().sort((a, b) => a[0] - b[0] || a[1] - b[1]);
  if (sorted.length < 3) return sorted;
  const cross = (o: Vec2, a: Vec2, b: Vec2) => (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0]);
  const lower: Vec2[] = [];
  for (const p of sorted) {
    while (lower.length >= 2 && cross(lower[lower.length - 2], lower[lower.length - 1], p) <= 0) lower.pop();
    lower.push(p);
  }
  const upper: Vec2[] = [];
  for (let i = sorted.length - 1; i >= 0; i--) {
    const p = sorted[i];
    while (upper.length >= 2 && cross(upper[upper.length - 2], upper[upper.length - 1], p) <= 0) upper.pop();
    upper.push(p);
  }
  lower.pop();
  upper.pop();
  return lower.concat(upper);
}
