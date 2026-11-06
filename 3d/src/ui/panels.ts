import { buildPackage, manifestOf, messageText, readiness } from "../core/package.ts";
import { chainOf, selectDepth, selectLayer } from "../core/selection.ts";
import { kindLabel } from "../core/stroke.ts";
import type { AgentDirective, Note, Vec2 } from "../core/types.ts";
import type { RunState } from "../hubClient.ts";
import type { Drawspeak3D } from "../tool.ts";
import { blobToDataUrl, renderComposite, toBlob } from "./composite.ts";
import { ICON, h, iconSpan, leave } from "./dom.ts";

/** The interface of the tool. It stays small while you play, and asks for nothing until there is something to send. */

function button(icon: string | undefined, label: string | undefined, onClick: () => void, options: { class?: string; title?: string; disabled?: boolean; kbd?: string } = {}) {
  return h(
    "button",
    {
      class: `ds3d-btn ${options.class ?? ""}`,
      title: options.title ?? label,
      "aria-label": options.title ?? label,
      disabled: options.disabled,
      // The keyboard belongs to the game: a button that was clicked doesn't keep it (Space is a jump).
      onclick: (e: Event) => {
        const pressed = e.currentTarget as HTMLElement;
        onClick();
        pressed.blur();
      },
    },
    icon && iconSpan(icon),
    label && h("span", { class: "ds3d-label" }, label),
    options.kbd && h("kbd", {}, options.kbd),
  );
}

const setLabel = (el: HTMLElement, text: string) => {
  let label = el.querySelector<HTMLElement>(".ds3d-label");
  if (!label) {
    label = h("span", { class: "ds3d-label" });
    el.append(label);
  }
  if (label.textContent !== text) label.textContent = text;
  label.style.display = text ? "" : "none";
};

const targetText = (note: Note): string => {
  const { path } = note.world;
  if (path) return `${path.from.label ?? "here"} → ${path.to.label ?? "there"}`;
  if (!note.target) return kindLabel(note.shape);
  const chain = chainOf(note.target).slice(note.target.depth);
  return chain.map((e) => e.label).join(" › ") || kindLabel(note.shape);
};

// ------------------------------------------------------------------------------- the palette

const DRAW_HINT = "Circle a thing, tap a spot or draw a line, then say it.";
const FIRST_HINT = "Press <kbd>C</kbd> and circle anything in the world, then say what should change.";
const KNOWS_HOW = "ds3d.knowsHow";

export class Palette {
  private readonly tool: Drawspeak3D;
  private readonly el: HTMLElement;
  private readonly hint: HTMLElement;
  private readonly chip: HTMLElement;
  private readonly draw: HTMLElement;
  private readonly more: HTMLElement;
  private readonly undoButton: HTMLButtonElement;
  private readonly voice: HTMLElement;
  private readonly list: HTMLElement;
  private readonly send: HTMLButtonElement;
  private readonly sendKey = h("kbd", {}, "Enter");
  private voiceOn?: boolean;
  private firstHint = false;
  private knowsHow = false;

  constructor(tool: Drawspeak3D) {
    this.tool = tool;
    this.draw = button(ICON.pencil, "Draw", () => tool.toggleArmed(), { title: "Draw marks on the world (hold or tap C; a pen always draws)", kbd: "C" });
    this.undoButton = button(ICON.undo, undefined, () => tool.undo(), { title: "Undo the last mark (Ctrl+Z)" });
    this.voice = button(ICON.mic, undefined, () => tool.setAutoVoice(!tool.autoVoice));
    // The tools for drawing open out of the palette, and what is under the pointer stays put.
    this.more = h("div", { class: "ds3d-more" }, h("div", {}, h("span", { class: "ds3d-sep" }), this.undoButton, this.voice));
    this.list = button(ICON.list, undefined, () => tool.toggleColumn(), { title: "Comments" });
    this.send = button(ICON.send, "Send", () => tool.openFeedback(), { title: "Feedback: review and send to the agent" });
    this.el = h(
      "div",
      { class: "ds3d-palette ds3d-glass", role: "toolbar", "aria-label": "Drawspeak" },
      this.draw,
      this.more,
      button(ICON.talk, undefined, () => tool.talkAboutView(), { title: "Say something about what is in view, or about the whole experience (T)" }),
      h("span", { class: "ds3d-sep" }),
      this.list,
      this.send,
    );
    this.hint = h("div", { class: "ds3d-hint ds3d-glass" });
    this.chip = h("div", { class: "ds3d-chip-label ds3d-glass" });
    this.chip.style.display = "none";
    tool.root.append(this.chip, this.hint, this.el);
    try {
      this.knowsHow = localStorage.getItem(KNOWS_HOW) !== null;
    } catch {
      this.knowsHow = true;
    }
  }

