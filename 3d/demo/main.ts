import * as THREE from "three";
import { OrbitControls } from "three/addons/controls/OrbitControls.js";
import { attach } from "../src/index.ts";

/**
 * A small room to try Drawspeak 3D in, with no game around it: drag to look around, hold C and circle
 * something, say what should change. Things are named from the scene graph, with no adapter at all,
 * so this is also what any three.js app gets for free.
 */
const renderer = new THREE.WebGLRenderer({ antialias: true });
renderer.setPixelRatio(Math.min(devicePixelRatio, 2));
renderer.setSize(innerWidth, innerHeight);
renderer.shadowMap.enabled = true;
document.body.append(renderer.domElement);

const scene = new THREE.Scene();
scene.background = new THREE.Color("#e9e4da");
scene.fog = new THREE.Fog("#e9e4da", 16, 38);

const camera = new THREE.PerspectiveCamera(52, innerWidth / innerHeight, 0.1, 100);
camera.position.set(0, 3.4, 8.5);
const controls = new OrbitControls(camera, renderer.domElement);
controls.target.set(0, 1.2, 0);
controls.enableDamping = true;
controls.maxPolarAngle = Math.PI * 0.49;
controls.update();

scene.add(new THREE.HemisphereLight("#fff8ee", "#b9a98f", 1.6));
const sun = new THREE.DirectionalLight("#fff3df", 2.2);
sun.position.set(5, 9, 6);
sun.castShadow = true;
sun.shadow.mapSize.set(2048, 2048);
Object.assign(sun.shadow.camera, { left: -10, right: 10, top: 10, bottom: -10 });
scene.add(sun);

const material = (color: string, roughness = 0.65) => new THREE.MeshStandardMaterial({ color, roughness });
function mesh(name: string, geometry: THREE.BufferGeometry, color: string, position: [number, number, number], parent: THREE.Object3D = scene) {
  const m = new THREE.Mesh(geometry, material(color));
  m.name = name;
  m.position.set(...position);
  m.castShadow = m.receiveShadow = true;
  parent.add(m);
  return m;
}

const floor = mesh("Floor", new THREE.PlaneGeometry(60, 60), "#d9d0bf", [0, 0, 0]);
floor.rotation.x = -Math.PI / 2;
mesh("Back wall", new THREE.BoxGeometry(24, 7, 0.3), "#efe9dc", [0, 3.5, -5]);

// A shelf of jars: one group, its parts named, an instanced row on it.
const shelf = new THREE.Group();
shelf.name = "Shelf";
shelf.position.set(-3.4, 0, -3.2);
scene.add(shelf);
mesh("Lower board", new THREE.BoxGeometry(4.4, 0.12, 1), "#a97c50", [0, 0.9, 0], shelf);
mesh("Upper board", new THREE.BoxGeometry(4.4, 0.12, 1), "#a97c50", [0, 2.1, 0], shelf);
mesh("Left post", new THREE.BoxGeometry(0.14, 3, 1), "#8c6541", [-2.15, 1.5, 0], shelf);
mesh("Right post", new THREE.BoxGeometry(0.14, 3, 1), "#8c6541", [2.15, 1.5, 0], shelf);
const jars = new THREE.InstancedMesh(new THREE.CylinderGeometry(0.22, 0.22, 0.6, 24), material("#ffffff", 0.3), 12);
jars.name = "Jars";
jars.castShadow = true;
const colors = ["#e4573d", "#f2b632", "#3fa66b", "#3b82c4", "#8e5bb5", "#e78ab0"];
const place = new THREE.Matrix4();
for (let i = 0; i < 12; i++) {
  const row = i < 6 ? 0 : 1;
  place.setPosition(-1.75 + (i % 6) * 0.7, row === 0 ? 1.27 : 2.47, 0);
  jars.setMatrixAt(i, place);
  jars.setColorAt(i, new THREE.Color(colors[i % colors.length]));
}
shelf.add(jars);

// A table with things on it; each says what it is for the agent.
const table = new THREE.Group();
table.name = "Table";
table.position.set(2.2, 0, -0.6);
scene.add(table);
mesh("Table top", new THREE.BoxGeometry(3, 0.14, 1.6), "#c9a06f", [0, 1, 0], table);
for (const [x, z] of [[-1.35, -0.65], [1.35, -0.65], [-1.35, 0.65], [1.35, 0.65]]) mesh("Table leg", new THREE.BoxGeometry(0.12, 1, 0.12), "#8c6541", [x, 0.5, z], table);
const teapot = mesh("Red box", new THREE.BoxGeometry(0.7, 0.7, 0.7), "#d9423b", [-0.8, 1.42, 0], table);
teapot.userData.drawspeak = { label: "Red box", kind: "prop", source: ["demo/main.ts"], data: { note: "the box on the table" } };
const ball = mesh("Blue ball", new THREE.SphereGeometry(0.36, 32, 24), "#2f6fd0", [0.7, 1.43, 0.1], table);
ball.userData.drawspeak = { label: "Blue ball", kind: "prop", source: ["demo/main.ts"] };

// A lamp that moves, so a stroke can be seen to stop the world.
const lamp = new THREE.Group();
lamp.name = "Lamp";
lamp.position.set(-0.6, 0, 1.6);
scene.add(lamp);
mesh("Lamp post", new THREE.CylinderGeometry(0.05, 0.05, 2.4, 12), "#3b3f46", [0, 1.2, 0], lamp);
mesh("Lamp foot", new THREE.CylinderGeometry(0.34, 0.38, 0.08, 24), "#3b3f46", [0, 0.04, 0], lamp);
const shade = mesh("Lamp shade", new THREE.ConeGeometry(0.46, 0.5, 32, 1, true), "#f4c95d", [0, 2.5, 0], lamp);
(shade.material as THREE.MeshStandardMaterial).side = THREE.DoubleSide;

addEventListener("resize", () => {
  camera.aspect = innerWidth / innerHeight;
  camera.updateProjectionMatrix();
  renderer.setSize(innerWidth, innerHeight);
});

// auto.html attaches from outside (attach.js), to show that an app need not know about the tool.
if (!document.title.includes("from outside")) {
  (window as unknown as Record<string, unknown>).__ds3d = attach({ renderer, scene, camera, project: { id: "demo", title: "Drawspeak 3D demo" } });
}
(window as unknown as Record<string, unknown>).__demo = { scene, camera, controls, teapot, ball, lamp, jars, shelf, table };

const clock = new THREE.Clock();
renderer.setAnimationLoop(() => {
  lamp.rotation.y = Math.sin(clock.getElapsedTime() * 0.7) * 0.4;
  controls.update();
  renderer.render(scene, camera);
});
