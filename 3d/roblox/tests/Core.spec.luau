-- The plugin's pure logic, by the same cases as test/core.test.ts:
--   node roblox/check.mjs
local Core = require("../src/Core")

local failures = 0
local function check(name: string, ok: boolean, detail: any?)
	if ok then
		print("  ok   " .. name)
	else
		failures += 1
		print("  FAIL " .. name .. (if detail ~= nil then " " .. tostring(detail) else ""))
	end
end

local function circle(cx: number, cy: number, r: number, sweep: number?)
	local out = {}
	local n = 40
	for i = 0, n do
		local a = i / n * (sweep or math.pi * 2)
		table.insert(out, { cx + math.cos(a) * r, cy + math.sin(a) * r })
	end
	return out
end

-- strokes, as on the iPad
local W, H = 1000, 800
local shape = Core.shapeFor(circle(400, 300, 60), W, H)
check("a closed circle is a lasso", shape and shape.kind == "lasso")
check("an almost closed circle is still a loop", Core.isClosedLoop(circle(400, 300, 100, math.pi * 2 * 0.92)))
check("a hasty circle with a wide gap is a loop", Core.isClosedLoop(circle(400, 300, 100, math.pi * 2 * 0.8)))
local function through(corners)
	local out = { corners[1] }
	for i = 2, #corners do
		local a, b = corners[i - 1], corners[i]
		local steps = math.max(1, math.round(Core.distance(a, b) / 4))
		for s = 1, steps do
			table.insert(out, { a[1] + (b[1] - a[1]) * s / steps, a[2] + (b[2] - a[2]) * s / steps })
		end
	end
	return out