  render() {
    const t = this.tool;
    if (t.armed) this.learned();
    this.draw.classList.toggle("is-on", t.armed);
    this.more.classList.toggle("is-open", t.armed);
    this.more.inert = !t.armed;
    this.undoButton.disabled = !t.canUndo;
    if (this.voiceOn !== t.autoVoice) {
      this.voiceOn = t.autoVoice;
      const title = t.autoVoice ? "Voice starts after each mark. Click to type instead." : "Voice is off: you type. Click to speak after each mark.";
      this.voice.title = title;
      this.voice.setAttribute("aria-label", title);
      this.voice.replaceChildren(iconSpan(t.autoVoice ? ICON.mic : ICON.micOff));
    }
    const count = t.visibleNotes.length;
    setLabel(this.list, count > 0 ? String(count) : "");
    const ready = t.readyCount;
    setLabel(this.send, ready > 0 ? `Send (${ready})` : "Send");
    this.send.classList.toggle("ds3d-primary", ready > 0);
    // Enter does it too, from anywhere in the world.
    if ((this.sendKey.parentElement !== null) !== ready > 0) {
      if (ready > 0) this.send.append(this.sendKey);
      else this.sendKey.remove();
    }
    this.send.disabled = ready === 0 && t.notes.length === 0;
    const hint = t.armed ? DRAW_HINT : this.firstHint ? FIRST_HINT : undefined;
    if (hint && this.hint.innerHTML !== hint) this.hint.innerHTML = hint;
    this.hint.classList.toggle("is-on", hint !== undefined);
  }

  /** Once, the first time the store is in sight: what this little bar is for. */
  greet() {
    if (this.knowsHow) return;
    this.firstHint = true;
    this.render();
    setTimeout(() => {
      this.learned();
      this.render();
    }, 14_000);
  }

  private learned() {
    this.firstHint = false;
    if (this.knowsHow) return;
    this.knowsHow = true;
    try {
      localStorage.setItem(KNOWS_HOW, "1");
    } catch {
      // it greets again next time, no harm
    }
  }

  /** The name of what a pressed pen is choosing. */
  pressLabel(text: string | undefined, at?: Vec2) {
    if (!text || !at) {
      this.chip.style.display = "none";
      return;
    }
    this.chip.style.display = "";
    this.chip.textContent = text;
    this.chip.style.transform = `translate(${at[0] + 18}px, ${at[1] - 40}px)`;
  }
}

// ------------------------------------------------------------------------------- the bubble

/** Beside the pin while you speak: your words, what they are about, and what to do with them. */
export class Bubble {
  private readonly tool: Drawspeak3D;
  private readonly el: HTMLElement;
  private readonly text: HTMLTextAreaElement;
  private readonly head: HTMLElement;
  private readonly about: HTMLElement;
  private readonly choices: HTMLElement;
  private readonly actions: HTMLElement;
  private readonly problemLine: HTMLElement;
  private time?: HTMLElement;
  private bars: HTMLElement[] = [];
  private closeAt = 0;
  private x = -1;
  private y = -1;
  private noteId?: string;
  /** The thing's parents and what is behind it are one click away. */
  private choosing = false;

  constructor(tool: Drawspeak3D) {
    this.tool = tool;
    this.head = h("div", { class: "ds3d-bubble-head" });
    this.text = h("textarea", {
      class: "ds3d-text",
      rows: 1,
      placeholder: "Say it, or type here…",
      oninput: () => {
        const note = this.tool.active;
        if (note) this.tool.typingStarted(note, this.text.value);
        this.closeAt = 0;
        this.fit();
      },
      onfocus: () => (this.closeAt = 0),
      onkeydown: (e: KeyboardEvent) => {
        // Like a message: Enter sends it, Shift+Enter is a new line.
        if (e.key !== "Enter" || e.shiftKey || e.isComposing) return;
        e.preventDefault();
        e.stopPropagation();
        this.text.blur();
        if (this.tool.recordingNote) void this.tool.stopRecording();
        else if (!this.tool.sendActive()) this.tool.activate(undefined);
      },
    }) as HTMLTextAreaElement;
    this.problemLine = h("div", { class: "ds3d-note-line" });
    this.about = h("div", { class: "ds3d-about-box" });
    this.actions = h("div", { class: "ds3d-actions" });
    this.choices = h("div", { class: "ds3d-choices" });
    this.el = h("div", { class: "ds3d-bubble ds3d-glass" }, this.head, this.text, this.problemLine, h("div", { class: "ds3d-bubble-foot" }, this.about, this.actions), this.choices);
    this.el.style.display = "none";
    // Hovering keeps it from closing by itself.
    this.el.addEventListener("pointerenter", () => (this.closeAt = 0));
    tool.root.append(this.el);
  }

  get visible(): boolean {
    return this.el.style.display !== "none";
  }

