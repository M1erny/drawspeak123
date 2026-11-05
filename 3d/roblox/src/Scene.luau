-- From a loop on the screen to Instances in the place. The same idea as src/three/world.ts: rays
-- through the loop say what is there, Core.rank says which of it is meant, and the ink is lifted onto
-- the surface it was drawn on, so it stays on the thing as you walk around it.
--
-- Everything works from a frozen copy of the camera, taken when the stroke began.

local Core = require(script.Parent.Core)

local Scene = {}

-- Rays per loop, and how far they look.
local RAYS = 72
local REACH = 2000
local MAX_LAYERS = 6
-- A Model this large is a building rather than a thing: its parts are the things.
local THING_DIAGONAL = 80
-- How far to look for what stands around a place, nearer first, and how much to ask for at a time.
local NEAR_RADII = { 16, 48 }
local NEAR_PARTS = 240
-- Names that say nothing about a thing.
local PLAIN_NAMES = { Part = true, MeshPart = true, Model = true, Union = true, WedgePart = true, CornerWedgePart = true, TrussPart = true }

export type View = { cframe: CFrame, fov: number, width: number, height: number }

function Scene.viewOf(camera: Camera): View
	local size = camera.ViewportSize
	return { cframe = camera.CFrame, fov = camera.FieldOfView, width = size.X, height = size.Y }
end

-- A camera as JSON: position, quaternion, field of view.
function Scene.poseOf(view: View)
	local axis, angle = view.cframe:ToAxisAngle()
	local s = math.sin(angle / 2)
	local p = view.cframe.Position
	return {
		position = { p.X, p.Y, p.Z },
		quaternion = { axis.X * s, axis.Y * s, axis.Z * s, math.cos(angle / 2) },
		fov = view.fov,
		aspect = view.width / math.max(1, view.height),
		near = 0.1,
		far = REACH,
	}
end

-- The ray through a viewport point. Viewport points ignore the top bar, as ViewportPointToRay does.
local function rayAt(x: number, y: number, view: View): (Vector3, Vector3)
	local tangent = math.tan(math.rad(view.fov) / 2)
	local nx = (x / view.width) * 2 - 1
	local ny = 1 - (y / view.height) * 2
	local inCamera = Vector3.new(nx * tangent * view.width / view.height, ny * tangent, -1)
	return view.cframe.Position, view.cframe:VectorToWorldSpace(inCamera).Unit
end
Scene.rayAt = rayAt

local function toScreen(point: Vector3, view: View): { number }?
	local inCamera = view.cframe:PointToObjectSpace(point)
	if inCamera.Z >= -1e-3 then
		return nil
	end
	local tangent = math.tan(math.rad(view.fov) / 2)
	local nx = inCamera.X / (-inCamera.Z * tangent * view.width / view.height)
	local ny = inCamera.Y / (-inCamera.Z * tangent)
	return { (nx + 1) / 2 * view.width, (1 - ny) / 2 * view.height }
end

local function worldBox(cf: CFrame, size: Vector3)
	local half = size / 2
	local x, y, z = cf.XVector, cf.YVector, cf.ZVector
	local ex = math.abs(x.X) * half.X + math.abs(y.X) * half.Y + math.abs(z.X) * half.Z
	local ey = math.abs(x.Y) * half.X + math.abs(y.Y) * half.Y + math.abs(z.Y) * half.Z
	local ez = math.abs(x.Z) * half.X + math.abs(y.Z) * half.Y + math.abs(z.Z) * half.Z
	local p = cf.Position
	return { min = { p.X - ex, p.Y - ey, p.Z - ez }, max = { p.X + ex, p.Y + ey, p.Z + ez } }
end

local function boundsOf(instance: Instance)
	if instance:IsA("BasePart") then
		if instance:IsA("Terrain") then
			return nil
		end
		return worldBox(instance.CFrame, instance.Size)
	end
	if instance:IsA("Model") then
		local ok, cf, size = pcall(function()
			return instance:GetBoundingBox()
		end)
		if ok then
			return worldBox(cf, size)
		end
	end
	return nil
