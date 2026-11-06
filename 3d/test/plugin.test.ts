import { describe, expect, it } from "vitest";
import { type ModuleLink, onThePage, updatesInPlace } from "../vite-plugin.ts";

const link = (name: string, self = false) => ({ name, isSelfAccepting: self, importers: new Set<ModuleLink>(), acceptedHmrDeps: new Set<ModuleLink>() });
const imports = (importer: ModuleLink, mod: ModuleLink) => mod.importers.add(importer);

describe("which changes update in place", () => {
  it("an ordinary module, imported from the page's entry, does not: the page must reload", () => {
    const entry = link("main.ts");
    const store = link("store.ts");
    imports(entry, store);
    expect(updatesInPlace(store)).toBe(false);
    expect(updatesInPlace(entry)).toBe(false);
  });
  it("a module something accepts does, and so does what only it imports", () => {
    const entry = link("main.ts");
    const mount = link("liveMount.ts");
    const live = link("live.ts");
    const kit = link("liveKit.ts");
    imports(entry, mount);
    imports(mount, live);
    imports(live, kit);
    mount.acceptedHmrDeps.add(live);
    expect(updatesInPlace(live)).toBe(true);
    expect(updatesInPlace(kit)).toBe(true);
    expect(updatesInPlace(mount)).toBe(false);
  });
  it("a module used elsewhere too does not, even if one importer accepts it", () => {
    const entry = link("main.ts");
    const mount = link("liveMount.ts");
    const kit = link("liveKit.ts");
    imports(entry, mount);
    imports(mount, kit);
    imports(entry, kit);
    mount.acceptedHmrDeps.add(kit);
    expect(updatesInPlace(kit)).toBe(false);
  });
  it("a file the page has not asked for yet is not on the page: saving it again is no reason to reload", () => {
    expect(onThePage(link("new.ts"))).toBe(false);
    const entry = link("main.ts");
    const store = link("store.ts");
    imports(entry, store);
    expect(onThePage(store)).toBe(true);
    expect(onThePage({ ...entry, importedModules: new Set([store]) })).toBe(true);
  });
  it("a module that accepts itself does, and circles end", () => {
    expect(updatesInPlace(link("styles.css", true))).toBe(true);
    const a = link("a");
    const b = link("b");
    imports(a, b);
    imports(b, a);
    expect(updatesInPlace(a)).toBe(true);
  });
});
