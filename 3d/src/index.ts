import { Drawspeak3D, type AttachOptions } from "./tool.ts";

export { Drawspeak3D, parsePose, viewLink } from "./tool.ts";
export type { AttachOptions } from "./tool.ts";
export type { RayHit, SceneAdapter } from "./three/world.ts";
export type { Box, Note, Pose, SceneEntity, Snapshot, Vec3 } from "./core/types.ts";

/** Puts Drawspeak over a three.js app: walk, circle, speak, send. */
export function attach(options: AttachOptions): Drawspeak3D {
  return new Drawspeak3D(options);
}
