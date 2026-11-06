import * as THREE from "three";
import type { Pose } from "../core/types.ts";
import { poseOf } from "./world.ts";

/** One render in a frame. */
interface Pass {
  scene: THREE.Scene;
  camera: THREE.PerspectiveCamera;
  area: number;
}

/**
 * The tie to the app's renderer. It wraps renderer.render, so marks are placed with the very camera
 * of the frame being drawn (no swimming behind the world), and adds nothing to the app's scene: marks
 * are drawn over the canvas in screen space, at any size, with no shaders to compile.
 *
 * It can also look from another camera (a saved view) without touching the app's own: the override is
 * put on for the render and taken off after it.
 */
export class Host {
  readonly renderer: THREE.WebGLRenderer;
  scene?: THREE.Scene;
  camera?: THREE.PerspectiveCamera;
  /** A copy of what is on screen now, whoever's camera it came from. */
  readonly shown = new THREE.PerspectiveCamera();
  onFrame: () => void = () => {};
  private readonly realRender: THREE.WebGLRenderer["render"];
  private readonly fixedCamera?: THREE.PerspectiveCamera;
  private view?: { pose: Pose; from?: Pose; start: number; duration: number; leaving: boolean };
  private seenFrame = false;
  private reportedError = false;
  private startPose?: Pose;
  /** A copy of the last frame covers the canvas, so the world needn't be drawn: all the time goes to the pen. */
  resting = false;
  private rendering = false;
  /** What is drawn in a frame, and which of it was the world in the last one. */
  private passes: Pass[] = [];
  private passesFrame: number | undefined;
  private world?: Pass;
  private readonly sizes = new WeakMap<THREE.Scene, { count: number; at: number }>();
  private readonly viewport = new THREE.Vector4();

  constructor(renderer: THREE.WebGLRenderer, options: { scene?: THREE.Scene; camera?: THREE.PerspectiveCamera } = {}) {
    this.renderer = renderer;
    this.scene = options.scene;
    this.camera = options.camera;
    this.fixedCamera = options.camera;
    this.realRender = renderer.render;
    renderer.render = (scene, camera) => this.render(scene as THREE.Scene, camera as THREE.PerspectiveCamera);
  }

  /** Whether a frame has been drawn yet, and there is a camera to work with. */
  get ready(): boolean {
    return this.seenFrame;
  }

  destroy() {
    this.renderer.render = this.realRender;
  }

  private render(scene: THREE.Scene, camera: THREE.PerspectiveCamera) {
    // The world's own camera, of either kind: not a mirror's pass inside this one, nor a post-processing quad.
    const isMain = !this.rendering && (this.fixedCamera ? camera === this.fixedCamera : scene.isScene === true && (camera.isPerspectiveCamera === true || (camera as unknown as THREE.OrthographicCamera).isOrthographicCamera === true) && this.isWorld(scene, camera));
    if (!isMain) {
      this.realRender.call(this.renderer, scene, camera);
      return;
    }
    this.rendering = true;
    try {
      this.renderMain(scene, camera);
    } finally {
      this.rendering = false;
    }
  }

  /**
   * Is this render the world, among all a game may draw in a frame: a map in a corner, a screen on a wall, a HUD
   * as a scene of its own? Each frame is judged by the one before: nothing flickers between them.
   */
  private isWorld(scene: THREE.Scene, camera: THREE.PerspectiveCamera): boolean {
    const frame = typeof document === "undefined" ? undefined : (document.timeline?.currentTime as number | null | undefined);
    if (frame === undefined || frame === null || frame !== this.passesFrame) {
      this.passesFrame = frame ?? undefined;
      if (this.passes.length > 0) this.world = this.biggest(this.passes);
      this.passes = [];
    }
    const pass = { scene, camera, area: this.areaNow() };
    this.passes.push(pass);
    this.world ??= pass;
    return this.world.scene === scene && this.world.camera === camera;
  }

  private areaNow(): number {
    const renderer = this.renderer;
    if (!renderer.getCurrentViewport) return 1;
    const { z, w } = renderer.getCurrentViewport(this.viewport);
    return z * w;
  }

  /** The biggest on the canvas, in perspective if it can be, with the most in it; the last, if they're alike: a mirror comes before what it shows in. */
  private biggest(passes: Pass[]): Pass {
    if (passes.length === 1) return passes[0];
    let best = passes[0];
    let bestScore = -1;
    for (const pass of passes) {
      const score = pass.area * (pass.camera.isPerspectiveCamera ? 4 : 1) * (1 + Math.min(this.sizeOf(pass.scene), 2000) / 2000);
      if (score >= bestScore) {
        best = pass;
        bestScore = score;
      }
    }
    return best;
  }

