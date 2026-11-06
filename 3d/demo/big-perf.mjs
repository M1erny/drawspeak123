// What the tool costs in a big world: frames with and without it, and a pick at the worst moments.
//   node ../../swing-shop-web/scripts/drive.mjs demo/big-perf.mjs --gpu --url "http://localhost:5190/demo/big.html" --size 1600x900
const RECORDER = `(() => {
  const r = window.__rec = { times: [], long: [], on: false, last: 0 };
  const tick = (now) => { if (r.on) r.times.push(now - r.last); r.last = now; requestAnimationFrame(tick); };
  requestAnimationFrame(tick);
  try { new PerformanceObserver((list) => { if (r.on) for (const e of list.getEntries()) r.long.push(Math.round(e.duration)); }).observe({ type: "longtask" }); } catch {}
  r.begin = () => { r.times = []; r.long = []; r.on = true; };
  r.end = () => {
    r.on = false;
    const t = r.times.slice(1).sort((a, b) => a - b);
    const at = (q) => +(t[Math.min(t.length - 1, Math.floor(t.length * q))] ?? 0).toFixed(1);
    const total = t.reduce((sum, x) => sum + x, 0);
    return { fps: +((t.length * 1000) / (total || 1)).toFixed(1), p50: at(0.5), p95: at(0.95), worst: +(t[t.length - 1] ?? 0).toFixed(1), long: r.long };
  };
  return true;
})()`;

export default async function bigPerf(play) {
  const g = (expr) => play.evaluate(`(() => { const b = window.__big; const t = window.__ds3d; return ${expr}; })()`);
  const stroke = async (points) => {
    const [first, ...rest] = points;
    await play.cdp("Input.dispatchMouseEvent", { type: "mouseMoved", x: first[0], y: first[1] });
    await play.cdp("Input.dispatchMouseEvent", { type: "mousePressed", x: first[0], y: first[1], button: "left", buttons: 1, clickCount: 1 });
    for (const [x, y] of rest) await play.cdp("Input.dispatchMouseEvent", { type: "mouseMoved", x, y, button: "left", buttons: 1 });
    const last = points[points.length - 1];
    await play.cdp("Input.dispatchMouseEvent", { type: "mouseReleased", x: last[0], y: last[1], button: "left", clickCount: 1 });
  };
  const circle = (cx, cy, rx, ry = rx, n = 28) => Array.from({ length: n + 1 }, (_, i) => [cx + Math.cos((i / n) * Math.PI * 2 - 1.2) * rx, cy + Math.sin((i / n) * Math.PI * 2 - 1.2) * ry]);
  const measure = async (name, seconds = 3) => {
    await play.evaluate("window.__rec.begin(), true");
    await play.sleep(seconds * 1000);
    const row = await play.evaluate("window.__rec.end()");
    console.log(`  ${name.padEnd(30)} ${String(row.fps).padStart(5)} fps  p50 ${row.p50}  p95 ${row.p95}  worst ${row.worst}  long ${JSON.stringify(row.long)}`);
    return row;
  };
  const moment = async (name, act) => {
    await play.evaluate("window.__rec.begin(), true");
    const begun = Date.now();
    await act();
    const took = Date.now() - begun;
    await play.sleep(600);
    const row = await play.evaluate("window.__rec.end()");
    console.log(`  ${name.padEnd(30)} worst frame ${row.worst} ms  long tasks ${JSON.stringify(row.long)}  (${took} ms)`);
  };

  await play.until("!!window.__big", 120000, "the big world");
  await play.evaluate(RECORDER);
  await play.sleep(3000);
  const hasTool = await play.evaluate("!!window.__ds3d");
  const info = await g(`({ calls: b.renderer.info.render.calls, tris: b.renderer.info.render.triangles, objects: (() => { let n = 0; b.scene.traverse(() => n++); return n; })() })`);
  console.log("  world:", JSON.stringify(info), "tool:", hasTool);
  await measure("standing");
  if (!hasTool) return;

  await g(`(localStorage.setItem("ds3d.knowsHow", "1"), t.setAutoVoice(false), t.notes.slice().forEach((n) => t.deleteNote(n.id, false)), true)`);
  await play.sleep(4000);
  await measure("tool idle, trees ready");
  const note = (i) => g(`(() => { const n = t.notes[${i}]; return n && { kind: n.shape.kind, target: n.target?.layers[0]?.[0]?.label, partial: n.target?.partial, on: n.world.place?.on, anchor: n.world.anchor.map((v) => +v.toFixed(1)) }; })()`);
  const done = (i) => g(`(t.setText(t.notes[${i}], "Tutaj", "typed"), document.activeElement?.blur(), t.activate(undefined), t.setArmed(true), true)`);
  await g(`(t.setArmed(true), true)`);
  await moment("circle on the terrain", async () => {
    await stroke(circle(play.width * 0.7, play.height * 0.8, 80, 40));
    await play.until("window.__ds3d.notes.length === 1", 15000, "a mark");
  });
  console.log("    ", JSON.stringify(await note(0)));
  await done(0);
  await moment("circle around buildings", async () => {
    await stroke(circle(play.width * 0.4, play.height * 0.55, 200, 120));
    await play.until("window.__ds3d.notes.length === 2", 15000, "a mark");
  });
  console.log("    ", JSON.stringify(await note(1)));
  await done(1);
  await moment("tap", async () => {
    await stroke([[play.width * 0.5, play.height * 0.6]]);
    await play.until("window.__ds3d.notes.length === 3", 15000, "a mark");
  });
  console.log("    ", JSON.stringify(await note(2)));
  await done(2);
  for (let i = 0; i < 9; i++) {
    await stroke(circle(play.width * (0.15 + i * 0.08), play.height * (0.45 + (i % 3) * 0.14), 36, 24));
    await play.until(`window.__ds3d.notes.length === ${i + 4}`, 15000, "a mark");
    await done(i + 3);
  }
  await g(`(t.setArmed(false), true)`);
  await play.sleep(1000);
  await measure("12 marks");
  await g(`(t.notes.slice().forEach((n) => t.deleteNote(n.id, false)), true)`);
}
