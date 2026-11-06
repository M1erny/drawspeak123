import { boundsOf } from "../core/geometry.ts";
import { linePoints } from "../core/stroke.ts";
import type { Note, Shape, Vec2 } from "../core/types.ts";
import { inkStroke, traceLine, tracePath } from "./overlay.ts";
import { HALO, INK } from "./styles.ts";

/**
 * The picture that goes to the agent: the view as it was, with its numbered marks drawn on it. Marks
 * are the strokes as drawn on that screen, not their lifted copies in the world.
 */
export interface CompositeItem {
  number: number;
  note: Note;
}

/** Where a shape's number goes: its top right corner, inside the picture. */
export function pinSpot(shape: Shape): Vec2 {
  switch (shape.kind) {
    case "component":
      return [shape.rect.x + shape.rect.w, shape.rect.y];
    case "lasso": {
      const b = boundsOf(shape.points);
      return [b.maxX, b.minY];
    }
    case "arrow":
      return shape.from;
    case "point":
      return shape.at;
    case "view":
      return [0.06, 0.1];
  }
}

function drawShape(ctx: CanvasRenderingContext2D, shape: Shape, width: number, height: number, line: number) {
  const px = ([x, y]: Vec2): Vec2 => [x * width, y * height];
  switch (shape.kind) {
    case "component": {
      const { x, y, w, h } = shape.rect;
      ctx.beginPath();
      ctx.roundRect(x * width, y * height, w * width, h * height, Math.min(w * width, h * height, line * 5) * 0.3);
      break;
    }
    case "lasso":
      tracePath(ctx, shape.points.map(px), true);
      break;
    case "arrow":
      traceLine(ctx, linePoints(shape).map(px), line * 7);
      break;
    case "point": {
      const [x, y] = px(shape.at);
      ctx.beginPath();
      ctx.arc(x, y, line * 5, 0, Math.PI * 2);
      break;
    }
    case "view":
      return;
  }
  inkStroke(ctx, line);
}

function drawPin(ctx: CanvasRenderingContext2D, x: number, y: number, size: number, number: number) {
  const r = size / 2;
  ctx.beginPath();
  ctx.arc(x, y, r, 0, Math.PI * 2);
  ctx.fillStyle = INK;
  ctx.fill();
  ctx.lineWidth = Math.max(2, size * 0.07);
  ctx.strokeStyle = HALO;
  ctx.stroke();
  ctx.fillStyle = "#fff";
  ctx.font = `700 ${Math.round(size * 0.5)}px -apple-system, "Segoe UI", system-ui, sans-serif`;
  ctx.textAlign = "center";
  ctx.textBaseline = "middle";
  ctx.fillText(String(number), x, y + size * 0.02);
}

/** A tag naming a thing that is not in the picture: the game's own interface is HTML over the canvas. */
function drawTag(ctx: CanvasRenderingContext2D, text: string, x: number, y: number, size: number, maxX: number) {
  ctx.font = `600 ${Math.round(size * 0.42)}px -apple-system, "Segoe UI", system-ui, sans-serif`;
  const width = Math.min(ctx.measureText(text).width + size * 0.5, maxX - 8);
  const left = Math.max(4, Math.min(x, maxX - width - 4));
  ctx.beginPath();
  ctx.roundRect(left, y, width, size * 0.78, size * 0.2);
  ctx.fillStyle = "rgba(24,27,31,0.9)";
  ctx.fill();
  ctx.fillStyle = "#fff";
  ctx.textAlign = "left";
  ctx.textBaseline = "middle";
  ctx.fillText(text, left + size * 0.25, y + size * 0.4, width - size * 0.5);
}