end

local function union(a, b)
	if not a then
		return b
	end
	if not b then
		return a
	end
	return {
		min = { math.min(a.min[1], b.min[1]), math.min(a.min[2], b.min[2]), math.min(a.min[3], b.min[3]) },
		max = { math.max(a.max[1], b.max[1]), math.max(a.max[2], b.max[2]), math.max(a.max[3], b.max[3]) },
	}
end

local function screenRect(bounds, view: View): Core.Rect?
	local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
	for _, px in { bounds.min[1], bounds.max[1] } do
		for _, py in { bounds.min[2], bounds.max[2] } do
			for _, pz in { bounds.min[3], bounds.max[3] } do
				local s = toScreen(Vector3.new(px, py, pz), view)
				if not s then
					return nil -- reaches behind the camera: it cannot be inside a loop
				end
				minX, minY = math.min(minX, s[1]), math.min(minY, s[2])
				maxX, maxY = math.max(maxX, s[1]), math.max(maxY, s[2])
			end
		end
	end
	return { minX = minX, minY = minY, maxX = maxX, maxY = maxY }
end

local function plainValue(value: any): any
	local t = typeof(value)
	if t == "string" or t == "number" or t == "boolean" then
		return value
	end
	return tostring(value)
end

local function dataOf(instance: Instance)
	local data: { [string]: any } = {}
	local ok, attributes = pcall(function()
		return instance:GetAttributes()
	end)
	if ok then
		for name, value in attributes do
			data[name] = plainValue(value)
		end
	end
	if instance:IsA("BasePart") and not instance:IsA("Terrain") then
		data.material = instance.Material.Name
		data.color = "#" .. instance.Color:ToHex()
		data.size = { instance.Size.X, instance.Size.Y, instance.Size.Z }
	end
	if instance:IsA("MeshPart") then
		data.meshId = instance.MeshId
	end
	if next(data) == nil then
		return nil
	end
	return data
end

local function keyOf(instance: Instance): string
	local ok, id = pcall(function()
		return instance:GetDebugId(8)
	end)
	return if ok then id else instance:GetFullName()
end

local function entityOf(instance: Instance)
	return {
		key = keyOf(instance),
		label = instance.Name,
		kind = instance.ClassName,
		locator = { strategy = "instance", value = instance:GetFullName() },
		bounds = boundsOf(instance),
		data = dataOf(instance),
	}
end

-- Measuring a Model walks all its parts; a pick asks about the same few things over and over.
local thingCache: { [Instance]: Instance } = {}

-- The thing a part belongs to: its nearest Model, unless that Model is really a building.
local function thingOf(part: Instance): Instance
	local known = thingCache[part]
	if known then
		return known
	end
	local thing = part
	local model = part:FindFirstAncestorWhichIsA("Model")
	if model and model ~= workspace then
		local ok, _, size = pcall(function()
			return model:GetBoundingBox()
		end)
		if ok and size.Magnitude <= THING_DIAGONAL then
			thing = model
		end
	end
	thingCache[part] = thing
	return thing
end

-- The hit, then its Models and Folders up to the Workspace. `depth` is where the thing itself is.
local function chainOf(part: Instance): ({ any }, number)
	local thing = thingOf(part)
	local chain = {}
	local depth = 0
	local cursor: Instance? = part
	while cursor and cursor ~= workspace and cursor ~= game do
		if cursor == part or cursor:IsA("Model") or cursor:IsA("Folder") then
			if cursor == thing then
				depth = #chain
			end
			table.insert(chain, entityOf(cursor))
		end
		cursor = cursor.Parent
	end
	return chain, depth
end

-- Everything along a ray, nearest first; things nobody can see let the ray through.
local function castAll(origin: Vector3, direction: Vector3, wanted: number)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.IgnoreWater = true
	local skipped = {}
	local hits = {}
	for _ = 1, wanted + 6 do
		params.FilterDescendantsInstances = skipped
		local result = workspace:Raycast(origin, direction * REACH, params)
		if not result then
			break
		end
		local hit = result.Instance
		table.insert(skipped, hit)
		if not (hit:IsA("BasePart") and hit.Transparency >= 0.95) then
			table.insert(hits, result)
			if #hits >= wanted then
				break
			end
		end
	end
	return hits
