import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { Voice, type VoiceEvents } from "../src/voice/speech.ts";

/** A speech engine that does what it is told, and can hang as real ones do. */
class FakeRecognition {
  static last: FakeRecognition;
  static hangs = false;
  onresult: ((e: { results: Array<{ isFinal: boolean; 0: { transcript: string } }> }) => void) | null = null;
  onerror: ((e: { error: string }) => void) | null = null;
  onend: (() => void) | null = null;
  lang = "";
  continuous = false;
  interimResults = false;
  stops = 0;
  constructor() {
    FakeRecognition.last = this;
  }
  start() {}
  stop() {
    this.stops++;
    if (!FakeRecognition.hangs) setTimeout(() => this.onend?.(), 10);
  }
  abort() {}
  say(transcript: string, isFinal = false) {
    this.onresult?.({ results: [{ isFinal, 0: { transcript } }] });
  }
}

const events = (over: Partial<VoiceEvents> = {}): VoiceEvents => ({ onText() {}, onLevel() {}, onSilence() {}, onFailure() {}, ...over });

beforeEach(() => {
  vi.useFakeTimers();
  FakeRecognition.hangs = false;
  // iOS's user agent: no level meter, so no microphone in these tests.
  vi.stubGlobal("window", { SpeechRecognition: FakeRecognition });
  vi.stubGlobal("navigator", { userAgent: "iPad", platform: "iPad", maxTouchPoints: 5 });
});
afterEach(() => {
  vi.useRealTimers();
  vi.unstubAllGlobals();
});

describe("the voice", () => {
  it("words arrive as they are said, and Stop gives them all", async () => {
    const voice = new Voice();
    const heard: string[] = [];
    voice.start("pl-PL", events({ onText: (t) => heard.push(t) }));
    FakeRecognition.last.say("Zrób");
    FakeRecognition.last.say("Zrób to większe", true);
    const stopped = voice.stop();
    await vi.advanceTimersByTimeAsync(20);
    expect(await stopped).toBe("Zrób to większe");
    expect(heard).toEqual(["Zrób", "Zrób to większe"]);
    expect(voice.active).toBe(false);
  });

  it("an engine that stops by itself is started again, and what it heard stays", async () => {
    const voice = new Voice();
    voice.start("pl-PL", events());
    const first = FakeRecognition.last;
    first.say("Pierwsze", true);
    await vi.advanceTimersByTimeAsync(2000);
    first.onend?.();
    const second = FakeRecognition.last;
    expect(second).not.toBe(first);
    second.say("drugie", true);
    const stopped = voice.stop();
    await vi.advanceTimersByTimeAsync(20);
    expect(await stopped).toBe("Pierwsze drugie");
  });

  it("stopping twice is one stop, and the time limit still holds when the engine hangs", async () => {
    FakeRecognition.hangs = true;
    const voice = new Voice();
    voice.start("pl-PL", events());
    FakeRecognition.last.say("Coś", true);
    const engine = FakeRecognition.last;
    const a = voice.stop();
    await vi.advanceTimersByTimeAsync(250);
    const b = voice.stop();
    expect(b).toBe(a);
    expect(engine.stops).toBe(1);
    await vi.advanceTimersByTimeAsync(1500);
    expect(await a).toBe("Coś");
    expect(voice.active).toBe(false);
  });

  it("silence is reported, and after Stop no more of it", async () => {
    FakeRecognition.hangs = true;
    const voice = new Voice();
    let silences = 0;
    voice.start("pl-PL", events({ onSilence: () => silences++ }));
    await vi.advanceTimersByTimeAsync(voice.silenceWithoutSpeechMs + 300);
    expect(silences).toBeGreaterThan(0);
    const before = silences;
    void voice.stop();
    await vi.advanceTimersByTimeAsync(1000);
    expect(silences).toBe(before);
  });

  it("a new recording during a stop: the old one's words still reach whoever waits", async () => {
    FakeRecognition.hangs = true;
    const voice = new Voice();
    voice.start("pl-PL", events());
    FakeRecognition.last.say("Pierwsza uwaga", true);
    const stopped = voice.stop();
    voice.start("pl-PL", events());
    expect(await stopped).toBe("Pierwsza uwaga");
    expect(voice.active).toBe(true);
    voice.cancel();
  });

  it("no permission is said once, and ends it", () => {
    const voice = new Voice();
    const failures: string[] = [];
    voice.start("pl-PL", events({ onFailure: (r) => failures.push(r) }));
    FakeRecognition.last.onerror?.({ error: "not-allowed" });
    expect(failures).toEqual(["denied"]);
    expect(voice.active).toBe(false);
  });

  it("a browser with no speech recognition says so", () => {
    vi.stubGlobal("window", {});
    const failures: string[] = [];
    new Voice().start("pl-PL", events({ onFailure: (r) => failures.push(r) }));
    expect(failures).toEqual(["unsupported"]);
  });
});
