/**
 * Voice to text in the browser, free and with no keys: the browser's own speech recognition, which
 * shows words as you say them. A mark starts it, silence (or Stop) ends it, and whatever was said
 * belongs to the note the recording started on.
 *
 * Microphones and speech engines fail in many ways. None of them loses a note: the mark stays and
 * the text can be typed.
 */
export interface VoiceEvents {
  /** All that was said so far, the part still being recognized included. */
  onText(text: string): void;
  /** Input level, 0…1, when it can be measured. */
  onLevel(level: number): void;
  /** Nothing said for a while: the recording may end by itself. */
  onSilence(): void;
  /** The engine cannot go on (no permission, no microphone, no service). */
  onFailure(reason: VoiceFailure): void;
}

export type VoiceFailure = "denied" | "no-microphone" | "no-service" | "unsupported";

export const FAILURE_TEXT: Record<VoiceFailure, string> = {
  denied: "The microphone is blocked for this page. Allow it in the address bar, or type your comment.",
  "no-microphone": "No microphone found. Type your comment.",
  "no-service": "Speech recognition did not respond. Type your comment.",
  unsupported: "This browser has no speech recognition (Chrome and Edge do). Type your comment.",
};

/** Silence after speech ends a recording; silence with no speech at all takes longer. */
export const SILENCE_AFTER_SPEECH_MS = 6000;
export const SILENCE_WITHOUT_SPEECH_MS = 12000;

interface RecognitionResultLike {
  isFinal: boolean;
  0: { transcript: string };
}
interface RecognitionLike {
  lang: string;
  continuous: boolean;
  interimResults: boolean;
  onresult: ((e: { results: ArrayLike<RecognitionResultLike> }) => void) | null;
  onerror: ((e: { error: string }) => void) | null;
  onend: (() => void) | null;
  start(): void;
  stop(): void;
  abort(): void;
}

function recognitionClass(): (new () => RecognitionLike) | undefined {
  const w = window as unknown as { SpeechRecognition?: new () => RecognitionLike; webkitSpeechRecognition?: new () => RecognitionLike };
  return w.SpeechRecognition ?? w.webkitSpeechRecognition;
}

export function voiceAvailable(): boolean {
  return recognitionClass() !== undefined;
}

export class Voice {
  silenceAfterSpeechMs = SILENCE_AFTER_SPEECH_MS;
  silenceWithoutSpeechMs = SILENCE_WITHOUT_SPEECH_MS;
  private recognition?: RecognitionLike;
  private events?: VoiceEvents;
  /** What earlier runs of the engine recognized: it stops by itself now and then, and gets restarted. */
  private committed = "";
  private latest = "";
  private lastWords = 0;
  private stopping?: (text: string) => void;
  private stopped?: Promise<string>;
  private silenceClock?: ReturnType<typeof setInterval>;
  private meter?: LevelMeter;
  private restarts = 0;
  private lang = "pl-PL";

  get active(): boolean {
    return this.recognition !== undefined;
  }

  start(lang: string, events: VoiceEvents) {
    this.cancel();
    this.stopped = undefined;
    this.events = events;
    this.lang = lang;
    this.committed = "";
    this.latest = "";
    this.restarts = 0;
    this.lastWords = performance.now();
    const Recognition = recognitionClass();
    if (!Recognition) {
      events.onFailure("unsupported");
      return;
    }
    this.run(Recognition);
    this.silenceClock = setInterval(() => {
      const quiet = performance.now() - this.lastWords;
      if (quiet > (this.latest.trim() ? this.silenceAfterSpeechMs : this.silenceWithoutSpeechMs)) this.events?.onSilence();
    }, 250);
    // The level meter is only for show. iOS cannot share the microphone with the recognizer.
    if (!/iP(ad|hone|od)/.test(navigator.userAgent) && !(navigator.platform === "MacIntel" && navigator.maxTouchPoints > 1)) {
      this.meter = new LevelMeter((level) => this.events?.onLevel(level));
    }
  }