end
local uTurn = through({ { 100, 100 }, { 400, 100 }, { 400, 300 }, { 100, 300 } })
check("a U-turn is a line, not a loop", not Core.isClosedLoop(uTurn) and Core.shapeFor(uTurn, W, H).kind == "arrow")
local line = Core.shapeFor({ { 100, 100 }, { 200, 160 }, { 300, 240 } }, W, H)
check("any open stroke is a line from here to there", line and line.kind == "arrow" and line.from[1] == 0.1 and line.to[2] == 0.3)
check("a straight line has no bends", line.via == nil and Core.shapeFor(through({ { 100, 100 }, { 300, 104 }, { 500, 99 }, { 700, 103 } }), W, H).via == nil)
local bent = Core.shapeFor(circle(400, 300, 200, math.pi / 2), W, H)
check("a bent one keeps them", bent and bent.kind == "arrow" and bent.via and #bent.via > 3 and #bent.via < 26, bent and bent.via and #bent.via)
check("a line needs some length", Core.shapeFor({ { 10, 10 }, { 38, 12 } }, W, H) == nil and Core.shapeFor({ { 10, 10 }, { 60, 12 } }, W, H).kind == "arrow")
local slip = { { 100, 100 }, { 106, 104 }, { 110, 101 } }
check("a tap or a slip marks nothing", Core.isTap(slip) and Core.shapeFor(slip, W, H) == nil)
local normal = Core.shapeFor(circle(500, 400, 100), W, H)
local allInside = true
for _, p in normal.points do
	allInside = allInside and p[1] > 0.39 and p[1] < 0.61 and p[2] > 0.37 and p[2] < 0.63
end
check("shapes are normalized", allInside)
local spot = Core.pinSpot({ kind = "component", rect = { x = 0.2, y = 0.3, w = 0.1, h = 0.1 } })
check("the pin goes top right", math.abs(spot[1] - 0.3) < 1e-9 and spot[2] == 0.3)
check("a line's pin is at its start", Core.pinSpot({ kind = "arrow", from = { 0.1, 0.2 }, to = { 0.5, 0.5 } })[2] == 0.2)
check("a spot's pin is on it", Core.pinSpot({ kind = "point", at = { 0.4, 0.6 } })[1] == 0.4)
check("a comment on the view has a corner of it", Core.pinSpot({ kind = "view" })[1] == 0.06)

-- sampling a loop
local loop = circle(200, 200, 100)
local samples = Core.samplePolygon(loop, 64)
local inLoop = #samples > 30
for _, p in samples do
	inLoop = inLoop and Core.pointInPolygon(p, loop)
end
check("every sample is inside", inLoop, #samples)
local quadrants = {}
for i = 1, 12 do
	local p = Core.samplePolygon(loop, 96)[i]
	quadrants[tostring(p[1] > 200) .. tostring(p[2] > 200)] = true
end
local count = 0
for _ in quadrants do
	count += 1
end
check("early samples cover the whole loop", count == 4, count)
check("a small loop still gets samples", #Core.samplePolygon(circle(50, 50, 8), 96) > 3)
local items = {}
for i = 1, 37 do
	items[i] = i
end
local spread = Core.spreadOrder(items)
table.sort(spread)
local same = #spread == 37
for i = 1, 37 do
	same = same and spread[i] == i
end
check("reordering keeps every item once", same)
check("enclosure: all inside", Core.enclosure({ minX = 180, minY = 180, maxX = 220, maxY = 220 }, loop) == 1)
check("enclosure: all outside", Core.enclosure({ minX = 800, minY = 800, maxX = 900, maxY = 900 }, loop) == 0)

-- what a loop is about
local function c(key: string, hits: number, enc: number, depth: number?, behind: number?)
	return { key = key, hits = hits, enclosure = enc, depth = depth or 5, behind = behind or 0 }
end
local function keys(list)
	local out = {}
	for _, m in list do
		table.insert(out, m.key)
	end
	table.sort(out)
	return table.concat(out, ",")
end
local r = Core.rank({ c("rack", 60, 0.03), c("milk", 36, 1) }, 96)
check("the carton in the loop beats the rack that fills it", keys(r.members) == "milk" and not r.partial and keys(r.others) == "rack", keys(r.members))
r = Core.rank({ c("rack", 30, 0.05), c("a", 14, 0.95), c("b", 16, 1), c("c", 12, 1), c("d", 14, 0.9) }, 96)
check("a row of products circled together is a group", keys(r.members) == "a,b,c,d", keys(r.members))
r = Core.rank({ c("webster", 48, 1, 4), c("tin1", 3, 1, 9), c("tin2", 2, 1, 9), c("rack", 40, 0.04, 9) }, 96)
check("a character in front of a shelf is the character", keys(r.members) == "webster", keys(r.members))
r = Core.rank({ c("wall", 90, 0.01), c("floor", 6, 0.02) }, 96)
check("a patch of wall is part of the wall", r.partial and keys(r.members) == "wall")
r = Core.rank({ c("walls", 60, 0), c("kiosk", 25, 0.35), c("floor", 10, 0.01) }, 96)
check("a counter with its sign sticking out beats the wall behind it", r.partial and keys(r.members) == "kiosk", keys(r.members))
r = Core.rank({ c("kiosk", 70, 0.6) }, 96)
check("a thing half inside still counts", not r.partial and keys(r.members) == "kiosk")
r = Core.rank({ c("far", 0, 1, 20, 12), c("near", 0, 1, 8, 4) }, 96)
check("nothing but hidden things: they are offered", #r.members == 0 and r.others[1].key == "near" and r.others[2].key == "far")

local store, aisle = { key = "store" }, { key = "dairy" }
local common = Core.commonChain({ { { key = "milk" }, aisle, store }, { { key = "kefir" }, aisle, store } })
check("groups climb to what their members share", #common == 2 and common[1].key == "dairy" and common[2].key == "store")

-- the bridge
check("the bridge finds the project", Core.allowedOverBridge("GET", "/v1/roblox"))
check("the bridge carries marks", Core.allowedOverBridge("POST", "/v1/projects/swing-shop/marks") and Core.allowedOverBridge("POST", "/v1/projects/swing-shop/marks/abc123") and Core.allowedOverBridge("GET", "/v1/projects/swing-shop/marks") and Core.allowedOverBridge("GET", "/v1/projects/swing-shop/run"))
check("the bridge never sends to the agent", not Core.allowedOverBridge("POST", "/v1/projects/swing-shop/marks/send"))
check("the bridge carries no batches", not Core.allowedOverBridge("POST", "/v1/projects/swing-shop/batches") and not Core.allowedOverBridge("POST", "/v1/projects/swing-shop/batches/b1/send") and not Core.allowedOverBridge("POST", "/v1/projects/swing-shop/stop"))
check("the bridge takes no strange paths", not Core.allowedOverBridge("POST", "/v1/projects/../marks") and not Core.allowedOverBridge("DELETE", "/v1/roblox") and not Core.allowedOverBridge(1, {}))

if failures > 0 then
	error(failures .. " check(s) failed")
end
print("All checks passed.")