  render() {
    const note = this.tool.active;
    if (!note) {
      this.el.style.display = "none";
      this.noteId = undefined;
      return;
    }
    if (this.noteId !== note.id) {
      this.noteId = note.id;
      this.problemLine.textContent = "";
      this.closeAt = 0;
      this.x = -1;
      this.text.value = note.text;
      this.choosing = false;
    }
    this.el.style.display = "";
    const recording = note.recording === "recording";
    const hearing = note.recording === "transcribing";
    this.text.placeholder = recording ? "Listening…" : "Say it, or type here…";
    if (document.activeElement !== this.text && !recording) this.text.value = note.text;
    this.fit();
    this.problemLine.style.display = this.problemLine.textContent ? "" : "none";

    const number = this.tool.numbers.get(note.id) ?? note.ordinal;
    this.bars = [];
    this.time = undefined;
    if (recording) {
      this.time = h("span", { class: "ds3d-time" }, "0:00");
      for (let i = 0; i < 16; i++) this.bars.push(h("i", {}));
      this.head.replaceChildren(
        h("span", { class: "ds3d-rec" }),
        this.time,
        h("div", { class: "ds3d-level" }, ...this.bars),
        this.languageButton(),
      );
    } else if (hearing) {
      this.head.replaceChildren(h("span", { class: "ds3d-spin" }), h("span", {}, "Finishing…"));
    } else {
      this.head.replaceChildren(
        h("span", { class: "ds3d-bubble-title" }, `Comment ${number}`),
        h("div", { class: "ds3d-level" }),
        button(ICON.close, undefined, () => this.tool.activate(undefined), { class: "ds3d-small ds3d-quiet", title: "Close" }),
      );
    }

    this.renderAbout(note);

    const buttons: Array<HTMLElement | false> = [];
    if (recording) {
      buttons.push(
        button(ICON.close, undefined, () => this.tool.discard(note), { class: "ds3d-small ds3d-quiet ds3d-danger", title: "Discard (Esc)" }),
        button(ICON.stop, "Stop", () => void this.tool.stopRecording(), { class: "ds3d-small ds3d-primary", kbd: "Enter" }),
      );
    } else if (!hearing) {
      const said = note.text.trim() !== "";
      const sendable = said && this.tool.canSend(note);
      buttons.push(
        button(ICON.trash, undefined, () => this.tool.deleteNote(note.id), { class: "ds3d-small ds3d-quiet ds3d-danger", title: "Delete this mark (Undo brings it back)" }),
        button(ICON.mic, sendable ? undefined : said ? "Add by voice" : "Speak", () => this.tool.startRecording(note), { class: "ds3d-small ds3d-quiet", title: said ? "Add by voice" : "Speak" }),
        !sendable && said && this.tool.snapshotOf(note) !== undefined && button(ICON.eye, undefined, () => void this.tool.showPicture(note), { class: "ds3d-small ds3d-quiet", title: "See the view with this mark" }),
        sendable && button(ICON.send, "Send", () => void this.tool.sendActive(), { class: "ds3d-small ds3d-primary", title: "Send this to the agent, and keep walking", kbd: "Enter" }),
      );
    }
    this.actions.replaceChildren(...buttons.filter((b): b is HTMLElement => b !== false));
  }

  /** What it is about, in one line; its parents and what stands behind it fold out. */
  private renderAbout(note: Note) {
    const target = note.target;
    if (!target) {
      this.about.replaceChildren(h("span", { class: "ds3d-about is-still" }, h("span", { class: "ds3d-about-name" }, note.shape.kind === "view" ? "The whole view" : kindLabel(note.shape))));
      this.choices.style.display = "none";
      return;
    }
    const chain = chainOf(target);
    const here = chain[target.depth] ?? chain[0];
    const behind = target.layers
      .map((layerChain, layer) => ({ entity: layerChain[0], layer }))
      .filter(({ layer }) => layer !== target.layer)
      .slice(0, 4);
    const more = chain.length > 1 || behind.length > 0;
    this.about.replaceChildren(
      h(
        "button",
        {
          class: `ds3d-about ${this.choosing ? "is-open" : ""} ${more ? "" : "is-still"}`,
          title: more ? `${here.label}: click to choose something else` : here.label,
          disabled: !more,
          onclick: () => {
            this.choosing = !this.choosing;
            this.render();
          },
        },
        h("span", { class: "ds3d-about-name" }, here.label),
        more && iconSpan(ICON.chevron),
      ),
    );
    if (!this.choosing) {
      this.choices.style.display = "none";
      return;
    }
    const links: HTMLElement[] = [];
    chain.forEach((entity, depth) => {
      if (depth > 0) links.push(h("span", { class: "ds3d-link-sep" }, "›"));
      links.push(h("button", { class: `ds3d-link ${depth === target.depth ? "is-current" : ""}`, title: `${entity.label} (${entity.kind})`, onclick: () => this.tool.setTarget(note, selectDepth(target, depth)) }, entity.label));
    });
    this.choices.replaceChildren(h("div", { class: "ds3d-chain" }, ...links));
    if (behind.length > 0) this.choices.append(h("div", { class: "ds3d-behind" }, "Or:", ...behind.map(({ entity, layer }) => h("button", { class: "ds3d-link", title: `${entity.label} (${entity.kind})`, onclick: () => this.tool.setTarget(note, selectLayer(target, layer)) }, entity.label))));
    this.choices.style.display = "";
  }

  private languageButton() {
    const t = this.tool;
    return h(
      "button",
      {
        class: "ds3d-lang",
        title: "Language of your speech",
        onclick: () => t.setLanguage(t.lang.startsWith("pl") ? "en-US" : "pl-PL"),
      },
      t.lang.startsWith("pl") ? "PL" : "EN",
    );
  }

  private fit() {
    this.text.style.height = "auto";
    this.text.style.height = `${Math.min(148, Math.max(46, this.text.scrollHeight + 2))}px`;
  }

  liveText(text: string) {
    if (document.activeElement === this.text) return;
    this.text.value = text;
    this.fit();
  }

  level(level: number) {
    if (this.bars.length === 0) return;
    // The newest level on the right, older ones moving left.
    for (let i = 0; i < this.bars.length - 1; i++) this.bars[i].style.height = this.bars[i + 1].style.height;
    this.bars[this.bars.length - 1].style.height = `${3 + level * 13}px`;
  }

