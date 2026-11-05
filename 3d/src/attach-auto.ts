import type * as THREE from "three";
import { Drawspeak3D } from "./tool.ts";

/**
 * Drawspeak over any three.js page, with no change to its code. three.js announces every renderer it
 * creates to window.__THREE_DEVTOOLS__ when that exists, so this file has to load before the page's
 * own scripts:
 *
 *   <script src="http://127.0.0.1:8799/attach.js" data-project="my-project"></script>
 *
 * The page's origin must be listed for that project in hub/projects.json. Things are named from the
 * scene graph: object.name, or object.userData.drawspeak = { label, kind, source, data }.
 */
declare global {
  interface Window {
    __THREE_DEVTOOLS__?: EventTarget;
    __ds3d?: Drawspeak3D;
    /** For a page that has already made its renderer: Drawspeak3D.attachTo(renderer). */
    Drawspeak3D?: unknown;
  }
}

const script = document.currentScript as HTMLScriptElement | null;
const projectId = script?.dataset.project ?? location.hostname.replace(/[^A-Za-z0-9_-]/g, "-");
const hub = script ? new URL(script.src).origin : "http://127.0.0.1:8799";

export function attachTo(renderer: THREE.WebGLRenderer): Drawspeak3D {
  window.__ds3d?.destroy();
  const tool = new Drawspeak3D({ renderer, project: { id: projectId, title: document.title || projectId }, hub });
  window.__ds3d = tool;
  return tool;
}

const devtools = (window.__THREE_DEVTOOLS__ ??= new EventTarget());
devtools.addEventListener("observe", (event) => {
  const object = (event as CustomEvent).detail as { isWebGLRenderer?: boolean; domElement?: HTMLCanvasElement } | undefined;
  // A page may make small renderers for thumbnails: the one that goes on screen is the one to draw on.
  if (object?.isWebGLRenderer !== true || window.__ds3d) return;
  const renderer = object as unknown as THREE.WebGLRenderer;
  const wait = () => {
    if (renderer.domElement.isConnected) attachTo(renderer);
    else setTimeout(wait, 200);
  };
  wait();
});