  /** How many things are in a scene, looked at now and then. */
  private sizeOf(scene: THREE.Scene): number {
    const now = performance.now();
    let known = this.sizes.get(scene);
    if (!known || now - known.at > 2000) {
      let count = 0;
      scene.traverse(() => {
        count++;
      });
      known = { count, at: now };
      this.sizes.set(scene, known);
    }
    return known.count;
  }

  /** Draws on the canvas itself, all of it, whatever pass the game was in, and leaves things as they were. */
  private onCanvas(draw: () => void) {
    const renderer = this.renderer;
    const target = renderer.getRenderTarget();
    const autoClear = renderer.autoClear;
    const viewport = renderer.getViewport(new THREE.Vector4());
    const scissor = renderer.getScissor(new THREE.Vector4());
    const scissorTest = renderer.getScissorTest();
    const size = renderer.getSize(new THREE.Vector2());
    renderer.setRenderTarget(null);
    renderer.autoClear = true;
    renderer.setViewport(0, 0, size.x, size.y);
    renderer.setScissorTest(false);
    try {
      draw();
    } finally {
      renderer.setViewport(viewport);
      renderer.setScissor(scissor);
      renderer.setScissorTest(scissorTest);
      renderer.autoClear = autoClear;
      renderer.setRenderTarget(target);
    }
  }

  private drawWorldNow(scene: THREE.Scene, camera: THREE.PerspectiveCamera) {
    const inFrame = this.rendering;
    this.rendering = true;
    try {
      this.renderMain(scene, camera);
    } finally {
      this.rendering = inFrame;
    }
  }

  private renderMain(scene: THREE.Scene, camera: THREE.PerspectiveCamera) {
    if (this.resting) {
      this.onFrame();
      return;
    }
    this.scene = scene;
    this.camera = camera;
    if (this.startPose) {
      setPose(camera, this.startPose);
      camera.updateMatrixWorld();
      this.startPose = undefined;
    }
    // The app's own camera is lent for this frame, and comes back as it was.
    const saved = this.view ? { position: camera.position.clone(), quaternion: camera.quaternion.clone(), fov: camera.fov } : undefined;
    if (this.view) this.applyView(camera);
    this.realRender.call(this.renderer, scene, camera);
    this.seenFrame = true;
    // The camera as a world-space one, wherever it hangs in the scene.
    this.shown.copy(camera, false);
    camera.matrixWorld.decompose(this.shown.position, this.shown.quaternion, this.shown.scale);
    this.shown.matrix.copy(camera.matrixWorld);
    this.shown.matrixWorld.copy(camera.matrixWorld);
    this.shown.matrixWorldInverse.copy(camera.matrixWorld).invert();
    // A dev tool must never stop the game it sits on.
    try {
      this.onFrame();
    } catch (error) {
      if (!this.reportedError) console.error("[drawspeak3d]", error);
      this.reportedError = true;
    }
    if (saved) {
      camera.position.copy(saved.position);
      camera.quaternion.copy(saved.quaternion);
      if (camera.fov !== saved.fov) {
        camera.fov = saved.fov;
        camera.updateProjectionMatrix();
      }
      camera.updateMatrixWorld();
    }
  }

  /** The view on screen now, to come back to after a reload. */
  get shownPose(): Pose {
    return poseOf(this.shown);
  }

  /** Puts the page's own camera there once, on the next frame. A page that drives its camera just goes on. */
  startFrom(pose: Pose) {
    this.startPose = pose;
  }

  /** Looks from a saved view, gliding there. Null lets go of it, gliding back. */
  setView(pose: Pose | null, duration = 550) {
    if (pose === null) {
      if (this.view && !this.view.leaving) {
        this.view = { pose: this.view.pose, from: poseOf(this.shown), start: performance.now(), duration: Math.min(duration, 350), leaving: true };
      }
      return;
    }
    this.view = { pose, from: this.seenFrame ? poseOf(this.shown) : undefined, start: performance.now(), duration, leaving: false };
  }

  get lookingFromView(): boolean {
    return this.view !== undefined && !this.view.leaving;
  }

