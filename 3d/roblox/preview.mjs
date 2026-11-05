// Runs the real plugin in swing-shop's Roblox simulator: boots it, plays a stroke against a fake hub,
// reports invalid properties and renders how it looks. Not Studio, but far better than nothing.
//   node roblox/preview.mjs        -> ../swing-shop/build/ui/desktop-plugin-*.png
import { execFileSync } from "node:child_process";
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const swingShop = process.env.SWING_SHOP ?? join(here, "..", "..", "..", "swing-shop");
if (!existsSync(join(swingShop, "tools", "ui-preview.mjs"))) {
  console.log(`No simulator at ${swingShop}. Set SWING_SHOP.`);
  process.exit(1);
}
// Inside a function a module's exported types are plain local ones; its `return` ends that function.
const source = (name) => readFileSync(join(here, "src", name), "utf8").replace(/^export type/gm, "type").replace(/^--!strict\s*$/m, "");
const template = readFileSync(join(here, "tests", "plugin-scenario.template.luau"), "utf8");

const endings = {
  // Two agents at once: the status says so, and reports when both are done.
  "plugin-agents": `
Hub.notes[1].live = "Zrób to większe"
ui.click("Stop")
advance(0.5)
ui.click("Done")
advance(4)
ui.click("Send (1)")
advance(2)
Hub.runs = {
	{ id = "a", status = "running", agent = "Claude Code", activity = { "Editing a.luau" } },
	{ id = "b", status = "running", agent = "Claude Code", activity = { "Editing b.luau" } },
}
advance(2)
local status = gui:FindFirstChild("Status")
step("two agents at work say so", string.find(status.Text, "2 agents are working", 1, true) ~= nil, status.Text)
Hub.runs[1].status = "done"
Hub.runs[1].changed = { "a.luau", "c.luau" }
Hub.runs[1].reply = "Pierwszy gotowy."
advance(2)
step("one done, one still at work", string.find(status.Text, "Claude Code is working", 1, true) ~= nil, status.Text)
Hub.runs[2].status = "done"
Hub.runs[2].changed = { "b.luau" }
Hub.runs[2].reply = "Drugi gotowy."
advance(2)
step("when both are done it says so, with all their files", string.find(status.Text, "2 agents", 1, true) ~= nil and string.find(status.Text, "3 files", 1, true) ~= nil, status.Text)
preview.note("Plugin: two agents, both done")
`,
  // A plugin only runs in Studio; this makes sure that anywhere else it does nothing at all.
  "plugin-outside-studio": `
services.CoreGui:FindFirstChild("Drawspeak3D"):Destroy()
inStudio = false
runPlugin()
advance(0.2)
step("outside Studio the plugin does nothing at all", services.CoreGui:FindFirstChild("Drawspeak3D") == nil)
`,
  // Anything in the world: a spot on the floor, a route, a move, a comment on the whole view.
  "plugin-world": `
local function lastPost()
	local found
	for _, r in Hub.requests do
		if r.method == "POST" and string.match(r.path, "/marks$") then
			found = r.body
		end
	end
	return found
end
local function done(words)
	Hub.notes[#Hub.notes].live = words
	ui.click("Stop")
	advance(0.3)
	ui.click("Done")
	advance(0.3)
end
local function near(a, x, y, z, tolerance)
	return math.abs(a[1] - x) < tolerance and math.abs(a[2] - y) < tolerance and math.abs(a[3] - z) < tolerance
end
local function press(at)
	mouse = at
	P.fireEvent(catcher, "InputBegan", P.inputObject({ UserInputType = Enum.UserInputType.MouseButton1, Position = Vector3.new(at.X, at.Y, 0), KeyCode = Enum.KeyCode.Unknown }), false)
end
local function drawLine(a, b)
	press(a)
	for i = 1, 16 do
		mouseEvent("InputChanged", Enum.UserInputType.MouseMovement, a + (b - a) * (i / 16))
	end
	mouseEvent("InputEnded", Enum.UserInputType.MouseButton1, b)
	advance(0.3)
end
-- Where a point on the floor shows, for this camera (at height 5, looking along -Z).
local function floorPoint(x, z)
	local tangent = math.tan(math.rad(70) / 2)
	local aspect = viewport.X / viewport.Y
	return Vector2.new((x / (-z * tangent * aspect) + 1) / 2 * viewport.X, (1 + 5 / (-z * tangent)) / 2 * viewport.Y)
end
done("Zrób to większe")
step("the palette offers a way to talk about the view", (function()
	for _, child in gui:FindFirstChild("Palette"):GetChildren() do
		if child:IsA("TextButton") and child.Text == "Talk" then
			return true
		end
	end
	return false
end)())
key("X", true)

-- A tap on the floor is a spot.
local spotAt = floorPoint(-2, -9)
press(spotAt)
mouseEvent("InputEnded", Enum.UserInputType.MouseButton1, spotAt)
advance(0.3)
local spot = lastPost()
print("spot: " .. HttpServiceReal:JSONEncode(spot.world.place))
step("a tap on the floor is a spot", spot.shape.kind == "point", spot.shape.kind)
step("the spot is where it was tapped", near(spot.world.place.center, -2, 0, -9, 0.05), HttpServiceReal:JSONEncode(spot.world.place.center))
step("it says what it lies on", spot.world.place.on == "Floor", spot.world.place.on)
local nearLabels = {}
for _, thing in spot.world.place.near do
	table.insert(nearLabels, thing.label)
end
step("and what stands near, without the floor", table.find(nearLabels, "Milk") ~= nil and table.find(nearLabels, "Floor") == nil, table.concat(nearLabels, ","))
step("its ring lies flat on the floor", #spot.world.ink == 20 and math.abs(spot.world.ink[1][2]) < 1e-3)
step("the screen's ring is gone once the mark is saved", #gui:FindFirstChild("Ink"):GetChildren() == 0)
done("Postaw tu ławkę")

-- A line along the floor is a way to walk.
drawLine(floorPoint(-5, -9), floorPoint(5, -9))
local route = lastPost()
print("route: " .. HttpServiceReal:JSONEncode(route.world.path))
step("a line is a line", route.shape.kind == "arrow", route.shape.kind)
step("it lies along the ground", route.world.path.onGround == true)
step("its ends are where they were drawn", near(route.world.path.from.at, -5, 0, -9, 0.05) and near(route.world.path.to.at, 5, 0, -9, 0.05))
step("it knows how long it is", math.abs(route.world.path.length - 10) < 0.2, route.world.path.length)
step("on a floor, not on things", route.world.path.from.isThing == false and route.world.path.to.isThing == false and route.target.partial == true)
done("Tędy niech idą klienci")

-- A straight line starting on a thing moves it.
drawLine(Vector2.new(viewport.X / 2, viewport.Y / 2), floorPoint(-4, -8))
local move = lastPost()
print("move: " .. HttpServiceReal:JSONEncode(move.world.path))
step("a line from a thing starts on the thing", move.world.path.from.isThing == true and move.world.path.from.label == "Milk", move.world.path.from.label)
step("and it is about that thing", move.target.layers[1][move.target.depth + 1].label == "Milk" and move.target.partial == false)
step("it ends where it was drawn, on the floor", move.world.path.to.isThing == false and move.world.path.to.label == "Floor" and near(move.world.path.to.at, -4, 0, -8, 0.05))
step("one straight move, not by way of the ground behind", #move.world.ink == 2 and move.world.path.onGround == false)
done("Przesuń to tutaj")
key("X", false)
advance(0.3)

-- A comment on the whole view: from the palette, and with Shift+X.
ui.click("Talk")
advance(0.3)
local view = lastPost()
step("Talk is a comment on the view, with no ink", view.shape.kind == "view" and #view.world.ink == 0 and view.target == nil)
preview.note("Plugin: a comment on the whole view")
done("Tu jest za pusto")
local before = #Hub.notes
shifted = true
key("X", true)
key("X", false)
shifted = false
advance(0.3)
step("Shift+X is the same, and does not arm the tool", #Hub.notes == before + 1 and lastPost().shape.kind == "view" and catcher.Visible == false)
Hub.notes[#Hub.notes].recording = nil

-- Where the player stands, in a test.
preview.character(Vector3.new(3, 0, 4))
local viewer = SceneModule.viewerOf(Players.LocalPlayer)
step("the player's place is known", viewer ~= nil and math.abs(viewer.position[1] - 3) < 1 and math.abs(viewer.position[3] - 4) < 1 and #viewer.facing == 3)
`,
  // While you speak: the words arrive, the chain can be climbed.
  "plugin-marking": `
Hub.notes[1].text = ""
Hub.notes[1].recording = "recording"
Hub.notes[1].live = "Zrób to opakowanie dwa razy większe"
local bubble = gui:FindFirstChild("Bubble")
for _, child in bubble:GetDescendants() do
	if child:IsA("TextBox") then
		child.Text = Hub.notes[1].live
	end
end
ui.click("Store")
advance(0.2)
local climbed
for _, r in Hub.requests do
	if r.body and r.body.depth then
		climbed = r.body.depth
	end
end
step("a chain chip climbs to a parent", climbed ~= nil and climbed > thingDepth, climbed)
preview.note("Plugin: a mark in Edit mode, voice listening")
`,
  // Stop, the words saved, Send, the agent at work.
  "plugin-sent": `
Hub.notes[1].live = "Zrób to opakowanie dwa razy większe"
ui.click("Stop")
advance(0.5)
ui.click("Done")
advance(4)
local palette = gui:FindFirstChild("Palette")
local sendText
for _, child in palette:GetChildren() do
	if child:IsA("TextButton") and string.find(child.Text, "Send", 1, true) then
		sendText = child.Text
	end
end
step("the palette counts what is ready", sendText == "Send (1)", sendText)
ui.click("Send (1)")
advance(2)
local sent = false
for _, r in Hub.requests do
	sent = sent or string.find(r.path, "/marks/send", 1, true) ~= nil
end
step("Send reaches the hub", sent)
local status = gui:FindFirstChild("Status")
step("the agent's work shows", status.Visible and string.find(status.Text, "Editing game/src/server/StoreBuilder.luau", 1, true) ~= nil, status.Text)
advance(4)
step("sent marks leave the world", marksFolder:FindFirstChild("Pin") == nil)
preview.note("Plugin: sent, the agent at work")
`,
};

