# Drawspeak 3D

Drawspeak, for 3D worlds instead of iPad screens. Walk through a running three.js scene or a Roblox place, mark what you want changed, and say it: this thing, this spot, from here to there, or this whole view. The mark stays where you put it as you walk around. When you've marked what you wanted, press Send: a coding agent gets the pictures, your words, the camera, and exactly which objects and places you meant, and edits the code. With hot reload, the change appears in front of you.

It isn't limited to what's already there. "Add a bench here", "a robot walks along this line", "move this over there", "this room feels empty": a comment can ask for anything in the world.

It sits in this fork next to the iPad app (`../App`, `../Packages`) and shares its ideas, its look and its message format. It runs in the browser, with no Xcode. Pens are built in, so an iPad with an Apple Pencil is a matter of serving it there (see the end of this page).

## Try it

```bash
npm install
```

```bash
npm run login
```

```bash
npm run hub
```

```bash
npm run demo
```

`npm run login` signs Claude Code in on the command line, once, with your own Claude account: the copy inside the desktop app has none of its own. No API key is needed. Everything but Send to Agent works without it.

Open `http://localhost:5190/demo/`: a small three.js room, named by nothing but its scene graph. Or on Swing Shop Web: `npm run draw` in `../../swing-shop-web` starts the game and this hub together. Then open it with `?draw`:

```
http://localhost:5180/?draw
```

| To | Do |
|---|---|
| Mark a thing or an area | Hold **C** and circle it with the mouse. A pen draws without any key. Tap C to leave Draw on. |
| Mark one spot, or one thing | In Draw mode, tap. On a floor or a wall it's that spot; on a thing it's that thing. |
| Say "from here to there" | In Draw mode, draw an open line. Along the floor it's a route. Starting on a thing, it's that thing moving. |
| Talk about what's in view | **T**, or the speech-bubble button. No mark: it's about this view, or about the whole experience. |
| Comment | Just talk: voice starts by itself, and silence or **Enter** ends it. You can walk while you talk, or type in the bubble. |
| Send it at once | **Enter** again. That one comment goes to the agent with no window in between, and you keep walking. |
| Point at something more exact | The name under your words opens to the thing's parents (`[` and `]` too), and to what lies behind it. With a pen, press harder for the parent. |
| Comment on the app's own interface | Circle or tap a HUD button. |
| See where you marked | The list button shows your comments. The eye looks from that exact camera; any move of yours brings you back. |
| Look over several, then send | **Send (N)** shows them all, then **Enter** or **Send to Agent**. A card over the game shows what the agent is doing and what it answers. |

Pressing Send starts Claude Code in the project's folder, on your own account. It may read and edit files and run the few commands listed for the project in `hub/projects.json`, plus `hub/look.mjs` (below). It's told not to commit, push, publish or deploy, and it has no other shell access.

Other ways to hand it over:

- **Save Draft** keeps the batch in `~/.drawspeak3d/<project>/batches/<id>/` as plain files: `message.md`, `manifest.json` and pictures.
- **Copy prompt** gives you a line to paste into any other agent, pointing at that folder.
- An agent session that's already open can pull feedback itself over MCP:

```bash
claude mcp add drawspeak3d -- node /path/to/drawspeak123/3d/hub/mcp.ts
```

## What the agent gets

Every comment carries where it is in the world, not only what it's on:

```
2. [Line] Add a small round robot here. It should walk back and forth along this line all the time.
   Target: Floor (mesh, a part of it) · path: Scene/Floor
   From: Floor at (-3.6, 0, 3.8), near Lamp (3), Table (5.6), Shelf (6.5)
   To: Floor at (3.6, 0, 3.8), near Table (3.6), Lamp (4), Shelf (8.1)
   Line: 7.2 long, along the ground, through (-3.6, 0, 3.8) → (-2.4, 0, 3.8) → … → (3.6, 0, 3.8)
```

- **A place** says what it lies on, its middle, how big the mark is, which way the surface faces, and what stands nearby.
- **A line** says where it starts and ends, how long it is, whether it runs along the ground, and what it passes. Its ends say whether they're on a thing ("this thing") or a spot on something big.
- **A view** gives the camera, and where your own character stands, for "next to me".

An app's adapter can add how things get built there (`world.notes`, which goes into every message) and which things are worth naming around a place (`nearby`). With no adapter, the named objects of the scene are used.

Then the agent can look at what it did: `node hub/look.mjs "<view link>" picture.png`. Started by the hub, it asks the page you have open, which draws that view on the real graphics card in a moment, unseen, and it prints any errors on the page. With no page open, it opens that exact view in a silent headless browser (half a minute or so in a big world). An agent compares the picture with yours and fixes what's off.

To try an agent by hand, `demo/batch.mjs` plays a set of requests like these in the demo room and saves them as a draft.

## While you play

You never have to leave the world.

