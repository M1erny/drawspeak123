-- Drawspeak 3D in Roblox Studio. In the 3D view, in Edit or in Play: hold X (or press Draw) and circle
-- a thing or an area, tap a spot, or draw a line from here to there; or press Shift+X to talk about the
-- whole view. Say what should change, and send it to a coding agent. The hub (npm run hub, in
-- drawspeak123/3d) takes the picture and runs the agent; its desk page holds the microphone, which a
-- plugin cannot have. Nothing is added to the place: all of this lives in CoreGui, and goes when you
-- close Studio.
--
-- Studio runs a plugin once for Edit, and during Play once more for the client and for the server. The
-- client may not make web requests, so there the server's copy carries them.

local CoreGui = game:GetService("CoreGui")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Core = require(script.Core)
local Scene = require(script.Scene)

local HUB = "http://127.0.0.1:8799"
-- Filled in when the plugin is installed: it shows the hub that this is the plugin, not a script in the place.
local KEY = "__DRAWSPEAK_KEY__"
local BRIDGE = "Drawspeak3DBridge"
local HOTKEY = Enum.KeyCode.X
local HINT = "Circle a thing or an area, tap a spot, or draw a line from here to there. Then say it."
local INK = Color3.fromRGB(189, 48, 72)
local ACTION = Color3.fromRGB(23, 88, 189)
local OUTLINE = Color3.fromRGB(77, 141, 255)
local GLASS = Color3.fromRGB(24, 27, 31)
local WHITE = Color3.new(1, 1, 1)
local SOFT = Color3.fromRGB(185, 194, 207)
local FONT = Enum.Font.GothamMedium
local BOLD = Enum.Font.GothamBold

local function rawRequest(method: string, path: string, body: any): (boolean, any)
	local ok, response = pcall(function()
		return HttpService:RequestAsync({
			Url = HUB .. path,
			Method = method,
			Headers = { ["Content-Type"] = "application/json", ["X-Drawspeak-Key"] = KEY },
			Body = if body ~= nil then HttpService:JSONEncode(body) else nil,
		})
	end)
	if not ok then
		return false, tostring(response)
	end
	local decoded = nil
	pcall(function()
		decoded = HttpService:JSONDecode(response.Body)
	end)
	if not response.Success then
		return false, (decoded and decoded.error) or response.StatusMessage
	end
	return true, decoded
end

local isPlaying = RunService:IsRunning()

-- The server's copy, during Play: only carries requests for the client's.
if isPlaying and RunService:IsServer() then
	local bridge = Instance.new("RemoteFunction")
	bridge.Name = BRIDGE
	bridge.Archivable = false
	bridge.Parent = ReplicatedStorage
	bridge.OnServerInvoke = function(_player, method: string, path: string, body: any)
		if not Core.allowedOverBridge(method, path) then
			return false, "Not during a test."
		end
		return rawRequest(method, path, body)
	end
	return
end

local bridge: RemoteFunction? = nil
if isPlaying then
	bridge = ReplicatedStorage:WaitForChild(BRIDGE, 15) :: RemoteFunction?
end

local function request(method: string, path: string, body: any): (boolean, any)
	if isPlaying then
		if not bridge then
			return false, "The plugin's server side did not start."
		end
		local ok, a, b = pcall(function()
			return (bridge :: RemoteFunction):InvokeServer(method, path, body)
		end)
		if not ok then
			return false, tostring(a)
		end
		return a, b
	end
	return rawRequest(method, path, body)
end

-- ---------------------------------------------------------------------------- a little UI kit

local function make(class: string, props: { [string]: any }, children: { Instance }?): any
	local instance = Instance.new(class)
	for name, value in props do
		(instance :: any)[name] = value
	end
	for _, child in children or {} do
		child.Parent = instance
	end
	return instance
end

local function corner(radius: number)
	return make("UICorner", { CornerRadius = UDim.new(0, radius) })
end

