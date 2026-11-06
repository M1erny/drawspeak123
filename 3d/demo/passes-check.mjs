// A game drawn in several passes, with nobody telling the tool which is the world. From 3d/:
// node ../../swing-shop-web/scripts/drive.mjs demo/passes-check.mjs --gpu --url "http://localhost:5190/demo/passes.html" --size 1600x900 --out <dir>
const FAKE_SPEECH = `(() => {
  class F { constructor() { window.__speech.current = this; } start() {} stop() { setTimeout(() => this.onend?.(), 20); } abort() {} }
  window.__speech = { say(text, isFinal) { window.__speech.current?.onresult?.({ results: [{ isFinal, 0: { transcript: text } }] }); } };
  window.SpeechRecognition = window.webkitSpeechRecognition = F;
  if (navigator.mediaDevices) navigator.mediaDevices.getUserMedia = () => Promise.reject(new Error("no microphone here"));
  return true;
})()`;

export default async function check(play) {
  const g = (expr) => play.evaluate(`(() => { const G = window.__game; const t = window.__ds3d; return ${expr}; })()`);
  const tap = async (x, y) => {
    await play.cdp("Input.dispatchMouseEvent", { type: "mouseMoved", x, y });
    await play.cdp("Input.dispatchMouseEvent", { type: "mousePressed", x, y, button: "left", buttons: 1, clickCount: 1 });
    await play.cdp("Input.dispatchMouseEvent", { type: "mouseReleased", x, y, button: "left", clickCount: 1 });
  };
  const stroke = async (points) => {
    const [first, ...rest] = points;
    await play.cdp("Input.dispatchMouseEvent", { type: "mouseMoved", x: first[0], y: first[1] });
    await play.cdp("Input.dispatchMouseEvent", { type: "mousePressed", x: first[0], y: first[1], button: "left", buttons: 1, clickCount: 1 });
    for (const [x, y] of rest) {
      await play.cdp("Input.dispatchMouseEvent", { type: "mouseMoved", x, y, button: "left", buttons: 1 });
      await play.sleep(8);
    }
    const last = points[points.length - 1];
    await play.cdp("Input.dispatchMouseEvent", { type: "mouseReleased", x: last[0], y: last[1], button: "left", clickCount: 1 });
  };
  const circle = (cx, cy, rx, ry = rx, n = 26) => Array.from({ length: n + 1 }, (_, i) => [cx + Math.cos((i / n) * Math.PI * 2 - 1.2) * rx, cy + Math.sin((i / n) * Math.PI * 2 - 1.2) * ry]);
  const onScreen = (name) => g(`(() => { const o = G.scene.getObjectByName(${JSON.stringify(name)}); const v = o.getWorldPosition(new G.THREE.Vector3()).project(G.camera); return [(v.x + 1) / 2 * innerWidth, (1 - v.y) / 2 * innerHeight]; })()`);

  await play.until("!!window.__ds3d", 30000, "the tool");
  await play.evaluate(FAKE_SPEECH);
  await g(`(localStorage.setItem("ds3d.knowsHow", "1"), t.voice.silenceAfterSpeechMs = t.voice.silenceWithoutSpeechMs = 120000, t.notes.slice().forEach((n) => t.deleteNote(n.id, false)), true)`);
  await play.sleep(1500);
  await play.shot("p0-start");
  play.check("it follows the world's camera, not the map's, the wall's or the HUD's", await g(`t.host.camera === G.camera`), await g(`t.host.camera?.name`));
  play.check("and the world's scene", await g(`t.host.scene === G.scene`), await g(`t.host.scene?.name ?? ""`));
  play.check("the shown view is the world's", await g(`t.host.shown.position.distanceTo(G.camera.getWorldPosition(new G.THREE.Vector3())) < 0.01`));

  // A tap on each of two things, through all the passes.
  const about = async (name) => {
    const [x, y] = await onScreen(name);
    const before = await g(`t.notes.length`);
    await g(`(t.setArmed(true), true)`);
    await tap(x, y);
    await play.until(`window.__ds3d.notes.length === ${before + 1}`, 6000, "a mark");
    await play.until(`window.__ds3d.notes.at(-1).recording === "recording"`, 8000, "the microphone");
    await g(`(t.setArmed(false), true)`);
    await play.evaluate(`window.__speech.say("Zmień to: ${name}", true)`);
    await play.sleep(150);
    await play.press("Enter");
    await play.until(`window.__ds3d.notes.at(-1).recording === undefined`, 6000, "the words");
    const label = await g(`t.notes.at(-1).target?.layers[0]?.[0]?.label`);
    play.check(`a tap on ${name} is about it`, label === name, label);
    const pin = await g(`(() => { const n = t.notes.at(-1); const v = new G.THREE.Vector3(...n.world.anchor).project(G.camera); return [(v.x + 1) / 2 * innerWidth, (1 - v.y) / 2 * innerHeight]; })()`);
    play.check(`its mark is on it`, Math.hypot(pin[0] - x, pin[1] - y) < 280, JSON.stringify(pin));
    await play.press("Escape");
    await play.sleep(150);
  };
  await about("Red crate");
  await about("Blue tower");
  await play.shot("p1-marks");

  // A circle while the world goes on.
  const [cx, cy] = await onScreen("Green ball");
  const before = await g(`t.notes.length`);
  await g(`(t.setArmed(true), true)`);
  await play.sleep(60);
  await stroke(circle(cx, cy - 10, 110, 110));
  await play.until(`window.__ds3d.notes.length === ${before + 1}`, 6000, "the circle's mark");
  await play.sleep(120);
  await play.shot("p2-circle-done");
  await g(`(t.setArmed(false), true)`);
  const label = await g(`t.notes.at(-1).target?.layers[0]?.[0]?.label`);
  play.check("a circle around the ball is about it", label === "Green ball", label);
  await play.press("Escape");

  // What the agent is shown: a real picture of the world.
  const picture = await play.evaluate(`(() => { const f = window.__ds3d.host.captureFrame(); const d = f.getContext("2d").getImageData(0, 0, f.width, f.height).data; let lit = 0, all = 0; for (let i = 0; i < d.length; i += 4000) { all++; if (d[i] + d[i + 1] + d[i + 2] > 60) lit++; } window.__copy = f; return { lit, all, w: f.width, h: f.height }; })()`);
  console.log("  frame copy:", JSON.stringify(picture));
  play.check("a copy of the frame has the world in it", picture.w === play.width && picture.lit > picture.all * 0.5, JSON.stringify(picture));
  await play.evaluate(`(() => { const f = window.__copy; f.style.cssText = "position:fixed;left:20px;bottom:20px;width:480px;z-index:999;outline:3px solid #fff"; document.body.append(f); return true; })()`);
  await play.sleep(300);
  await play.shot("p3-the-copy");
  await play.evaluate(`window.__copy.remove()`);
  await g(`(t.notes.slice().forEach((n) => t.deleteNote(n.id, false)), true)`);
}
