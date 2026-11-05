import type { Note, Snapshot } from "./core/types.ts";

/**
 * Notes and pictures, kept in the browser. An agent's edit reloads the page with hot reload, and
 * nothing here may be lost to that, or to a closed tab: everything is written as it happens.
 */
const DB = "drawspeak3d";
const VERSION = 1;

function open(): Promise<IDBDatabase> {
  return new Promise((resolve, reject) => {
    const request = indexedDB.open(DB, VERSION);
    request.onupgradeneeded = () => {
      const db = request.result;
      db.createObjectStore("notes", { keyPath: "id" }).createIndex("project", "projectId");
      db.createObjectStore("snapshots", { keyPath: "id" }).createIndex("project", "projectId");
      db.createObjectStore("images");
    };
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error);
  });
}

const done = (tx: IDBTransaction) =>
  new Promise<void>((resolve, reject) => {
    tx.oncomplete = () => resolve();
    tx.onerror = tx.onabort = () => reject(tx.error);
  });

const asPromise = <T>(request: IDBRequest<T>) =>
  new Promise<T>((resolve, reject) => {
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error);
  });

export class Store {
  private readonly projectId: string;
  private db?: Promise<IDBDatabase>;

  constructor(projectId: string) {
    this.projectId = projectId;
  }

  private database(): Promise<IDBDatabase> {
    return (this.db ??= open());
  }

  async load(): Promise<{ notes: Note[]; snapshots: Snapshot[] }> {
    const db = await this.database();
    const tx = db.transaction(["notes", "snapshots"]);
    const notes = await asPromise(tx.objectStore("notes").index("project").getAll(this.projectId));
    const snapshots = await asPromise(tx.objectStore("snapshots").index("project").getAll(this.projectId));
    return { notes: notes as Note[], snapshots: snapshots as Snapshot[] };
  }

  async saveNote(note: Note) {
    const db = await this.database();
    const tx = db.transaction("notes", "readwrite");
    // A recording in flight does not survive a reload: stored notes never claim one.
    const { recording: _recording, ...stored } = note;
    tx.objectStore("notes").put({ ...stored, projectId: this.projectId });
    await done(tx);
  }

  async deleteNote(id: string) {
    const db = await this.database();
    const tx = db.transaction("notes", "readwrite");
    tx.objectStore("notes").delete(id);
    await done(tx);
  }

  async saveSnapshot(snapshot: Snapshot, image: Blob) {
    const db = await this.database();
    const tx = db.transaction(["snapshots", "images"], "readwrite");
    tx.objectStore("snapshots").put({ ...snapshot, projectId: this.projectId });
    tx.objectStore("images").put(image, snapshot.id);
    await done(tx);
  }

  async deleteSnapshot(id: string) {
    const db = await this.database();
    const tx = db.transaction(["snapshots", "images"], "readwrite");
    tx.objectStore("snapshots").delete(id);
    tx.objectStore("images").delete(id);
    await done(tx);
  }

  async image(id: string): Promise<Blob | undefined> {
    const db = await this.database();
    return asPromise(db.transaction("images").objectStore("images").get(id)) as Promise<Blob | undefined>;
  }
}