  problem(text: string) {
    this.problemLine.textContent = text;
    this.render();
  }

  focusText() {
    this.render();
    this.text.focus();
  }

  closeSoon() {
    this.closeAt = performance.now() + 4500;
  }

  /** ] goes up to the parent, [ back down. */
  climb(step: number) {
    const note = this.tool.active;
    if (note?.target) this.tool.setTarget(note, selectDepth(note.target, note.target.depth + step));
  }

  tick() {
    if (this.time) {
      const seconds = Math.floor(this.tool.recordingSeconds);
      const text = `${Math.floor(seconds / 60)}:${String(seconds % 60).padStart(2, "0")}`;
      if (this.time.textContent !== text) this.time.textContent = text;
    }
    if (this.closeAt > 0 && performance.now() > this.closeAt && document.activeElement !== this.text) {
      this.closeAt = 0;
      this.tool.activate(undefined);
    }
  }

  /** Beside the pin, inside the screen (the iPad's RecordingBubblePlacement). Off screen: docked low on the left. */
  place(pin: Vec2 | undefined) {
    const width = this.el.offsetWidth;
    const height = this.el.offsetHeight;
    const margin = 10;
    let x: number;
    let y: number;
    if (pin && pin[0] > -40 && pin[0] < innerWidth + 40 && pin[1] > -40 && pin[1] < innerHeight + 40) {
      const gap = 26;
      x = pin[0] + gap + width <= innerWidth - margin ? pin[0] + gap : pin[0] - gap - width;
      y = pin[1] - height / 2;
    } else {
      x = margin + 80;
      y = innerHeight - height - 76;
    }
    x = Math.min(Math.max(x, margin), Math.max(margin, innerWidth - width - margin));
    // Above the palette, which is where the bottom of the screen ends for it.
    y = Math.min(Math.max(y, margin), Math.max(margin, innerHeight - height - 68));
    // It follows the pin softly, so it does not shake as you walk.
    if (this.x < 0) {
      this.x = x;
      this.y = y;
    } else {
      this.x += (x - this.x) * 0.25;
      this.y += (y - this.y) * 0.25;
    }
    this.el.style.transform = `translate(${this.x.toFixed(1)}px, ${this.y.toFixed(1)}px)`;
  }
}

// ------------------------------------------------------------------------------- the comments

export class Column {
  private readonly tool: Drawspeak3D;
  private readonly el: HTMLElement;
  private readonly list: HTMLElement;
  private readonly head: HTMLElement;
  private readonly thumbs = new Map<string, string>();
  open = false;
  private renderedKey = "";

  constructor(tool: Drawspeak3D) {
    this.tool = tool;
    this.head = h("div", { class: "ds3d-column-head" });
    this.list = h("div", { class: "ds3d-column-list" });
    this.el = h("div", { class: "ds3d-column ds3d-glass" }, this.head, this.list);
    this.el.style.display = "none";
    tool.root.append(this.el);
  }

  toggle() {
    this.open = !this.open;
    this.renderedKey = "";
    if (this.open) {
      this.el.classList.remove("ds3d-leaving");
      this.el.style.display = "";
      this.render();
      return;
    }
    this.el.classList.add("ds3d-leaving");
    setTimeout(() => {
      if (this.open) return;
      this.el.style.display = "none";
      this.el.classList.remove("ds3d-leaving");
    }, 160);
  }

  /** Text fields keep focus and caret: only rebuilt when the list itself changes. */
  render() {
    if (!this.open) return;
    const t = this.tool;
    const notes = t.visibleNotes;
    const sent = t.notes.filter((n) => readiness(n) === "sent").length;
    const key = JSON.stringify([notes.map((n) => [n.id, readiness(n), t.numbers.get(n.id), n.target?.depth, n.target?.layer, document.activeElement?.getAttribute("data-note") === n.id ? "" : n.text]), t.showSent, sent, t.active?.id]);
    if (key === this.renderedKey) return;
    this.renderedKey = key;
    this.head.replaceChildren(
      h("span", {}, "Comments"),
      h(
        "div",
        { class: "ds3d-card-buttons" },
        sent > 0 && button(undefined, t.showSent ? "Hide sent" : `Sent (${sent})`, () => {
          t.showSent = !t.showSent;
          t.changed();
        }, { class: "ds3d-small" }),
        t.showSent && sent > 0 && button(undefined, "Clear sent", () => t.clearSent(), { class: "ds3d-small ds3d-danger" }),
        button(ICON.close, undefined, () => this.toggle(), { class: "ds3d-small", title: "Close" }),
      ),
    );
    if (notes.length === 0) {
      this.list.replaceChildren(h("div", { class: "ds3d-empty" }, sent > 0 ? "All sent. Circle something new to go on." : "Hold C and circle something in the world, then say what should change."));
      return;
    }
    this.list.replaceChildren(...notes.map((note) => this.card(note)));
  }