local function stroke()
	return make("UIStroke", { Color = WHITE, Transparency = 0.86, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end

local function padding(all: number)
	local p = UDim.new(0, all)
	return make("UIPadding", { PaddingLeft = p, PaddingRight = p, PaddingTop = p, PaddingBottom = p })
end

local function button(text: string, width: number, color: Color3?, onClick: () -> ()): TextButton
	local b = make("TextButton", {
		Size = UDim2.fromOffset(width, 34),
		BackgroundColor3 = color or WHITE,
		BackgroundTransparency = if color then 0 else 0.92,
		AutoButtonColor = true,
		Font = FONT,
		TextSize = 14,
		TextColor3 = WHITE,
		Text = text,
		BorderSizePixel = 0,
	}, { corner(12) })
	b.Activated:Connect(onClick)
	return b
end

-- ---------------------------------------------------------------------------- what is on screen

-- CoreGui keeps all of it out of the place, in Edit too.
for _, name in { "Drawspeak3D", "Drawspeak3DMarks" } do
	local old = CoreGui:FindFirstChild(name)
	if old then
		old:Destroy()
	end
end
local gui = make("ScreenGui", {
	Name = "Drawspeak3D",
	IgnoreGuiInset = true,
	ResetOnSpawn = false,
	DisplayOrder = 1000,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Archivable = false,
})
gui.Parent = CoreGui
-- Beside the ScreenGui, not in it: a BillboardGui under a ScreenGui can draw flat in its corner.
local marksFolder = make("Folder", { Name = "Drawspeak3DMarks", Archivable = false })
marksFolder.Parent = CoreGui

-- Takes the mouse while Draw is on, so the game and Studio's selection do not get it.
local catcher: TextButton = make("TextButton", {
	Name = "Catcher",
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Text = "",
	AutoButtonColor = false,
	Modal = true,
	Visible = false,
	ZIndex = 1,
})
catcher.Parent = gui

local inkLayer = make("Frame", { Name = "Ink", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 2 })
inkLayer.Parent = gui

local palette = make("Frame", {
	Name = "Palette",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -14),
	Size = UDim2.fromOffset(0, 44),
	AutomaticSize = Enum.AutomaticSize.X,
	BackgroundColor3 = GLASS,
	BackgroundTransparency = 0.12,
	ZIndex = 5,
}, {
	corner(22),
	stroke(),
	make("UIPadding", { PaddingLeft = UDim.new(0, 5), PaddingRight = UDim.new(0, 5), PaddingTop = UDim.new(0, 5), PaddingBottom = UDim.new(0, 5) }),
	make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Center }),
})
palette.Parent = gui

local statusLabel = make("TextLabel", {
	Name = "Status",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -66),
	Size = UDim2.fromOffset(0, 0),
	AutomaticSize = Enum.AutomaticSize.XY,
	BackgroundColor3 = GLASS,
	BackgroundTransparency = 0.12,
	Font = FONT,
	TextSize = 14,
	TextColor3 = WHITE,
	TextWrapped = false,
	Text = "",
	Visible = false,
	ZIndex = 5,
}, { corner(13), stroke(), padding(9), make("UISizeConstraint", { MaxSize = Vector2.new(640, 260) }) })
statusLabel.Parent = gui

local bubble = make("Frame", {
	Name = "Bubble",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -66),
	Size = UDim2.fromOffset(380, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundColor3 = GLASS,
	BackgroundTransparency = 0.08,
	Visible = false,
	ZIndex = 6,
}, {
	corner(18),
	stroke(),
	padding(11),
	make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
})
bubble.Parent = gui

local bubbleHead: TextLabel = make("TextLabel", { LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 20), BackgroundTransparency = 1, Font = BOLD, TextSize = 14, TextColor3 = WHITE, TextXAlignment = Enum.TextXAlignment.Left, Text = "", ZIndex = 6 })
bubbleHead.Parent = bubble
local bubbleText: TextBox = make("TextBox", {
	LayoutOrder = 2,
	Size = UDim2.new(1, 0, 0, 72),
	BackgroundColor3 = Color3.new(0, 0, 0),
	BackgroundTransparency = 0.72,
	Font = FONT,
	TextSize = 15,
	TextColor3 = WHITE,
	PlaceholderText = "Say it, or type here…",
	PlaceholderColor3 = SOFT,
	Text = "",
	ClearTextOnFocus = false,
	MultiLine = true,
	TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
	ZIndex = 6,
}, { corner(10), padding(8) })
bubbleText.Parent = bubble
local chainRow = make("Frame", {
	LayoutOrder = 3,
	Size = UDim2.new(1, 0, 0, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1,
	ZIndex = 6,
}, { make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Wraps = true, Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder }) })
chainRow.Parent = bubble
local bubbleLine: TextLabel = make("TextLabel", { LayoutOrder = 4, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Font = FONT, TextSize = 12, TextColor3 = SOFT, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, Text = "", Visible = false, ZIndex = 6 })
bubbleLine.Parent = bubble
local bubbleActions = make("Frame", { LayoutOrder = 5, Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = 1, ZIndex = 6 }, {
	make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Right, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
})
bubbleActions.Parent = bubble

-- ---------------------------------------------------------------------------- state

local project: string? = nil
local armed = false
local keyDownAt = 0
local wasArmed = false
local usedWhileHeld = false
local keyHeld = false
local stroke_: any = nil
local lastDepth = 20

-- Marks in the world, by note id.
local marks: { [string]: { pin: BillboardGui, ink: Instance?, note: any, pinLabel: TextButton } } = {}
local activeId: string? = nil
local highlight: Highlight? = nil
local pollGeneration = 0
local actionsFor = ""
local running = false
local statusUntil = 0

