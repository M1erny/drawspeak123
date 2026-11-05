// Marks in the demo room, saved as a draft: exactly what a coding agent gets, for trying one by hand
// (run with swing-shop-web's scripts/drive.mjs, with the hub and the demo running):
//   node ../../swing-shop-web/scripts/drive.mjs demo/batch.mjs --url http://localhost:5190/demo/ --size 1280x800 --out dist/demo-shots
// It asks for what is not in the room yet: a new thing on the floor, a walking character, a move, and
// something about the whole view.
const FAKE_SPEECH = `(() => {
  class F { constructor() { window.__speech.current = this; } start() {} stop() { setTimeout(() => this.onend?.(), 20); } abort() {} }
  window.__speech = { say(text, isFinal) { window.__speech.current?.onresult?.({ results: [{ isFinal, 0: { transcript: text } }] }); } };
  window.SpeechRecognition = window.webkitSpeechRecognition = F;
  if (navigator.mediaDevices) navigator.mediaDevices.getUserMedia = () => Promise.reject(new Error("no microphone in tests"));
  return true;
})()`;

export default async function batch(play) {
  await play.until("!!window.__ds3d && window.__ds3d.host.ready", 40000, "the room");
  await play.evaluate(FAKE_SPEECH);
  await play.evaluate(`(window.__ds3d.voice.silenceAfterSpeechMs = window.__ds3d.voice.silenceWithoutSpeechMs = 120000, window.__ds3d.notes.slice().forEach((n) => window.__ds3d.deleteNote(n.id, false)), window.__ds3d.setArmed(true), true)`);
  await play.sleep(1500);

  const screenOf = (x, y, z) => play.evaluate(`(() => { const v = new (window.__demo.camera.position.constructor)(${x}, ${y}, ${z}).project(window.__demo.camera); return [((v.x + 1) / 2) * innerWidth, ((1 - v.y) / 2) * innerHeight]; })()`);
  const stroke = async (a, b, n = 18) => {
    await play.cdp("Input.dispatchMouseEvent", { type: "mouseMoved", x: a[0], y: a[1] });
    await play.cdp("Input.dispatchMouseEvent", { type: "mousePressed", x: a[0], y: a[1], button: "left", buttons: 1, clickCount: 1 });
    for (let i = 1; i <= n; i++) await play.cdp("Input.dispatchMouseEvent", { type: "mouseMoved", x: a[0] + ((b[0] - a[0]) * i) / n, y: a[1] + ((b[1] - a[1]) * i) / n, button: "left", buttons: 1 });
    await play.cdp("Input.dispatchMouseEvent", { type: "mouseReleased", x: b[0], y: b[1], button: "left", clickCount: 1 });
  };
  const say = async (i, text) => {
    await play.until(`window.__ds3d.notes.length === ${i + 1}`, 15000, `mark ${i + 1}`);
    await play.evaluate(`window.__speech.say(${JSON.stringify(text)}, true)`);
    await play.press("Enter");
    await play.until(`window.__ds3d.notes[${i}].text === ${JSON.stringify(text)}`, 8000, "the words");
    await play.evaluate(`(window.__ds3d.activate(undefined), true)`);
    await play.sleep(800);
  };

  const spot = await screenOf(-3, 0, 2.2);
  await play.click(spot[0], spot[1]);
  await say(0, "Postaw tutaj zieloną choinkę, mniej więcej tak wysoką jak ta lampa.");

  await stroke(await screenOf(-3.6, 0, 3.8), await screenOf(3.6, 0, 3.8));
  await say(1, "Add a small round robot here. It should walk back and forth along this line all the time.");

  const box = await play.evaluate(`(() => { const d = window.__demo; const o = d.teapot; o.geometry.computeBoundingBox(); const b = o.geometry.boundingBox.clone().applyMatrix4(o.matrixWorld); const c = b.getCenter(new b.min.constructor()).project(d.camera); return [((c.x + 1) / 2) * innerWidth, ((1 - c.y) / 2) * innerHeight]; })()`);
  await stroke(box, await screenOf(3.6, 0, 1.8));
  await say(2, "Move the red box here, onto the floor.");

  await play.evaluate(`(window.__ds3d.talkAboutView(), true)`);
  await say(3, "This room feels closed in. Put one big window in the back wall, in the middle.");

  await play.evaluate(`(window.__ds3d.setArmed(false), window.__ds3d.openFeedback(), true)`);
  await play.until(`document.querySelector(".ds3d-sheet")`, 8000, "the preview");
  await play.until(`[...document.querySelectorAll(".ds3d-sheet button")].some((b) => b.textContent.includes("Save Draft") && !b.disabled)`, 15000, "Save Draft");
  await play.shot("batch-sheet");
  await play.clickText("Save Draft");
  await play.until(`!document.querySelector(".ds3d-sheet")`, 60000, "the draft saved");
  await play.sleep(500);
  console.log("  Saved. The batch is the newest folder in <data>/demo/batches.");
  await play.evaluate(`(window.__ds3d.notes.slice().forEach((n) => window.__ds3d.deleteNote(n.id, false)), true)`);
}