const outDir = join(here, "..", "dist", "preview");
mkdirSync(outDir, { recursive: true });
let failed = false;
for (const [name, ending] of Object.entries(endings)) {
  const scenario = template
    .replace("--[[CORE]]", () => source("Core.luau"))
    .replace("--[[SCENE]]", () => source("Scene.luau"))
    .replace("--[[MAIN]]", () => source("Main.server.luau"))
    .replace("--[[ENDING]]", () => ending);
  const file = join(outDir, `${name}.luau`);
  writeFileSync(file, scenario);
  console.log(`--- ${name}`);
  try {
    const out = execFileSync("node", ["tools/ui-preview.mjs", "--scenario", file, "--device", "desktop", "--world", "--scale", "1"], { cwd: swingShop, encoding: "utf8", stdio: ["ignore", "pipe", "pipe"] });
    console.log(out.trim().split("\n").slice(-4).join("\n"));
  } catch (error) {
    failed = true;
    console.log(`${error.stdout ?? ""}${error.stderr ?? ""}`.trim().split("\n").slice(-12).join("\n"));
  }
  const log = join(swingShop, "build", "ui", `desktop-${name}.log`);
  if (existsSync(log)) {
    const lines = readFileSync(log, "utf8").split("\n");
    for (const line of lines) if (/STEP|chain:|BADPROP|ERROR|error|stubbed|unknown/i.test(line)) console.log(`  ${line.slice(0, 200)}`);
    // A step that fails ends the scenario, and the simulator still draws what it has.
    if (lines.some((line) => /^ERROR|BADPROP/.test(line))) failed = true;
  }
}
process.exit(failed ? 1 : 0);