local function path(rest: string): string
	return "/v1/projects/" .. tostring(project) .. rest
end

local function say(text: string, seconds: number?)
	statusLabel.Text = text
	statusLabel.Visible = text ~= ""
	statusUntil = if seconds then os.clock() + seconds else math.huge
end

-- ---------------------------------------------------------------------------- the palette

local drawButton: TextButton
local sendButton: TextButton
local countLabel: TextButton

local function readyCount(): number
	local n = 0
	for _, mark in marks do
		if mark.note.readiness == "ready" then
			n += 1
		end
	end
	return n
end

local function markCount(): number
	local n = 0
	for _ in marks do
		n += 1
	end
	return n
end

local function refreshPalette()
	drawButton.BackgroundColor3 = if armed then INK else WHITE
	drawButton.BackgroundTransparency = if armed then 0 else 0.92
	local ready = readyCount()
	sendButton.Text = if ready > 0 then "Send (" .. ready .. ")" else "Send"
	sendButton.BackgroundColor3 = if ready > 0 then ACTION else WHITE
	sendButton.BackgroundTransparency = if ready > 0 then 0 else 0.92
	countLabel.Text = if markCount() > 0 then tostring(markCount()) .. " marks" else ""
	countLabel.Visible = markCount() > 0
end

local function setArmed(on: boolean)
	if on == armed then
		return
	end
	armed = on
	catcher.Visible = on
	refreshPalette()
	if not isPlaying then
		pcall(function()
			if on then
				plugin:Activate(true)
			else
				plugin:Deactivate()
			end
		end)
	end
	if on then
		say(HINT, nil)
	elseif statusLabel.Text == HINT then
		say("", 0)
	end
end

-- ---------------------------------------------------------------------------- ink on the screen

local function clearInk()
	inkLayer:ClearAllChildren()
end

local function segment(a: { number }, b: { number }, width: number, color: Color3, z: number)
	local dx, dy = b[1] - a[1], b[2] - a[2]
	local length = math.sqrt(dx * dx + dy * dy)
	if length < 0.5 then
		return
	end
	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromOffset((a[1] + b[1]) / 2, (a[2] + b[2]) / 2)
	frame.Size = UDim2.fromOffset(length + width * 0.6, width)
	frame.Rotation = math.deg(math.atan2(dy, dx))
	frame.BackgroundColor3 = color
	frame.BorderSizePixel = 0
	frame.ZIndex = z
	frame.Parent = inkLayer
end

local function inkSegment(a: { number }, b: { number })
	segment(a, b, 5.5, WHITE, 2)
	segment(a, b, 3, INK, 3)
end

