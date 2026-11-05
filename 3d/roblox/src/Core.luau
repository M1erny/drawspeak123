--!strict
-- What a stroke means and what a loop is about, with no Roblox in it: the same rules as the browser
-- tool (src/core/stroke.ts, geometry.ts, selection.ts), so the same gesture means the same thing in
-- both worlds. Points are { x, y } in screen pixels; shapes come out in normalized space, as JSON for
-- the hub.

local Core = {}

export type Point = { number }
export type Rect = { minX: number, minY: number, maxX: number, maxY: number }
export type Candidate = { key: string, hits: number, behind: number, enclosure: number, depth: number }

-- Marks whose screen box fits in this square are taps or slips.
Core.MINIMUM_MARK_SIZE = 24
-- A line needs at least this length.
Core.MINIMUM_LINE_LENGTH = 32
-- A loop is closed when its end is within this fraction of its length, or this close, to its start.
Core.CLOSE_FRACTION = 0.12
Core.CLOSE_DISTANCE = 30
-- A hasty circle leaves a wider gap, but it turned most of the way round; a U-turn does not.
Core.HASTY_GAP = 0.35
Core.HASTY_TURN = math.rad(250)
-- A line this close to straight, as a share of its length, is straight.
Core.STRAIGHT_ENOUGH = 0.06
Core.MAX_BENDS = 22
-- Stored points are at least this far apart. Each is a Frame on screen, so fewer than in a browser.
Core.SAMPLE_SPACING = 4
-- Below this much inside the loop, a thing is not circled, only seen through the loop.
Core.WHOLE = 0.5
-- Others join the best one when they score at least this share of it.
Core.ALIKE = 0.45
-- Not whole, but this much of it inside and this much of the loop on it: it is the subject.
Core.MOSTLY_ABOUT = 0.15
Core.ENOUGH_OF_THE_LOOP = 0.08

function Core.distance(a: Point, b: Point): number
	local dx, dy = b[1] - a[1], b[2] - a[2]
	return math.sqrt(dx * dx + dy * dy)
end

function Core.pathLength(points: { Point }): number
	local total = 0
	for i = 2, #points do
		total += Core.distance(points[i - 1], points[i])
	end
	return total
end

function Core.boundsOf(points: { Point }): Rect
	local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
	for _, p in points do
		minX = math.min(minX, p[1])
		minY = math.min(minY, p[2])
		maxX = math.max(maxX, p[1])
		maxY = math.max(maxY, p[2])
	end
	return { minX = minX, minY = minY, maxX = maxX, maxY = maxY }
end

