import assert from 'node:assert/strict';
import { createElevenLabsTranscriber, MAX_AUDIO_BYTES, TranscriptionError } from '../adapters/elevenlabs-transcription.mjs';

// Synthetic credentials and bytes only. Every adapter invocation injects fetch.
const KEY = 'synthetic-test-key-never-live';
const fixture = () => ({
  language_code: 'pl', language_probability: 0.99, text: 'Zmień przycisk.',
  words: [{ text: 'Zmień', type: 'word', start: 0, end: 0.4, logprob: -0.1 },
    { text: ' ', type: 'spacing', start: 0.4, end: 0.4 },
    { text: 'przycisk.', type: 'word', start: 0.4, end: 0.9, speaker_id: null }],
});
const request = overrides => ({
  audio: new Blob(['synthetic audio bytes'], { type: 'audio/mp4' }), language: 'pl-PL',
  scope: { canvasId: 'canvas-a', noteId: 'note-1', recordingId: 'recording-1' }, ...overrides,
});
let passed = 0;
async function check(name, run) {
  await run();
  passed += 1;
  process.stdout.write(`ok ${passed} - ${name}\n`);
}
function expectError(code, extra = () => {}) {
  return error => {
    assert.ok(error instanceof TranscriptionError);
    assert.equal(error.code, code);
    assert.ok(!String(error).includes(KEY));
    assert.ok(!JSON.stringify(error).includes(KEY));
    assert.equal(error.cause, undefined);
    extra(error);
    return true;
  };
}

await check('multipart contract, fixed endpoint, auth and Polish mapping', async () => {
  let calls = 0;
  const input = request();
  const transcribe = createElevenLabsTranscriber({ apiKey: KEY, fetchImpl: async (url, options) => {
    calls += 1;
    assert.equal(url, 'https://api.elevenlabs.io/v1/speech-to-text');
    assert.equal(options.method, 'POST');
    assert.equal(options.redirect, 'error');
    assert.equal(options.credentials, 'omit');
    assert.deepEqual(options.headers, { 'xi-api-key': KEY, Accept: 'application/json' });
    assert.ok(options.body instanceof FormData);
    assert.deepEqual([...options.body.keys()], ['file', 'model_id', 'language_code', 'diarize', 'tag_audio_events', 'timestamps_granularity']);
    assert.equal(options.body.get('model_id'), 'scribe_v2');
    assert.equal(options.body.get('language_code'), 'pol');
    assert.equal(options.body.get('diarize'), 'false');
    assert.equal(options.body.get('tag_audio_events'), 'false');
    assert.equal(options.body.get('timestamps_granularity'), 'word');
    assert.equal(options.body.get('file').name, 'recording.m4a');
    assert.equal(await options.body.get('file').text(), await input.audio.text());
    assert.ok(![...options.body.values()].includes(input.scope.noteId));
    return Response.json(fixture());
  } });
  const result = await transcribe(input);
  assert.equal(calls, 1);
  assert.equal(result.rawTranscript, 'Zmień przycisk.');
  assert.equal(result.requestedLanguage, 'pol');
  assert.equal(result.detectedLanguage, 'pl');
  assert.equal(result.words[0].logprob, -0.1);
});

await check('PL/EN locale and ISO aliases', async () => {
  for (const [locale, code] of [['pl', 'pol'], ['pol', 'pol'], ['PL-pl', 'pol'], ['en-US', 'eng'], ['en-GB', 'eng'], ['en', 'eng'], ['eng', 'eng']]) {
    let calls = 0;
    const transcribe = createElevenLabsTranscriber({ apiKey: KEY, fetchImpl: async (_, options) => {
      calls += 1;
      assert.equal(options.body.get('language_code'), code);
      return Response.json(fixture());
    } });
    assert.equal((await transcribe(request({ language: locale }))).requestedLanguage, code);
    assert.equal(calls, 1);
  }
});

await check('late result owns captured scope; input and provider objects stay independent', async () => {
  const input = request({ text: 'Keep my typed edit.' });
  const originalScope = { ...input.scope };
  const data = fixture();
  let resolveResponse;
  const transcribe = createElevenLabsTranscriber({ apiKey: KEY, fetchImpl: () => new Promise(resolve => { resolveResponse = resolve; }) });
  const pending = transcribe(input);
  input.scope.canvasId = 'canvas-b';
  input.scope.noteId = 'note-9';
  input.scope.recordingId = 'recording-9';
  resolveResponse({ status: 200, json: async () => data });
  const result = await pending;
  data.words[0].text = 'mutated';
  assert.deepEqual(result.scope, originalScope);
  assert.equal(result.words[0].text, 'Zmień');
  assert.equal(input.text, 'Keep my typed edit.');
  for (const value of [result, result.scope, result.words, result.words[0]]) assert.ok(Object.isFrozen(value));
  assert.throws(() => { result.scope.noteId = 'wrong'; }, TypeError);
});

await check('scope and audio retained on auth, rate-limit and HTTP errors; no retries or leaked bodies', async () => {
  for (const [status, code] of [[401, 'auth'], [403, 'auth'], [429, 'rate_limited'], [422, 'upstream'], [500, 'upstream'], [302, 'upstream']]) {
    let calls = 0;
    const input = request();
    const before = await input.audio.text();
    const transcribe = createElevenLabsTranscriber({ apiKey: KEY, fetchImpl: async () => {
      calls += 1;
      return { status, json() { throw new Error(`Never read provider error body ${KEY}`); } };
    } });
    await assert.rejects(transcribe(input), expectError(code, error => {
      assert.equal(error.status, status);
      assert.deepEqual(error.scope, input.scope);
      assert.equal(error.requestMayHaveBeenProcessed, true);
    }));
    assert.equal(calls, 1);
    assert.equal(await input.audio.text(), before);
  }
});