- **Say it, Enter, Enter.** The first Enter ends your sentence and the second sends it. Light rises over what the agent is working on, so it shows from across the room, and the mark says goodbye when it's done. If the agent is stopped or fails, the mark stays, ready to send again. Enter with the bubble gone sends what's waiting.
- **New things are built in front of you.** A file that a page accepts in place (`import.meta.hot.accept`) changes with no reload at all. In Swing Shop anything new is one file in `client/world/live/`: furniture, signs, characters, things that walk. It comes up part by part from the ground, with a ring on the floor, sparks and its name over it, and solid things block the way at once. Saving one file touches nothing else, so agents can't get in each other's way, and a file that fails stops nothing.
- **Don't like it? Undo.** Every finished card can take its change back, with one click: a new thing shrinks out of the world, and its mark returns, ready for another try. Anything changed since is left alone, and so is what was already changed before the run.
- **Everything else is one reload, at a good moment.** An agent saves file after file, and each save would reload the page under you. With `vite-plugin.ts` the page waits until the agent pauses or finishes, and never reloads under a stroke, your words, a window that's open or a mission. You stay where you stood, and the last frame stays up until the new world can melt in, so there's no flash, no loading screen and no welcome.
- **The model is one click away.** The button at the end of the palette chooses Sonnet, Opus, Fable or Haiku, and each card says which one it ran on. Agents run on Sonnet unless you choose otherwise. `DRAWSPEAK_MODEL`, or `"model"` for a project in `hub/projects.json`, changes the default.
- **What's out of sight says which way.** With an agent at work somewhere you aren't looking, an arrow at the edge of the screen points there, like a compass: straight back is straight down. Something built behind you shows its name there too, and stays long enough for you to turn around.
- **What's done stays at hand.** The list of comments ends with what agents have done lately, each with a way to look at it from where you marked it, and its Undo, long after its card has gone.
- **It's quick.** In real runs in the store, a small ice cream stand stood on the marked spot 11 seconds after Enter, and the agent was done at about 30. It depends on what's asked and on how much the agent wants to read first: other runs took up to about 25 seconds. An agent starts up ahead of time and waits, it's told at once how things are made (`world.notes`), so it needn't go and read about it, and each comment sent with Enter starts a new conversation, told what was just done and not taken back. The Send window carries on the last one, unless you tick **New conversation**.

## Several agents at once

You don't have to wait. Press Send, keep walking, mark another part of the world and press Send again: up to three agents work on a project at the same time, each with its own card and its own Stop. They all work in the same folder, so what each one does shows up in the running world straight away.

Each is told that others may be at work (and on what, if they already are), to read a file again right before editing it, and to leave changes it didn't make alone. If two change the same file anyway, both cards say so, because that's worth a look. An agent working alone carries on your last conversation; one that starts while others are at work begins a new one. Each uses your Claude plan like any other session.

## Only for you

It's a tool for whoever is editing the world, and players never get it.

- **In the browser:** it comes only with a development build and `?draw` in the address. Production builds contain none of it, and it refuses to start on a page that isn't served from this computer.
- **In Roblox:** it's a plugin in your own copy of Studio. Nothing goes into the place, `game/src` has none of it, and it does nothing outside Studio.
- **The hub** listens only on this computer. A web page reaches it only from an origin listed for its project, and a program with no origin needs the key in `~/.drawspeak3d/key`.
- **The agent** is told not to commit, push, publish or deploy, so what it changes stays on your computer until you say otherwise.

## Small and big games

It has been measured in a big world (`demo/big.html`: 2.4 million triangles, 9,300 objects, 100,000 instanced trees and 3,475 draw calls, on an Intel UHD 620), and it costs that world about a frame a second. Finishing a circle there takes 110 ms, where it used to take 450. While the pen is down the world rests behind a still copy of its last frame, so ink is smooth however slow the game is. Rays search a tree in big meshes (`three-mesh-bvh`), try only the things under the loop, and instances are spheres first.

It doesn't mind the size of a world, or the kind of camera: `?scale=100` and `?ortho` on the same page work the same. Names come from the scene graph, so "Building 12" is what you marked, not "Box mesh", and seven of them are "7 × Building in City". On a page it knows nothing about (the Tylko showroom, through `attach.js`, with no change to its code) it names shelves and partitions from their objects.

Nor how many passes it's drawn in. A game may draw its world through post-processing, with a map in a corner, a screen on a wall and a HUD as a scene of its own (`demo/passes.html` has them all): nobody has to tell the tool which of those is the world, and what agents are shown is the world alone, without the game's interface.

In a store on the same card, it runs at 60 fps with eight marks, with its panels open and with agents at work. `npm run perf:draw` in `swing-shop-web` measures all this. On a card that struggles it drops the panels' blur by itself.

## Put it on your own three.js app

```ts
if (import.meta.env.DEV) {
  const { attach } = await import("drawspeak3d");
  attach({ renderer, camera, project: { id: "my-app", title: "My App" } });
}
```

