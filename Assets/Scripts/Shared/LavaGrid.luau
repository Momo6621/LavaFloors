--!strict
-- Lava grid schedule. Pure function of the server clock so every client agrees without replicating movement.
local G = {}

local SPIN = { 0, 3.5 / 12 }
local GROW = { 3.5 / 12, 6 / 12 }
local WARN = { 6 / 12, 7.5 / 12 }
local FALL = { 7.5 / 12, 8.3 / 12 }
local RISE = { 8.5 / 12, 11.5 / 12 }
local FALL_DEPTH = 45
local TUCK_DROP = 1.4

local parsed: { [string]: { number } } = {}
local planCache: { [string]: { appear: { [number]: number }, leave: { [number]: number }, drop: { [number]: number } } } = {}

local function attr(tower: Instance, name: string): number?
	local v = tower:GetAttribute(name)
	return if type(v) == "number" then v else nil
end

local function list(tower: Instance, name: string): { number }
	local raw = tower:GetAttribute(name)
	if type(raw) ~= "string" then
		return {}
	end
	local hit = parsed[raw]
	if hit then
		return hit
	end
	local out = {}
	for n in string.gmatch(raw, "-?[%d%.]+") do
		table.insert(out, tonumber(n) :: number)
	end
	parsed[raw] = out
	return out
end

local function smooth(a: number): number
	a = math.clamp(a, 0, 1)
	return a * a * (3 - 2 * a)
end

local function window(s: number, w: { number }, phaseTime: number): number
	return smooth((s - w[1] * phaseTime) / ((w[2] - w[1]) * phaseTime))
end

function G.Ring(size: number, row: number, col: number): number
	local mid = (size + 1) / 2
	return math.max(math.abs(row - mid), math.abs(col - mid))
end

function G.Phase(tower: Instance, t: number): (number, number)
	local start, phaseTime, phases = attr(tower, "Start"), attr(tower, "PhaseTime") or 12, attr(tower, "Phases") or 0
	if not start or t < start then
		return -1, 0
	end
	local p = math.floor((t - start) / phaseTime)
	if p >= phases then
		return phases, 0
	end
	return p, (t - start) - p * phaseTime
end

function G.EndsAt(tower: Instance): number?
	local start, phaseTime, phases = attr(tower, "Start"), attr(tower, "PhaseTime") or 12, attr(tower, "Phases") or 0
	return if start then start + phaseTime * phases else nil
end