  private card(note: Note): HTMLElement {
    const t = this.tool;
    const number = t.numbers.get(note.id) ?? note.ordinal;
    const state = readiness(note);
    const image = h("img", { alt: "", onclick: () => void t.showPicture(note), title: "See the view with this mark" }) as HTMLImageElement;
    void this.thumb(note, number).then((url) => url && (image.src = url));
    const text = h("textarea", {
      class: "ds3d-card-text",
      rows: 1,
      placeholder: state === "recording" ? "Listening…" : "No comment yet",
      "data-note": note.id,
      value: note.text,
      disabled: state === "recording",
      oninput: () => {
        t.setText(note, text.value, note.textSource === "voice" ? "edited" : "typed");
        grow();
      },
    }) as HTMLTextAreaElement;
    const grow = () => {
      text.style.height = "auto";
      text.style.height = `${text.scrollHeight + 2}px`;
    };
    requestAnimationFrame(grow);
    return h(
      "div",
      { class: `ds3d-card ${t.active?.id === note.id ? "is-active" : ""}` },
      h("div", { class: `ds3d-card-pin ${state === "sent" ? "is-sent" : ""}` }, String(number)),
      h(
        "div",
        { class: "ds3d-card-body" },
        image,
        text,
        h(
          "div",
          { class: "ds3d-card-meta" },
          h("span", { class: "ds3d-card-target", title: targetText(note) }, targetText(note)),
          h(
            "div",
            { class: "ds3d-card-buttons" },
            button(ICON.eye, undefined, () => t.lookFrom(note), { title: "Look from where this was marked (any move of yours brings you back)" }),
            button(ICON.mic, undefined, () => t.startRecording(note), { title: "Add by voice" }),
            button(ICON.trash, undefined, () => t.deleteNote(note.id), { class: "ds3d-danger", title: "Delete" }),
          ),
        ),
      ),
    );
  }

  private async thumb(note: Note, number: number): Promise<string | undefined> {
    const key = `${note.id}:${number}`;
    const cached = this.thumbs.get(key);
    if (cached) return cached;
    const image = await this.tool.pictureOf(note.snapshotId);
    if (!image) return undefined;
    const canvas = await renderComposite(image, [{ number, note }], 640);
    const url = canvas.toDataURL("image/jpeg", 0.8);
    this.thumbs.set(key, url);
    return url;
  }
}

// ------------------------------------------------------------------------------- send

/** Feedback (N) → preview → Send to Agent / Save Draft. Two clicks once the comments are there. */
export class Sheet {
  private readonly tool: Drawspeak3D;
  private scrim?: HTMLElement;
  private chosen = new Set<string>();
  private directive: AgentDirective = { mode: "apply", note: "" };
  private newThread = false;
  private busy = false;
  private frozenIds = new Set<string>();

  constructor(tool: Drawspeak3D) {
    this.tool = tool;
  }

  get open(): boolean {
    return this.scrim !== undefined;
  }

  /** Pictures are on their way to the hub. */
  get sending(): boolean {
    return this.busy;
  }

  close() {
    if (!this.scrim) return;
    this.tool.adapter.freeze?.(false);
    leave(this.scrim);
    this.scrim = undefined;
  }

  /** Enter, with the window open: what is ticked goes. */
  sendChosen() {
    if (this.chosen.size > 0 && !this.busy) void this.deliver("send");
  }

  /** Said and done: one comment goes to the agent as it is, with no window in the way. */
  async sendOne(note: Note): Promise<boolean> {
    if (this.busy) return false;
    this.chosen = new Set([note.id]);
    this.directive = { mode: "apply", note: "" };
    return this.deliver("send");
  }

  show() {
    const t = this.tool;
    const ready = t.notes.filter((n) => readiness(n) === "ready");
    this.frozenIds = new Set(ready.map((n) => n.id));
    this.chosen = new Set(this.frozenIds);
    this.directive = { mode: "apply", note: "" };
    this.close();
    // The keys are for the text field here, not for walking under the window.
    t.adapter.freeze?.(true);
    this.scrim = h("div", {
      class: "ds3d-scrim",
      onpointerdown: (e: Event) => {
        if (e.target === this.scrim) this.close();
      },
    });
    t.root.append(this.scrim);
    this.render();
    void t.refreshHub().then(() => this.render());
  }

