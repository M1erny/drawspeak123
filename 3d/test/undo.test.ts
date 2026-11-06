import { execFileSync } from "node:child_process";
import { existsSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { afterEach, describe, expect, it } from "vitest";
import { fingerprint, keepBefore, undoFiles } from "../hub/undo.ts";

const made: string[] = [];
const repo = () => {
  const cwd = mkdtempSync(join(tmpdir(), "ds3d-undo-"));
  const folder = mkdtempSync(join(tmpdir(), "ds3d-batch-"));
  made.push(cwd, folder);
  const git = (...args: string[]) => execFileSync("git", ["-C", cwd, ...args], { stdio: "ignore" });
  git("init", "-q");
  git("config", "user.email", "test@example.com");
  git("config", "user.name", "Test");
  git("config", "core.autocrlf", "false");
  writeFileSync(join(cwd, "clean.txt"), "as committed");
  writeFileSync(join(cwd, "dirty.txt"), "as committed");
  git("add", ".");
  git("commit", "-qm", "first");
  return { cwd, folder };
};
afterEach(() => {
  for (const path of made.splice(0)) rmSync(path, { recursive: true, force: true });
});

describe("taking an agent's change back", () => {
  it("brings each file back as it was before the run", () => {
    const { cwd, folder } = repo();
    // Someone was already working on this one.
    writeFileSync(join(cwd, "dirty.txt"), "my own work");
    keepBefore(cwd, folder, ["dirty.txt"]);
    // The agent's run.
    writeFileSync(join(cwd, "clean.txt"), "changed by the agent");
    writeFileSync(join(cwd, "dirty.txt"), "my own work, changed by the agent");
    writeFileSync(join(cwd, "new.txt"), "made by the agent");
    const changed = ["clean.txt", "dirty.txt", "new.txt"];
    const after = Object.fromEntries(changed.map((file) => [file, fingerprint(cwd, file)]));
    const answer = undoFiles(cwd, folder, changed, ["dirty.txt"], after);
    expect(answer).toEqual({ undone: changed, left: [] });
    expect(readFileSync(join(cwd, "clean.txt"), "utf8")).toBe("as committed");
    expect(readFileSync(join(cwd, "dirty.txt"), "utf8")).toBe("my own work");
    expect(existsSync(join(cwd, "new.txt"))).toBe(false);
  });

  it("leaves alone what has changed since", () => {
    const { cwd, folder } = repo();
    writeFileSync(join(cwd, "clean.txt"), "changed by the agent");
    const after = { "clean.txt": fingerprint(cwd, "clean.txt") };
    writeFileSync(join(cwd, "clean.txt"), "changed again, by someone else");
    expect(undoFiles(cwd, folder, ["clean.txt"], [], after)).toEqual({ undone: [], left: ["clean.txt"] });
    expect(readFileSync(join(cwd, "clean.txt"), "utf8")).toBe("changed again, by someone else");
  });

  it("never touches anything outside the folder", () => {
    const { cwd, folder } = repo();
    const outside = join(cwd, "..", `ds3d-outside-${Date.now()}.txt`);
    made.push(outside);
    writeFileSync(outside, "not yours");
    const name = `../${outside.split(/[\\/]/).pop()}`;
    expect(undoFiles(cwd, folder, [name], [], { [name]: fingerprint(cwd, name) }).left).toEqual([name]);
    expect(readFileSync(outside, "utf8")).toBe("not yours");
  });
});