function G.Plan(tower: Instance): { appear: { [number]: number }, leave: { [number]: number }, drop: { [number]: number } }
	local seed = attr(tower, "GridSeed") or 1
	local size = attr(tower, "Size") or 9
	local key = table.concat({ seed, size, tostring(tower:GetAttribute("StartRings")), tostring(tower:GetAttribute("Grow")), tostring(tower:GetAttribute("Shrink")), tostring(tower:GetAttribute("Drops")) }, "|")
	local hit = planCache[key]
	if hit then
		return hit
	end
	local outer = (size - 1) / 2
	local ringAppear: { [number]: number } = {}
	local present = attr(tower, "StartRings") or outer
	for phase, count in list(tower, "Grow") do
		for _ = 1, count do
			if present < outer then
				present += 1
				ringAppear[present] = phase - 1
			end
		end
	end
	local ringLeave: { [number]: number } = {}
	local edge = outer
	for phase, count in list(tower, "Shrink") do
		for _ = 1, count do
			if edge > 0 then
				ringLeave[edge] = phase - 1
				edge -= 1
			end
		end
	end
	local plan = { appear = {}, leave = {}, drop = {} }
	for row = 1, size do
		for col = 1, size do
			local index = (row - 1) * size + col
			local ring = G.Ring(size, row, col)
			plan.appear[index] = ringAppear[ring]
			plan.leave[index] = ringLeave[ring]
		end
	end
	for phase, count in list(tower, "Drops") do
		local q = phase - 1
		local pool = {}
		for index = 1, size * size do
			local appear, leave = plan.appear[index], plan.leave[index]
			if not plan.drop[index] and (appear == nil or appear <= q) and (leave == nil or leave > q) then
				table.insert(pool, index)
			end
		end
		local rng = Random.new(seed * 7919 + phase * 104729)
		for _ = 1, math.min(count, #pool - 1) do
			plan.drop[table.remove(pool, rng:NextInteger(1, #pool)) :: number] = q
		end
	end
	planCache[key] = plan
	return plan
end

function G.Pose(tower: Instance, t: number): (number, number)
	local phaseTime = attr(tower, "PhaseTime") or 12
	local spins = list(tower, "Spins")
	local baseY, riseStep = attr(tower, "BaseY") or 10, attr(tower, "RiseStep") or 10
	local p, s = G.Phase(tower, t)
	if p < 0 then
		return 0, baseY
	end
	local angle = 0
	for q = 1, math.min(p, #spins) do
		angle += math.rad(spins[q])
	end
	local y = baseY + riseStep * p
	if p < (attr(tower, "Phases") or 0) then
		angle += math.rad(spins[p + 1] or 0) * window(s, SPIN, phaseTime)
		y += riseStep * window(s, RISE, phaseTime)
	end
	return angle, y
end

local function freezeTime(tower: Instance, phase: number): number
	local phaseTime = attr(tower, "PhaseTime") or 12
	return (attr(tower, "Start") or 0) + phase * phaseTime + RISE[1] * phaseTime
end

function G.TileState(tower: Instance, row: number, col: number, t: number): (string, number, number)
	local size = attr(tower, "Size") or 9
	local phaseTime = attr(tower, "PhaseTime") or 12
	local index = (row - 1) * size + col
	local plan = G.Plan(tower)
	local appear, leave, drop = plan.appear[index], plan.leave[index], plan.drop[index]
	local p, s = G.Phase(tower, t)
	if appear then
		if p < appear or (p == appear and s < GROW[1] * phaseTime) then
			return "Hidden", 0, 0
		elseif p == appear and s < GROW[2] * phaseTime then
			return "Growing", 0, window(s, GROW, phaseTime)
		end
	end
	if drop then
		if p > drop or (p == drop and s >= FALL[2] * phaseTime) then
			return "Gone", FALL_DEPTH, 1
		elseif p == drop and s >= FALL[1] * phaseTime then
			return "Falling", FALL_DEPTH * window(s, FALL, phaseTime), 1
		elseif p == drop and s >= WARN[1] * phaseTime then
			return "Warning", 0, 1
		end
	end
	if leave then
		if p > leave + 1 then
			return "Gone", FALL_DEPTH, 1
		elseif p > leave or (p == leave and s >= RISE[1] * phaseTime) then
			return "Left", 0, 1
		elseif p == leave and s >= WARN[1] * phaseTime then
			return "Warning", 0, 1
		end
	end
	return "Still", 0, 1
end

function G.TileCFrame(tower: Instance, row: number, col: number, t: number): CFrame
	local size = attr(tower, "Size") or 9
	local tile = attr(tower, "Tile") or 7
	local step = tile + (attr(tower, "Gap") or 0.15)
	local mid = (size + 1) / 2
	local state, sink, out = G.TileState(tower, row, col, t)
	local poseTime = t
	if state == "Left" or (state == "Gone" and G.Plan(tower).leave[(row - 1) * size + col] ~= nil and not G.Plan(tower).drop[(row - 1) * size + col]) then
		poseTime = freezeTime(tower, G.Plan(tower).leave[(row - 1) * size + col] :: number)
	end
	local angle, y = G.Pose(tower, poseTime)
	local x, z = (col - mid) * step, (row - mid) * step
	local lift = 0
	if out < 1 then
		local slide = math.min(1, out / 0.7)
		local pop = math.max(0, (out - 0.7) / 0.3)
		if math.abs(col - mid) >= math.abs(row - mid) then
			x -= math.sign(col - mid) * step * (1 - slide)
		else
			z -= math.sign(row - mid) * step * (1 - slide)
		end
		lift = -TUCK_DROP * (1 - pop)
	end
	local centre = CFrame.new(attr(tower, "CenterX") or 0, y - sink + lift, attr(tower, "CenterZ") or 0)
	return centre * CFrame.Angles(0, angle, 0) * CFrame.new(x, 0, z)
end

function G.Delta(tower: Instance?, tilePart: Instance?, t: number): CFrame
	if not tower or not tilePart then
		return CFrame.identity
	end
	local row, col = tilePart:GetAttribute("Row"), tilePart:GetAttribute("Col")
	if type(row) ~= "number" or type(col) ~= "number" then
		return CFrame.identity
	end
	return G.TileCFrame(tower, row, col, t) * G.TileCFrame(tower, row, col, -math.huge):Inverse()
end

function G.FallLift(item: Instance, t: number): number
	local from, start, speed = item:GetAttribute("FallFrom"), item:GetAttribute("FallStart"), item:GetAttribute("FallSpeed")
	if type(from) ~= "number" or type(start) ~= "number" or type(speed) ~= "number" then
		return 0
	end
	return math.max(0, from - speed * math.max(0, t - start))
end

function G.Safe(tower: Instance, row: number, col: number, t: number): boolean
	if G.TileState(tower, row, col, t) ~= "Still" then
		return false
	end
	local size = attr(tower, "Size") or 9
	local index = (row - 1) * size + col
	local plan = G.Plan(tower)
	local p = G.Phase(tower, t)
	local drop, leave = plan.drop[index], plan.leave[index]
	return (drop == nil or drop > p + 1) and (leave == nil or leave > p + 1)
end

return G
