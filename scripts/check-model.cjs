// Exercise the actual inline model without browser or package dependencies.
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const html = fs.readFileSync(process.argv[2] || path.join(__dirname, '../prototype/index.html'), 'utf8');
const script = html.match(/<script>([\s\S]*?)<\/script>/)[1];
const pure = script.slice(script.indexOf('const KEY='), script.indexOf('const $='));
const {Store, regionIntent, sampleTranscript} = new Function('crypto', pure + '\nreturn {Store:ReviewStore,regionIntent,sampleTranscript};')(crypto);
const store = new Store();
assert.equal(store.settings.autoVoice, true, 'auto voice is on by default');
assert.equal(store.settings.drawWithFinger, false, 'finger defaults to navigation');
assert.throws(() => store.batch(), /Select at least/);
const shape = {type: 'circle', coordinateSpace: 'normalized', points: [{x: .1, y: .2}, {x: .7, y: .8}]};
const n1 = store.addNote('checkout:current', shape);
shape.points[0].x = .99;
assert.equal(n1.shape.points[0].x, .1, 'annotation owns its geometry');
assert.throws(() => store.batch(), /Add a comment/);
n1.text = 'Show the final total.';
const n2 = store.addNote('checkout:a2', shape);
n2.text = 'Keep the date visible.';
const batch = store.batch();
assert.equal(batch.notes.length, 2);
assert.equal(batch.threadId, 'fixture-thread-checkout');
assert.equal(batch.notes[0].snapshotId, 'checkout:current');
const stash = store.stash();
n1.text = 'Later edit';
n1.shape.points[0].x = .4;
assert.equal(stash.notes[0].text, 'Show the final total.');
assert.equal(stash.notes[0].shape.points[0].x, .1);
store.current.versions.a = 'a3';
assert.equal(n2.snapshotId, 'checkout:a2', 'iteration changes never remap old notes');
const extra = store.addNote('checkout:a3', shape);
extra.text = 'An unrelated later note';
store.loadStash(stash.batchId);
assert.equal(extra.selected, false, 'restoring a stash restores its selection scope');
assert.equal(n1.text, 'Later edit', 'loading a stash never overwrites current text');
const restoredCopy = store.current.notes.find(n => n.sourceNoteId === n1.id);
assert.equal(restoredCopy.text, 'Show the final total.');
assert.notEqual(restoredCopy.id, n1.id);
assert.equal(n1.selected, false);
assert.equal(store.batch().notes.length, 2);
assert.equal(store.current.deliveries.length, 0, 'stash never executes delivery');
const checkout = store.current;
store.activeId = 'onboarding';
assert.notEqual(store.current.threadId, checkout.threadId);
assert.equal(store.current.notes.length, 0);
assert.equal(store.current.stashes.length, 0);
assert.throws(() => store.loadStash(stash.batchId), /another canvas/);
assert.throws(() => store.batch(), /Select at least/);
const other = store.addNote('onboarding:current', shape);
other.text = 'Explain the next step.';
assert.equal(store.batch().threadId, 'fixture-thread-onboarding');
assert.equal(checkout.notes.length, 5);
store.settings.autoVoice = false;
const restored = new Store(JSON.parse(JSON.stringify(store.serialize())));
assert.equal(restored.settings.autoVoice, false);
assert.equal(restored.current.id, 'onboarding');
assert.equal(restored.canvases.find(c => c.id === 'checkout').stashes.length, 1);
restored.current.notes.push({...n1, selected: true});
assert.throws(() => restored.batch(), /one canvas and thread/);
const undoStore = new Store();
const first = undoStore.addNote('checkout:current', shape);
first.text = 'First note';
const second = undoStore.addNote('checkout:a2', shape);
undoStore.removeNote(first.id);
assert.equal(undoStore.current.notes[0].id, second.id);
assert.equal(undoStore.undo(), true);
assert.equal(undoStore.current.notes[0].id, first.id);
assert.equal(undoStore.current.notes[0].ordinal, 1);
assert.equal(undoStore.current.notes[1].ordinal, 2);
assert.equal(undoStore.current.notes[0].text, 'First note');
assert.equal(undoStore.current.notes[1].id, second.id);
undoStore.undo();
assert.equal(undoStore.current.notes.length, 1);
assert.equal(undoStore.current.notes[0].id, first.id);
// Run the actual recording finalizer with only its view side effects stubbed.
const vm = require('node:vm');
const finishSource = script.slice(script.indexOf('function finishRecording('), script.indexOf('function point('));
function recordingCase(text, cancel, explicitStop, switchCanvas = false) {
  const note = {id: 'original-note', text};
  const original = {id: 'original-canvas', notes: [note]};
  const other = {id: 'other-canvas', notes: []};
  const elements = new Map();
  const context = vm.createContext({
    store: {canvases: [original, other], current: switchCanvas ? other : original},
    document: {hidden: false}, Date, clearInterval() {},
    persist() {}, recordingUI() {}, renderNotes() {}, renderMarkers() {}, toast() {}, announce() {},
    clone: value => JSON.parse(JSON.stringify(value)), sampleTranscript,
    showPanel() {}, snapshotPreview() {},
    $: id => {
      if (!elements.has(id)) elements.set(id, {value: '', textContent: '', replaceChildren() {}});
      return elements.get(id);
    }
  });
  vm.runInContext("let recording={canvasId:'original-canvas',noteId:'original-note',started:Date.now(),language:'en-US'};let editing='original-note';let timer=null;" + finishSource + ';globalThis.finish=finishRecording;', context);
  context.finish(cancel, explicitStop);
  assert.equal(other.notes.length, 0, 'interruption never creates a note on the new canvas');
  return note;
}
assert.equal(recordingCase('', false, false).text, '', 'implicit interruption adds no invented transcript');
assert.equal(recordingCase('Typed text', false, false).text, 'Typed text');
assert.equal(recordingCase('', false, false, true).audio.status, 'interrupted');
assert.equal(recordingCase('', true, false).audio, undefined, 'cancel captures no audio fixture');
const typedRecording = recordingCase('My own words', false, true);
assert.equal(typedRecording.text, 'My own words', 'explicit stop preserves edited text');
assert.match(typedRecording.audio.transcript, /Show the full total/, 'raw transcript is preserved separately');
assert.match(recordingCase('', false, true).text, /Show the full total/);
assert.equal(regionIntent([{x: .1, y: .1}, {x: .11, y: .11}], 330, 480), false, 'tiny movement does not trigger voice');
assert.equal(regionIntent([{x: .1, y: .1}, {x: .8, y: .11}], 330, 480), false, 'thin accidental stroke is not a region');
assert.equal(regionIntent([{x: .1, y: .2}, {x: .7, y: .8}], 330, 480), true, 'deliberate diagonal drag');
assert.equal(regionIntent([{x: .2, y: .5}, {x: .5, y: .2}, {x: .8, y: .5}, {x: .5, y: .8}, {x: .2, y: .5}], 330, 480), true, 'closed circle');
const assets = new Map();
const missingSource = script.slice(script.indexOf('function missingSnapshots('), script.indexOf('function fixtureMarkup('));
const missingSnapshots = new Function('sessionImages', missingSource + '\nreturn missingSnapshots;')(assets);
const importedBatch = {notes: [{snapshotId: 'checkout:import-example'}, {snapshotId: 'checkout:current'}]};
assert.deepEqual(missingSnapshots(importedBatch), ['checkout:import-example']);
assets.set('checkout:import-example', 'fixture-image-bytes');
assert.deepEqual(missingSnapshots(importedBatch), []);
new Function(script); // syntax-check the complete UI script, without executing DOM code
console.log('PASS: settings, immutable anchors/stash copies, grouping, thread isolation, stable note/undo identity, intentional region threshold, voice stop ownership/raw transcript, missing image guard, persistence and UI syntax.');