-- The hub's picture shows what is on the screen: a line gets its head, a tap its ring.
local function inkHead(points: { { number } })
	local finish = points[#points]
	local back = points[1]
	for i = #points - 1, 1, -1 do
		back = points[i]
		if Core.distance(finish, back) >= 18 then
			break
		end
	end
	local angle = math.atan2(finish[2] - back[2], finish[1] - back[1])
	for _, side in { -1, 1 } do
		local wing = angle + math.pi + side * math.pi / 6.5
		inkSegment(finish, { finish[1] + math.cos(wing) * 18, finish[2] + math.sin(wing) * 18 })
	end
end

local function inkRing(at: { number }, radius: number)
	local count = 16
	for i = 1, count do
		local a, b = (i - 1) / count * math.pi * 2, i / count * math.pi * 2
		inkSegment({ at[1] + math.cos(a) * radius, at[2] + math.sin(a) * radius }, { at[1] + math.cos(b) * radius, at[2] + math.sin(b) * radius })
	end
end

-- ---------------------------------------------------------------------------- marks in the world

local function removeMark(id: string)
	local mark = marks[id]
	if mark then
		mark.pin:Destroy()
		if mark.ink then
			mark.ink:Destroy()
		end
		marks[id] = nil
	end
end

local closeBubble, openBubble

local function ensureMark(note: any)
	local mark = marks[note.id]
	if not mark then
		local anchor = note.world.anchor
		local kind = note.shape and note.shape.kind
		-- A spot's pin stands over its ring, like a pin on a map, and leaves it in sight.
		local lift = Vector3.zero
		if kind == "point" and note.world.ink[1] then
			local p = note.world.ink[1]
			lift = Vector3.new(0, (Vector3.new(p[1], p[2], p[3]) - Vector3.new(anchor[1], anchor[2], anchor[3])).Magnitude * 1.7, 0)
		end
		local label: TextButton = make("TextButton", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = INK,
			Font = BOLD,
			TextSize = 14,
			TextColor3 = WHITE,
			Text = "",
			AutoButtonColor = false,
		}, { make("UICorner", { CornerRadius = UDim.new(0.5, 0) }), make("UIStroke", { Color = WHITE, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }) })
		local pin: BillboardGui = make("BillboardGui", {
			Name = "Pin",
			Adornee = workspace.Terrain,
			Size = UDim2.fromOffset(30, 30),
			StudsOffsetWorldSpace = Vector3.new(anchor[1], anchor[2], anchor[3]),
			StudsOffset = lift,
			AlwaysOnTop = true,
			Active = true,
			LightInfluence = 0,
			MaxDistance = math.huge,
			ClipsDescendants = false,
			Archivable = false,
		}, { label })
		pin.Parent = marksFolder
		-- The ink as lines in the world. If the engine will not draw them, the pin is enough.
		local ink = nil
		pcall(function()
			if #note.world.ink < 2 then
				return -- a comment on the whole view has no ink
			end
			local wire = Instance.new("WireframeHandleAdornment")
			wire.Name = "Ink"
			wire.Adornee = workspace.Terrain
			wire.Color3 = INK
			wire.Archivable = false
			pcall(function()
				wire.Thickness = 3
			end)
			local points = {}
			for _, p in note.world.ink do
				table.insert(points, Vector3.new(p[1], p[2], p[3]))
			end
			wire:AddPath(points, note.world.closed == true)
			if kind == "arrow" then
				-- Its head, on its end.
				local finish = points[#points]
				local along = finish - points[#points - 1]
				local n = note.world.normal
				local across = along:Cross(Vector3.new(n[1], n[2], n[3]))
				if along.Magnitude > 1e-3 and across.Magnitude > 1e-3 then
					local size = math.clamp((finish - points[1]).Magnitude * 0.08, 0.5, 6)
					local wingBase = finish - along.Unit * size
					wire:AddLine(finish, wingBase + across.Unit * size * 0.5)
					wire:AddLine(finish, wingBase - across.Unit * size * 0.5)
				end
			end
			wire.Parent = marksFolder
			ink = wire
		end)
		local id = note.id
		label.Activated:Connect(function()
			if activeId == id then
				closeBubble()
			else
				openBubble(id)
			end
		end)
		mark = { pin = pin, ink = ink, note = note, pinLabel = label }
		marks[note.id] = mark
	end
	mark.note = note
	mark.pinLabel.Text = tostring(note.number or note.ordinal)
	mark.pinLabel.BackgroundColor3 = if note.readiness == "markOnly" then WHITE else INK
	mark.pinLabel.TextColor3 = if note.readiness == "markOnly" then INK else WHITE
	return mark
end

-- Marks come from the hub, so they are the same in Edit and in Play, and follow the desk page.
local function syncMarks()
	if not project then
		return
	end
	local ok, data = request("GET", path("/marks"))
	if not ok or not data then
		return
	end
	local seen = {}
	for _, note in data.notes do
		if note.readiness ~= "sent" then
			seen[note.id] = true
			ensureMark(note)
		end
	end
	for id in marks do
		if not seen[id] then
			if activeId == id then
				closeBubble()
			end
			removeMark(id)
		end
	end
	refreshPalette()
end

-- ---------------------------------------------------------------------------- the bubble

local function setHighlight(instance: Instance?)
	if highlight then
		highlight:Destroy()
		highlight = nil
	end
	if instance then
		pcall(function()
			local h = Instance.new("Highlight")
			h.Name = "Target"
			h.Adornee = instance
			h.FillColor = OUTLINE
			h.FillTransparency = 0.82
			h.OutlineColor = OUTLINE
			h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
			h.Archivable = false
			h.Parent = marksFolder
			highlight = h
		end)
	end
end

local function renderChain(note: any)
	chainRow:ClearAllChildren()
	make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Wraps = true, Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder }).Parent = chainRow
	local target = note.target
	if not target then
		return
	end
	local chain = target.layers[target.layer + 1] or {}
	for i, entity in chain do
		local depth = i - 1
		local current = depth == target.depth
		local chip: TextButton = make("TextButton", {
			LayoutOrder = i,
			Size = UDim2.fromOffset(0, 24),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = OUTLINE,
			BackgroundTransparency = if current then 0.65 else 1,
			Font = if current then BOLD else FONT,
			TextSize = 12,
			TextColor3 = if current then WHITE else SOFT,
			Text = entity.label,
			AutoButtonColor = false,
			ZIndex = 6,
		}, { corner(8), make("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }) })
		chip.Activated:Connect(function()
			local ok, updated = request("POST", path("/marks/" .. note.id), { depth = depth })
			if ok and updated then
				ensureMark(updated)
				renderChain(updated)
				setHighlight(Scene.findInstance(entity.locator.value))
			end
		end)
		chip.Parent = chainRow
	end
end

local function renderActions(note: any)
	for _, child in bubbleActions:GetChildren() do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
	local recording = note.recording == "recording"
	local function add(order: number, b: TextButton)
		b.LayoutOrder = order
		b.ZIndex = 6
		b.Parent = bubbleActions
	end
	add(1, button("Discard", 84, nil, function()
		local id = note.id
		closeBubble()
		removeMark(id)
		refreshPalette()
		request("POST", path("/marks/" .. id), { discard = true })
	end))
	if recording then
		add(2, button("Stop", 76, ACTION, function()
			request("POST", path("/marks/" .. note.id), { stop = true })
		end))
	else
		add(2, button("Done", 76, nil, function()
			closeBubble()
		end))
	end
end

local function showNote(note: any)
	local number = note.number or note.ordinal
	if note.recording == "recording" then
		bubbleHead.Text = "● Listening… comment " .. number
		bubbleHead.TextColor3 = Color3.fromRGB(255, 120, 140)
	elseif note.recording == "transcribing" then
		bubbleHead.Text = "Finishing…"
		bubbleHead.TextColor3 = WHITE
	else
		bubbleHead.Text = "Comment " .. number .. if note.shape and note.shape.kind == "view" then ": this view" else ""
		bubbleHead.TextColor3 = WHITE
	end
	if not bubbleText:IsFocused() then
		bubbleText.Text = note.text or ""
	end
	-- Rebuilt only when what they do changes: a press spanning a rebuild would be lost.
	local state = note.id .. ":" .. tostring(note.recording)
	if state ~= actionsFor then
		actionsFor = state
		renderActions(note)
	end
end

function closeBubble()
	activeId = nil
	actionsFor = ""
	bubble.Visible = false
	setHighlight(nil)
	bubbleLine.Visible = false
end

local function pollNote(id: string)
	-- A newer poll replaces this one, whatever note it is for.
	pollGeneration += 1
	local generation = pollGeneration
	task.spawn(function()
		while activeId == id and generation == pollGeneration do
			local mark = marks[id]
			if not mark then
				break
			end
			local ok, note = request("GET", path("/marks/" .. id))
			if generation ~= pollGeneration then
				break
			end
			if ok and note then
				local wasRecording = mark.note.recording ~= nil
				ensureMark(note)
				if activeId == id then
					showNote(note)
				end
				refreshPalette()
				if wasRecording and not note.recording then
					-- Done speaking: it closes by itself shortly, unless they are typing.
					if (note.text or "") ~= "" then
						task.delay(2.6, function()
							if activeId == id and not bubbleText:IsFocused() then
								closeBubble()
							end
						end)
					end
				end
				if not note.recording then
					break
				end
			end
			task.wait(0.35)
		end
	end)
end

function openBubble(id: string, instance: Instance?)
	local mark = marks[id]
	if not mark then
		return
	end
	activeId = id
	bubble.Visible = true
	statusLabel.Visible = false
	bubbleLine.Visible = false
	bubbleText.Text = mark.note.text or ""
	showNote(mark.note)
	renderChain(mark.note)
	setHighlight(instance)
	pollNote(id)
end

bubbleText.FocusLost:Connect(function()
	local id = activeId
	if not id or not marks[id] then
		return
	end
	if bubbleText.Text ~= (marks[id].note.text or "") then
		task.spawn(function()
			local ok, note = request("POST", path("/marks/" .. id), { text = bubbleText.Text })
			if ok and note then
				ensureMark(note)
				if activeId == id then
					showNote(note)
				end
				refreshPalette()
			end
		end)
	end
end)

-- ---------------------------------------------------------------------------- a stroke becomes a mark

-- Hands a mark to the hub, which takes the picture now, with the ink still on screen.
local function saveMark(title: string, shape: any, view: Scene.View, world: any, target: any, method: string, instance: Instance?)
	if target then
		target.method = method
	end
	local body = {
		title = title,
		shape = shape,
		pose = Scene.poseOf(view),
		world = world,
		target = target,
		-- Only a test has a character of one's own.
		viewer = if isPlaying then Scene.viewerOf(game:GetService("Players").LocalPlayer) else nil,
		voice = true,
	}
	say("Saving the mark…", 5)
	task.spawn(function()
		local ok, note = request("POST", path("/marks"), body)
		clearInk()
		if not ok then
			say("The hub did not answer: " .. tostring(note) .. ". Start it with npm run hub.", 7)
			return
		end
		ensureMark(note)
		refreshPalette()
		say("", 0)
		openBubble(note.id, instance)
		if note.desks == 0 then
			bubbleLine.Text = "For voice, open " .. HUB .. "/desk and turn on the microphone. You can type here too."
			bubbleLine.Visible = true
			bubbleText:CaptureFocus()
		end
		if note.picture == false then
			bubbleLine.Text = "No picture of the window (" .. tostring(note.pictureProblem) .. "). The mark and its target still go to the agent."
			bubbleLine.Visible = true
		end
	end)
end

-- A circle, or a thing chosen by a tap.
local function commit(points: { { number } }, shape: any, pick: Scene.Pick, view: Scene.View, method: string)
	local about = pick.target
	local onGround = about ~= nil and about.partial and Scene.isSurfaceLike(about.layers[about.layer + 1][about.depth + 1], view)
	local planePoint, normal = Scene.inkPlane(pick.surface, view, lastDepth, onGround)
	if #pick.surface > 0 then
		lastDepth = pick.surface[math.ceil(#pick.surface / 2)].distance
	end
	local inkPoints = points
	if shape.kind == "component" then
		local r = shape.rect
		local x0, y0, x1, y1 = r.x * view.width, r.y * view.height, (r.x + r.w) * view.width, (r.y + r.h) * view.height
		inkPoints = { { x0, y0 }, { x1, y0 }, { x1, y1 }, { x0, y1 } }
	else
		inkPoints = Core.simplified(points, Core.SAMPLE_SPACING)
	end
	-- Lines in the world are costly for the engine: a loop keeps at most 64 of them.
	if #inkPoints > 64 then
		local fewer = {}
		for i = 1, 64 do
			table.insert(fewer, inkPoints[math.ceil(i * #inkPoints / 64)])
		end
		inkPoints = fewer
	end
	local lifted = Scene.liftOnto(inkPoints, planePoint, normal, view)
	local ink = {}
	for _, p in lifted do
		table.insert(ink, Scene.arrayOf(p))
	end
	local spot = Core.pinSpot(shape)
	local spotPx = { spot[1] * view.width, spot[2] * view.height }
	local nearest, nearestDistance = 1, math.huge
	for i, p in inkPoints do
		local d = Core.distance(p, spotPx)
		if d < nearestDistance then
			nearest, nearestDistance = i, d
		end
	end
	local world = { anchor = ink[nearest], normal = Scene.arrayOf(normal), ink = ink, closed = true, place = Scene.placeOf(lifted, normal, pick.target) }
	saveMark(Scene.titleFor(pick.instance), shape, view, world, pick.target, method, pick.instance)
end

-- "Here": one spot on a floor or a wall. Its ring lies on that surface and stays there.
local function commitSpot(at: { number }, pick: Scene.Pick, view: Scene.View, method: string)
	local planePoint, normal = Scene.inkPlane(pick.surface, view, lastDepth, true)
	local first = pick.surface[1]
	if first then
		lastDepth = first.distance
	end
	local center: Vector3 = if first then first.point else planePoint
	local target = pick.target
	if target then
		target.partial = true
	end
	inkRing(at, 14)
	-- As wide in the world as a small ring on the screen, at that distance.
	local radius = 2 * math.tan(math.rad(view.fov) / 2) * (center - view.cframe.Position).Magnitude / view.height * 14
	local ink = {}
	for _, p in Scene.ringOn(center, normal, radius) do
		table.insert(ink, Scene.arrayOf(p))
	end
	local world = { anchor = Scene.arrayOf(center), normal = Scene.arrayOf(normal), ink = ink, closed = true, place = Scene.placeOf({ center }, normal, target) }
	saveMark(Scene.titleFor(pick.instance), { kind = "point", at = { at[1] / view.width, at[2] / view.height } }, view, world, target, method, pick.instance)
end

-- From here to there.
local function commitLine(points: { { number } }, shape: any, view: Scene.View, method: string)
	local mark = Scene.lineMark(points, shape, view, lastDepth)
	if mark.distance then
		lastDepth = mark.distance
	end
	inkHead(points)
	saveMark(Scene.titleFor(mark.instance), shape, view, mark.world, mark.target, method, mark.instance)
end

-- A comment with no mark: about what is in view, or about the whole experience.
local function talkAboutView()
	if not project then
		say("Looking for the hub… start it with npm run hub (in drawspeak123/3d).", 5)
		return
	end
	if stroke_ then
		return
	end
	local view = Scene.viewOf(workspace.CurrentCamera)
	local planePoint, normal = Scene.inkPlane({}, view, lastDepth)
	local shape = { kind = "view" }
	-- Its pin stands in a corner of the view, not in the way of what is talked about.
	local spot = Core.pinSpot(shape)
	local anchor = Scene.liftOnto({ { spot[1] * view.width, spot[2] * view.height } }, planePoint, normal, view)[1]
	saveMark(Scene.titleFor(nil), shape, view, { anchor = Scene.arrayOf(anchor), normal = Scene.arrayOf(normal), ink = {}, closed = false }, nil, "keyboard", nil)
end

local function pointOf(input: InputObject): { number }
	local at = if input.UserInputType == Enum.UserInputType.Touch then Vector2.zero else UserInputService:GetMouseLocation()
	if at.X == 0 and at.Y == 0 then
		-- Touches, and the mouse where its location is not known, come without the top bar; the view is measured with it.
		local inset = game:GetService("GuiService"):GetGuiInset()
		return { input.Position.X + inset.X, input.Position.Y + inset.Y }
	end
	return { at.X, at.Y }
end

local function beginStroke(input: InputObject)
	if stroke_ or not project then
		if not project then
			say("Looking for the hub… start it with npm run hub (in drawspeak123/3d).", 5)
		end
		return
	end
	usedWhileHeld = true
	clearInk()
	local camera = workspace.CurrentCamera
	stroke_ = {
		points = { pointOf(input) },
		view = Scene.viewOf(camera),
		method = if input.UserInputType == Enum.UserInputType.Touch then "touch" else "mouse",
	}
end

local function moveStroke(input: InputObject)
	if not stroke_ then
		return
	end
	local p = pointOf(input)
	local points = stroke_.points
	local last = points[#points]
	if Core.distance(last, p) >= Core.SAMPLE_SPACING then
		table.insert(points, p)
		inkSegment(last, p)
	end
end

local function endStroke()
	local current = stroke_
	if not current then
		return
	end
	stroke_ = nil
	local points, view = current.points, current.view
	local shape = Core.shapeFor(points, view.width, view.height)
	local ok, problem = pcall(function()
		if shape and shape.kind == "arrow" then
			commitLine(points, shape, view, current.method)
		elseif shape then
			commit(points, shape, Scene.pickLoop(points, view), view, current.method)
		elseif Core.isTap(points) then
			-- A tap is the thing under it, or, on a floor or a wall, that spot.
			local at = points[1]
			local pick = Scene.pickPoint(at[1], at[2], view)
			local target = pick.target
			local entity = target and target.layers[1][target.depth + 1]
			if Scene.isSurfaceLike(entity, view) then
				commitSpot(at, pick, view, current.method)
			else
				local size = 44
				local tapShape = { kind = "component", rect = { x = (at[1] - size / 2) / view.width, y = (at[2] - size / 2) / view.height, w = size / view.width, h = size / view.height } }
				inkRing(at, size / 2)
				commit(points, tapShape, pick, view, current.method)
			end
		else
			clearInk()
		end
	end)
	if not ok then
		clearInk()
		say("That mark did not work: " .. tostring(problem), 7)
	end
	-- X let go during the stroke: back to the game.
	if armed and not keyHeld and not wasArmed and keyDownAt > 0 then
		setArmed(false)
		keyDownAt = 0
	end
end

catcher.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		beginStroke(input)
	end
end)
UserInputService.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
		moveStroke(input)
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		endStroke()
	end
end)

-- ---------------------------------------------------------------------------- X, like C in the browser

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or UserInputService:GetFocusedTextBox() then
		return
	end
	if input.KeyCode == HOTKEY and (UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)) then
		talkAboutView()
	elseif input.KeyCode == HOTKEY then
		keyDownAt = os.clock()
		keyHeld = true
		wasArmed = armed
		usedWhileHeld = false
		setArmed(true)
	elseif input.KeyCode == Enum.KeyCode.Return and activeId then
		local mark = marks[activeId]
		if mark and mark.note.recording then
			request("POST", path("/marks/" .. activeId), { stop = true })
		end
	elseif input.KeyCode == Enum.KeyCode.Escape then
		if activeId then
			closeBubble()
		elseif armed then
			setArmed(false)
		end
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode ~= HOTKEY or not keyHeld then
		return
	end
	keyHeld = false
	local quick = os.clock() - keyDownAt < 0.26 and not usedWhileHeld
	local mark = activeId and marks[activeId]
	if quick and mark and mark.note.recording == "recording" then
		-- While you speak, a tap means you are done.
		setArmed(wasArmed)
		keyDownAt = 0
		request("POST", path("/marks/" .. (activeId :: string)), { stop = true })
	elseif quick then
		-- A tap switches Draw on or off and leaves it so.
		setArmed(not wasArmed)
		wasArmed = armed
		keyDownAt = 0
	elseif not stroke_ then
		setArmed(wasArmed)
		keyDownAt = 0
	end
end)

-- Studio or the game lost the focus in the middle of it: no key is held any more, and no stroke goes on.
UserInputService.WindowFocusReleased:Connect(function()
	stroke_ = nil
	clearInk()
	keyHeld = false
	if keyDownAt > 0 then
		setArmed(wasArmed)
		keyDownAt = 0
	end
end)

-- ---------------------------------------------------------------------------- send, and the agent at work

local function watchRun()
	if running then
		return
	end
	running = true
	task.spawn(function()
		while true do
			local ok, run = request("GET", path("/run"))
			if ok and run and run.status then
				if run.status == "running" then
					local line = run.activity and run.activity[#run.activity] or "Reading your comments…"
					say(run.agent .. " is working: " .. line, nil)
				else
					local changed = run.changed and #run.changed or 0
					local reply = run.reply or run.error or ""
					if run.status == "done" then
						say("Done: " .. changed .. " file" .. (if changed == 1 then "" else "s") .. " changed. " .. reply .. "\nRebuild the place to see it (node tools/build-place.mjs).", 30)
					elseif run.status == "stopped" then
						say("Stopped.", 5)
					else
						say("The agent could not finish: " .. reply, 20)
					end
					statusLabel.TextWrapped = true
					break
				end
			end
			task.wait(1.5)
		end
		running = false
	end)
end

local function send()
	if not project then
		say("Looking for the hub… start it with npm run hub (in drawspeak123/3d).", 5)
		return
	end
	if isPlaying then
		-- Scripts in the place can use the bridge too, so it does not start the agent.
		say("During a test, send from the desk page (" .. HUB .. "/desk), or here after stopping the test.", 7)
		return
	end
	if activeId then
		closeBubble()
	end
	if readyCount() == 0 then
		say(if markCount() > 0 then "A mark needs a comment first." else "Nothing to send yet.", 4)
		return
	end
	task.spawn(function()
		local ok, result = request("POST", path("/marks/send"), {})
		if not ok then
			say(tostring(result), 7)
			return
		end
		syncMarks()
		watchRun()
	end)
end

drawButton = button("Draw  X", 82, nil, function()
	setArmed(not armed)
end)
drawButton.LayoutOrder = 1
drawButton.ZIndex = 5
drawButton.Parent = palette
local talkButton = button("Talk", 62, nil, talkAboutView)
talkButton.LayoutOrder = 2
talkButton.ZIndex = 5
talkButton.Parent = palette
countLabel = make("TextButton", { LayoutOrder = 3, Size = UDim2.fromOffset(0, 34), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1, Font = FONT, TextSize = 13, TextColor3 = SOFT, Text = "", AutoButtonColor = false, Visible = false, ZIndex = 5 }, {
	make("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }),
})
countLabel.Parent = palette
-- Opens each mark in turn: the way back to a comment, whether or not pins take clicks here.
countLabel.Activated:Connect(function()
	local ids = {}
	for id, mark in marks do
		table.insert(ids, { id = id, ordinal = mark.note.ordinal })
	end
	table.sort(ids, function(a, b)
		return a.ordinal < b.ordinal
	end)
	for i, entry in ids do
		if entry.id == activeId then
			local following = ids[i + 1]
			if following then
				openBubble(following.id)
			else
				closeBubble()
			end
			return
		end
	end
	if ids[1] then
		openBubble(ids[1].id)
	end
end)
sendButton = button("Send", 86, nil, send)
sendButton.LayoutOrder = 4
sendButton.ZIndex = 5
sendButton.Parent = palette
refreshPalette()

-- Studio's own button, in the Plugins tab: shows or hides the palette.
pcall(function()
	local toolbar = plugin:CreateToolbar("Drawspeak 3D")
	local toggle = toolbar:CreateButton("Drawspeak 3D", "Mark things and places in the 3D view and tell a coding agent what should change", "rbxassetid://0")
	toggle.ClickableWhenViewportHidden = false
	toggle.Click:Connect(function()
		gui.Enabled = not gui.Enabled
		if not gui.Enabled then
			setArmed(false)
		end
	end)
end)

-- ---------------------------------------------------------------------------- staying in touch

task.spawn(function()
	while gui.Parent do
		if not project then
			local ok, found = request("GET", "/v1/roblox")
			if ok and found then
				project = found.id
				syncMarks()
				local running_ok, run = request("GET", path("/run"))
				if running_ok and run and run.status == "running" then
					watchRun()
				end
			else
				say("Drawspeak: start the hub with npm run hub (in drawspeak123/3d).", 6)
			end
			task.wait(if project then 0 else 5)
		else
			if not stroke_ and not activeId then
				syncMarks()
			end
			task.wait(3)
		end
		if statusLabel.Visible and os.clock() > statusUntil then
			statusLabel.Visible = false
			statusLabel.TextWrapped = false
		end
	end
end)

plugin.Unloading:Connect(function()
	gui:Destroy()
	marksFolder:Destroy()
end)