Add the project to `hub/projects.json` (or `hub/projects.local.json`, which git ignores) with its folder and the page's origin. Things are named from the scene graph: `object.name`, or `object.userData.drawspeak = { label, kind, source, data }`. For more, pass an `adapter` (`src/three/world.ts`): `swing-shop-web/client/dev/drawspeak.ts` is a full example, where a circled carton is a product in an aisle, not instance 412 of a mesh.

On Vite, `calmReloads()` from `vite-plugin.ts` gives it the calm reloads above:

```ts
import { calmReloads } from "../drawspeak123/3d/vite-plugin.ts";

export default defineConfig({ plugins: [calmReloads()] });
```

To have new things appear with no reload, mount a file the way Swing Shop does (`client/world/liveMount.ts`).

A page you can't change, or would rather not: `npm run build:attach`, then load this before the page's own scripts:

```html
<script src="http://127.0.0.1:8799/attach.js" data-project="my-app"></script>
```

## Roblox

Roblox can't load any of this into a page, so there's a Studio plugin. It draws and picks in the 3D view, in Edit and in Play. The hub takes the picture of the window, and the desk page holds the microphone, which a plugin can't have.

```bash
npm run roblox:install
```

Then, with the hub running:

1. Open `http://127.0.0.1:8799/desk` and press **Turn on the microphone**. Leave the tab open.
2. Open your place in Studio. Allow the plugin to talk to 127.0.0.1 when asked.
3. In the 3D view, hold **X** and circle a thing or an area, tap a spot, or draw a line from here to there. **Shift+X** or **Talk** is about the whole view. Say what should change, or type it.
4. Press **Send**, or during a test press it on the desk: scripts in a place can reach what the plugin uses in Play, so only the desk and the plugin in Edit can start the agent. The agent works in `../../swing-shop`. Rebuild the place to see the result (`node tools/build-place.mjs`).

Marks name Roblox Instances by their full path, with the things inside the loop chosen by the same rules as in the browser, and places and lines work the same way, in studs. **Not yet run in real Studio**: the pure logic and the hub side are tested, and the plugin itself runs in swing-shop's Roblox simulator (`npm run roblox:preview`), which is good but is not Studio.

## How it works

- `src/core`: the rules, with no browser and no three.js. Ported from the iPad app: strokes (`StrokeClassifier`), pressure (`PressureDepthTracker`), numbering, the feedback package. New: what a loop in 3D is about (`selection.ts`), and one gesture language instead of tools (`stroke.ts`): a closed stroke is a circle, an open one a line, a short one a tap.
- `src/three`: from marks on the screen to things and places in the world (`world.ts`), and the tie to the renderer (`host.ts`). A loop on a screen is a cone in the world. Rays sampled inside it say what's visible. Whole things inside the loop beat big things that merely show through it, so circling a carton picks the carton, not the rack behind it. The ink is then lifted onto the surface it was drawn on. A line drawn mostly over level ground lies on that ground, passing behind what stands in the way.
- `src/ui`: marks are drawn on a 2D canvas over the game and re-projected every frame, inside `renderer.render`, with the same camera as the frame. Nothing is added to the app's scene, no shaders are compiled, and marks keep their width at any distance.
- `hub`: a small local program that keeps batches as folders and runs the agent. It listens only on this computer, a web page may reach it only from an origin listed for its project, a program with no origin needs its key (the Studio plugin gets it when installed), and it refuses requests that name another host. `look.mjs` is the agent's eyes.
- `vite-plugin.ts`: holds an agent's run of saves back from the page, and puts the page's last frame up first thing after a reload. Only on the dev server.
- It holds up: an agent silent for 5 minutes or at work for 30 is stopped and says so; agents go when the hub goes; a mistake in a save is told in the tool instead of covering the game; when the hub comes back, the page finds it again and the marks of a lost run return. `npm run draw` brings back a part that falls over.
- `roblox`: the Studio plugin, and its specs (`npm run roblox:check`).

## Checks

```bash
npm test
```

```bash
npm run typecheck
```

```bash
npm run roblox:check
```

The whole flow, played in a silent headless browser with a stand-in agent and scripted speech: `npm run hub:fake` here, then `npm run play:draw` in `swing-shop-web`.

## Not verified yet

- **Three real agents at once.** Two have worked side by side from real speech, in the store. Three at once have only run with stand-ins.
- **Speech in every language.** A real microphone has worked, in Edge, but the browser's engine misheard part of a sentence mixing Polish and English. The bubble is there to fix it, by voice or by typing.
- **A pen on real hardware.** Tests send pen events with force; pressure thresholds need calibrating by hand, as the iPad's ADR-0003 says too.
- **An iPad.** The page needs HTTPS for the microphone there (for example `tailscale serve`), and the hub would have to listen beyond this computer, which it doesn't yet.
- **Real Roblox Studio** (see above), including how places, lines and their heads look there.
