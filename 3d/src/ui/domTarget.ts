import { samplePolygon } from "../core/geometry.ts";
import type { SceneEntity, Vec2 } from "../core/types.ts";

/**
 * A loop can be about the game's own interface, which is HTML over the canvas: a button, a panel.
 * Then the target is a chain of elements, as on the iPad's HTML mockups, not a thing in the world.
 */

/** A loop mostly over HTML gives its element's chain; a loop over the world gives nothing. */
export function domTargetFor(points: Vec2[], canvas: HTMLCanvasElement): { layers: SceneEntity[][] } | undefined {
  const samples = samplePolygon(points, 36);
  if (samples.length === 0) return undefined;
  const counts = new Map<Element, number>();
  let overDom = 0;
  for (const [x, y] of samples) {
    const el = document.elementFromPoint(x, y);
    if (!el || el === canvas || el === document.body || el === document.documentElement || el.closest(".ds3d-root")) continue;
    overDom++;
    for (let e: Element | null = el; e && e !== document.body; e = e.parentElement) counts.set(e, (counts.get(e) ?? 0) + 1);
  }
  if (overDom / samples.length < 0.6) return undefined;
  // The deepest element holding most of what is inside the loop.
  let best: Element | undefined;
  let bestDepth = -1;
  for (const [el, count] of counts) {
    if (count < overDom * 0.6) continue;
    let depth = 0;
    for (let e: Element | null = el; e; e = e.parentElement) depth++;
    if (depth > bestDepth) {
      bestDepth = depth;
      best = el;
    }
  }
  if (!best) return undefined;
  const chain: SceneEntity[] = [];
  for (let e: Element | null = best; e && e !== document.body && chain.length < 6; e = e.parentElement) {
    if (e === best || isMeaningful(e)) chain.push(entityOf(e, e === best));
  }
  return { layers: [chain] };
}

function isMeaningful(el: Element): boolean {
  return el.id !== "" || el.hasAttribute("aria-label") || el.hasAttribute("role") || el.tagName === "BUTTON" || el.tagName === "A" || el.classList.length > 0;
}

function entityOf(el: Element, isHit: boolean): SceneEntity {
  const path = cssPath(el);
  const rect = el.getBoundingClientRect();
  return {
    key: `html:${path}`,
    label: labelOf(el, isHit),
    kind: "html",
    locator: { strategy: "css-path", value: path },
    data: { tag: el.tagName.toLowerCase(), screenRect: [Math.round(rect.left), Math.round(rect.top), Math.round(rect.width), Math.round(rect.height)], text: textOf(el).slice(0, 120) || undefined },
  };
}

function textOf(el: Element): string {
  return (el.textContent ?? "").replace(/\s+/g, " ").trim();
}

/** The thing itself by what it says; what holds it by what it is (its whole text would be a jumble). */
function labelOf(el: Element, isHit: boolean): string {
  const named = el.getAttribute("aria-label") || el.getAttribute("title");
  if (named) return named;
  if (isHit) {
    const text = textOf(el);
    if (text) return text.length > 34 ? `${text.slice(0, 33)}…` : text;
  }
  if (el.id) return `#${el.id}`;
  const tag = el.tagName.toLowerCase();
  return el.classList.length > 0 ? `${tag}.${el.classList[0]}` : tag;
}

export function cssPath(el: Element): string {
  const parts: string[] = [];
  for (let e: Element | null = el; e && e !== document.body; e = e.parentElement) {
    if (e.id) {
      parts.unshift(`#${CSS.escape(e.id)}`);
      break;
    }
    const classes = [...e.classList].slice(0, 2).map((c) => `.${CSS.escape(c)}`).join("");
    const parent: Element | null = e.parentElement;
    const tag = e.tagName.toLowerCase();
    const same = parent ? [...parent.children].filter((c) => c.tagName === e!.tagName && (classes === "" || c.matches(classes))) : [];
    parts.unshift(same.length > 1 ? `${tag}${classes}:nth-of-type(${[...parent!.children].filter((c) => c.tagName === e!.tagName).indexOf(e) + 1})` : `${tag}${classes}`);
  }
  return parts.join(" > ");
}