  private applyView(camera: THREE.PerspectiveCamera) {
    const view = this.view!;
    const t = view.duration > 0 ? Math.min(1, (performance.now() - view.start) / view.duration) : 1;
    const k = t * t * (3 - 2 * t);
    if (view.leaving) {
      if (t >= 1) {
        this.view = undefined;
        return;
      }
      setPose(camera, blend(view.from!, worldPoseOf(camera), k));
    } else {
      setPose(camera, view.from && t < 1 ? blend(view.from, view.pose, k) : view.pose);
    }
    camera.updateMatrixWorld();
  }

  /** Draws a frame now and copies it, while the drawing buffer still holds it. */
  captureFrame(): HTMLCanvasElement | undefined {
    if (!this.scene || !this.camera) return undefined;
    const { scene, camera } = this;
    const canvas = document.createElement("canvas");
    this.onCanvas(() => {
      this.drawWorldNow(scene, camera);
      const gl = this.renderer.domElement;
      canvas.width = gl.width;
      canvas.height = gl.height;
      canvas.getContext("2d")!.drawImage(gl, 0, 0);
    });
    return canvas;
  }

  /**
   * Draws a frame from another view and copies it, unseen: the usual frame is drawn again before the
   * page is painted, and nobody's camera moves.
   */
  captureFrom(pose: Pose): HTMLCanvasElement | undefined {
    const { scene, camera } = this;
    if (!scene || !camera) return undefined;
    const saved = { position: camera.position.clone(), quaternion: camera.quaternion.clone(), fov: camera.fov };
    setPose(camera, pose);
    camera.updateMatrixWorld();
    const canvas = document.createElement("canvas");
    this.onCanvas(() => {
      this.realRender.call(this.renderer, scene, camera);
      const gl = this.renderer.domElement;
      canvas.width = gl.width;
      canvas.height = gl.height;
      canvas.getContext("2d")!.drawImage(gl, 0, 0);
      camera.position.copy(saved.position);
      camera.quaternion.copy(saved.quaternion);
      if (camera.fov !== saved.fov) {
        camera.fov = saved.fov;
        camera.updateProjectionMatrix();
      }
      camera.updateMatrixWorld();
      this.drawWorldNow(scene, camera);
    });
    return canvas;
  }

  rect(): DOMRect {
    return this.renderer.domElement.getBoundingClientRect();
  }
}

const parentPosition = new THREE.Vector3();
const parentTurn = new THREE.Quaternion();
const parentScale = new THREE.Vector3();

/** A camera's place in the world, wherever it hangs in the scene. */
function worldPoseOf(camera: THREE.PerspectiveCamera): Pose {
  camera.updateWorldMatrix(true, false);
  const position = new THREE.Vector3();
  const turn = new THREE.Quaternion();
  camera.matrixWorld.decompose(position, turn, new THREE.Vector3());
  return { position: position.toArray(), quaternion: [turn.x, turn.y, turn.z, turn.w], fov: camera.fov, aspect: camera.aspect, near: camera.near, far: camera.far };
}

/** Puts a camera at a place in the world, wherever it hangs in the scene. */
export function setPose(camera: THREE.PerspectiveCamera, pose: Pose) {
  camera.position.set(pose.position[0], pose.position[1], pose.position[2]);
  camera.quaternion.set(pose.quaternion[0], pose.quaternion[1], pose.quaternion[2], pose.quaternion[3]);
  const parent = camera.parent;
  if (parent) {
    parent.updateWorldMatrix(true, false);
    parent.worldToLocal(camera.position);
    parent.matrixWorld.decompose(parentPosition, parentTurn, parentScale);
    camera.quaternion.premultiply(parentTurn.invert());
  }
  if (camera.isPerspectiveCamera && camera.fov !== pose.fov && pose.fov > 0) {
    camera.fov = pose.fov;
    camera.updateProjectionMatrix();
  }
}

const a = new THREE.Quaternion();
const b = new THREE.Quaternion();

function blend(from: Pose, to: Pose, k: number): Pose {
  a.set(from.quaternion[0], from.quaternion[1], from.quaternion[2], from.quaternion[3]);
  b.set(to.quaternion[0], to.quaternion[1], to.quaternion[2], to.quaternion[3]);
  a.slerp(b, k);
  const mix = (p: number, q: number) => p + (q - p) * k;
  return {
    position: [mix(from.position[0], to.position[0]), mix(from.position[1], to.position[1]), mix(from.position[2], to.position[2])],
    quaternion: [a.x, a.y, a.z, a.w],
    fov: mix(from.fov, to.fov),
    aspect: to.aspect,
    near: to.near,
    far: to.far,
  };
}
