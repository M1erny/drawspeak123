// Host-only Node 22 adapter. Never import this module into the HTML prototype.
export const MAX_AUDIO_BYTES = 25 * 1024 * 1024; // Local application policy.
const ENDPOINT = 'https://api.elevenlabs.io/v1/speech-to-text';
const MODEL = 'scribe_v2';
const FORMATS = new Map([
  ['', 'bin'], ['application/octet-stream', 'bin'],
  ['audio/mp4', 'm4a'], ['audio/m4a', 'm4a'], ['audio/x-m4a', 'm4a'],
  ['audio/mpeg', 'mp3'], ['audio/mp3', 'mp3'], ['audio/aac', 'aac'],
  ['audio/wav', 'wav'], ['audio/x-wav', 'wav'], ['audio/flac', 'flac'],
  ['audio/webm', 'webm'], ['audio/ogg', 'ogg'], ['audio/3gpp', '3gp'],
]);
const MESSAGES = Object.freeze({
  invalid_config: 'Invalid transcription adapter configuration.',
  invalid_request: 'Invalid transcription request.',
  aborted: 'Transcription was cancelled. Keep the local recording.',
  network: 'Transcription connection failed. Keep the local recording.',
  auth: 'Transcription authorization failed. Check host credentials.',
  rate_limited: 'Transcription is rate limited. Retry only on explicit request.',
  upstream: 'The transcription service returned an error.',
  invalid_response: 'The transcription service returned an invalid response.',
});

export class TranscriptionError extends Error {
  constructor(code, { scope = null, status = null, requestMayHaveBeenProcessed = false } = {}) {
    super(MESSAGES[code]);
    this.name = 'TranscriptionError';
    this.code = code;
    this.scope = scope;
    this.status = status;
    this.requestMayHaveBeenProcessed = requestMayHaveBeenProcessed;
    // Do not attach upstream bodies, exception messages, headers or a cause:
    // injected fetch implementations can include credentials in any of them.
  }
}

const isRecord = value => value !== null && typeof value === 'object' && !Array.isArray(value);
const finite = value => typeof value === 'number' && Number.isFinite(value);

function captureScope(scope) {
  if (!isRecord(scope)) throw new TranscriptionError('invalid_request');
  const captured = {};
  for (const key of ['canvasId', 'noteId', 'recordingId']) {
    const value = scope[key];
    if (typeof value !== 'string' || !value.trim() || value.length > 200 || /[\u0000-\u001f\u007f]/u.test(value)) {
      throw new TranscriptionError('invalid_request');
    }
    captured[key] = value;
  }
  return Object.freeze(captured);
}

function normalizeLanguage(language) {
  if (typeof language !== 'string') return null;
  const normalized = language.trim().toLowerCase();
  if (/^(pl|pol)(-[a-z]{2})?$/u.test(normalized)) return 'pol';
  if (/^(en|eng)(-[a-z]{2})?$/u.test(normalized)) return 'eng';
  return null;
}

function copyTranscript(data, scope, requestedLanguage) {
  if (!isRecord(data) || typeof data.text !== 'string' || !Array.isArray(data.words)
    || typeof data.language_code !== 'string' || !data.language_code
    || (data.language_probability != null && (!finite(data.language_probability)
      || data.language_probability < 0 || data.language_probability > 1))) {
    throw new TranscriptionError('invalid_response', { scope, requestMayHaveBeenProcessed: true });
  }
  const words = data.words.map(word => {
    if (!isRecord(word) || typeof word.text !== 'string'
      || !['word', 'spacing', 'audio_event'].includes(word.type)
      || !finite(word.start) || !finite(word.end) || word.start < 0 || word.end < word.start
      || (word.speaker_id != null && typeof word.speaker_id !== 'string')
      || (word.logprob != null && !finite(word.logprob))) {
      throw new TranscriptionError('invalid_response', { scope, requestMayHaveBeenProcessed: true });
    }
    return Object.freeze({
      text: word.text, type: word.type, start: word.start, end: word.end,
      speaker_id: word.speaker_id ?? null, logprob: word.logprob ?? null,
    });
  });
  return Object.freeze({
    provider: 'elevenlabs', modelId: MODEL, scope, requestedLanguage,
    detectedLanguage: data.language_code,
    languageProbability: data.language_probability ?? null,
    rawTranscript: data.text,
    words: Object.freeze(words),
  });
}

