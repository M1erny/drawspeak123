// The demo room played with no adapter (run with swing-shop-web's scripts/drive.mjs):
//   node ../../swing-shop-web/scripts/drive.mjs demo/play.mjs --url http://localhost:5190/demo/ --size 1280x800 --out ../dist/demo-shots
// Checks what any three.js app gets for free: things named from the scene graph, parents, instances.
const FAKE_SPEECH = `(() => {
  class F { constructor() { window.__speech.current = this; } start() {} stop() { setTimeout(() => this.onend?.(), 20); } abort() {} }
  window.__speech = { say(text, isFinal) { window.__speech.current?.onresult?.({ results: [{ isFinal, 0: { transcript: text } }] }); } };
  window.SpeechRecognition = window.webkitSpeechRecognition = F;
  if (navigator.mediaDevices) navigator.mediaDevices.getUserMedia = () => Promise.reject(new Error("no microphone in tests"));
  return true;
})()`;

export default async function demo(play) {
  await play.until("!!window.__ds3d && window.__ds3d.host.ready", 40000, "the room");
  await play.evaluate(FAKE_SPEECH);
  await play.evaluate(`(window.__ds3d.voice.silenceAfterSpeechMs = window.__ds3d.voice.silenceWithoutSpeechMs = 120000, window.__ds3d.notes.slice().forEach((n) => window.__ds3d.deleteNote(n.id, false)), true)`);
  await play.sleep(1500);

  const rectOf = (expression) => play.evaluate(`(() => {
    const d = window.__demo;
    const box = ${expression};
    const V = box.min.constructor;
    const xs = [], ys = [];
    for (const x of [box.min.x, box.max.x]) for (const y of [box.min.y, box.max.y]) for (const z of [box.min.z, box.max.z]) {
      const v = new V(x, y, z).project(d.camera);
      xs.push(((v.x + 1) / 2) * innerWidth);
      ys.push(((1 - v.y) / 2) * innerHeight);
    }
    return { minX: Math.min(...xs), maxX: Math.max(...xs), minY: Math.min(...ys), maxY: Math.max(...ys) };
  })()`);
  const boxOf = (name) => `(() => { const o = d.${name}; o.geometry.computeBoundingBox(); return o.geometry.boundingBox.clone().applyMatrix4(o.matrixWorld); })()`;
  const stroke = async (pts) => {
    await play.cdp("Input.dispatchMouseEvent", { type: "mouseMoved", x: pts[0][0], y: pts[0][1] });
    await play.cdp("Input.dispatchMouseEvent", { type: "mousePressed", x: pts[0][0], y: pts[0][1], button: "left", buttons: 1, clickCount: 1 });
    for (const [x, y] of pts.slice(1)) await play.cdp("Input.dispatchMouseEvent", { type: "mouseMoved", x, y, button: "left", buttons: 1 });
    await play.cdp("Input.dispatchMouseEvent", { type: "mouseReleased", x: pts.at(-1)[0], y: pts.at(-1)[1], button: "left", clickCount: 1 });
  };
  const circleAround = (r, grow = 1.5) => {
    const cx = (r.minX + r.maxX) / 2;
    const cy = (r.minY + r.maxY) / 2;
    const rx = ((r.maxX - r.minX) / 2) * grow + 6;
    const ry = ((r.maxY - r.minY) / 2) * grow + 6;
    return Array.from({ length: 29 }, (_, i) => [cx + Math.cos((i / 28) * Math.PI * 2 - 1) * rx, cy + Math.sin((i / 28) * Math.PI * 2 - 1) * ry]);
  };
  const noteTarget = (i) => play.evaluate(`(() => { const n = window.__ds3d.notes[${i}]; const t = n.target; return t && { chain: t.layers[t.layer].map((e) => e.label), kinds: t.layers[t.layer].map((e) => e.kind), others: t.layers.slice(1).map((c) => c[0].label), depth: t.depth, partial: t.partial, members: t.members?.map((m) => m.label), locator: t.layers[t.layer][t.depth].locator, source: t.layers[t.layer][t.depth].source, data: t.layers[t.layer][t.depth].data, bounds: !!t.layers[t.layer][t.depth].bounds }; })()`);

  await play.shot("demo-1-room");
  await play.evaluate(`(window.__ds3d.setArmed(true), true)`);

  // The red box on the table: userData names it, the scene graph gives its parent.
  await stroke(circleAround(await rectOf(boxOf("teapot"))));
  await play.until("window.__ds3d.notes.length === 1", 15000, "the first mark");
  const box = await noteTarget(0);
  console.log("  (box)", JSON.stringify(box));
  play.check("the red box is the target, by its userData", box?.chain[0] === "Red box" && box.kinds[0] === "prop" && box.source?.[0] === "demo/main.ts", JSON.stringify(box));
  play.check("its parent comes from the scene graph", box?.chain.includes("Table"), JSON.stringify(box?.chain));
  await play.evaluate(`window.__speech.say("Make the red box twice as wide", true)`);
  await play.press("Enter");
  await play.until(`window.__ds3d.notes[0].text.includes("twice")`, 8000, "the words");
  await play.shot("demo-2-box");

  // One jar of an instanced row: an instance has its own name and box.
  const jar = await play.evaluate(`(() => {
    const d = window.__demo;
    const V = d.camera.position.constructor;
    const m = new d.scene.matrixWorld.constructor();
    d.jars.getMatrixAt(2, m);
    m.premultiply(d.jars.matrixWorld);
    const p = new V().setFromMatrixPosition(m);
    const out = [];
    for (const [dx, dy] of [[-0.24, -0.32], [0.24, -0.32], [-0.24, 0.32], [0.24, 0.32]]) {
      const v = new V(p.x + dx, p.y + dy, p.z).project(d.camera);
      out.push([((v.x + 1) / 2) * innerWidth, ((1 - v.y) / 2) * innerHeight]);
    }
    return out;
  })()`);
  const xs = jar.map((c) => c[0]);
  const ys = jar.map((c) => c[1]);
  await stroke(circleAround({ minX: Math.min(...xs), maxX: Math.max(...xs), minY: Math.min(...ys), maxY: Math.max(...ys) }, 1.3));
  await play.until("window.__ds3d.notes.length === 2", 15000, "the jar's mark");
  const oneJar = await noteTarget(1);
  console.log("  (jar)", JSON.stringify(oneJar));
  play.check("one instance of an instanced mesh is the target", oneJar?.chain[0] === "Jars#2", JSON.stringify(oneJar));
  play.check("it climbs to its mesh and the shelf", oneJar?.chain.includes("Jars") && oneJar?.chain.includes("Shelf"), JSON.stringify(oneJar?.chain));
  play.check("it has its own box", oneJar?.bounds === true);
  await play.evaluate(`window.__speech.say("This jar should be taller", true)`);
  await play.press("Enter");
  await play.until(`window.__ds3d.notes[1].text.includes("taller")`, 8000, "the words");

  // A patch of the wall has no whole thing in it.
  await stroke(Array.from({ length: 25 }, (_, i) => [760 + Math.cos((i / 24) * 6.283) * 70, 190 + Math.sin((i / 24) * 6.283) * 50]));
  await play.until("window.__ds3d.notes.length === 3", 15000, "the wall's mark");
  const wall = await noteTarget(2);
  console.log("  (wall)", JSON.stringify(wall));
  play.check("a patch of wall is part of the wall", wall?.partial === true && wall?.chain[0] === "Back wall", JSON.stringify(wall));
  await play.evaluate(`window.__speech.say("Paint this wall green", true)`);
  await play.press("Enter");
  await play.until(`window.__ds3d.notes[2].text.includes("green")`, 8000, "the words");

  // ---- places and routes: where a mark is in the world is as good as what it is on
  const screenOf = (x, y, z) => play.evaluate(`(() => { const v = new (window.__demo.camera.position.constructor)(${x}, ${y}, ${z}).project(window.__demo.camera); return [((v.x + 1) / 2) * innerWidth, ((1 - v.y) / 2) * innerHeight]; })()`);
  const line = (a, b, n = 16) => Array.from({ length: n + 1 }, (_, i) => [a[0] + ((b[0] - a[0]) * i) / n, a[1] + ((b[1] - a[1]) * i) / n]);
  const near = (a, b, tolerance) => Math.hypot(a[0] - b[0], a[1] - b[1], a[2] - b[2]) < tolerance;
  const noteAt = (i) => play.evaluate(`(() => { const n = window.__ds3d.notes[${i}]; return { kind: n.shape.kind, world: n.world, recording: n.recording, chain: n.target?.layers[n.target.layer].map((e) => e.label), partial: n.target?.partial, viewer: window.__ds3d.snapshotOf(n)?.viewer }; })()`);
  const say = async (i, text) => {
    await play.evaluate(`window.__speech.say(${JSON.stringify(text)}, true)`);
    await play.press("Enter");
    await play.until(`window.__ds3d.notes[${i}].text === ${JSON.stringify(text)}`, 8000, "the words");
    await play.evaluate(`(window.__ds3d.activate(undefined), true)`);
    await play.sleep(1000);
  };

  // A tap on the floor is a spot, right there.
  const spotAt = await screenOf(1, 0, 3);
  await play.click(spotAt[0], spotAt[1]);
  await play.until("window.__ds3d.notes.length === 4", 15000, "the spot");
  const spot = await noteAt(3);
  console.log("  (spot)", JSON.stringify(spot.world.place));
  play.check("a tap on the floor is a spot", spot.kind === "point", spot.kind);
  play.check("and it starts the voice", spot.recording === "recording");
  play.check("the spot is where it was tapped", near(spot.world.place.center, [1, 0, 3], 0.05), JSON.stringify(spot.world.place.center));
  play.check("it says what it lies on and what stands near", spot.world.place.on === "Floor" && spot.world.place.near.some((n) => n.label === "Lamp"), JSON.stringify(spot.world.place));
  play.check("what it lies on is not among what stands near", !spot.world.place.near.some((n) => n.label === "Floor"));
  play.check("its ring lies flat on the floor", spot.world.ink.length === 20 && spot.world.ink.every((p) => Math.abs(p[1]) < 1e-3));
  await play.shot("demo-2b-spot");
  await say(3, "Put a green cone here");

  // A line along the floor is a way to walk.
  await stroke(line(await screenOf(-3, 0, 3.4), await screenOf(3.2, 0, 3.4)));
  await play.until("window.__ds3d.notes.length === 5", 15000, "the route");
  const route = await noteAt(4);
  console.log("  (route)", JSON.stringify({ ...route.world.path, points: route.world.path?.points.length }));
  play.check("a line is a line, and it starts the voice", route.kind === "arrow" && route.recording === "recording", route.kind);
  play.check("it lies along the ground", route.world.path?.onGround === true && route.world.ink.every((p) => Math.abs(p[1]) < 1e-3));
  play.check("its ends are where they were drawn", near(route.world.path.from.at, [-3, 0, 3.4], 0.05) && near(route.world.path.to.at, [3.2, 0, 3.4], 0.05), JSON.stringify(route.world.path.to.at));
  play.check("it knows how long it is", Math.abs(route.world.path.length - 6.2) < 0.1, String(route.world.path.length));
  play.check("on a floor, not on things", route.world.path.from.isThing === false && route.world.path.to.isThing === false && route.partial === true);
  await play.shot("demo-2c-route");
  await say(4, "A robot walks along here");

  // A line starting on a thing moves it.
  const redBox = await rectOf(boxOf("teapot"));
  const moveTo = await screenOf(-1.2, 0, 2.6);
  await stroke(line([(redBox.minX + redBox.maxX) / 2, (redBox.minY + redBox.maxY) / 2], moveTo));
  await play.until("window.__ds3d.notes.length === 6", 15000, "the move");
  const move = await noteAt(5);
  console.log("  (move)", JSON.stringify({ ...move.world.path, points: move.world.path?.points.length }));
  play.check("a line from a thing starts on the thing", move.world.path?.from.isThing === true && move.world.path.from.label === "Red box", JSON.stringify(move.world.path?.from));
  play.check("and it is about that thing", move.chain?.[0] === "Red box" && move.partial === false, JSON.stringify(move.chain));
  play.check("it ends where it was drawn, on the floor", move.world.path.to.isThing === false && move.world.path.to.label === "Floor" && near(move.world.path.to.at, [-1.2, 0, 2.6], 0.05), JSON.stringify(move.world.path.to));
  play.check("its length is what it looks like, not by way of the ground behind the thing", move.world.path.length < 6, String(move.world.path.length));
  play.check("nothing calls the floor near the box", !move.world.path.from.near.some((n) => n.label === "Floor"));
  await play.shot("demo-2d-move");
  await say(5, "Move the red box here");

  // A tap on a thing is that thing, not a spot on it.
  const blue = await rectOf(boxOf("ball"));
  await play.click((blue.minX + blue.maxX) / 2, (blue.minY + blue.maxY) / 2);
  await play.until("window.__ds3d.notes.length === 7", 15000, "the tap");
  const tapped = await noteAt(6);
  play.check("a tap on a thing is that thing", tapped.kind === "component" && tapped.chain?.[0] === "Blue ball", JSON.stringify(tapped.chain));
  await say(6, "Make this ball smaller");

  // Talking about the whole view needs no mark, from the palette or with T.
  await play.evaluate(`document.querySelector(".ds3d-palette button[title^='Say something']").click()`);
  await play.until("window.__ds3d.notes.length === 8", 15000, "the comment on the view");
  const whole = await noteAt(7);
  play.check("a comment on the view has no ink and starts the voice", whole.kind === "view" && whole.world.ink.length === 0 && whole.recording === "recording", JSON.stringify(whole));
  await play.shot("demo-2e-view");
  await say(7, "The whole room feels empty");
  await play.press("KeyT");
  await play.until("window.__ds3d.notes.length === 9", 15000, "T");
  await play.evaluate(`(window.__ds3d.discard(window.__ds3d.notes[8]), window.__ds3d.setArmed(true), true)`);
  await play.until("window.__ds3d.notes.length === 8", 5000, "the empty comment gone");

  // The picture the agent gets shows them all.
  await play.evaluate(`window.__ds3d.showPicture(window.__ds3d.notes[4])`);
  await play.sleep(1500);
  await play.shot("demo-2f-picture");
  await play.press("Escape");

  // Orbit the camera: marks keep to their things. OrbitControls still gets the mouse when Draw is off.
  await play.evaluate(`(window.__ds3d.setArmed(false), true)`);
  const before = await play.evaluate(`window.__demo.camera.position.toArray()`);
  await play.drag(640, 680, 220, -60, 8);
  await play.sleep(3000);
  const after = await play.evaluate(`window.__demo.camera.position.toArray()`);
  play.check("with Draw off, the mouse goes to the app's own camera controls", Math.hypot(after[0] - before[0], after[2] - before[2]) > 0.5, `${before} -> ${after}`);
  const pin = await play.evaluate(`(() => { const r = document.querySelector(".ds3d-pin").getBoundingClientRect(); const a = window.__ds3d.notes[0].world.anchor; const v = new (window.__demo.camera.position.constructor)(a[0], a[1], a[2]).project(window.__ds3d.host.shown); return { pin: [r.x + r.width / 2, r.y + r.height / 2], want: [((v.x + 1) / 2) * innerWidth, ((1 - v.y) / 2) * innerHeight] }; })()`);
  play.check("pins follow the world", Math.hypot(pin.pin[0] - pin.want[0], pin.pin[1] - pin.want[1]) < 4, JSON.stringify(pin));
  await play.shot("demo-3-orbited");

  // Look from where it was marked: the view changes, the app's own camera does not.
  await play.evaluate(`(window.__demo.controls.enableDamping = false, true)`);
  await play.sleep(2500);
  const own = await play.evaluate(`window.__demo.camera.position.toArray()`);
  await play.evaluate(`(window.__ds3d.lookFrom(window.__ds3d.notes[0]), true)`);
  await play.sleep(3500);
  const shown = await play.evaluate(`window.__ds3d.host.shown.position.toArray()`);
  const pose = await play.evaluate(`window.__ds3d.snapshots[0].pose.position`);
  play.check("Look shows the saved camera", Math.hypot(shown[0] - pose[0], shown[1] - pose[1], shown[2] - pose[2]) < 0.02, `${shown} vs ${pose}`);
  const ownNow = await play.evaluate(`window.__demo.camera.position.toArray()`);
  play.check("and leaves the app's own camera alone", Math.hypot(ownNow[0] - own[0], ownNow[2] - own[2]) < 0.02, `${own} vs ${ownNow}`);
  await play.shot("demo-4-looked");
  await play.evaluate(`(window.__ds3d.host.setView(null), window.__ds3d.activate(undefined), true)`);
  await play.evaluate(`(window.__ds3d.notes.slice().forEach((n) => window.__ds3d.deleteNote(n.id, false)), true)`);
}