  private render() {
    if (!this.scrim) return;
    const t = this.tool;
    const numbers = t.numbers;
    const ready = t.notes.filter((n) => this.frozenIds.has(n.id));
    const waiting = t.notes.filter((n) => readiness(n) === "markOnly" || n.recording);
    const hub = t.hubProject;
    const groups = new Map<string, Note[]>();
    for (const note of ready) groups.set(note.snapshotId, [...(groups.get(note.snapshotId) ?? []), note]);

    const body: HTMLElement[] = [];
    if (ready.length === 0) body.push(h("div", { class: "ds3d-empty" }, "Nothing to send yet: a mark needs a comment first."));
    for (const [snapshotId, notes] of groups) {
      const snapshot = t.snapshots.find((s) => s.id === snapshotId);
      const picture = h("img", { alt: "" }) as HTMLImageElement;
      void this.preview(snapshotId, notes).then((url) => url && (picture.src = url));
      body.push(
        h(
          "div",
          { class: "ds3d-group" },
          picture,
          h(
            "div",
            {},
            h("h3", {}, snapshot?.title ?? "View"),
            ...notes.map((note) =>
              h(
                "label",
                { class: "ds3d-item" },
                h("input", {
                  type: "checkbox",
                  checked: this.chosen.has(note.id),
                  onchange: (e: Event) => {
                    if ((e.target as HTMLInputElement).checked) this.chosen.add(note.id);
                    else this.chosen.delete(note.id);
                    this.renderFoot();
                  },
                }),
                h("div", { class: "ds3d-card-pin" }, String(numbers.get(note.id) ?? note.ordinal)),
                h("div", {}, h("div", { class: "ds3d-item-text" }, note.text.trim()), h("div", { class: "ds3d-item-target" }, targetText(note))),
              ),
            ),
          ),
        ),
      );
    }
    if (waiting.length > 0) {
      body.push(h("div", { class: "ds3d-pending" }, `${waiting.length} mark${waiting.length === 1 ? "" : "s"} without a comment stay${waiting.length === 1 ? "s" : ""} here and ${waiting.length === 1 ? "is" : "are"} not sent.`));
    }
    const trouble = hub && (hub.agent.problem ?? (hub.agent.available ? undefined : `${hub.agent.label} was not found.`));
    const to = hub
      ? h("div", { class: "ds3d-to" }, h("span", { class: `ds3d-dot ${trouble ? "off" : ""}` }), trouble ? `${trouble} Save Draft and Copy prompt still work.` : `To: ${hub.agent.label} in ${hub.folder}${this.tool.agentsWorking > 0 ? ` · ${this.tool.agentsWorking} already at work, this one joins ${this.tool.agentsWorking === 1 ? "it" : "them"}` : ""}`)
      : h("div", { class: "ds3d-to" }, h("span", { class: "ds3d-dot off" }), "The hub is not running: start it with npm run hub (in drawspeak123/3d)");
    this.scrim.replaceChildren(
      h(
        "div",
        { class: "ds3d-sheet ds3d-glass", role: "dialog", "aria-label": "Send feedback" },
        h(
          "div",
          { class: "ds3d-sheet-head" },
          h("div", {}, h("h2", {}, "Send feedback"), to),
          button(ICON.close, undefined, () => this.close(), { title: "Close" }),
        ),
        h("div", { class: "ds3d-sheet-body" }, ...body),
        h("div", { class: "ds3d-sheet-foot", id: "ds3d-foot" }),
      ),
    );
    this.renderFoot();
  }

  private renderFoot() {
    const foot = this.scrim?.querySelector("#ds3d-foot");
    if (!foot) return;
    const hub = this.tool.hubProject;
    const count = this.chosen.size;
    const seg = (mode: AgentDirective["mode"], label: string) =>
      h(
        "button",
        {
          class: this.directive.mode === mode ? "is-chosen" : "",
          onclick: () => {
            this.directive.mode = mode;
            this.renderFoot();
          },
        },
        label,
      );
    const extra = h("input", {
      class: "ds3d-extra",
      type: "text",
      placeholder: "Anything else for the agent? (optional)",
      value: this.directive.note,
      oninput: (e: Event) => (this.directive.note = (e.target as HTMLInputElement).value),
      onkeydown: (e: KeyboardEvent) => {
        if (e.key === "Enter") this.sendChosen();
      },
    });
    foot.replaceChildren(
      h("div", { class: "ds3d-direct" }, h("div", { class: "ds3d-seg" }, seg("apply", "Make the changes"), seg("replyOnly", "Just reply")), extra),
      h(
        "div",
        { class: "ds3d-foot-row" },
        h(
          "label",
          { class: "ds3d-check", title: "Off: the agent carries on from your last batch, and remembers it" },
          h("input", {
            type: "checkbox",
            checked: this.newThread,
            onchange: (e: Event) => (this.newThread = (e.target as HTMLInputElement).checked),
          }),
          "New conversation",
        ),
        h(
          "div",
          { class: "ds3d-foot-buttons" },
          button(undefined, "Copy prompt", () => void this.deliver("copy"), { disabled: count === 0 || this.busy, title: "Saves the batch, and copies a prompt for any other agent" }),
          button(undefined, "Save Draft", () => void this.deliver("draft"), { disabled: count === 0 || !hub || this.busy, title: "Saves the batch in the inbox without running the agent" }),
          button(ICON.send, this.busy ? "Sending…" : `Send to Agent${count > 0 ? ` (${count})` : ""}`, () => void this.deliver("send"), { class: "ds3d-primary", disabled: count === 0 || !hub?.agent.available || hub.agent.problem !== undefined || this.busy }),
        ),
      ),
    );
  }

  private async preview(snapshotId: string, notes: Note[]): Promise<string | undefined> {
    const image = await this.tool.pictureOf(snapshotId);
    if (!image) return undefined;
    const numbers = this.tool.numbers;
    const canvas = await renderComposite(image, notes.map((note) => ({ number: numbers.get(note.id) ?? note.ordinal, note })), 900);
    return canvas.toDataURL("image/jpeg", 0.85);
  }

