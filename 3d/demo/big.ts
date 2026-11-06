import * as THREE from "three";
import { OrbitControls } from "three/addons/controls/OrbitControls.js";
import { attach } from "../src/index.ts";

/**
 * A big world, to see what the tool costs in one: a million-triangle terrain, thousands of separate
 * buildings, a hundred thousand instanced trees and things that move. ?nodraw leaves the tool out, for
 * comparing, and ?scale=100 builds it all a hundred times bigger, as a game in centimetres would be.
 */
const params = new URLSearchParams(location.search);
const scale = Number(params.get("scale") ?? 1);
const scene = new THREE.Scene();
scene.background = new THREE.Color("#cfe0ee");
scene.fog = new THREE.Fog("#cfe0ee", 300 * scale, 1200 * scale);
const camera = params.has("ortho")
  ? new THREE.OrthographicCamera((-90 * innerWidth) / innerHeight * scale, (90 * innerWidth) / innerHeight * scale, 90 * scale, -90 * scale, 0.1 * scale, 3000 * scale)
  : new THREE.PerspectiveCamera(55, innerWidth / innerHeight, 0.5 * scale, 3000 * scale);
camera.position.set(0, 60 * scale, 150 * scale);
const renderer = new THREE.WebGLRenderer({ antialias: true });
renderer.setPixelRatio(1);
renderer.setSize(innerWidth, innerHeight);
document.body.prepend(renderer.domElement);
scene.add(new THREE.HemisphereLight("#ffffff", "#7a8a6a", 1.6));
const sun = new THREE.DirectionalLight("#fff4e0", 2);
sun.position.set(1, 2, 1);
scene.add(sun);
const controls = new OrbitControls(camera, renderer.domElement);
controls.target.set(0, 0, 0);
controls.enableDamping = true;

const height = (x: number, z: number) => 6 * scale * Math.sin(x / (40 * scale)) * Math.cos(z / (55 * scale)) + 2 * scale * Math.sin(x / (9 * scale) + z / (13 * scale));

// A terrain of about a million triangles.
const terrainGeometry = new THREE.PlaneGeometry(1200 * scale, 1200 * scale, 700, 700).rotateX(-Math.PI / 2);
const positions = terrainGeometry.attributes.position;
for (let i = 0; i < positions.count; i++) positions.setY(i, height(positions.getX(i), positions.getZ(i)));
terrainGeometry.computeVertexNormals();
const terrain = new THREE.Mesh(terrainGeometry, new THREE.MeshLambertMaterial({ color: "#8fae74" }));
terrain.name = "Terrain";
scene.add(terrain);

// Three thousand buildings, each its own mesh and its own group of parts.
const palette = ["#c9b8a3", "#a9b4c2", "#d6c9b0", "#b7a79a", "#9fb0a8"].map((color) => new THREE.MeshLambertMaterial({ color }));
const roof = new THREE.MeshLambertMaterial({ color: "#6d4c41" });
const walls = new THREE.BoxGeometry(1, 1, 1);
const top = new THREE.ConeGeometry(0.75, 0.5, 4);
const city = new THREE.Group();
city.name = "City";
scene.add(city);
for (let i = 0; i < 3000; i++) {
  const row = Math.floor(i / 60);
  const x = ((i % 60) - 30) * 9 * scale;
  const z = (row - 25) * 9 * scale;
  const h = (4 + ((i * 7919) % 17)) * scale;
  const house = new THREE.Group();
  house.name = `Building ${i + 1}`;
  const body = new THREE.Mesh(walls, palette[i % palette.length]);
  body.scale.set(6 * scale, h, 6 * scale);
  body.position.y = h / 2;
  const cap = new THREE.Mesh(top, roof);
  cap.scale.set(6 * scale, 6 * scale, 6 * scale);
  cap.position.y = h + 1.5 * scale;
  cap.rotation.y = Math.PI / 4;
  house.add(body, cap);
  house.position.set(x, height(x, z), z);
  city.add(house);
}

// A hundred thousand instanced trees.
const trees = new THREE.InstancedMesh(new THREE.ConeGeometry(1.4, 5, 7).translate(0, 2.5, 0), new THREE.MeshLambertMaterial({ color: "#3f7a48" }), 100_000);
trees.name = "Trees";
const matrix = new THREE.Matrix4();
for (let i = 0; i < trees.count; i++) {
  const x = (Math.sin(i * 12.9898) * 43758.5453) % 1;
  const z = (Math.sin(i * 78.233) * 12543.123) % 1;
  const px = x * 590 * scale;
  const pz = z * 590 * scale;
  const s = (0.7 + Math.abs(x * z)) * scale;
  matrix.makeScale(s, s, s).setPosition(px, height(px, pz), pz);
  trees.setMatrixAt(i, matrix);
}
scene.add(trees);

// Things that move, each frame.
const movers: THREE.Mesh[] = [];
const moverGeometry = new THREE.BoxGeometry(2.4 * scale, 1.4 * scale, 4.4 * scale);
const moverMaterial = new THREE.MeshLambertMaterial({ color: "#c0392b" });
for (let i = 0; i < 300; i++) {
  const car = new THREE.Mesh(moverGeometry, moverMaterial);
  car.name = `Car ${i + 1}`;
  movers.push(car);
  scene.add(car);
}

const clock = new THREE.Clock();
renderer.setAnimationLoop(() => {
  const time = clock.getElapsedTime();
  movers.forEach((car, i) => {
    const x = (((time * 12 + i * 31) % 500) - 250) * scale;
    const z = ((i % 50) - 25) * 9 * scale + 4.5 * scale;
    car.position.set(x, height(x, z) + 1 * scale, z);
    car.rotation.y = Math.PI / 2;
  });
  controls.update();
  renderer.render(scene, camera);
});

addEventListener("resize", () => {
  if ((camera as THREE.PerspectiveCamera).isPerspectiveCamera) (camera as THREE.PerspectiveCamera).aspect = innerWidth / innerHeight;
  camera.updateProjectionMatrix();
  renderer.setSize(innerWidth, innerHeight);
});

Object.assign(window, { __big: { scene, camera, renderer, controls, THREE, scale } });
if (!params.has("nodraw")) {
  Object.assign(window, { __ds3d: attach({ renderer, scene, camera: camera as THREE.PerspectiveCamera, project: { id: "demo", title: "Drawspeak 3D big world" } }) });
}
