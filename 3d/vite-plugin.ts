import type { Plugin } from "vite";

/** As much of Vite's module graph as it takes to tell. */
export interface ModuleLink {
  isSelfAccepting?: boolean;
  importers: Set<ModuleLink>;
  acceptedHmrDeps: Set<ModuleLink>;
}

/** Does a change to this module update in place: does something accept it, on every way up to the page? */
export function updatesInPlace(mod: ModuleLink, seen = new Set<ModuleLink>()): boolean {
  if (mod.isSelfAccepting) return true;
  if (seen.has(mod)) return true;
  seen.add(mod);
  if (mod.importers.size === 0) return false;
  for (const importer of mod.importers) {
    if (!importer.acceptedHmrDeps.has(mod) && !updatesInPlace(importer, seen)) return false;
  }
  return true;
}

/** How long a page may be silent and still count as having the tool on it. */
const ALIVE_MS = 10_000;

/**
 * The first thing a page does: if it has just been reloaded, the last frame of the page before it goes
 * straight back up, so nothing flashes. The tool melts it away when the world is ready (tool.ts).
 */
const COVER_SCRIPT = `(() => {
  try {
    const saved = JSON.parse(sessionStorage.getItem("ds3d.cover") || "null");
    sessionStorage.removeItem("ds3d.cover");
    if (!saved || Date.now() - saved.at > 20000) return;
    const cover = new Image();
    cover.id = "ds3d-cover";
    cover.alt = "";
    cover.src = saved.image;
    const [left, top, width, height] = saved.rect;
    cover.style.cssText = "position:fixed;z-index:2147483000;pointer-events:none;object-fit:cover;transition:opacity .6s ease;left:" + left + "px;top:" + top + "px;width:" + width + "px;height:" + height + "px";
    document.documentElement.append(cover);
    setTimeout(() => cover.remove(), 15000);
  } catch {}
})();`;

/**
 * An agent saves one file after another, and each save would reload the page under whoever is walking
 * through the world. While the tool is on a page (it says so: ds3d:alive), this holds those reloads back
 * and tells the tool, which reloads once, when the agent has paused and nobody is drawing or talking.
 * What can update in place still does, at once, and a page without the tool is left to Vite as usual.
 * When the reload comes, the page's last frame stays up until the new page is ready.
 */
export function calmReloads(): Plugin {
  let aliveAt = 0;
  return {
    name: "drawspeak3d-calm-reloads",
    apply: "serve",
    configureServer(server) {
      server.ws.on("ds3d:alive", () => {
        aliveAt = Date.now();
      });
    },
    transformIndexHtml() {
      return [{ tag: "script", children: COVER_SCRIPT, injectTo: "head-prepend" }];
    },
    hotUpdate({ file, modules, timestamp }) {
      if (this.environment.name !== "client" || Date.now() - aliveAt > ALIVE_MS) return;
      if (modules.length === 0 || modules.every((mod) => updatesInPlace(mod as unknown as ModuleLink))) return;
      const invalidated = new Set<(typeof modules)[number]>();
      for (const mod of modules) this.environment.moduleGraph.invalidateModule(mod, invalidated, timestamp, true);
      this.environment.hot.send({ type: "custom", event: "ds3d:change", data: { file } });
      return [];
    },
  };
}
