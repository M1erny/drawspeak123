import type { RevisionInfo } from "./core/types.ts";

/**
 * The page's side of the hub (hub/server.ts), the small local program that keeps the batches and
 * runs the agent. Everything works without it except sending.
 */
export interface HubProject {
  id: string;
  title: string;
  folder: string;
  revision?: RevisionInfo;
  /** `problem`: why it cannot run right now, in words a person can act on. */
  agent: { id: string; label: string; available: boolean; problem?: string };
}

export interface RunState {
  id: string;
  batchId: string;
  status: "running" | "done" | "failed" | "stopped";
  agent: string;
  startedAt: string;
  endedAt?: string;
  /** What it is doing, latest last. */
  activity: string[];
  reply?: string;
  changed?: string[];
  error?: string;
  /** The notes this run was sent for. */
  noteIds?: string[];
  /** What it was asked, in a few words. */
  about?: string;
  /** Files another agent changed too, while both were at work. */
  shared?: string[];
}

/** An agent wants to see a view. */
export interface LookRequest {
  id: string;
  /** The view, as in a comment's link (ds3d_view). */
  view?: string;
}

export class HubClient {
  readonly url: string;
  readonly projectId: string;

  constructor(url: string, projectId: string) {
    this.url = url.replace(/\/$/, "");
    this.projectId = projectId;
  }

  private path(rest: string) {
    return `${this.url}/v1/projects/${encodeURIComponent(this.projectId)}${rest}`;
  }

  /** "busy": it did not answer in time, which says nothing about whether it is there. */
  async project(): Promise<HubProject | "busy" | undefined> {
    try {
      const response = await fetch(this.path(""), { signal: AbortSignal.timeout(8000) });
      return response.ok ? ((await response.json()) as HubProject) : undefined;
    } catch (error) {
      return error instanceof DOMException && error.name === "TimeoutError" ? "busy" : undefined;
    }
  }

  private async post<T>(rest: string, body: unknown): Promise<T> {
    const response = await fetch(this.path(rest), {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify(body),
    });
    const data = (await response.json().catch(() => ({}))) as T & { error?: string };
    if (!response.ok) throw new Error(data.error ?? `The hub said ${response.status}`);
    return data;
  }

  /** Saves a batch in the inbox. Sent or not, it stays there as a folder any agent can read. */
  saveBatch(batch: { batchId: string; message: string; manifest: unknown; files: Array<{ name: string; dataUrl: string }> }) {
    return this.post<{ batchId: string; folder: string; messageFile: string; look: string }>("/batches", batch);
  }

  send(batchId: string, options: { noteIds: string[]; newThread?: boolean }) {
    return this.post<RunState>(`/batches/${encodeURIComponent(batchId)}/send`, options);
  }

  /** Stops one agent. */
  stop(runId: string) {
    return this.post<{ stopped: boolean }>("/stop", { runId });
  }

  /** Answers an agent that asked to see a view. */
  answerLook(id: string, answer: { image: string; errors: string[] }) {
    return this.post<{ ok: boolean }>(`/look/${encodeURIComponent(id)}`, answer);
  }

  /** The runs as they change, and what agents ask to see; keeps trying. Returns the way to stop listening. */
  listen(on: { runs(runs: RunState[]): void; look(request: LookRequest): void }): () => void {
    let source: EventSource | undefined;
    let closed = false;
    const connect = () => {
      if (closed) return;
      source = new EventSource(`${this.path("/events")}?page=1`);
      source.addEventListener("runs", (e) => on.runs(JSON.parse((e as MessageEvent).data) as RunState[]));
      source.addEventListener("look", (e) => on.look(JSON.parse((e as MessageEvent).data) as LookRequest));
      source.onerror = () => {
        source?.close();
        setTimeout(connect, 5000);
      };
    };
    connect();
    return () => {
      closed = true;
      source?.close();
    };
  }
}