  /** Freezes what is shown, and hands it over. */
  private async deliver(how: "send" | "draft" | "copy"): Promise<boolean> {
    if (this.busy) return false;
    const t = this.tool;
    this.busy = true;
    this.renderFoot();
    try {
      const ids = new Set(this.chosen);
      const stamp = new Date().toISOString().replace(/[-:]/g, "").replace("T", "-").slice(0, 15);
      const batchId = `${stamp}-${Math.random().toString(36).slice(2, 6)}`;
      const pkg = buildPackage({
        batchId,
        project: t.project,
        notes: t.notes,
        snapshots: t.snapshots,
        noteIds: ids,
        directive: { ...this.directive },
        now: new Date().toISOString(),
        revision: t.hubProject?.revision,
        world: t.worldInfo(),
      });
      const message = messageText(pkg);
      const files: Array<{ name: string; dataUrl: string }> = [];
      if (t.hubProject) {
        for (const group of pkg.groups) {
          const image = await t.pictureOf(group.snapshot.id);
          if (!image) throw new Error(`The picture of "${group.snapshot.title}" is missing`);
          const composite = await renderComposite(image, group.items, 1600);
          files.push({ name: group.compositeFileName, dataUrl: await blobToDataUrl(await toBlob(composite, 0.9)) });
          files.push({ name: group.cleanFileName, dataUrl: await blobToDataUrl(image) });
        }
      }
      if (how === "copy" && !t.hubProject) {
        await navigator.clipboard.writeText(message);
        t.toast("Copied the comments as text. Start the hub to send the pictures too.");
        this.close();
        return true;
      }
      const saved = await t.hub.saveBatch({ batchId, message, manifest: manifestOf(pkg), files });
      if (how === "send") {
        await t.hub.send(batchId, { noteIds: [...ids], newThread: this.newThread });
        t.markSent(ids);
        this.newThread = false;
      } else if (how === "draft") {
        t.toast(`Draft saved: ${saved.folder}`);
      } else {
        await navigator.clipboard.writeText(`Read ${saved.messageFile} and the pictures next to it, then do what it says. To see a change as the reviewer will, run node "${saved.look}" "<the view's Open this view link>" "${saved.folder}/after-1.png" and read that picture.`);
        t.toast("Prompt copied. Paste it to any agent.");
      }
      this.close();
      return true;
    } catch (error) {
      t.toast(error instanceof Error ? error.message : String(error), true);
      return false;
    } finally {
      this.busy = false;
      this.renderFoot();
    }
  }
}

// ------------------------------------------------------------------------------- the agent at work

const NOT_SHOWN = "ds3d.runs.dismissed";
const MOST_CARDS = 4;

const elapsed = (run: RunState): string => {
  const seconds = Math.max(0, Math.floor((Date.now() - Date.parse(run.startedAt)) / 1000));
  return `${Math.floor(seconds / 60)}:${String(seconds % 60).padStart(2, "0")}`;
};
const lastLine = (run: RunState) => run.activity[run.activity.length - 1] ?? "Reading your comments…";

interface RunCard {
  status: RunState["status"];
  el: HTMLElement;
  line?: HTMLElement;
  clock?: HTMLElement;
  run: RunState;
  /** How long a finished card stays, counted only while the world is being looked at. */
  staysFor?: number;
  held?: boolean;
}

/** A card for each agent at work and each that just finished, over the world. Good news leaves by itself. */
export class RunCards {
  private readonly tool: Drawspeak3D;
  private readonly el: HTMLElement;
  private runs: RunState[] = [];
  private readonly seenWorking = new Set<string>();
  /** The comments an agent is working on right now. */
  readonly workingNotes = new Set<string>();
  /** Kept between updates: a press on a button that gets rebuilt half way is lost. */
  private readonly cards = new Map<string, RunCard>();
  private lastTick = performance.now();

  constructor(tool: Drawspeak3D) {
    this.tool = tool;
    this.el = h("div", { class: "ds3d-runs" });
    this.el.style.display = "none";
    tool.root.append(this.el);
  }

  get working(): number {
    return this.runs.filter((run) => run.status === "running").length;
  }

  update(runs: RunState[]) {
    this.runs = runs;
    this.workingNotes.clear();
    for (const run of runs) if (run.status === "running") for (const id of run.noteIds ?? []) this.workingNotes.add(id);
    this.render();
  }

  /** A run seen working here, or just finished (an agent's edit reloads the page): an old one is no news. */
  private isNews(run: RunState): boolean {
    return this.seenWorking.has(run.id) || Date.now() - Date.parse(run.endedAt ?? run.startedAt) < 180_000;
  }

  private dismissed(): string[] {
    try {
      return JSON.parse(localStorage.getItem(NOT_SHOWN) ?? "[]") as string[];
    } catch {
      return [];
    }
  }

  private dismiss(run: RunState) {
    try {
      localStorage.setItem(NOT_SHOWN, JSON.stringify([...this.dismissed(), run.id].slice(-24)));
    } catch {
      // it shows again after a reload, no harm
    }
    this.seenWorking.delete(run.id);
    this.runs = this.runs.filter((other) => other.id !== run.id);
    this.render();
  }

  private fadeAway(run: RunState, el: HTMLElement) {
    el.classList.add("ds3d-leaving");
    setTimeout(() => this.dismiss(run), 170);
  }

  private render() {
    const gone = this.dismissed();
    const atWork = this.runs.filter((run) => run.status === "running");
    for (const run of atWork) this.seenWorking.add(run.id);
    const finished = this.runs.filter((run) => run.status !== "running" && !gone.includes(run.id) && this.isNews(run)).reverse();
    const shown = [...atWork, ...finished].slice(0, MOST_CARDS);
    for (const id of this.cards.keys()) if (!shown.some((run) => run.id === id)) this.cards.delete(id);
    const wanted = shown.map((run) => this.card(run));
    const current = [...this.el.children];
    if (wanted.length !== current.length || wanted.some((card, i) => card !== current[i])) this.el.replaceChildren(...wanted);
    this.el.style.display = shown.length > 0 ? "" : "none";
  }