end

export type Pick = {
	target: any?,
	surface: { { point: Vector3, normal: Vector3, distance: number } },
	instance: Instance?,
	rays: number,
}

-- What a loop on the screen holds.
function Scene.pickLoop(points: { { number } }, view: View): Pick
	local polygon = points
	thingCache = {}
	local stats: { [string]: any } = {}
	local samples = Core.samplePolygon(polygon, RAYS)
	local rays = 0
	for i, p in samples do
		if i > RAYS * 1.5 then
			break
		end
		rays += 1
		local origin, direction = rayAt(p[1], p[2], view)
		for order, result in castAll(origin, direction, 4) do
			local thing = thingOf(result.Instance)
			local key = keyOf(thing)
			local seen = stats[key]
			if not seen then
				seen = { thing = thing, part = result.Instance, hits = 0, behind = 0, depths = {}, surface = {}, bounds = nil }
				stats[key] = seen
			end
			if order == 1 then
				seen.hits += 1
				table.insert(seen.surface, { point = result.Position, normal = result.Normal, distance = result.Distance })
			else
				seen.behind += 1
			end
			table.insert(seen.depths, result.Distance)
			seen.bounds = seen.bounds or boundsOf(thing)
		end
	end
	local candidates = {}
	for key, seen in stats do
		table.sort(seen.depths)
		local rect = seen.bounds and screenRect(seen.bounds, view)
		table.insert(candidates, {
			key = key,
			hits = seen.hits,
			behind = seen.behind,
			depth = seen.depths[math.ceil(#seen.depths / 2)],
			enclosure = if rect then Core.enclosure(rect, polygon) else 0,
		})
	end
	local ranked = Core.rank(candidates, rays)
	if #ranked.members == 0 and #ranked.others == 0 then
		return { surface = {}, rays = rays }
	end

	local layers = {}
	local depth = 0
	local surface = {}
	local members = nil
	local instance = nil
	if #ranked.members == 1 then
		local seen = stats[ranked.members[1].key]
		local chain, at = chainOf(seen.part)
		table.insert(layers, chain)
		depth = at
		surface = seen.surface
		instance = seen.thing
	elseif #ranked.members > 1 then
		local chains = {}
		local bounds = nil
		members = {}
		for _, member in ranked.members do
			local seen = stats[member.key]
			local chain, at = chainOf(seen.part)
			local own = {}
			for i = at + 1, #chain do
				table.insert(own, chain[i])
			end
			table.insert(chains, own)
			table.insert(members, chain[at + 1])
			bounds = union(bounds, seen.bounds)
			for _, s in seen.surface do
				table.insert(surface, s)
			end
		end
		local shared = Core.commonChain(chains)
		local names = {}
		for _, m in members do
			table.insert(names, m.label)
		end
		local first = stats[ranked.members[1].key]
		instance = first.thing
		local group = {
			key = "group:" .. table.concat(names, ","),
			label = #members .. " × " .. first.thing.ClassName .. if shared[1] then " in " .. shared[1].label else "",
			kind = "group",
			locator = { strategy = "instance", value = table.concat(names, ", ") },
			bounds = bounds,
			data = { members = names },
		}
		local chain = { group }
		for _, entity in shared do
			table.insert(chain, entity)
		end
		table.insert(layers, chain)
	end
	for _, other in ranked.others do
		if #layers >= MAX_LAYERS then
			break
		end
		local chain = chainOf(stats[other.key].part)
		table.insert(layers, chain)
	end
	return {
		target = { layers = layers, layer = 0, depth = depth, partial = ranked.partial, members = members },
		surface = surface,
		instance = instance,
		rays = rays,
	}
end

-- What is under a point: each thing along the ray.
function Scene.pickPoint(x: number, y: number, view: View): Pick
	thingCache = {}
	local origin, direction = rayAt(x, y, view)
	local results = castAll(origin, direction, MAX_LAYERS)
	if #results == 0 then
		return { surface = {}, rays = 1 }
	end
	local layers = {}
	local seenKeys = {}
	local depth = 0
	for i, result in results do
		local key = keyOf(thingOf(result.Instance))
		if not seenKeys[key] then
			seenKeys[key] = true
			local chain, at = chainOf(result.Instance)
			table.insert(layers, chain)
			if i == 1 then
				depth = at
			end
		end
	end
	local first = results[1]
	return {
		target = { layers = layers, layer = 0, depth = depth, partial = false },
		surface = { { point = first.Position, normal = first.Normal, distance = first.Distance } },
		instance = thingOf(first.Instance),
		rays = 1,
	}
end

-- The plane to lay the ink on: through the middle of what was hit, along its surface when that is one
-- surface, facing the camera when it is not, or when the surface is seen nearly edge-on. A place on the
-- ground is the exception: seen at a shallow angle from afar, a mark on it should still lie on it.
function Scene.inkPlane(surface: { any }, view: View, fallbackDistance: number, onGround: boolean?): (Vector3, Vector3)
	local facing = -view.cframe.LookVector
	if #surface == 0 then
		return view.cframe.Position + view.cframe.LookVector * fallbackDistance, facing
	end
	local sorted = table.clone(surface)
	table.sort(sorted, function(a, b)
		return a.distance < b.distance
	end)
	local middle = sorted[math.ceil(#sorted / 2)]
	local sum = Vector3.zero
	for _, s in surface do
		sum += s.normal
	end
	if sum.Magnitude / #surface > 0.8 then
		local normal = sum.Unit
		local toEye = (view.cframe.Position - middle.point).Unit
		if normal:Dot(toEye) > (if onGround and normal.Y > 0.8 then 0.05 else 0.3) then
			return middle.point, normal
		end
	end
	return middle.point, facing
end

-- Screen points onto a plane. A point whose ray misses it stays at the plane's distance.
function Scene.liftOnto(points: { { number } }, planePoint: Vector3, normal: Vector3, view: View): { Vector3 }
	local eye = view.cframe.Position
	local reach = (planePoint - eye).Magnitude
	local out = {}
	for _, p in points do
		local origin, direction = rayAt(p[1], p[2], view)
		local denominator = direction:Dot(normal)
		local t = if math.abs(denominator) > 1e-5 then (planePoint - origin):Dot(normal) / denominator else -1
		if t > 0 and t < reach * 3 then
			table.insert(out, origin + direction * t)
		else
			table.insert(out, origin + direction * reach)
		end
	end
	return out
end

local function arrayOf(v: Vector3): { number }
	return { v.X, v.Y, v.Z }
end
Scene.arrayOf = arrayOf

-- A thing this big on the screen is a surface rather than a thing: a mark on it is about a place on
-- it. So is what reaches behind the camera, what has no size of its own, and something wide and flat
-- (a floor, a wall) seen whole from afar.
function Scene.isSurfaceLike(entity: any?, view: View): boolean
	local bounds = entity and entity.bounds
	if not bounds then
		return true
	end
	local rect = screenRect(bounds, view)
	if not rect then
		return true
	end
	local across = (rect.maxX - rect.minX) / view.width
	local high = (rect.maxY - rect.minY) / view.height
	if across * high > 0.4 then
		return true
	end
	local sides = { bounds.max[1] - bounds.min[1], bounds.max[2] - bounds.min[2], bounds.max[3] - bounds.min[3] }
	table.sort(sides, function(a, b)
		return a > b
	end)
	return sides[3] < sides[2] * 0.12 and math.max(across, high) > 0.3
end

-- The parts around a point. A field of its own, so that a test can stand in for the physics.
function Scene.partsNear(point: Vector3, radius: number): { Instance }
	local params = OverlapParams.new()
	params.MaxParts = NEAR_PARTS
	local ok, parts = pcall(function()
		return workspace:GetPartBoundsInRadius(point, radius, params)
	end)
	return if ok then parts else {}
end

local function distanceToBox(point: Vector3, bounds): number
	local dx = math.max(bounds.min[1] - point.X, 0, point.X - bounds.max[1])
	local dy = math.max(bounds.min[2] - point.Y, 0, point.Y - bounds.max[2])
	local dz = math.max(bounds.min[3] - point.Z, 0, point.Z - bounds.max[3])
	return math.sqrt(dx * dx + dy * dy + dz * dz)
end

-- The ground under a place is not something near it.
local function liesUnder(point: Vector3, bounds): boolean
	local min, max = bounds.min, bounds.max
	local flat = max[2] - min[2] < 0.1 * math.min(max[1] - min[1], max[3] - min[3])
	return flat and point.X >= min[1] and point.X <= max[1] and point.Z >= min[3] and point.Z <= max[3]
end

-- What stands around a place, nearest first, leaving out the given things (what it is on, what it is about).
function Scene.nearby(point: Vector3, leaveOut: { [string]: boolean }, count: number?): { any }
	local wanted = count or 5
	local seen: { [string]: boolean } = {}
	local out = {}
	for _, radius in NEAR_RADII do
		for _, part in Scene.partsNear(point, radius) do
			if part:IsA("BasePart") and not part:IsA("Terrain") and (part :: BasePart).Transparency < 0.95 then
				local thing = thingOf(part)
				local key = keyOf(thing)
				if not seen[key] then
					seen[key] = true
					local bounds = boundsOf(thing)
					if bounds and not leaveOut[key] and not PLAIN_NAMES[thing.Name] and not liesUnder(point, bounds) then
						table.insert(out, { label = thing.Name, kind = thing.ClassName, locator = { strategy = "instance", value = thing:GetFullName() }, distance = distanceToBox(point, bounds) })
					end
				end
			end
		end
		if #out >= wanted then
			break
		end
	end
	table.sort(out, function(a, b)
		return a.distance < b.distance
	end)
	return table.move(out, 1, math.min(wanted, #out), 1, {})
end

-- Where a mark is, as a place: its middle, its size, what it lies on and what stands around it.
function Scene.placeOf(ink: { Vector3 }, normal: Vector3, target: any?): any
	local sum = Vector3.zero
	local minX, minY, minZ = math.huge, math.huge, math.huge
	local maxX, maxY, maxZ = -math.huge, -math.huge, -math.huge
	for _, p in ink do
		sum += p
		minX, minY, minZ = math.min(minX, p.X), math.min(minY, p.Y), math.min(minZ, p.Z)
		maxX, maxY, maxZ = math.max(maxX, p.X), math.max(maxY, p.Y), math.max(maxZ, p.Z)
	end
	local center = sum / math.max(1, #ink)
	local own: { [string]: boolean } = {}
	local entity = nil
	if target then
		local chain = target.layers[target.layer + 1] or {}
		for _, e in chain do
			own[e.key] = true
		end
		for _, m in target.members or {} do
			own[m.key] = true
		end
		entity = chain[target.depth + 1]
	end
	return {
		center = arrayOf(center),
		normal = arrayOf(normal),
		size = { maxX - minX, maxY - minY, maxZ - minZ },
		on = if target and target.partial and entity then entity.label else nil,
		near = Scene.nearby(center, own),
	}
end

-- A ring on a surface, for a single spot.
function Scene.ringOn(center: Vector3, normal: Vector3, radius: number): { Vector3 }
	local up = if math.abs(normal.Y) > 0.9 then Vector3.new(1, 0, 0) else Vector3.new(0, 1, 0)
	local side = up:Cross(normal).Unit
	local other = normal:Cross(side).Unit
	local out = {}
	local count = 20
	for i = 0, count - 1 do
		local angle = i / count * math.pi * 2
		table.insert(out, center + side * math.cos(angle) * radius + other * math.sin(angle) * radius)
	end
	return out
end

-- What is first under a line on the screen, at up to `count` points along it, its two ends always among them.
function Scene.alongLine(points: { { number } }, view: View, count: number?): { any }
	thingCache = {}
	local n = math.max(2, math.min(count or 24, #points))
	local chains: { [Instance]: { chain: { any }, depth: number } } = {}
	local out = {}
	for i = 0, n - 1 do
		local at = points[1 + math.round(i * (#points - 1) / (n - 1))]
		local origin, direction = rayAt(at[1], at[2], view)
		local result = castAll(origin, direction, 1)[1]
		local hit = nil
		if result then
			local part = result.Instance
			local known = chains[part]
			if not known then
				local chain, depth = chainOf(part)
				known = { chain = chain, depth = depth }
				chains[part] = known
			end
			hit = {
				thing = thingOf(part),
				chain = known.chain,
				depth = known.depth,
				entity = known.chain[known.depth + 1],
				point = result.Position,
				normal = result.Normal,
				distance = result.Distance,
			}
		end
		table.insert(out, { at = at, hit = hit })
	end
	return out
end

-- The height most of these hits on level surfaces share, when they do share one (not a flight of stairs).
local function levelOf(flat: { any }): number?
	local heights, distances = {}, {}
	for _, hit in flat do
		table.insert(heights, hit.point.Y)
		table.insert(distances, hit.distance)
	end
	table.sort(heights)
	table.sort(distances)
	local middle = heights[math.floor(#heights / 2) + 1]
	local tolerance = distances[math.floor(#distances / 2) + 1] * 0.02
	local same = 0
	for _, y in heights do
		if math.abs(y - middle) <= tolerance then
			same += 1
		end
	end
	return if same >= #heights * 0.7 then middle else nil
end

-- A line drawn mostly over level ground lies on that ground, passing behind what stands in the way: a
-- way to walk. Any other line follows what it crosses. `touches` says, for each point, that it really
-- is on what shows there on the screen, not on ground hidden behind it.
function Scene.lineInWorld(samples: { any }, view: View, fallbackDistance: number): any
	local hits, flat = {}, {}
	for _, sample in samples do
		if sample.hit then
			table.insert(hits, sample.hit)
			if sample.hit.normal.Y > 0.8 then
				table.insert(flat, sample.hit)
			end
		end
	end
	local onGround = #flat >= 2 and #flat * 2 >= #hits
	local level = if onGround then levelOf(flat) else nil
	-- Near the horizon the ground runs away to nowhere.
	local farthest = 0
	for _, hit in flat do
		farthest = math.max(farthest, hit.distance * 3)
	end
	local reach = if hits[1] then hits[1].distance else fallbackDistance
	local points, touches = {}, {}
	for _, sample in samples do
		local origin, direction = rayAt(sample.at[1], sample.at[2], view)
		local hit = sample.hit
		local point: Vector3? = nil
		if level and math.abs(direction.Y) > 1e-5 then
			local t = (level - origin.Y) / direction.Y
			if t > 0 and t < farthest then
				point = origin + direction * t
			end
		end
		if not point then
			if hit then
				reach = hit.distance
				point = hit.point
			else
				point = origin + direction * reach
			end
		end
		table.insert(points, point)
		table.insert(touches, hit ~= nil and (hit.point - (point :: Vector3)).Magnitude < hit.distance * 0.02)
	end
	return { points = points, touches = touches, onGround = onGround, normal = if level then Vector3.new(0, 1, 0) else -view.cframe.LookVector }
end

-- From here to there: a route along the ground, or, starting on a thing, something to move.
function Scene.lineMark(points: { { number } }, shape: any, view: View, fallbackDistance: number): any
	local samples = Scene.alongLine(points, view)
	local first, last = samples[1].hit, samples[#samples].hit
	local function thingAt(hit: any): any
		return if hit and not Scene.isSurfaceLike(hit.entity, view) then hit else nil
	end
	local fromThing, toThing = thingAt(first), thingAt(last)
	local line = Scene.lineInWorld(samples, view, fallbackDistance)
	-- A straight line from a thing, or to one, is one move through the air. With bends, its ends stay on
	-- their things and go straight to the first point that really is on the ground, not by way of the
	-- ground hidden behind the thing.
	local straight = (fromThing ~= nil or toThing ~= nil) and shape.via == nil
	local inWorld: { Vector3 }
	if straight then
		inWorld = { if fromThing then fromThing.point else line.points[1], if toThing then toThing.point else line.points[#line.points] }
	else
		local start, finish = 1, #line.points
		if fromThing then
			while start < finish and not line.touches[start] do
				start += 1
			end
		end
		if toThing then
			while finish > start and not line.touches[finish] do
				finish -= 1
			end
		end
		inWorld = table.move(line.points, start, finish, 1, {})
		if fromThing and inWorld[1] ~= fromThing.point then
			table.insert(inWorld, 1, fromThing.point)
		end
		if toThing and inWorld[#inWorld] ~= toThing.point then
			table.insert(inWorld, toThing.point)
		end
	end
	-- Each thing once, in the order the line meets it, and how often: what it mostly lies on is what it runs along.
	local met, order = {}, {}
	for _, sample in samples do
		local hit = sample.hit
		if hit then
			local key = hit.entity.key
			if met[key] then
				met[key].count += 1
			else
				met[key] = { hit = hit, count = 1 }
				table.insert(order, key)
			end
		end
	end
	local runsAlong = nil
	local most = 0
	for _, key in order do
		if met[key].count > most then
			most = met[key].count
			runsAlong = met[key].hit
		end
	end
	local passed: { [string]: boolean } = {}
	for _, hit in { first or false, last or false, runsAlong or false } do
		if hit then
			passed[hit.entity.key] = true
		end
	end
	local through, named = {}, {}
	for _, key in order do
		local label = met[key].hit.entity.label
		if not passed[key] and not named[label] then
			named[label] = true
			table.insert(through, label)
		end
	end
	local function endOf(hit: any, isThing: boolean, at: Vector3)
		local own: { [string]: boolean } = {}
		for _, e in hit and hit.chain or {} do
			own[e.key] = true
		end
		return {
			at = arrayOf(at),
			label = hit and hit.entity.label,
			kind = hit and hit.entity.kind,
			locator = hit and hit.entity.locator,
			isThing = isThing,
			near = Scene.nearby(at, own, 3),
		}
	end
	local ink = {}
	local length = 0
	for i, p in inWorld do
		table.insert(ink, arrayOf(p))
		if i > 1 then
			length += (p - inWorld[i - 1]).Magnitude
		end
	end
	local subject = fromThing or toThing or runsAlong
	return {
		world = {
			anchor = ink[1],
			normal = arrayOf(line.normal),
			ink = ink,
			closed = false,
			path = {
				points = ink,
				length = length,
				onGround = line.onGround and not straight,
				from = endOf(first, fromThing ~= nil, inWorld[1]),
				to = endOf(last, toThing ~= nil, inWorld[#inWorld]),
				through = through,
			},
		},
		target = if subject then { layers = { subject.chain }, layer = 0, depth = subject.depth, partial = not fromThing and not toThing } else nil,
		instance = subject and subject.thing,
		distance = subject and subject.distance,
	}
end

-- Where a player's own character stands, for "next to me".
function Scene.viewerOf(player: Player?): any
	local character = player and player.Character
	local root: any = character and (character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart)
	if not root then
		return nil
	end
	return { position = arrayOf(root.Position), facing = arrayOf(root.CFrame.LookVector) }
end

-- An Instance from its full name, when the path still leads somewhere.
function Scene.findInstance(fullName: string): Instance?
	local cursor: Instance? = game
	for name in string.gmatch(fullName, "[^.]+") do
		if not cursor then
			return nil
		end
		cursor = cursor:FindFirstChild(name)
	end
	return if cursor ~= game then cursor else nil
end

-- Where a place is, in words: the nearest named Folder or Model above what was hit.
function Scene.titleFor(instance: Instance?): string
	if instance then
		-- Above the thing itself: "where" rather than "what".
		local cursor: Instance? = instance.Parent
		while cursor and cursor ~= workspace do
			if cursor:IsA("Folder") or cursor:IsA("Model") then
				return cursor.Name
			end
			cursor = cursor.Parent
		end
	end
	return game.Name
end

return Scene
