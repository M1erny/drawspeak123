type Child = Node | string | null | undefined | false;

/** A small element builder: h("div", { class: "x", onclick: fn }, "text", child). */
export function h<K extends keyof HTMLElementTagNameMap>(tag: K, attrs: Record<string, unknown> = {}, ...children: Child[]): HTMLElementTagNameMap[K] {
  const el = document.createElement(tag);
  for (const [name, value] of Object.entries(attrs)) {
    if (value === undefined || value === false || value === null) continue;
    if (name.startsWith("on") && typeof value === "function") el.addEventListener(name.slice(2), value as EventListener);
    else if (name === "class") el.className = String(value);
    else if (name === "html") el.innerHTML = String(value);
    else if (name in el && name !== "list") (el as unknown as Record<string, unknown>)[name] = value;
    else el.setAttribute(name, value === true ? "" : String(value));
  }
  for (const child of children) if (child !== null && child !== undefined && child !== false) el.append(child);
  return el;
}

const svg = (body: string) => `<svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${body}</svg>`;

/** The icons of the palette and panels. */
export const ICON = {
  pencil: svg('<path d="M4 20l1-4.5L16.5 4a2.1 2.1 0 0 1 3 3L8 18.5 4 20z"/><path d="M14.5 6l3.5 3.5"/>'),
  talk: svg('<path d="M4.500 5.500h15a1.500 1.500 0 0 1 1.500 1.500v8.500a1.500 1.500 0 0 1-1.500 1.500H11l-4.500 3.500V17h-2A1.500 1.500 0 0 1 3 15.500V7a1.500 1.500 0 0 1 1.500-1.500z"/>'),
  undo: svg('<path d="M9 7L4.500 11.500 9 16"/><path d="M5 11.500h9.500a5 5 0 0 1 0 10H12"/>'),
  mic: svg('<rect x="9" y="3" width="6" height="11" rx="3"/><path d="M5.500 11.500a6.500 6.500 0 0 0 13 0"/><path d="M12 18v3"/>'),
  micOff: svg('<path d="M9 8.500V6a3 3 0 0 1 5.800-1"/><path d="M15 10v1a3 3 0 0 1-4.600 2.500"/><path d="M5.500 11.500a6.500 6.500 0 0 0 10.400 5.200"/><path d="M18.500 11.500c0 .7-.1 1.400-.3 2"/><path d="M12 18v3"/><path d="M4 4l16 16"/>'),
  list: svg('<path d="M4 6h1M4 12h1M4 18h1"/><path d="M9 6h11M9 12h11M9 18h11"/>'),
  send: svg('<path d="M5 12l14-7-5 15-2.500-6.500L5 12z"/>'),
  stop: svg('<rect x="6.500" y="6.500" width="11" height="11" rx="2.500" fill="currentColor" stroke="none"/>'),
  close: svg('<path d="M6 6l12 12M18 6L6 18"/>'),
  eye: svg('<path d="M2.500 12S6 5.500 12 5.500 21.500 12 21.500 12 18 18.500 12 18.500 2.500 12 2.500 12z"/><circle cx="12" cy="12" r="2.800"/>'),
  trash: svg('<path d="M4.500 7h15"/><path d="M9.500 7V4.500h5V7"/><path d="M6.500 7l1 13h9l1-13"/>'),
  check: svg('<path d="M5 12.500l4.500 4.500L19 7.500"/>'),
  chevron: svg('<path d="M9.500 6l6 6-6 6"/>'),
  spark: svg('<path d="M12 3.500l1.800 5.200 5.200 1.800-5.200 1.800L12 17.500l-1.800-5.200-5.200-1.800 5.200-1.800L12 3.500z"/>'),
};

/** Lets an element fade before it goes. */
export function leave(el: HTMLElement) {
  el.classList.add("ds3d-leaving");
  setTimeout(() => el.remove(), 160);
}

export function iconSpan(icon: string, className = "ds3d-ic"): HTMLElement {
  return h("span", { class: className, html: icon });
}
