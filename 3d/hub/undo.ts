import { execFileSync } from "node:child_process";
import { createHash } from "node:crypto";
import { copyFileSync, existsSync, mkdirSync, readFileSync, rmSync, statSync } from "node:fs";
import { dirname, isAbsolute, join, relative, resolve } from "node:path";

/**
 * Taking an agent's change back, with one click. Before a run, what is already changed in the folder is
 * copied beside the batch, so that undoing brings back how it was, not the last commit. After a run, each file
 * it changed is fingerprinted, so that something changed since (by you, by another agent) is never overwritten.
 */
const LARGEST = 8 * 1024 * 1024;

const inside = (cwd: string, file: string): boolean => {
  const path = relative(cwd, resolve(cwd, file));
  return path !== "" && !path.startsWith("..") && !isAbsolute(path);
};

const copyName = (file: string) => file.replace(/[\\/:]/g, "__");

export function keepBefore(cwd: string, folder: string, dirty: Iterable<string>): void {
  for (const file of dirty) {
    const from = join(cwd, file);
    try {
      if (!inside(cwd, file) || !existsSync(from) || !statSync(from).isFile() || statSync(from).size > LARGEST) continue;
      mkdirSync(join(folder, "before"), { recursive: true });
      copyFileSync(from, join(folder, "before", copyName(file)));
    } catch {
      // it just can't be taken back to that state
    }
  }
}

export function fingerprint(cwd: string, file: string): string {
  try {
    return createHash("sha1").update(readFileSync(join(cwd, file))).digest("hex");
  } catch {
    return "gone";
  }
}

export interface UndoAnswer {
  undone: string[];
  /** Changed since, or impossible to bring back: left as they are. */
  left: string[];
}

export function undoFiles(cwd: string, folder: string, changed: string[], dirtyBefore: Iterable<string>, after: Record<string, string>): UndoAnswer {
  const dirty = new Set(dirtyBefore);
  const answer: UndoAnswer = { undone: [], left: [] };
  const git = (...args: string[]) => execFileSync("git", ["-C", cwd, ...args], { encoding: "utf8", stdio: ["ignore", "pipe", "ignore"], windowsHide: true });
  for (const file of changed) {
    if (!inside(cwd, file) || fingerprint(cwd, file) !== after[file]) {
      answer.left.push(file);
      continue;
    }
    try {
      const copy = join(folder, "before", copyName(file));
      if (dirty.has(file) && existsSync(copy)) {
        mkdirSync(dirname(join(cwd, file)), { recursive: true });
        copyFileSync(copy, join(cwd, file));
      } else if (dirty.has(file)) {
        // It was changed before the run, and too big to keep a copy of, or gone.
        answer.left.push(file);
        continue;
      } else {
        let tracked = true;
        try {
          git("ls-files", "--error-unmatch", "--", file);
        } catch {
          tracked = false;
        }
        if (tracked) git("checkout", "HEAD", "--", file);
        else rmSync(join(cwd, file), { force: true });
      }
      answer.undone.push(file);
    } catch {
      answer.left.push(file);
    }
  }
  return answer;
}