/**
 * Trusted-host function, not an HTTP endpoint. The caller persists audio before
 * invoking it and stores results by returned scope, separately from editable text.
 * Exactly one fetch is attempted per invocation; there are no automatic retries.
 */
export function createElevenLabsTranscriber(config) {
  if (!isRecord(config)) throw new TranscriptionError('invalid_config');
  const { apiKey, fetchImpl = globalThis.fetch, maxAudioBytes = MAX_AUDIO_BYTES } = config;
  if (typeof apiKey !== 'string' || !/^[\x21-\x7e]+$/u.test(apiKey)
    || typeof fetchImpl !== 'function'
    || !Number.isSafeInteger(maxAudioBytes) || maxAudioBytes < 1 || maxAudioBytes > MAX_AUDIO_BYTES) {
    throw new TranscriptionError('invalid_config');
  }

  return async function transcribe(request) {
    if (!isRecord(request)) throw new TranscriptionError('invalid_request');
    // Capture before the first await: switching canvas cannot redirect a result.
    const scope = captureScope(request.scope);
    const { audio, signal } = request;
    const language = normalizeLanguage(request.language);
    if (!(audio instanceof Blob) || audio.size < 1 || audio.size > maxAudioBytes
      || !FORMATS.has(audio.type) || !language
      || (signal !== undefined && !(signal instanceof AbortSignal))) {
      throw new TranscriptionError('invalid_request', { scope });
    }
    if (signal?.aborted) throw new TranscriptionError('aborted', { scope });

    const form = new FormData();
    form.append('file', audio, `recording.${FORMATS.get(audio.type)}`);
    form.append('model_id', MODEL);
    form.append('language_code', language);
    form.append('diarize', 'false');
    form.append('tag_audio_events', 'false');
    form.append('timestamps_granularity', 'word');
    let response;
    try {
      response = await fetchImpl(ENDPOINT, {
        method: 'POST', headers: { 'xi-api-key': apiKey, Accept: 'application/json' },
        body: form, signal, redirect: 'error', credentials: 'omit',
      });
    } catch {
      throw new TranscriptionError(signal?.aborted ? 'aborted' : 'network', {
        scope, requestMayHaveBeenProcessed: true,
      });
    }
    if (signal?.aborted) {
      throw new TranscriptionError('aborted', { scope, requestMayHaveBeenProcessed: true });
    }
    if (!response || !Number.isInteger(response.status) || response.status < 100 || response.status > 599
      || typeof response.json !== 'function') {
      throw new TranscriptionError('invalid_response', { scope, requestMayHaveBeenProcessed: true });
    }
    if (response.status < 200 || response.status >= 300) {
      const code = [401, 403].includes(response.status) ? 'auth'
        : response.status === 429 ? 'rate_limited' : 'upstream';
      // Error bodies are intentionally never read or copied into diagnostics.
      throw new TranscriptionError(code, { scope, status: response.status, requestMayHaveBeenProcessed: true });
    }
    let data;
    try {
      data = await response.json();
    } catch {
      throw new TranscriptionError(signal?.aborted ? 'aborted' : 'invalid_response', {
        scope, requestMayHaveBeenProcessed: true,
      });
    }
    if (signal?.aborted) {
      throw new TranscriptionError('aborted', { scope, requestMayHaveBeenProcessed: true });
    }
    return copyTranscript(data, scope, language);
  };
}