  private run(Recognition: new () => RecognitionLike) {
    const recognition = new Recognition();
    this.recognition = recognition;
    recognition.lang = this.lang;
    recognition.continuous = true;
    recognition.interimResults = true;
    let finals = "";
    recognition.onresult = (e) => {
      finals = "";
      let interim = "";
      for (let i = 0; i < e.results.length; i++) {
        const part = e.results[i][0].transcript;
        if (e.results[i].isFinal) finals = join(finals, part);
        else interim = join(interim, part);
      }
      const text = join(join(this.committed, finals), interim);
      if (text !== this.latest) {
        this.latest = text;
        this.lastWords = performance.now();
        this.events?.onText(text);
      }
    };
    recognition.onerror = (e) => {
      if (recognition !== this.recognition) return;
      if (e.error === "not-allowed" || e.error === "service-not-allowed") this.fail("denied");
      else if (e.error === "audio-capture") this.fail("no-microphone");
      else if (e.error === "language-not-supported") this.fail("no-service");
      // no-speech, aborted, network: the end handler below decides.
    };
    recognition.onend = () => {
      if (recognition !== this.recognition) return;
      this.committed = join(this.committed, finals);
      if (this.stopping) {
        this.finish();
        return;
      }
      // Engines stop after a pause. Carry on, unless it keeps failing at once.
      if (performance.now() - this.lastStart < 800) this.restarts++;
      else this.restarts = 0;
      if (this.restarts >= 4) {
        if (this.latest.trim()) this.events?.onSilence();
        else this.fail("no-service");
        return;
      }
      this.run(Recognition);
    };
    this.lastStart = performance.now();
    try {
      recognition.start();
    } catch {
      this.fail("no-service");
    }
  }
  private lastStart = 0;

  private fail(reason: VoiceFailure) {
    const events = this.events;
    this.cleanUp();
    events?.onFailure(reason);
  }

  /** Ends the recording; resolves with all that was said. Waits briefly for the engine's last words. */
  stop(): Promise<string> {
    const recognition = this.recognition;
    if (!recognition) return Promise.resolve(this.latest.trim());
    if (this.stopped) return this.stopped; // already ending: the same answer
    if (this.silenceClock !== undefined) clearInterval(this.silenceClock);
    this.silenceClock = undefined;
    this.stopped = new Promise((resolve) => {
      this.stopping = resolve;
      setTimeout(() => {
        if (this.stopping === resolve) this.finish();
      }, 1500);
      try {
        recognition.stop();
      } catch {
        this.finish();
      }
    });
    return this.stopped;
  }

  private finish() {
    this.cleanUp();
  }

  /** Ends it, keeping nothing. */
  cancel() {
    if (this.recognition) this.cleanUp();
  }

  private cleanUp() {
    const recognition = this.recognition;
    const waiting = this.stopping;
    const said = this.latest.trim();
    this.recognition = undefined;
    this.events = undefined;
    this.stopping = undefined;
    this.stopped = undefined;
    if (this.silenceClock !== undefined) clearInterval(this.silenceClock);
    this.silenceClock = undefined;
    this.meter?.close();
    this.meter = undefined;
    if (recognition) {
      recognition.onresult = recognition.onerror = recognition.onend = null;
      try {
        recognition.abort();
      } catch {
        // already stopped
      }
    }
    // Whoever waits for the end of this recording gets what was said, however it ended.
    waiting?.(said);
  }
}

function join(a: string, b: string): string {
  if (!a) return b.trim();
  if (!b) return a;
  return `${a.trimEnd()} ${b.trimStart()}`;
}

/** Input level from the microphone, a few times a second. Failing is fine: the ring just stays still. */
class LevelMeter {
  private stream?: MediaStream;
  private context?: AudioContext;
  private timer?: ReturnType<typeof setInterval>;
  private closed = false;

  constructor(report: (level: number) => void) {
    void navigator.mediaDevices?.getUserMedia?.({ audio: { echoCancellation: true, noiseSuppression: true } })
      .then((stream) => {
        if (this.closed) {
          stream.getTracks().forEach((t) => t.stop());
          return;
        }
        this.stream = stream;
        this.context = new AudioContext();
        const analyser = this.context.createAnalyser();
        analyser.fftSize = 512;
        this.context.createMediaStreamSource(stream).connect(analyser);
        const samples = new Float32Array(analyser.fftSize);
        this.timer = setInterval(() => {
          analyser.getFloatTimeDomainData(samples);
          let sum = 0;
          for (const s of samples) sum += s * s;
          report(Math.min(1, Math.sqrt(sum / samples.length) * 6));
        }, 80);
      })
      .catch(() => undefined);
  }

  close() {
    this.closed = true;
    if (this.timer !== undefined) clearInterval(this.timer);
    this.stream?.getTracks().forEach((t) => t.stop());
    void this.context?.close().catch(() => undefined);
  }
}