export async function renderComposite(image: Blob, items: CompositeItem[], maxWidth: number): Promise<HTMLCanvasElement> {
  const bitmap = await createImageBitmap(image);
  const scale = Math.min(1, maxWidth / bitmap.width);
  const width = Math.round(bitmap.width * scale);
  const height = Math.round(bitmap.height * scale);
  const canvas = document.createElement("canvas");
  canvas.width = width;
  canvas.height = height;
  const ctx = canvas.getContext("2d")!;
  ctx.drawImage(bitmap, 0, 0, width, height);
  bitmap.close();
  // Sizes follow the picture, as they follow the screen on the canvas: a 1600 px picture has 3 px ink and 30 px pins.
  const line = Math.max(2, width / 480);
  const pin = Math.max(18, width / 54);
  for (const { note } of items) drawShape(ctx, note.shape, width, height, line);
  for (const { number, note } of items) {
    const [nx, ny] = pinSpot(note.shape);
    const x = Math.min(width - pin * 0.6, Math.max(pin * 0.6, nx * width));
    // A spot's pin stands over its ring, as it does on the screen.
    const lift = note.shape.kind === "point" ? pin * 0.85 : 0;
    const y = Math.min(height - pin * 0.6, Math.max(pin * 0.6, ny * height - lift));
    drawPin(ctx, x, y, pin, number);
    const top = note.target?.layers[note.target.layer]?.[note.target.depth];
    if (top?.kind === "html") drawTag(ctx, `Interface: ${top.label}`, x + pin * 0.7, y - pin * 0.4, pin, width);
  }
  return canvas;
}

export function toBlob(canvas: HTMLCanvasElement, quality = 0.9): Promise<Blob> {
  return new Promise((resolve, reject) => canvas.toBlob((blob) => (blob ? resolve(blob) : reject(new Error("no picture"))), "image/jpeg", quality));
}

/** A frame scaled down to what is worth keeping. */
let encoder: Worker | null | undefined;
const waiting = new Map<number, (blob: Blob | undefined) => void>();
let nextPicture = 0;

function theEncoder(): Worker | null {
  if (encoder !== undefined) return encoder;
  try {
    const source = `self.onmessage = async (e) => {
      const { id, bitmap, quality } = e.data;
      try {
        const canvas = new OffscreenCanvas(bitmap.width, bitmap.height);
        canvas.getContext("2d").drawImage(bitmap, 0, 0);
        bitmap.close();
        self.postMessage({ id, blob: await canvas.convertToBlob({ type: "image/jpeg", quality }) });
      } catch {
        self.postMessage({ id });
      }
    };`;
    encoder = new Worker(URL.createObjectURL(new Blob([source], { type: "text/javascript" })));
    encoder.onmessage = (e: MessageEvent<{ id: number; blob?: Blob }>) => {
      waiting.get(e.data.id)?.(e.data.blob);
      waiting.delete(e.data.id);
    };
    encoder.onerror = () => {
      encoder = null;
      for (const done of waiting.values()) done(undefined);
      waiting.clear();
    };
  } catch {
    encoder = null;
  }
  return encoder;
}

/** A picture as a file, made away from the page's thread: in a big world, reading a frame back can stop the game for a moment. */
export async function toBlobAway(canvas: HTMLCanvasElement, quality: number): Promise<Blob> {
  const worker = theEncoder();
  if (worker && typeof OffscreenCanvas !== "undefined") {
    const bitmap = await createImageBitmap(canvas);
    const id = nextPicture++;
    const blob = await new Promise<Blob | undefined>((done) => {
      waiting.set(id, done);
      worker.postMessage({ id, bitmap, quality }, [bitmap]);
    });
    if (blob) return blob;
  }
  return toBlob(canvas, quality);
}

export function scaledCopy(frame: HTMLCanvasElement, maxWidth: number): HTMLCanvasElement {
  if (frame.width <= maxWidth) return frame;
  const canvas = document.createElement("canvas");
  canvas.width = maxWidth;
  canvas.height = Math.round((frame.height * maxWidth) / frame.width);
  const ctx = canvas.getContext("2d")!;
  ctx.imageSmoothingQuality = "high";
  ctx.drawImage(frame, 0, 0, canvas.width, canvas.height);
  return canvas;
}

export function blobToDataUrl(blob: Blob): Promise<string> {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => resolve(String(reader.result));
    reader.onerror = () => reject(reader.error);
    reader.readAsDataURL(blob);
  });
}