-- Drops points closer than `spacing` to the last kept one; keeps the end point.
function Core.simplified(points: { Point }, spacing: number): { Point }
	if #points == 0 then
		return {}
	end
	local kept = { points[1] }
	for i = 2, #points do
		if Core.distance(points[i], kept[#kept]) >= spacing then
			table.insert(kept, points[i])
		end
	end
	local last = points[#points]
	local tail = kept[#kept]
	if tail[1] ~= last[1] or tail[2] ~= last[2] then
		table.insert(kept, last)
	end
	return kept
end

-- How far a stroke turned in all, in radians, ignoring the jitter of a hand.
local function totalTurn(points: { Point }): number
	local coarse = Core.simplified(points, 14)
	local turn = 0
	for i = 3, #coarse do
		local a = math.atan2(coarse[i - 1][2] - coarse[i - 2][2], coarse[i - 1][1] - coarse[i - 2][1])
		local b = math.atan2(coarse[i][2] - coarse[i - 1][2], coarse[i][1] - coarse[i - 1][1])
		local step = b - a
		while step > math.pi do
			step -= math.pi * 2
		end
		while step < -math.pi do
			step += math.pi * 2
		end
		turn += step
	end
	return math.abs(turn)
end

function Core.isClosedLoop(points: { Point }): boolean
	if #points < 3 then
		return false
	end
	local length = Core.pathLength(points)
	if length <= 0 then
		return false
	end
	local gap = Core.distance(points[1], points[#points])
	if gap <= Core.CLOSE_FRACTION * length then
		return true
	end
	-- Close by, and it really went somewhere and came back: a short straight line is not a loop.
	if gap <= Core.CLOSE_DISTANCE and length >= gap * 2.2 then
		return true
	end
	return gap <= Core.HASTY_GAP * length and totalTurn(points) >= Core.HASTY_TURN
end

function Core.isTap(points: { Point }): boolean
	if #points == 0 then
		return false
	end
	local b = Core.boundsOf(points)
	return b.maxX - b.minX < Core.MINIMUM_MARK_SIZE and b.maxY - b.minY < Core.MINIMUM_MARK_SIZE
end

-- How far a stroke strays from the straight line between its ends.
local function strayFromChord(points: { Point }): number
	local a, b = points[1], points[#points]
	local length = Core.distance(a, b)
	if length <= 0 then
		length = 1
	end
	local most = 0
	for _, p in points do
		most = math.max(most, math.abs((b[1] - a[1]) * (a[2] - p[2]) - (a[1] - p[1]) * (b[2] - a[2])) / length)
	end
	return most
end

-- A finished stroke as a mark, or nil when it shows no intent (a tap is for the caller, who can see
-- the world). A closed loop is a lasso: this thing, or this area. Any other stroke is a line: from
-- here to there, a route or something to move.
function Core.shapeFor(points: { Point }, width: number, height: number): any
	if #points < 2 or width <= 0 or height <= 0 or Core.isTap(points) then
		return nil
	end
	local function normalized(p: Point): Point
		return { p[1] / width, p[2] / height }
	end
	if Core.isClosedLoop(points) then
		local out = {}
		for _, p in Core.simplified(points, Core.SAMPLE_SPACING) do
			table.insert(out, normalized(p))
		end
		if #out < 3 then
			return nil
		end
		return { kind = "lasso", points = out }
	end
	local length = Core.pathLength(points)
	if length < Core.MINIMUM_LINE_LENGTH then
		return nil
	end
	local shape: any = { kind = "arrow", from = normalized(points[1]), to = normalized(points[#points]) }
	if strayFromChord(points) > Core.STRAIGHT_ENOUGH * length then
		local bends = Core.simplified(points, math.max(Core.SAMPLE_SPACING, length / Core.MAX_BENDS))
		local via = {}
		for i = 2, #bends - 1 do
			table.insert(via, normalized(bends[i]))
		end
		if #via > 0 then
			shape.via = via
		end
	end
	return shape
end

-- Where a shape's number goes.
function Core.pinSpot(shape: any): Point
	if shape.kind == "lasso" then
		local b = Core.boundsOf(shape.points)
		return { b.maxX, b.minY }
	elseif shape.kind == "arrow" then
		return shape.from
	elseif shape.kind == "point" then
		return shape.at
	elseif shape.kind == "view" then
		return { 0.06, 0.1 }
	end
	return { shape.rect.x + shape.rect.w, shape.rect.y }
end

-- What the plugin's client side may ask its server side to carry during a test. Scripts in the place
-- can call that bridge too, so it carries marks and comments, which a person sees, and never a Send:
-- starting the agent stays with the desk page, and with the plugin in Edit, where no game code runs.
function Core.allowedOverBridge(method: any, path: any): boolean
	if type(method) ~= "string" or type(path) ~= "string" then
		return false
	end
	if string.find(path, "/marks/send", 1, true) then
		return false
	end
	if method == "GET" then
		return path == "/v1/roblox"
			or string.match(path, "^/v1/projects/[%w_-]+/run$") ~= nil
			or string.match(path, "^/v1/projects/[%w_-]+/marks$") ~= nil
			or string.match(path, "^/v1/projects/[%w_-]+/marks/%w+$") ~= nil
	end
	if method == "POST" then
		return string.match(path, "^/v1/projects/[%w_-]+/marks$") ~= nil or string.match(path, "^/v1/projects/[%w_-]+/marks/%w+$") ~= nil
	end
	return false
end

-- Even-odd rule; the polygon closes itself.
function Core.pointInPolygon(point: Point, polygon: { Point }): boolean
	local x, y = point[1], point[2]
	local inside = false
	local j = #polygon
	for i = 1, #polygon do
		local xi, yi = polygon[i][1], polygon[i][2]
		local xj, yj = polygon[j][1], polygon[j][2]
		if (yi > y) ~= (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi) + xi then
			inside = not inside
		end
		j = i
	end
	return inside
end

-- Reorders a list so that any prefix is spread over all of it (bit-reversed indices).
function Core.spreadOrder<T>(items: { T }): { T }
	local n = #items
	if n < 3 then
		return items
	end
	local bits = 0
	while bit32.lshift(1, bits) < n do
		bits += 1
	end
	local out = {}
	for i = 0, bit32.lshift(1, bits) - 1 do
		local reversed = 0
		for b = 0, bits - 1 do
			if bit32.band(i, bit32.lshift(1, b)) ~= 0 then
				reversed = bit32.bor(reversed, bit32.lshift(1, bits - 1 - b))
			end
		end
		if reversed < n then
			table.insert(out, items[reversed + 1])
		end
	end
	return out
end

-- Points inside a polygon on an even grid, about `target` of them, in an order that covers the whole
-- shape early.
function Core.samplePolygon(polygon: { Point }, target: number): { Point }
	local b = Core.boundsOf(polygon)
	local width, height = b.maxX - b.minX, b.maxY - b.minY
	if width <= 0 or height <= 0 then
		return {}
	end
	local step = math.max(2, math.sqrt(width * height / (target * 1.3)))
	local points: { Point } = {}
	for _ = 1, 5 do
		points = {}
		local y = b.minY + step / 2
		while y < b.maxY do
			local x = b.minX + step / 2
			while x < b.maxX do
				if Core.pointInPolygon({ x, y }, polygon) then
					table.insert(points, { x, y })
				end
				x += step
			end
			y += step
		end
		if #points >= target * 0.6 or step <= 2 then
			break
		end
		step = math.max(2, step * 0.72)
	end
	if #points == 0 then
		return { { (b.minX + b.maxX) / 2, (b.minY + b.maxY) / 2 } }
	end
	return Core.spreadOrder(points)
end

-- How much of a screen rectangle lies inside the polygon (0…1).
function Core.enclosure(rect: Rect, polygon: { Point }): number
	local cells = 7
	local width, height = rect.maxX - rect.minX, rect.maxY - rect.minY
	if width < 0 or height < 0 then
		return 0
	end
	local inside = 0
	for j = 0, cells - 1 do
		for i = 0, cells - 1 do
			if Core.pointInPolygon({ rect.minX + width * (i + 0.5) / cells, rect.minY + height * (j + 0.5) / cells }, polygon) then
				inside += 1
			end
		end
	end
	return inside / (cells * cells)
end

function Core.score(c: Candidate, totalRays: number): number
	return math.sqrt(c.hits / math.max(1, totalRays)) * c.enclosure * c.enclosure
end

-- What a loop is about. Whole things inside the loop beat big things that merely show through it.
function Core.rank(candidates: { Candidate }, totalRays: number): { members: { Candidate }, partial: boolean, others: { Candidate } }
	local seen = {}
	for _, c in candidates do
		if c.hits > 0 then
			table.insert(seen, c)
		end
	end
	local function byDepth(a: Candidate, b: Candidate)
		return a.depth < b.depth
	end
	if #seen == 0 then
		local hidden = {}
		for _, c in candidates do
			if c.behind > 0 then
				table.insert(hidden, c)
			end
		end
		table.sort(hidden, byDepth)
		return { members = {}, partial = false, others = hidden }
	end
	local ranked = table.clone(seen)
	table.sort(ranked, function(a, b)
		local sa, sb = Core.score(a, totalRays), Core.score(b, totalRays)
		if sa ~= sb then
			return sa > sb
		end
		return a.hits > b.hits
	end)
	local best = ranked[1]
	local members: { Candidate } = {}
	local partial = false
	if best.enclosure < Core.WHOLE then
		-- No whole thing inside: the loop is on something bigger. A thing with a real part inside the
		-- loop is what it is on; failing that, what fills it.
		local subject = best
		if best.enclosure < Core.MOSTLY_ABOUT or best.hits / math.max(1, totalRays) < Core.ENOUGH_OF_THE_LOOP then
			subject = seen[1]
			for _, c in seen do
				if c.hits > subject.hits then
					subject = c
				end
			end
		end
		members = { subject }
		partial = true
	else
		local bar = Core.score(best, totalRays) * Core.ALIKE
		for _, c in ranked do
			if c.enclosure >= Core.WHOLE and Core.score(c, totalRays) >= bar then
				table.insert(members, c)
			end
		end
	end
	local chosen = {}
	for _, m in members do
		chosen[m.key] = true
	end
	local others = {}
	for _, c in candidates do
		if not chosen[c.key] then
			table.insert(others, c)
		end
	end
	table.sort(others, byDepth)
	return { members = members, partial = partial, others = others }
end

-- The common ancestors of several chains (each hit-to-root, entities with a `key`), nearest first.
function Core.commonChain(chains: { { any } }): { any }
	local out = {}
	if #chains == 0 then
		return out
	end
	for _, entity in chains[1] do
		local everywhere = true
		for i = 2, #chains do
			local found = false
			for _, other in chains[i] do
				if other.key == entity.key then
					found = true
					break
				end
			end
			if not found then
				everywhere = false
				break
			end
		end
		if everywhere then
			table.insert(out, entity)
		end
	end
	return out
end

return Core