  private card(run: RunState): HTMLElement {
    const known = this.cards.get(run.id);
    // A finished agent's card can still learn that a later one changed the same file.
    if (known?.status === run.status && known.run.shared?.length === run.shared?.length) {
      known.run = run;
      if (known.line && known.line.textContent !== lastLine(run)) known.line.textContent = lastLine(run);
      return known.el;
    }
    const made = run.status === "running" ? this.workingCard(run) : this.finishedCard(run);
    const card: RunCard = { status: run.status, run, ...made };
    this.cards.set(run.id, card);
    if (run.status === "done" && !run.shared?.length) {
      // Time to read it, and a pointer resting on it keeps it.
      card.staysFor = Math.min(30_000, 10_000 + (run.reply?.length ?? 0) * 45);
      made.el.addEventListener("pointerenter", () => (card.held = true));
      made.el.addEventListener("pointerleave", () => (card.held = false));
    }
    return made.el;
  }

  private workingCard(run: RunState) {
    const clock = h("span", { class: "ds3d-time ds3d-run-clock" }, elapsed(run));
    const line = h("div", { class: "ds3d-run-line" }, lastLine(run));
    const el = h(
      "div",
      { class: "ds3d-run ds3d-glass is-working" },
      h(
        "div",
        { class: "ds3d-run-head" },
        h("span", { class: "ds3d-spin" }),
        h("span", { class: "ds3d-run-title", title: run.about ?? "" }, run.about ?? `${run.agent} is working`),
        clock,
        button(ICON.stop, undefined, () => void this.tool.hub.stop(run.id), { class: "ds3d-small ds3d-quiet ds3d-danger", title: "Stop this agent" }),
      ),
      line,
      h("div", { class: "ds3d-run-going" }),
    );
    return { el, line, clock };
  }

  private finishedCard(run: RunState) {
    const ok = run.status === "done";
    const files = run.changed ?? [];
    const title = ok ? (run.about ?? "Done") : run.status === "stopped" ? "Stopped" : "The agent could not finish";
    const close = () => this.fadeAway(run, el);
    const parts: HTMLElement[] = [
      h(
        "div",
        { class: "ds3d-run-head" },
        iconSpan(ok ? ICON.check : ICON.close, ok ? "ds3d-run-ok" : "ds3d-run-bad"),
        h("span", { class: "ds3d-run-title", title }, title),
        ok && (run.noteIds?.length ?? 0) > 0 ? button(ICON.eye, "See it", () => this.tool.seeRun(run), { class: "ds3d-small ds3d-quiet", title: "Look from where you marked it (any move of yours brings you back)" }) : null,
        button(ICON.close, undefined, close, { class: "ds3d-small ds3d-quiet", title: "Close" }),
      ),
    ];
    if (!ok && run.about) parts.push(h("div", { class: "ds3d-run-line" }, `${run.about}${run.noteIds?.length ? " · still marked, ready to send again" : ""}`));
    if (run.reply || run.error) parts.push(h("div", { class: "ds3d-run-reply" }, run.reply ?? run.error ?? ""));
    if (files.length > 0) {
      const count = `${files.length} file${files.length === 1 ? "" : "s"} changed`;
      const list = files.join(" · ");
      const line: HTMLElement = h("button", { class: "ds3d-run-files", title: list, onclick: () => (line.textContent = line.textContent === count ? list : count) }, count);
      parts.push(line);
    }
    if (run.shared?.length) parts.push(h("div", { class: "ds3d-run-shared" }, `Another agent changed this too, worth a look: ${run.shared.join(", ")}`));
    const el = h("div", { class: "ds3d-run ds3d-glass" }, ...parts);
    return { el };
  }

  tick() {
    const now = performance.now();
    // Frames only come while the world is in sight, and the steps are capped: a reply does not leave while you are away.
    const step = Math.min(now - this.lastTick, 100);
    this.lastTick = now;
    for (const card of this.cards.values()) {
      if (card.clock) {
        const text = elapsed(card.run);
        if (card.clock.textContent !== text) card.clock.textContent = text;
      }
      if (card.staysFor === undefined || card.held) continue;
      card.staysFor -= step;
      if (card.staysFor <= 0) {
        card.staysFor = undefined;
        this.fadeAway(card.run, card.el);
      }
    }
  }
}

export class Toast {
  private readonly root: HTMLElement;
  private el?: HTMLElement;
  private timer?: ReturnType<typeof setTimeout>;

  constructor(root: HTMLElement) {
    this.root = root;
  }

  show(text: string, warn = false) {
    this.el?.remove();
    clearTimeout(this.timer);
    const el = h("div", { class: `ds3d-toast ds3d-glass ${warn ? "warn" : ""}` }, text);
    this.root.append(el);
    this.el = el;
    this.timer = setTimeout(() => leave(el), warn ? 7000 : 3200);
  }
}

export function lightbox(root: HTMLElement, url: string) {
  const scrim = h("div", { class: "ds3d-scrim ds3d-picture", onpointerdown: () => leave(scrim) }, h("img", { class: "ds3d-lightbox", src: url, alt: "The view with its mark" }));
  root.append(scrim);
}
