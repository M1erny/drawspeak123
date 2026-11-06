import * as THREE from "three";
import type { Pose } from "../core/types.ts";
import { poseOf } from "./world.ts";

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
    const isMain = this.fixedCamera ? camera === this.fixedCamera : camera.isPerspectiveCamera === true;
    if (!isMain) {
      this.realRender.call(this.renderer, scene, camera);
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
    this.render(this.scene, this.camera);
    const gl = this.renderer.domElement;
    const canvas = document.createElement("canvas");
    canvas.width = gl.width;
    canvas.height = gl.height;
    canvas.getContext("2d")!.drawImage(gl, 0, 0);
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
    this.realRender.call(this.renderer, scene, camera);
    const gl = this.renderer.domElement;
    const canvas = document.createElement("canvas");
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
    this.render(scene, camera);
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
  if (camera.fov !== pose.fov) {
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