await check('network exception is sanitized; no automatic retry', async () => {
  let calls = 0;
  const transcribe = createElevenLabsTranscriber({ apiKey: KEY, fetchImpl: async () => {
    calls += 1;
    throw new Error(`network error with ${KEY}`);
  } });
  await assert.rejects(transcribe(request()), expectError('network', error => assert.equal(error.requestMayHaveBeenProcessed, true)));
  assert.equal(calls, 1);
});

await check('pre-aborted request never reaches fetch or exposes abort reason', async () => {
  let calls = 0;
  const controller = new AbortController();
  controller.abort(new Error(KEY));
  const transcribe = createElevenLabsTranscriber({ apiKey: KEY, fetchImpl: async () => { calls += 1; } });
  await assert.rejects(transcribe(request({ signal: controller.signal })), expectError('aborted', error => assert.equal(error.requestMayHaveBeenProcessed, false)));
  assert.equal(calls, 0);
});

await check('abort during upload cancels signal and reports uncertain processing', async () => {
  const controller = new AbortController();
  let calls = 0;
  const transcribe = createElevenLabsTranscriber({ apiKey: KEY, fetchImpl: async (_, options) => {
    calls += 1;
    assert.equal(options.signal, controller.signal);
    controller.abort(KEY);
    throw new Error(KEY);
  } });
  await assert.rejects(transcribe(request({ signal: controller.signal })), expectError('aborted', error => assert.equal(error.requestMayHaveBeenProcessed, true)));
  assert.equal(calls, 1);
});

await check('abort during response decode does not publish transcript', async () => {
  const controller = new AbortController();
  const transcribe = createElevenLabsTranscriber({ apiKey: KEY, fetchImpl: async () => ({
    status: 200, json: async () => { controller.abort(KEY); return fixture(); },
  }) });
  await assert.rejects(transcribe(request({ signal: controller.signal })), expectError('aborted'));
});

await check('invalid JSON is sanitized', async () => {
  const transcribe = createElevenLabsTranscriber({ apiKey: KEY, fetchImpl: async () => ({ status: 200, json: async () => { throw new Error(KEY); } }) });
  await assert.rejects(transcribe(request()), expectError('invalid_response'));
});

await check('malformed transcript or timestamps rejected', async () => {
  const malformed = [null, {}, { ...fixture(), text: 1 }, { ...fixture(), words: null },
    { ...fixture(), language_probability: 2 }, { ...fixture(), language_code: null },
    { ...fixture(), words: [{ ...fixture().words[0], start: -1 }] },
    { ...fixture(), words: [{ ...fixture().words[0], end: 0, start: 1 }] },
    { ...fixture(), words: [{ ...fixture().words[0], logprob: 'bad' }] },
    { ...fixture(), words: [{ ...fixture().words[0], type: 'unknown' }] }];
  for (const data of malformed) {
    const transcribe = createElevenLabsTranscriber({ apiKey: KEY, fetchImpl: async () => Response.json(data) });
    await assert.rejects(transcribe(request()), expectError('invalid_response'));
  }
});

await check('silence response remains an empty raw transcript', async () => {
  const transcribe = createElevenLabsTranscriber({ apiKey: KEY, fetchImpl: async () => Response.json({ text: '', words: [], language_code: 'pl' }) });
  const result = await transcribe(request());
  assert.equal(result.rawTranscript, '');
  assert.deepEqual(result.words, []);
  assert.equal(result.languageProbability, null);
});

await check('invalid request, scope, locale, MIME, signal and local size policy do not upload', async () => {
  let calls = 0;
  const transcribe = createElevenLabsTranscriber({ apiKey: KEY, maxAudioBytes: 32, fetchImpl: async () => { calls += 1; } });
  for (const input of [null, {}, request({ scope: null }), request({ scope: { canvasId: 'a', noteId: '', recordingId: 'c' } }),
    request({ scope: { canvasId: 'a', noteId: 'bad\nvalue', recordingId: 'c' } }),
    request({ audio: 'bytes' }), request({ audio: new Blob([]) }),
    request({ audio: new Blob(['x'], { type: 'text/html' }) }),
    request({ audio: new Blob(['x'.repeat(33)], { type: 'audio/mp4' }) }),
    request({ language: 'de-DE' }), request({ signal: {} })]) {
    await assert.rejects(transcribe(input), expectError('invalid_request', error => assert.equal(error.requestMayHaveBeenProcessed, false)));
  }
  assert.equal(calls, 0);
});

await check('configuration validation does not echo credentials or invoke fetch', async () => {
  for (const config of [null, {}, { apiKey: '' }, { apiKey: `${KEY}\n` }, { apiKey: KEY, fetchImpl: null },
    { apiKey: KEY, maxAudioBytes: 0 }, { apiKey: KEY, maxAudioBytes: MAX_AUDIO_BYTES + 1 }]) {
    assert.throws(() => createElevenLabsTranscriber(config), expectError('invalid_config'));
  }
});

process.stdout.write(`Passed ${passed} mocked ElevenLabs checks; no API calls or credentials used.\n`);
