import * as THREE from "three";
import { OrbitControls } from "three/addons/controls/OrbitControls.js";
import { EffectComposer } from "three/addons/postprocessing/EffectComposer.js";
import { OutputPass } from "three/addons/postprocessing/OutputPass.js";
import { RenderPass } from "three/addons/postprocessing/RenderPass.js";
import { UnrealBloomPass } from "three/addons/postprocessing/UnrealBloomPass.js";
import { attach } from "../src/index.ts";

/**
 * A game drawn the way many are: the world through post-processing, a map in the corner from a camera of its
 * own, a small picture of the world on a screen in it, and a HUD as a scene of its own on top. Nobody tells
 * the tool which of all those is the world: it has to see that for itself.
 */
const params = new URLSearchParams(location.search);
const plain = params.has("plain");
const renderer = new THREE.WebGLRenderer({ antialias: true });
renderer.setPixelRatio(1);
renderer.setSize(innerWidth, innerHeight);
renderer.autoClear = false;
document.body.prepend(renderer.domElement);

const scene = new THREE.Scene();
scene.background = new THREE.Color("#16202e");
const camera = new THREE.PerspectiveCamera(55, innerWidth / innerHeight, 0.1, 400);
camera.position.set(0, 7, 16);
camera.name = "The world's camera";
const controls = new OrbitControls(camera, renderer.domElement);
controls.target.set(0, 1, 0);
controls.enableDamping = true;
scene.add(new THREE.HemisphereLight("#cfe4ff", "#28303c", 2));
const sun = new THREE.DirectionalLight("#fff2dd", 2);
sun.position.set(4, 9, 3);
scene.add(sun);

const floor = new THREE.Mesh(new THREE.BoxGeometry(40, 0.4, 40), new THREE.MeshStandardMaterial({ color: "#3a4a5e" }));
floor.position.y = -0.2;
floor.name = "Floor";
scene.add(floor);
const thing = (name: string, color: string, x: number, z: number, geometry: THREE.BufferGeometry) => {
  const mesh = new THREE.Mesh(geometry, new THREE.MeshStandardMaterial({ color, emissive: color, emissiveIntensity: 0.25 }));
  mesh.position.set(x, 1.2, z);
  mesh.name = name;
  scene.add(mesh);
  return mesh;
};
const red = thing("Red crate", "#e0483e", -5, 0, new THREE.BoxGeometry(2.4, 2.4, 2.4));
const ball = thing("Green ball", "#3ecf7a", 0, -2, new THREE.SphereGeometry(1.5, 32, 20));
const tower = thing("Blue tower", "#4a8df0", 5, 1, new THREE.CylinderGeometry(1, 1.4, 4, 24));

// A screen in the world showing it from elsewhere: a render of its own, every frame.
const lookout = new THREE.PerspectiveCamera(60, 16 / 9, 0.1, 100);
lookout.position.set(-14, 9, -14);
lookout.lookAt(0, 0, 0);
lookout.name = "A camera on the wall";
const onWall = new THREE.WebGLRenderTarget(640, 360);
const wall = new THREE.Mesh(new THREE.PlaneGeometry(8, 4.5), new THREE.MeshBasicMaterial({ map: onWall.texture }));
wall.position.set(0, 3.2, -8);
wall.name = "Wall screen";
scene.add(wall);

// The map: straight down, in a corner of the canvas.
const map = new THREE.OrthographicCamera(-22, 22, 22, -22, 0.1, 100);
map.position.set(0, 40, 0);
map.lookAt(0, 0, 0);
map.name = "The map's camera";

// A HUD: a scene of its own over everything.
const hud = new THREE.Scene();
hud.name = "HUD";
const hudCamera = new THREE.OrthographicCamera(0, innerWidth, innerHeight, 0, -1, 1);
hudCamera.name = "The HUD's camera";
const bar = new THREE.Mesh(new THREE.PlaneGeometry(260, 22), new THREE.MeshBasicMaterial({ color: "#ffd24a" }));
bar.position.set(150, 40, 0);
bar.name = "Health bar";
hud.add(bar);

const composer = new EffectComposer(renderer);
composer.addPass(new RenderPass(scene, camera));
composer.addPass(new UnrealBloomPass(new THREE.Vector2(innerWidth, innerHeight), 0.35, 0.6, 0.75));
composer.addPass(new OutputPass());

const clock = new THREE.Clock();
renderer.setAnimationLoop(() => {
  const time = clock.getElapsedTime();
  ball.position.y = 1.5 + Math.abs(Math.sin(time * 1.4)) * 1.2;
  tower.rotation.y = time * 0.4;
  red.rotation.y = time * 0.15;
  controls.update();
  if (plain) {
    renderer.clear();
    renderer.render(scene, camera);
    return;
  }
  // The wall's picture, before anything else.
  wall.visible = false;
  renderer.setRenderTarget(onWall);
  renderer.clear();
  renderer.render(scene, lookout);
  renderer.setRenderTarget(null);
  wall.visible = true;
  // The world, through its passes.
  renderer.clear();
  composer.render();
  // The map in its corner.
  renderer.clearDepth();
  renderer.setScissorTest(true);
  renderer.setViewport(innerWidth - 230, innerHeight - 230, 210, 210);
  renderer.setScissor(innerWidth - 230, innerHeight - 230, 210, 210);
  renderer.render(scene, map);
  renderer.setScissorTest(false);
  renderer.setViewport(0, 0, innerWidth, innerHeight);
  // The HUD on top.
  renderer.clearDepth();
  renderer.render(hud, hudCamera);
});

Object.assign(window, { __game: { scene, camera, renderer, composer, map, hud, hudCamera, lookout, red, ball, tower, THREE } });
Object.assign(window, { __ds3d: attach({ renderer, project: { id: "demo", title: "Drawspeak 3D: several passes" } }) });
