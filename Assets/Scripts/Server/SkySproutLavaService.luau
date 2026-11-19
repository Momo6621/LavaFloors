--!strict
-- Lava Rush: survive the lava grid until the last phase.

local Players = game:GetService("Players")
local Run = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local Profiles = require(script.Parent.SkySproutProfiles)
local GameConfig = require(game.ReplicatedStorage.SkySproutConfig) :: any
local Themes = require(game.ReplicatedStorage:WaitForChild("LavaThemes")) :: any
local Grid = require(game.ReplicatedStorage:WaitForChild("LavaGrid")) :: any
local FruitModels = game.ReplicatedStorage:WaitForChild("FruitModels")
local applyHat: (Player) -> ()
local wear: { [number]: number } = {}

local CFG = {
	-- Arena
	Floor = 1,
	Center = Vector3.new(-250, 0, 300),
	Beacon = Vector3.new(-200.7, 0, 262.4),
	MinPlayers = 1,
	Countdown = 6,
	ResultsTime = 4,

	-- Grid
	GridSize = 9,
	GridTile = 8,
	GridGap = 0.15,
	StartRings = 2,
	GridBaseY = 12,
	GridRise = 10,
	PhaseTime = 10,
	StartDelay = 4,
	GridSpins = { 90, -90, 180, 45, -90, 135, -180 },
	GridGrow = { 1, 1, 0, 0, 0, 0, 0 },
	GridShrink = { 0, 0, 1, 0, 1, 1, 0 },
	GridDrops = { 0, 2, 3, 3, 2, 1, 1 },
	RoundJumpPower = 48,
	CharacterScale = 0.8,

	-- Lava
	LavaBelow = 7,
	LavaLag = 2,
	LavaPool = 92,
	LavaStart = -6,
	LavaGlowRange = 60,
	LavaGlowBrightness = 2.2,

	-- Island
	IslandRadius = 340,

	-- Stage lights
	StageLights = 4,
	StageLightHeight = 26,
	StageLightReach = 30,

	-- Shove
	ShoveRange = 9,
	ShoveCooldown = 0.8,
	ShoveSpeed = 55,
	ShoveLift = 18,

	-- Rewards
	EmberCoins = 3,
	CoinsPerStud = 0.15,
	SurviveCoins = 20,
	CrownCoins = 60,
	XPPerCoin = 2,
	FriendBonus = 0.25,

	-- Shield
	ShieldOrbs = 2,
	ShieldTime = 10,

	-- Drops
	DropEvery = 8,
	DropPartyEvery = 3.5,
	DropFirstAt = 6,
	DropMaxLive = 3,
	DropLifetime = 16,
	SpeedBoost = 10,
	SpeedTime = 6,
	JumpBoostPower = 64,
	JumpTime = 7,
	EmberBag = 3,

	-- Keep moving
	CampTime = 6,
	CampRespawn = 6,

	-- Raise
	LiftCost = 40,
	LiftTime = 10,
	LiftHeight = 6,
	LiftCooldown = 15,
}

type Mutator = { Id: string, Name: string, Weight: number }
local MUTATORS: { Mutator } = {
	{ Id = "Classic", Name = "Classic", Weight = 3 },
	{ Id = "LowGravity", Name = "🚀 Low Gravity", Weight = 2 },
	{ Id = "TurboSpin", Name = "🌀 Turbo Spin", Weight = 2 },
	{ Id = "HoleParty", Name = "🕳️ Hole Party", Weight = 2 },
	{ Id = "SpeedRush", Name = "💨 Speed Rush", Weight = 2 },
	{ Id = "ShieldParty", Name = "🛡️ Shield Party", Weight = 1 },
	{ Id = "DropParty", Name = "🎁 Drop Party", Weight = 2 },
}
local function pickMutator(previous: Mutator?): Mutator
	local total = 0
	for _, m in MUTATORS do
		total += m.Weight
	end
	for _ = 1, 5 do
		local roll = math.random() * total
		for _, m in MUTATORS do
			roll -= m.Weight
			if roll <= 0 then
				if not previous or m.Id == "Classic" or m.Id ~= previous.Id then
					return m
				end
				break
			end
		end
	end
	return MUTATORS[1]
end
local DEFAULT_GRAVITY = workspace.Gravity

type Runner = {
	peak: number,
	alive: boolean,
	crowned: boolean,
	embers: number,
	enteredAt: number,
	nextShove: number,
	shieldUntil: number,
	speedUntil: number,
	jumpUntil: number,
	rescue: boolean,
	nextLift: number,
}

type Phase = "Idle" | "Countdown" | "Round" | "Results"

local L = {
	Phase = "Idle" :: Phase,
	EndsAt = 0,
	Queue = {} :: { [Player]: boolean },
	Runners = {} :: { [Player]: Runner },
	LavaY = CFG.Center.Y + CFG.LavaStart,
	Mutator = MUTATORS[1],
	Theme = "Sunset",
}
local friends: { [Player]: { [number]: boolean } } = {}

local A: any, event: RemoteEvent, pushStats: (Player) -> (), tell: (Player, string) -> ()
local arenaFolder: Model
local tower: Model? = nil
local lava: BasePart? = nil
local platforms: { BasePart } = {}
local crownHeight = CFG.GridBaseY + #CFG.GridSpins * CFG.GridRise
type Pickup = { item: BasePart, radius: number, take: (Player, any) -> () }
local pickups: { Pickup } = {}

local function data(p: Player): any
	local s = Profiles.Sessions[p]
	return s and s.Data
end

local function root(p: Player): BasePart?
	local r = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
	return if r and r:IsA("BasePart") then r else nil
end

local function now(): number
	return workspace:GetServerTimeNow()
end

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- Grid helpers

local function tileDelta(stepIndex: number): CFrame
	return Grid.Delta(tower, platforms[stepIndex], workspace:GetServerTimeNow())
end

local function tileSafe(tile: BasePart): boolean
	local row, col = tile:GetAttribute("Row"), tile:GetAttribute("Col")
	return tower ~= nil and type(row) == "number" and type(col) == "number" and Grid.Safe(tower, row, col, workspace:GetServerTimeNow())
end

local function ride(item: Instance, stepIndex: number)
	local list = { item }
	for _, d in item:GetDescendants() do
		table.insert(list, d)
	end
	for _, d in list do
		if d:IsA("BasePart") then
			d:SetAttribute("RideStep", stepIndex)
			d:SetAttribute("RestCFrame", d.CFrame)
			CollectionService:AddTag(d, "LavaRider")
		end
	end
end

local function pickupPosition(item: BasePart): Vector3
	local stepIndex = item:GetAttribute("RideStep")
	local rest = item:GetAttribute("RestCFrame")
	if type(stepIndex) == "number" and typeof(rest) == "CFrame" then
		local t = workspace:GetServerTimeNow()
		return (tileDelta(stepIndex) * rest).Position + Vector3.new(0, Grid.FallLift(item, t), 0)
	end
	return item.Position
end

local BadgeService = game:GetService("BadgeService")
local awarded: { [Player]: { [string]: boolean } } = {}
-- Badges & net

local function badge(p: Player, key: string)
	local ids = GameConfig.BadgeIds
	local id = type(ids) == "table" and ids[key] or 0
	if type(id) ~= "number" or id <= 0 then
		return
	end
	awarded[p] = awarded[p] or {}
	if awarded[p][key] then
		return
	end
	awarded[p][key] = true
	task.spawn(function()
		pcall(function()
			if not BadgeService:UserHasBadgeAsync(p.UserId, id) then
				BadgeService:AwardBadge(p.UserId, id)
			end
		end)
	end)
end

local function hasFriendHere(p: Player): boolean
	local mine = friends[p]
	if not mine then
		return false
	end
	for _, o in Players:GetPlayers() do
		if o ~= p and mine[o.UserId] then
			return true
		end
	end
	return false
end

local function count(t: { [Player]: any }): number
	local n = 0
	for _ in t do
		n += 1
	end
	return n
end

local function aliveCount(): number
	local n = 0
	for _, r in L.Runners do
		if r.alive and not r.crowned then
			n += 1
		end
	end
	return n
end

local function gridPhase(): number
	if not tower or L.Phase ~= "Round" then
		return 0
	end
	local phase = Grid.Phase(tower, workspace:GetServerTimeNow())
	return math.clamp(phase + 1, 0, #CFG.GridSpins)
end

local function broadcast()
	local payload = {
		Phase = L.Phase,
		EndsAt = L.EndsAt,
		Mutator = L.Mutator.Name,
		Theme = Themes.Get(L.Theme).Name,
		Queued = count(L.Queue),
		Running = count(L.Runners),
		Alive = aliveCount(),
		LavaY = L.LavaY,
		BaseY = CFG.Center.Y,
		CrownY = CFG.Center.Y + crownHeight,
		GridPhase = gridPhase(),
		GridPhases = #CFG.GridSpins,
	}
	for _, p in Players:GetPlayers() do
		event:FireClient(p, "LavaState", payload)
	end
end

local function personal(p: Player)
	local r = L.Runners[p]
	event:FireClient(p, "LavaMe", {
		Queued = L.Queue[p] == true,
		Running = r ~= nil and r.alive and not r.crowned,
		Crowned = r ~= nil and r.crowned,
		Embers = r and r.embers or 0,
		Peak = r and math.floor(r.peak) or 0,
	})
end

-- Arena

local function buildArena()
	arenaFolder = Instance.new("Model")
	arenaFolder.Name = "LavaRush"
	arenaFolder.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	local c = CFG.Center
	part(arenaFolder, "ArenaFloor", Vector3.new(76, 1, 76), CFrame.new(c + Vector3.new(0, 0.5, 0)), Color3.fromRGB(46, 36, 40), Enum.Material.Basalt)
	for _, e in { Vector3.new(38, 0, 0), Vector3.new(-38, 0, 0), Vector3.new(0, 0, 38), Vector3.new(0, 0, -38) } do
		local long = e.X ~= 0
		local rim = part(
			arenaFolder,
			"Rim",
			if long then Vector3.new(0.6, 0.3, 76.6) else Vector3.new(76.6, 0.3, 0.6),
			CFrame.new(c + e + Vector3.new(0, 1.05, 0)),
			Color3.fromRGB(190, 60, 15),
			Enum.Material.Neon
		)
		rim.Transparency = 0.25
		rim.CanCollide = false
	end

	local function beacon(position: Vector3, label: string, sub: string): Part
		local base = part(arenaFolder, "LavaBeaconBase", Vector3.new(2.2, 6, 2.2), CFrame.new(position + Vector3.new(0, 3, 0)) * CFrame.Angles(0, math.rad(45), 0), Color3.fromRGB(48, 38, 42), Enum.Material.Basalt)
		base.CanCollide = false
		local pillar = part(arenaFolder, "LavaBeacon", Vector3.new(1.6, 1.6, 1.6), CFrame.new(position + Vector3.new(0, 6.8, 0)) * CFrame.Angles(math.rad(45), 0, math.rad(45)), Color3.fromRGB(230, 90, 20), Enum.Material.Neon)
		pillar.CanCollide = false
		local fire = Instance.new("Fire")
		fire.Size = 6
		fire.Heat = 10
		fire.Parent = pillar
		local light = Instance.new("PointLight")
		light.Range = 22
		light.Brightness = 2
		light.Color = Color3.fromRGB(255, 140, 50)
		light.Parent = pillar
		local bb = Instance.new("BillboardGui")
		bb.Size = UDim2.fromOffset(240, 70)
		bb.StudsOffset = Vector3.new(0, 7, 0)
		bb.MaxDistance = 220
		bb.Parent = pillar
		for i, t in { label, sub } do
			local l = Instance.new("TextLabel")
			l.BackgroundTransparency = 1
			l.Size = UDim2.new(1, 0, if i == 1 then 0.6 else 0.4, 0)
			l.Position = UDim2.fromScale(0, if i == 1 then 0 else 0.6)
			l.Font = Enum.Font.FredokaOne
			l.TextScaled = true
			l.TextColor3 = if i == 1 then Color3.fromRGB(255, 190, 70) else Color3.new(1, 1, 1)
			l.Text = t
			local s = Instance.new("UIStroke")
			s.Thickness = 2
			s.Color = Color3.fromRGB(60, 15, 0)
			s.Parent = l
			l.Parent = bb
		end
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Join Lava Rush"
		prompt.ObjectText = "Floor is Lava"
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt:SetAttribute("LavaJoin", true)
		prompt.Parent = pillar
		return pillar
	end
	local beacons = { beacon(CFG.Beacon, "🔥 LAVA RUSH", "Climb • Shove • Survive"), beacon(c + Vector3.new(0, 0, 44), "🔥 LAVA RUSH", "Join the next round") }
	if GameConfig.PartyMode then
		for _, b in beacons do
			local label = b:FindFirstChildOfClass("BillboardGui")
			if label then
				label.Enabled = false
			end
		end
	end

	local plazaPos = CFG.Beacon
	local plaza = part(arenaFolder, "LobbyPlaza", Vector3.new(0.6, 30, 30), CFrame.new(plazaPos + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(72, 54, 52), Enum.Material.Basalt)
	plaza.Shape = Enum.PartType.Cylinder
	for k = 0, 5 do
		local a = k * math.pi / 3 + math.pi / 6
		local at = plazaPos + Vector3.new(math.cos(a) * 14, 0, math.sin(a) * 14)
		local post = part(arenaFolder, "LanternPost", Vector3.new(0.45, 3.6, 0.45), CFrame.new(at + Vector3.new(0, 2.1, 0)), Color3.fromRGB(40, 30, 30), Enum.Material.Basalt)
		post.CanCollide = false
		local flame = part(arenaFolder, "Lantern", Vector3.new(0.7, 0.7, 0.7), CFrame.new(at + Vector3.new(0, 4.2, 0)), Color3.fromRGB(230, 90, 20), Enum.Material.Neon)
		flame.Shape = Enum.PartType.Ball
		flame.CanCollide = false
		local glow = Instance.new("PointLight")
		glow.Range = 14
		glow.Brightness = 1.6
		glow.Color = Color3.fromRGB(255, 140, 60)
		glow.Parent = flame
	end

	do
		local toward = (Vector3.new(c.X, 0, c.Z) - Vector3.new(plazaPos.X, 0, plazaPos.Z)).Unit
		local side = Vector3.new(-toward.Z, 0, toward.X)
		local spawnAt = plazaPos + toward * 16
		local function board(name: string, offset: number, title: string, titleColor: Color3, fill: () -> { string })
			local at = plazaPos + toward * 10 + side * offset + Vector3.new(0, 5.5, 0)
			local slab = part(arenaFolder, name, Vector3.new(13, 8.5, 0.8), CFrame.lookAt(at, Vector3.new(spawnAt.X, at.Y, spawnAt.Z)), Color3.fromRGB(48, 36, 36), Enum.Material.Basalt)
			local post = part(arenaFolder, name .. "Post", Vector3.new(0.8, 1.5, 0.8), CFrame.new(at.X, 0.75, at.Z), Color3.fromRGB(40, 30, 30), Enum.Material.Basalt)
			post.CanCollide = false
			local sg = Instance.new("SurfaceGui")
			sg.Face = Enum.NormalId.Front
			sg.PixelsPerStud = 40
			sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			sg.Parent = slab
			local card = Instance.new("Frame")
			card.Size = UDim2.new(1, -24, 1, -24)
			card.Position = UDim2.fromOffset(12, 12)
			card.BackgroundColor3 = Color3.fromRGB(255, 247, 232)
			card.Parent = sg
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0, 24)
			corner.Parent = card
			local stroke = Instance.new("UIStroke")
			stroke.Thickness = 8
			stroke.Color = Color3.fromRGB(62, 28, 14)
			stroke.Parent = card
			local list = Instance.new("UIListLayout")
			list.Padding = UDim.new(0, 6)
			list.HorizontalAlignment = Enum.HorizontalAlignment.Center
			list.Parent = card
			local pad = Instance.new("UIPadding")
			pad.PaddingTop = UDim.new(0, 14)
			pad.Parent = card
			local lines = {}
			for i = 0, 5 do
				local l = Instance.new("TextLabel")
				l.BackgroundTransparency = 1
				l.Size = UDim2.new(1, -40, 0, if i == 0 then 70 else 44)
				l.Font = Enum.Font.FredokaOne
				l.TextScaled = true
				l.TextColor3 = if i == 0 then titleColor else Color3.fromRGB(62, 28, 14)
				l.Text = if i == 0 then title else ""
				l.LayoutOrder = i
				l.Parent = card
				if i > 0 then
					table.insert(lines, l)
				end
			end
			task.spawn(function()
				while slab.Parent do
					local rows = fill()
					for i, l in lines do
						l.Text = rows[i] or ""
					end
					task.wait(4)
				end
			end)
		end
		board("TopClimbers", 13, "🏆 TOP CLIMBERS", Color3.fromRGB(235, 90, 20), function()
			local ranked = Players:GetPlayers()
			table.sort(ranked, function(a, b)
				local ca, cb = a:GetAttribute("Crowns") or 0, b:GetAttribute("Crowns") or 0
				if ca ~= cb then
					return ca > cb
				end
				return (a:GetAttribute("Coins") or 0) > (b:GetAttribute("Coins") or 0)
			end)
			local rows = {}
			for i = 1, math.min(5, #ranked) do
				table.insert(rows, string.format("%d. %s  👑 %d", i, ranked[i].DisplayName, ranked[i]:GetAttribute("Crowns") or 0))
			end
			return rows
		end)
		board("TopSupporters", -13, "💖 TOP SUPPORTERS", Color3.fromRGB(235, 60, 130), function()
			local top = A and A.Shop and A.Shop.TopSupporters() or {}
			local rows = {}
			for i = 1, math.min(5, #top) do
				table.insert(rows, string.format("%d. %s  💖 %d", i, top[i].Name, top[i].Amount))
			end
			if #rows == 0 then
				rows[1] = "Be the first supporter!"
			end
			return rows
		end)
	end

	local beamBase = part(arenaFolder, "LandmarkBase", Vector3.new(1, 1, 1), CFrame.new(c + Vector3.new(0, 2, 0)), Color3.new(), Enum.Material.SmoothPlastic)
	beamBase.Transparency = 1
	beamBase.CanCollide = false
	beamBase.CanQuery = false
	beamBase.CanTouch = false
	local a0 = Instance.new("Attachment")
	a0.Parent = beamBase
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, 230, 0)
	a1.Parent = beamBase
	local beam = Instance.new("Beam")
	beam.Name = "LandmarkBeam"
	beam.Attachment0 = a0
	beam.Attachment1 = a1
	beam.Width0 = 10
	beam.Width1 = 3
	beam.FaceCamera = true
	beam.LightEmission = 0.25
	beam.LightInfluence = 0
	beam.Color = ColorSequence.new(Color3.fromRGB(255, 80, 20), Color3.fromRGB(255, 170, 40))
	beam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.05), NumberSequenceKeypoint.new(0.75, 0.35), NumberSequenceKeypoint.new(1, 1) })
	beam.Parent = beamBase

	local scenery = Instance.new("Model")
	scenery.Name = "Volcanic"
	scenery.Parent = arenaFolder
	local scorch = part(scenery, "ScorchedGround", Vector3.new(0.2, 160, 160), CFrame.new(c + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(58, 46, 44), Enum.Material.Ground)
	scorch.Shape = Enum.PartType.Cylinder
	local rng = Random.new(2026)
	local toTown = math.atan2(CFG.Beacon.Z - c.Z, CFG.Beacon.X - c.X)
	local avoid = { Vector3.new(-328, 0, 262), Vector3.new(-207, 0, 431) }
	local roads = {}
	local floorModel = workspace.SkySprout.Floors:FindFirstChild("Floor_" .. CFG.Floor)
	local trails = floorModel and floorModel:FindFirstChild("RegionalTrails")
	if trails then
		for _, r in trails:GetDescendants() do
			if r:IsA("BasePart") and r.Name == "TrailRoad" then
				table.insert(roads, r)
			end
		end
	end
	local function clear(pos: Vector3, room: number): boolean
		for _, a in avoid do
			if (Vector3.new(pos.X, 0, pos.Z) - a).Magnitude < room then
				return false
			end
		end
		for _, r in roads do
			local p = r.CFrame:PointToObjectSpace(Vector3.new(pos.X, r.Position.Y, pos.Z))
			if math.abs(p.X) < r.Size.X / 2 + 12 and math.abs(p.Z) < r.Size.Z / 2 + 6 then
				return false
			end
		end
		return true
	end
	local placed = 0
	for _ = 1, 80 do
		if placed >= 22 then
			break
		end
		local angle = rng:NextNumber(0, math.pi * 2)
		local off = math.abs(math.atan2(math.sin(angle - toTown), math.cos(angle - toTown)))
		local radius = rng:NextNumber(60, 104)
		local pos = c + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
		if off > math.rad(42) and clear(pos, 30) then
			placed += 1
			local h = rng:NextNumber(14, 48)
			local w = rng:NextNumber(7, 15)
			local tilt = CFrame.Angles(math.rad(rng:NextNumber(-9, 9)), rng:NextNumber(0, math.pi), math.rad(rng:NextNumber(-9, 9)))
			local base = CFrame.new(pos + Vector3.new(0, h / 2 - 1, 0)) * tilt
			part(scenery, "Spire", Vector3.new(w, h, w * rng:NextNumber(0.7, 1.1)), base, Color3.fromRGB(48, 40, 44), Enum.Material.Basalt)
			part(scenery, "SpireCap", Vector3.new(w * 0.6, h * 0.45, w * 0.6), base * CFrame.new(0, h * 0.55, 0) * CFrame.Angles(0, math.rad(45), math.rad(rng:NextNumber(-12, 12))), Color3.fromRGB(62, 52, 56), Enum.Material.Basalt)
			if placed % 3 == 0 then
				local crack = part(scenery, "GlowCrack", Vector3.new(0.6, h * 0.7, 1.2), base * CFrame.new(w / 2 - 0.15, -h * 0.1, 0), Color3.fromRGB(255, 90, 20), Enum.Material.Neon)
				crack.CanCollide = false
			end
		end
	end
	for i = 1, 4 do
		local angle = toTown + math.pi * (0.5 + i * 0.25)
		local pos = c + Vector3.new(math.cos(angle) * 54, 0, math.sin(angle) * 54)
		if clear(pos, 22) then
			local vent = part(scenery, "LavaVent", Vector3.new(0.4, rng:NextNumber(9, 14), rng:NextNumber(9, 14)), CFrame.new(pos + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(230, 70, 10), Enum.Material.Neon)
			vent.Shape = Enum.PartType.Cylinder
			vent.CanCollide = false
			local glow = Instance.new("PointLight")
			glow.Name = "VentGlow"
			glow.Range = 18
			glow.Brightness = 2.5
			glow.Color = Color3.fromRGB(255, 110, 40)
			glow.Parent = vent
			local smoke = Instance.new("ParticleEmitter")
			smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
			smoke.EmissionDirection = Enum.NormalId.Right
			smoke.Rate = 4
			smoke.Lifetime = NumberRange.new(4, 6)
			smoke.Speed = NumberRange.new(3, 5)
			smoke.Color = ColorSequence.new(Color3.fromRGB(80, 60, 58))
			smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1) })
			smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 4), NumberSequenceKeypoint.new(1, 12) })
			smoke.Parent = vent
		end
	end
	arenaFolder.Parent = workspace.SkySprout.Floors:FindFirstChild("Floor_" .. CFG.Floor)
end

local function fruit(name: string, scale: number, cf: CFrame, parent: Instance): Model
	local model = (FruitModels:FindFirstChild(name) :: Model):Clone()
	model:ScaleTo(scale)
	model:PivotTo(cf)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d:SetAttribute("NoTheme", true)
		end
	end
	model.Parent = parent
	return model
end

local function makeEmber(parent: Instance, position: Vector3, stepIndex: number)
	local ember = part(parent, "Ember", Vector3.new(1.6, 1.6, 1.6), CFrame.new(position), Color3.fromRGB(255, 160, 40), Enum.Material.SmoothPlastic)
	ember.Transparency = 1
	ember.CanCollide = false
	ember.CanQuery = false
	ember.CanTouch = false
	local berry = fruit("Strawberry", 0.9, CFrame.new(position), ember)
	CollectionService:AddTag(berry.PrimaryPart :: BasePart, "LavaEmber")
	ride(ember, stepIndex)
	table.insert(pickups, {
		item = ember,
		radius = 3.5,
		take = function(p: Player, r: any)
			r.embers += 1
			event:FireClient(p, "LavaFX", { Kind = "Ember", Position = pickupPosition(ember) })
			ember:Destroy()
			personal(p)
		end,
	})
end

-- Backdrop

local function buildBackdrop()
	local floorModel = workspace.SkySprout.Floors:FindFirstChild("Floor_" .. CFG.Floor)
	if not floorModel then
		return
	end
	local old = floorModel:FindFirstChild("Backdrop")
	if old then
		old:Destroy()
	end
	local scene = Instance.new("Model")
	scene.Name = "Backdrop"
	scene.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	local rng = Random.new(1777)
	local c = Vector3.new(CFG.Center.X, 0, CFG.Center.Z)
	local toTower = (c - Vector3.new(CFG.Beacon.X, 0, CFG.Beacon.Z)).Unit
	local rock = { Color3.fromRGB(58, 44, 46), Color3.fromRGB(70, 52, 52), Color3.fromRGB(84, 62, 58) }
	local function deco(p: BasePart)
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
	end
	local VERTEX_UP = CFrame.Angles(math.rad(45), 0, math.rad(35.264))
	local function crag(at: Vector3, size: number, yaw: number, color: Color3)
		local p = part(scene, "Crag", Vector3.new(size, size, size), CFrame.new(at) * CFrame.Angles(0, yaw, 0) * VERTEX_UP, color, Enum.Material.Basalt)
		deco(p)
		return p
	end
	local function pool(at: Vector3, r: number)
		local p = part(scene, "EmberPool", Vector3.new(0.4, r * 2, r * 2), CFrame.new(at + Vector3.new(0, 0.25, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(230, 70, 12), Enum.Material.Neon)
		p.Shape = Enum.PartType.Cylinder
		deco(p)
	end

	local a18 = math.rad(18)
	local dir = Vector3.new(toTower.X * math.cos(a18) - toTower.Z * math.sin(a18), 0, toTower.X * math.sin(a18) + toTower.Z * math.cos(a18))
	local vc = c + dir * 420
	local kit = game:GetService("ServerStorage"):FindFirstChild("BackdropAssets")
	local function placeModel(template: Model, at: Vector3, width: number, yaw: number): Model
		local m = template:Clone()
		local _, size = m:GetBoundingBox()
		m:ScaleTo(m:GetScale() * width / math.max(size.X, size.Z))
		m:PivotTo(CFrame.new(m:GetPivot().Position) * CFrame.Angles(0, yaw, 0))
		local bb, bs = m:GetBoundingBox()
		m:PivotTo(m:GetPivot() + (at - Vector3.new(bb.Position.X, bb.Position.Y - bs.Y / 2, bb.Position.Z)))
		m.Parent = scene
		return m
	end
	local heroTemplate = kit and kit:FindFirstChild("HeroVolcano")
	if heroTemplate and heroTemplate:IsA("Model") then
		local hero = placeModel(heroTemplate, vc, 340, math.atan2(-dir.X, -dir.Z))
		for _, d in hero:GetDescendants() do
			if d:IsA("BasePart") and d.Material == Enum.Material.Neon then
				local glow = Instance.new("PointLight")
				glow.Range = 60
				glow.Brightness = 3
				glow.Color = Color3.fromRGB(255, 110, 40)
				glow.Parent = d
				break
			end
		end
		local coneTemplate = kit:FindFirstChild("Cone")
		if coneTemplate and coneTemplate:IsA("Model") then
			for _, side in { -1, 1 } do
				local a = math.atan2(dir.Z, dir.X) + side * math.rad(48)
				placeModel(coneTemplate, c + Vector3.new(math.cos(a), 0, math.sin(a)) * 560, 230, rng:NextNumber(0, math.pi * 2))
			end
		end
	else
		local layers, height = 14, 210
		for k = 0, layers - 1 do
			local t = k / (layers - 1)
			local r = 150 - 105 * t
			local h = height / layers
			local layer = part(scene, "Volcano", Vector3.new(h + 0.5, r * 2, r * 2), CFrame.new(vc + Vector3.new(0, h * k + h / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)), rock[1]:Lerp(rock[3], t), Enum.Material.Basalt)
			layer.Shape = Enum.PartType.Cylinder
			deco(layer)
		end
		local crater = part(scene, "VolcanoCrater", Vector3.new(1, 76, 76), CFrame.new(vc + Vector3.new(0, height + 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(255, 90, 15), Enum.Material.Neon)
		crater.Shape = Enum.PartType.Cylinder
		deco(crater)
		local craterLight = Instance.new("PointLight")
		craterLight.Range = 60
		craterLight.Brightness = 4
		craterLight.Color = Color3.fromRGB(255, 110, 40)
		craterLight.Parent = crater
		local plume = Instance.new("ParticleEmitter")
		plume.Texture = "rbxasset://textures/particles/smoke_main.dds"
		plume.EmissionDirection = Enum.NormalId.Right
		plume.Rate = 3
		plume.Lifetime = NumberRange.new(10, 14)
		plume.Speed = NumberRange.new(12, 18)
		plume.SpreadAngle = Vector2.new(12, 12)
		plume.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 40), NumberSequenceKeypoint.new(1, 130) })
		plume.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
		plume.Color = ColorSequence.new(Color3.fromRGB(90, 66, 64), Color3.fromRGB(150, 120, 120))
		plume.Parent = crater
		local sparks = Instance.new("ParticleEmitter")
		sparks.EmissionDirection = Enum.NormalId.Right
		sparks.Rate = 25
		sparks.Lifetime = NumberRange.new(2, 4)
		sparks.Speed = NumberRange.new(30, 50)
		sparks.SpreadAngle = Vector2.new(30, 30)
		sparks.Size = NumberSequence.new(3, 0)
		sparks.LightEmission = 1
		sparks.Color = ColorSequence.new(Color3.fromRGB(255, 210, 80), Color3.fromRGB(255, 60, 10))
		sparks.Parent = crater
		for k = 0, 3 do
			local a = k * math.pi / 2 + 0.6
			local top = Instance.new("Attachment")
			top.Parent = crater
			top.WorldPosition = vc + Vector3.new(math.cos(a) * 48, height, math.sin(a) * 48)
			local foot = Instance.new("Attachment")
			foot.Parent = crater
			foot.WorldPosition = vc + Vector3.new(math.cos(a) * 158, 3, math.sin(a) * 158)
			local stream = Instance.new("Beam")
			stream.Attachment0 = top
			stream.Attachment1 = foot
			stream.Width0 = 7
			stream.Width1 = 14
			stream.LightEmission = 0.6
			stream.LightInfluence = 0
			stream.Color = ColorSequence.new(Color3.fromRGB(255, 160, 40), Color3.fromRGB(230, 50, 10))
			stream.Transparency = NumberSequence.new(0.05)
			stream.Parent = crater
			pool(vc + Vector3.new(math.cos(a) * 160, 0, math.sin(a) * 160), 12)
		end

	end

	for _ = 1, 22 do
		local a = rng:NextNumber(0, math.pi * 2)
		local off = math.abs(math.atan2(math.sin(a - math.atan2(dir.Z, dir.X)), math.cos(a - math.atan2(dir.Z, dir.X))))
		if off > math.rad(20) then
			local at = c + Vector3.new(math.cos(a), 0, math.sin(a)) * rng:NextNumber(330, 520)
			local s = rng:NextNumber(110, 210)
			local yaw = rng:NextNumber(0, math.pi * 2)
			local peakTemplate = kit and kit:FindFirstChild("Peak")
			if peakTemplate and peakTemplate:IsA("Model") then
				placeModel(peakTemplate, at, s, yaw)
				placeModel(peakTemplate, at + Vector3.new(rng:NextNumber(-40, 40), 0, rng:NextNumber(-40, 40)), s * 0.6, yaw + 1.3)
			else
				crag(at + Vector3.new(0, -s * 0.12, 0), s, yaw, rock[rng:NextInteger(1, 3)])
				crag(at + Vector3.new(rng:NextNumber(-25, 25), s * 0.35, rng:NextNumber(-25, 25)), s * 0.55, yaw + 0.7, rock[rng:NextInteger(1, 3)])
			end
			if rng:NextNumber() < 0.5 then
				pool(at + Vector3.new(math.cos(a) * -s * 0.6, 0, math.sin(a) * -s * 0.6), rng:NextNumber(6, 12))
			end
		end
	end

	local placed = 0
	for _ = 1, 30 do
		if placed >= 4 then
			break
		end
		local a = rng:NextNumber(0, math.pi * 2)
		local back = math.atan2(-toTower.Z, -toTower.X)
		local off = math.abs(math.atan2(math.sin(a - back), math.cos(a - back)))
		if off > math.rad(35) then
			placed += 1
			local at = c + Vector3.new(math.cos(a), 0, math.sin(a)) * rng:NextNumber(150, 230) + Vector3.new(0, rng:NextNumber(60, 110), 0)
			local s = rng:NextNumber(30, 46)
			local capY = at.Y + s * 0.42
			local spike = kit and kit:FindFirstChild("Peak")
			if spike and spike:IsA("Model") then
				local m = spike:Clone()
				local _, sz = m:GetBoundingBox()
				m:ScaleTo(m:GetScale() * (s * 1.15) / math.max(sz.X, sz.Z))
				m:PivotTo(CFrame.new(m:GetPivot().Position) * CFrame.Angles(math.pi, rng:NextNumber(0, 6), 0))
				local bb, bs = m:GetBoundingBox()
				m:PivotTo(m:GetPivot() + (Vector3.new(at.X, capY - 0.5, at.Z) - Vector3.new(bb.Position.X, bb.Position.Y + bs.Y / 2, bb.Position.Z)))
				m.Name = "Island"
				m.Parent = scene
			else
				local body = part(scene, "Island", Vector3.new(s, s, s), CFrame.new(at) * CFrame.Angles(0, rng:NextNumber(0, 6), 0) * CFrame.Angles(math.rad(225), 0, math.rad(35.264)), rock[2], Enum.Material.Basalt)
				deco(body)
			end
			local cap = part(scene, "IslandTop", Vector3.new(2, s * 0.95, s * 0.95), CFrame.new(at.X, capY, at.Z) * CFrame.Angles(0, 0, math.rad(90)), rock[3], Enum.Material.Basalt)
			cap.Shape = Enum.PartType.Cylinder
			deco(cap)
			local glowPool = part(scene, "IslandLava", Vector3.new(0.4, s * 0.45, s * 0.45), CFrame.new(at.X, capY + 1.1, at.Z) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(240, 80, 15), Enum.Material.Neon)
			glowPool.Shape = Enum.PartType.Cylinder
			deco(glowPool)
			crag(Vector3.new(at.X + s * 0.15, capY + s * 0.18, at.Z), s * 0.3, rng:NextNumber(0, 6), rock[1])
			local edge = Vector3.new(math.cos(a), 0, math.sin(a)) * (s * 0.45)
			local fallTop = Instance.new("Attachment")
			fallTop.Parent = glowPool
			fallTop.WorldPosition = Vector3.new(at.X, capY, at.Z) + edge
			local fallFoot = Instance.new("Attachment")
			fallFoot.Parent = glowPool
			fallFoot.WorldPosition = Vector3.new(at.X, 1, at.Z) + edge * 1.3
			local fall = Instance.new("Beam")
			fall.Attachment0 = fallTop
			fall.Attachment1 = fallFoot
			fall.Width0 = 5
			fall.Width1 = 9
			fall.FaceCamera = true
			fall.LightEmission = 0.6
			fall.LightInfluence = 0
			fall.Color = ColorSequence.new(Color3.fromRGB(255, 170, 50), Color3.fromRGB(235, 60, 10))
			fall.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.05), NumberSequenceKeypoint.new(1, 0.4) })
			fall.Parent = glowPool
			pool(Vector3.new(at.X, 0, at.Z) + edge * 1.3, 8)
			local light = Instance.new("PointLight")
			light.Range = 30
			light.Brightness = 2
			light.Color = Color3.fromRGB(255, 120, 40)
			light.Parent = glowPool
		end
	end

	local side = Vector3.new(-dir.Z, 0, dir.X)
	local prev = c + dir * 48
	for k = 1, 12 do
		local nextPoint = c + dir * (48 + k * 26) + side * math.sin(k * 0.9) * 14
		local mid = (prev + nextPoint) / 2
		local length = (nextPoint - prev).Magnitude + 4
		local seg = part(scene, "LavaRiver", Vector3.new(9, 0.4, length), CFrame.lookAt(mid + Vector3.new(0, 0.2, 0), nextPoint + Vector3.new(0, 0.2, 0)), Color3.fromRGB(235, 75, 12), Enum.Material.Neon)
		deco(seg)
		prev = nextPoint
	end

	local moonDir = (CFrame.Angles(0, math.rad(28), 0) * CFrame.new(toTower)).Position.Unit
	local moonAnchor = part(scene, "Moon", Vector3.new(1, 1, 1), CFrame.new(c + moonDir * 560 + Vector3.new(0, 320, 0)), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic)
	moonAnchor.Transparency = 1
	deco(moonAnchor)
	local moonGui = Instance.new("BillboardGui")
	moonGui.Name = "MoonGui"
	moonGui.Size = UDim2.fromScale(170, 170)
	moonGui.LightInfluence = 0
	moonGui.AlwaysOnTop = false
	moonGui.MaxDistance = 100000
	moonGui.Parent = moonAnchor
	local body = Instance.new("Frame")
	body.Name = "Body"
	body.Size = UDim2.fromScale(1, 1)
	body.BackgroundTransparency = 1
	body.Visible = false
	body.Parent = moonGui
	local function disc(name: string, size: number, x: number, y: number, transparency: number, z: number): Frame
		local f = Instance.new("Frame")
		f.Name = name
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Position = UDim2.fromScale(x, y)
		f.Size = UDim2.fromScale(size, size)
		f.BackgroundTransparency = transparency
		f.BorderSizePixel = 0
		f.ZIndex = z
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = f
		f.Parent = body
		return f
	end
	disc("HaloOuter", 1, 0.5, 0.5, 0.86, 1)
	disc("HaloInner", 0.74, 0.5, 0.5, 0.7, 2)
	local face = disc("Face", 0.5, 0.5, 0.5, 0, 3)
	local shade = Instance.new("UIGradient")
	shade.Rotation = 35
	shade.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(175, 175, 190))
	shade.Parent = face
	for i, crater in { { 0.13, 0.42, 0.4 }, { 0.08, 0.58, 0.58 }, { 0.06, 0.45, 0.62 }, { 0.05, 0.6, 0.41 } } do
		local f = disc("Crater" .. i, crater[1], crater[2], crater[3], 0.55, 4)
		f.BackgroundColor3 = Color3.new(0, 0, 0)
	end

	scene.Parent = floorModel
end

-- Themes

local function isLava(c: Color3): boolean
	local h, s, v = c:ToHSV()
	return s > 0.45 and v > 0.25 and (h < 0.105 or h > 0.95)
end

local function shift(c: Color3, theme: any): Color3
	if not theme.Hue or not isLava(c) then
		return c
	end
	local h, s, v = c:ToHSV()
	local offset = if h > 0.5 then h - 1 else h
	return Color3.fromHSV((theme.Hue + (offset - 0.05) * 0.6) % 1, math.min(1, s * 0.9), v * 0.85)
end

local function isRock(p: BasePart): boolean
	if p.Material == Enum.Material.Neon or p.Material == Enum.Material.Foil or p.Material == Enum.Material.Glass then
		return false
	end
	local _, _, v = p.Color:ToHSV()
	return v < 0.5
end

local function themeColor(d: Instance, theme: any)
	if d:GetAttribute("NoTheme") then
		return
	end
	if d:IsA("BasePart") then
		local base = d:GetAttribute("BaseColor")
		if typeof(base) ~= "Color3" then
			base = d.Color
			d:SetAttribute("BaseColor", base)
		end
		local c = base :: Color3
		if d:IsA("MeshPart") then
			local tex = d:GetAttribute("BaseTexture")
			if type(tex) ~= "string" then
				tex = d.TextureID
				d:SetAttribute("BaseTexture", tex)
			end
			if tex ~= "" then
				d.TextureID = if theme.Hue then "" else tex :: string
			end
		end
		if isLava(c) then
			d.Color = shift(c, theme)
		elseif theme.Rock and isRock(d) then
			d.Color = c:Lerp(theme.Rock, theme.RockMix)
		else
			d.Color = c
		end
	elseif d:IsA("Light") then
		local base = d:GetAttribute("BaseColor")
		if typeof(base) ~= "Color3" then
			base = d.Color
			d:SetAttribute("BaseColor", base)
		end
		d.Color = shift(base :: Color3, theme)
	elseif d:IsA("Beam") or d:IsA("ParticleEmitter") or d:IsA("Trail") then
		local base = d:GetAttribute("BaseColor")
		if typeof(base) ~= "ColorSequence" then
			base = (d :: any).Color
			d:SetAttribute("BaseColor", base)
		end
		local points = {}
		for _, k in (base :: ColorSequence).Keypoints do
			table.insert(points, ColorSequenceKeypoint.new(k.Time, shift(k.Value, theme)))
		end
		(d :: any).Color = ColorSequence.new(points)
	end
end

local function applyTheme(root: Instance?)
	if not root then
		return
	end
	local theme = Themes.Get(L.Theme)
	for i, d in root:GetDescendants() do
		themeColor(d, theme)
		if i % 1500 == 0 then
			task.wait()
		end
	end
	local moon = root:FindFirstChild("Moon")
	local gui = moon and moon:FindFirstChild("MoonGui")
	local body = gui and gui:FindFirstChild("Body")
	if body and body:IsA("Frame") then
		body.Visible = theme.Moon ~= nil
		if theme.Moon then
			for _, f in body:GetChildren() do
				if f:IsA("Frame") then
					if f.Name == "Face" then
						f.BackgroundColor3 = theme.Moon
					elseif f.Name:sub(1, 4) == "Halo" then
						f.BackgroundColor3 = theme.MoonHalo or theme.Moon
					elseif f.Name:sub(1, 6) == "Crater" then
						f.BackgroundColor3 = (theme.Moon :: Color3):Lerp(Color3.new(0, 0, 0), 0.35)
						f.BackgroundTransparency = 0.45
					end
				end
			end
		end
	end
end

local function setTheme(id: string)
	L.Theme = id
	workspace:SetAttribute("LavaTheme", id)
	applyTheme(arenaFolder)
	local floorModel = workspace.SkySprout.Floors:FindFirstChild("Floor_" .. CFG.Floor)
	applyTheme(floorModel and floorModel:FindFirstChild("Backdrop"))
end

-- Boosts

local function grantShield(p: Player, character: Model, r: Runner, position: Vector3)
	r.shieldUntil = now() + CFG.ShieldTime
	local old = character:FindFirstChild("LavaBubble")
	if old then
		old:Destroy()
	end
	local bubble = Instance.new("ForceField")
	bubble.Name = "LavaBubble"
	bubble.Visible = true
	bubble.Parent = character
	task.delay(CFG.ShieldTime, function()
		if bubble.Parent then
			bubble:Destroy()
		end
	end)
	event:FireClient(p, "LavaFX", { Kind = "Shield", Position = position })
	tell(p, "🛡️ Bubble shield! Shoves can't move you for " .. CFG.ShieldTime .. "s.")
end

local function baseWalkSpeed(): number
	return if L.Mutator.Id == "SpeedRush" then 26 else GameConfig.WalkSpeed
end

local function restoreJump(hum: Humanoid)
	local base = hum:GetAttribute("LavaBaseJump")
	if type(base) == "number" then
		if hum.UseJumpPower then
			hum.JumpPower = base
		else
			hum.JumpHeight = base
		end
		hum:SetAttribute("LavaBaseJump", nil)
	end
end

local function setJump(hum: Humanoid, power: number)
	if hum:GetAttribute("LavaBaseJump") == nil then
		hum:SetAttribute("LavaBaseJump", if hum.UseJumpPower then hum.JumpPower else hum.JumpHeight)
	end
	if hum.UseJumpPower then
		hum.JumpPower = power
	else
		hum.JumpHeight = power ^ 2 / (2 * workspace.Gravity)
	end
end

local function makeShield(parent: Instance, position: Vector3, stepIndex: number)
	local orb = part(parent, "ShieldOrb", Vector3.new(3.4, 3.4, 3.4), CFrame.new(position), Color3.fromRGB(90, 190, 255), Enum.Material.SmoothPlastic)
	orb.Shape = Enum.PartType.Ball
	orb.Transparency = 1
	orb.CanCollide = false
	orb.CanQuery = false
	local core = part(orb, "Core", Vector3.new(2, 2, 2), CFrame.new(position), Color3.fromRGB(50, 150, 255), Enum.Material.Neon)
	core.Shape = Enum.PartType.Ball
	core.Transparency = 1
	fruit("Blueberry", 1.1, CFrame.new(position), orb)
	core.CanCollide = false
	core.CanQuery = false
	core.CanTouch = false
	local ring = part(orb, "Ring", Vector3.new(0.25, 3.2, 3.2), CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(150, 215, 255), Enum.Material.Neon)
	ring.Shape = Enum.PartType.Cylinder
	ring.Transparency = 0.35
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	local icon = Instance.new("BillboardGui")
	icon.Size = UDim2.fromOffset(44, 44)
	icon.StudsOffset = Vector3.new(0, 2.6, 0)
	icon.MaxDistance = 90
	icon.Parent = orb
	local emoji = Instance.new("TextLabel")
	emoji.BackgroundTransparency = 1
	emoji.Size = UDim2.fromScale(1, 1)
	emoji.TextScaled = true
	emoji.Text = "🛡️"
	emoji.Parent = icon
	local glow = Instance.new("PointLight")
	glow.Color = orb.Color
	glow.Range = 12
	glow.Brightness = 2
	glow.Parent = orb
	orb.CanTouch = false
	ride(orb, stepIndex)
	table.insert(pickups, {
		item = orb,
		radius = 4,
		take = function(p: Player, r: any)
			local at = pickupPosition(orb)
			orb:Destroy()
			if p.Character then
				grantShield(p, p.Character, r, at)
			end
		end,
	})
end

type Boost = { Id: string, Name: string, Icon: string, Color: Color3, Weight: number, Fruit: string }
local BOOSTS: { Boost } = {
	{ Id = "Speed", Name = "⚡ Speed Boost", Icon = "⚡", Color = Color3.fromRGB(255, 225, 60), Weight = 3, Fruit = "Banana" },
	{ Id = "Jump", Name = "🦘 Super Jump", Icon = "🦘", Color = Color3.fromRGB(255, 120, 210), Weight = 3, Fruit = "Pineapple" },
	{ Id = "Shield", Name = "🛡️ Shield", Icon = "🛡️", Color = Color3.fromRGB(90, 190, 255), Weight = 2, Fruit = "Blueberry" },
	{ Id = "Rescue", Name = "🪂 Rescue", Icon = "🪂", Color = Color3.fromRGB(150, 230, 255), Weight = 2, Fruit = "Coconut" },
	{ Id = "Embers", Name = "🔥 Ember Bag", Icon = "🔥", Color = Color3.fromRGB(255, 170, 60), Weight = 2, Fruit = "Watermelon" },
}
local drops: { Model } = {}

local function pickBoost(): Boost
	if Run:IsStudio() then
		local forced = workspace:GetAttribute("StudioNextDrop")
		for _, b in BOOSTS do
			if b.Id == forced then
				workspace:SetAttribute("StudioNextDrop", nil)
				return b
			end
		end
	end
	local total = 0
	for _, b in BOOSTS do
		total += b.Weight
	end
	local roll = math.random() * total
	for _, b in BOOSTS do
		roll -= b.Weight
		if roll <= 0 then
			return b
		end
	end
	return BOOSTS[1]
end

local function clearDrops()
	for _, d in drops do
		d:Destroy()
	end
	table.clear(drops)
end

local function applyBoost(p: Player, r: Runner, boost: Boost, at: Vector3)
	local character = p.Character
	local hum = character and character:FindFirstChildOfClass("Humanoid")
	event:FireClient(p, "LavaFX", { Kind = "Boost", Position = at, Text = boost.Name, Color = boost.Color })
	if boost.Id == "Speed" and hum then
		r.speedUntil = now() + CFG.SpeedTime
		hum.WalkSpeed = baseWalkSpeed() + CFG.SpeedBoost
		local speedUntil = r.speedUntil
		hum:SetAttribute("LavaSpeedUntil", speedUntil)
		task.delay(CFG.SpeedTime, function()
			if hum.Parent and hum:GetAttribute("LavaSpeedUntil") == speedUntil then
				hum:SetAttribute("LavaSpeedUntil", nil)
				if p:GetAttribute("ArenaMode") == "LavaRush" then
					hum.WalkSpeed = baseWalkSpeed()
				end
			end
		end)
		tell(p, "⚡ SPEED BOOST for " .. CFG.SpeedTime .. "s, go go go!")
	elseif boost.Id == "Jump" and hum then
		r.jumpUntil = now() + CFG.JumpTime
		setJump(hum, CFG.JumpBoostPower)
		local jumpUntil = r.jumpUntil
		hum:SetAttribute("LavaJumpUntil", jumpUntil)
		task.delay(CFG.JumpTime, function()
			if hum.Parent and hum:GetAttribute("LavaJumpUntil") == jumpUntil then
				hum:SetAttribute("LavaJumpUntil", nil)
				if p:GetAttribute("ArenaMode") == "LavaRush" then
					setJump(hum, CFG.RoundJumpPower)
				else
					restoreJump(hum)
				end
			end
		end)
		tell(p, "🦘 SUPER JUMP for " .. CFG.JumpTime .. "s, skip a level!")
	elseif boost.Id == "Shield" and character then
		grantShield(p, character, r, at)
	elseif boost.Id == "Rescue" then
		r.rescue = true
		tell(p, "🪂 RESCUE ready: if you fall, you'll be caught once!")
	else
		r.embers += CFG.EmberBag
		tell(p, "🔥 Ember bag! +" .. CFG.EmberBag .. " embers (bank them by surviving).")
	end
	personal(p)
end

-- Drops

local function spawnDrop()
	if not tower or #drops >= CFG.DropMaxLive then
		return
	end
	local candidates = {}
	for _, tile in platforms do
		if tileSafe(tile) and not tile:GetAttribute("DropHere") then
			table.insert(candidates, tile)
		end
	end
	if #candidates == 0 then
		return
	end
	local step = candidates[math.random(1, #candidates)]
	local stepIndex = step:GetAttribute("StepIndex") :: number
	local boost = pickBoost()
	local born = now()
	local landAt = step.Position + Vector3.new(0, step.Size.Y / 2 + 1.3, 0)
	step:SetAttribute("DropHere", true)

	local drop = Instance.new("Model")
	drop.Name = "BoostDrop"
	local crate = part(drop, "Crate", Vector3.new(2.2, 2.2, 2.2), CFrame.new(landAt), Color3.fromRGB(255, 250, 235), Enum.Material.SmoothPlastic)
	crate.Transparency = 1
	local treat = fruit(boost.Fruit, 1.5, crate.CFrame, drop).PrimaryPart :: BasePart
	for _, piece in { crate, treat } do
		piece.CanCollide = false
		piece.CanQuery = false
		piece.CanTouch = false
	end
	-- Clients pop it in with a bright flash (no parachute).
	crate:SetAttribute("SpawnFlash", true)
	crate:SetAttribute("FlashColor", boost.Color)
	local icon = Instance.new("BillboardGui")
	icon.Size = UDim2.fromOffset(52, 52)
	icon.StudsOffset = Vector3.new(0, 2.4, 0)
	icon.MaxDistance = 140
	icon.Parent = crate
	local emoji = Instance.new("TextLabel")
	emoji.BackgroundTransparency = 1
	emoji.Size = UDim2.fromScale(1, 1)
	emoji.TextScaled = true
	emoji.Text = boost.Icon
	emoji.Parent = icon
	local glow = Instance.new("PointLight")
	glow.Color = boost.Color
	glow.Range = 14
	glow.Brightness = 2
	glow.Shadows = false
	glow.Parent = crate
	local ring = part(drop, "LandingRing", Vector3.new(0.15, 4.2, 4.2), CFrame.new(step.Position + Vector3.new(0, step.Size.Y / 2 + 0.1, 0)) * CFrame.Angles(0, 0, math.rad(90)), boost.Color, Enum.Material.Neon)
	ring.Shape = Enum.PartType.Cylinder
	ring.Transparency = 0.45
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ride(drop, stepIndex)
	drop.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	drop.Parent = tower
	table.insert(drops, drop)

	local taken = false
	local function finish()
		local i = table.find(drops, drop)
		if i then
			table.remove(drops, i)
		end
		if step.Parent then
			step:SetAttribute("DropHere", nil)
		end
		drop:Destroy()
	end
	table.insert(pickups, {
		item = crate,
		radius = 4,
		take = function(p: Player, r: any)
			if taken or L.Phase ~= "Round" then
				return
			end
			taken = true
			local at = pickupPosition(crate)
			finish()
			applyBoost(p, r, boost, at)
		end,
	})
	task.spawn(function()
		local row, col = step:GetAttribute("Row"), step:GetAttribute("Col")
		while drop.Parent and not taken do
			local state = if tower then Grid.TileState(tower, row, col, now()) else "Gone"
			if now() - born > CFG.DropLifetime or state ~= "Still" and state ~= "Warning" or L.Phase ~= "Round" then
				finish()
				return
			end
			task.wait(0.25)
		end
	end)
end

local function giveCrownHat(p: Player)
	local character = p.Character
	local head = character and character:FindFirstChild("Head")
	if not character or not head or not head:IsA("BasePart") then
		return
	end
	local old = character:FindFirstChild("LavaCrownHat")
	if old then
		old:Destroy()
	end
	local hat = Instance.new("Model")
	hat.Name = "LavaCrownHat"
	local gold = Color3.fromRGB(255, 205, 70)
	local top = head.CFrame * CFrame.new(0, head.Size.Y / 2 + 0.25, 0)
	local pieces = {}
	local band = part(hat, "Band", Vector3.new(0.45, 1.5, 1.5), top * CFrame.Angles(0, 0, math.rad(90)), gold, Enum.Material.Foil)
	band.Shape = Enum.PartType.Cylinder
	table.insert(pieces, band)
	for i = 0, 4 do
		local a = i * math.pi * 2 / 5
		local spike = part(hat, "Spike", Vector3.new(0.32, 0.55, 0.32), top * CFrame.new(math.cos(a) * 0.6, 0.45, math.sin(a) * 0.6), gold, Enum.Material.Foil)
		local gem = part(hat, "Gem", Vector3.new(0.22, 0.22, 0.22), spike.CFrame * CFrame.new(0, 0.35, 0), Color3.fromRGB(255, 80, 60), Enum.Material.Neon)
		gem.Shape = Enum.PartType.Ball
		table.insert(pieces, spike)
		table.insert(pieces, gem)
	end
	for _, piece in pieces do
		piece.Anchored = false
		piece.CanCollide = false
		piece.CanTouch = false
		piece.CanQuery = false
		piece.Massless = true
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = head
		weld.Part1 = piece
		weld.Parent = piece
	end
	hat.Parent = character
	task.delay(120, function()
		if hat.Parent then
			hat:Destroy()
		end
	end)
end

-- Grid

local TILE_COLOURS = {
	Color3.fromRGB(240, 180, 40),
	Color3.fromRGB(130, 200, 50),
	Color3.fromRGB(40, 185, 160),
	Color3.fromRGB(60, 135, 235),
	Color3.fromRGB(145, 85, 235),
}

local function buildTower()
	local model = Instance.new("Model")
	model.Name = "LavaRushTower"
	local rng = Random.new()
	local c = CFG.Center + Vector3.new(0, 1, 0)
	table.clear(platforms)
	table.clear(pickups)
	local drops = table.clone(CFG.GridDrops)
	if L.Mutator.Id == "HoleParty" then
		for q = 2, #drops do
			drops[q] += 1
		end
	end
	local spins = table.clone(CFG.GridSpins)
	if L.Mutator.Id == "TurboSpin" then
		for q = 1, #spins do
			spins[q] *= 2
		end
	end
	model:SetAttribute("GridSeed", rng:NextInteger(1, 1000000))
	model:SetAttribute("PhaseTime", CFG.PhaseTime)
	model:SetAttribute("Phases", #CFG.GridSpins)
	model:SetAttribute("Size", CFG.GridSize)
	model:SetAttribute("Tile", CFG.GridTile)
	model:SetAttribute("Gap", CFG.GridGap)
	model:SetAttribute("StartRings", CFG.StartRings)
	model:SetAttribute("Grow", table.concat(CFG.GridGrow, ","))
	model:SetAttribute("Shrink", table.concat(CFG.GridShrink, ","))
	model:SetAttribute("Spins", table.concat(spins, ","))
	model:SetAttribute("Drops", table.concat(drops, ","))
	model:SetAttribute("RiseStep", CFG.GridRise)
	model:SetAttribute("BaseY", c.Y + CFG.GridBaseY)
	model:SetAttribute("CenterX", c.X)
	model:SetAttribute("CenterZ", c.Z)

	table.clear(wear)
	local size = CFG.GridSize
	for row = 1, size do
		for col = 1, size do
			local index = (row - 1) * size + col
			local base = TILE_COLOURS[Grid.Ring(size, row, col) + 1]
			local color = if (row + col) % 2 == 0 then base else base:Lerp(Color3.new(1, 1, 1), 0.2)
			local tile = part(model, "Tile" .. index, Vector3.new(CFG.GridTile, 1.2, CFG.GridTile), Grid.TileCFrame(model, row, col, -math.huge), color, Enum.Material.SmoothPlastic)
			tile:SetAttribute("NoTheme", true)
			tile:SetAttribute("StepIndex", index)
			tile:SetAttribute("Row", row)
			tile:SetAttribute("Col", col)
			local under = part(model, "LiftGlow", Vector3.new(CFG.GridTile - 0.8, 0.25, CFG.GridTile - 0.8), tile.CFrame * CFrame.new(0, -0.72, 0), Color3.fromRGB(255, 120, 40), Enum.Material.Neon)
			local warn = part(model, "WarnPlate", Vector3.new(CFG.GridTile - 0.6, 0.12, CFG.GridTile - 0.6), tile.CFrame * CFrame.new(0, 0.66, 0), Color3.fromRGB(255, 45, 45), Enum.Material.Neon)
			warn.Transparency = 1
			warn:SetAttribute("NoTheme", true)
			for _, deco in { under, warn } do
				deco.CanCollide = false
				deco.CanQuery = false
				deco.CanTouch = false
				deco.CastShadow = false
			end
			ride(tile, index)
			ride(under, index)
			ride(warn, index)
			table.insert(platforms, tile)
		end
	end
	local startTiles = {}
	for index, tile in platforms do
		if Grid.Ring(size, tile:GetAttribute("Row"), tile:GetAttribute("Col")) <= CFG.StartRings then
			table.insert(startTiles, index)
		end
	end
	for _ = 1, 6 do
		local index = startTiles[rng:NextInteger(1, #startTiles)]
		makeEmber(model, platforms[index].Position + Vector3.new(0, 2.6, 0), index)
	end
	local special: { [number]: boolean } = {}
	local placed = 0
	for _ = 1, 40 do
		if placed >= (if L.Mutator.Id == "ShieldParty" then 6 else CFG.ShieldOrbs) then
			break
		end
		local index = startTiles[rng:NextInteger(1, #startTiles)]
		if not special[index] then
			special[index] = true
			placed += 1
			makeShield(model, platforms[index].Position + Vector3.new(0, 4, 0), index)
		end
	end

	local centre = platforms[(size * size + 1) / 2]
	local centreIndex = centre:GetAttribute("StepIndex") :: number
	for k = 1, CFG.StageLights do
		local a = (k - 0.5) * 2 * math.pi / CFG.StageLights
		local at = centre.Position + Vector3.new(math.cos(a) * CFG.StageLightReach, CFG.StageLightHeight, math.sin(a) * CFG.StageLightReach)
		local rig = part(model, "StageLight", Vector3.new(1.4, 1.4, 1.4), CFrame.lookAt(at, centre.Position + Vector3.new(math.cos(a) * 6, 0, math.sin(a) * 6)), Color3.fromRGB(255, 150, 70), Enum.Material.Neon)
		rig.Shape = Enum.PartType.Ball
		rig.CanCollide = false
		rig.CanQuery = false
		rig.CanTouch = false
		rig.CastShadow = false
		local spot = Instance.new("SpotLight")
		spot.Face = Enum.NormalId.Front
		spot.Range = 60
		spot.Angle = 75
		spot.Brightness = 2.5
		spot.Shadows = true
		spot.Color = Color3.fromRGB(255, 160, 80)
		spot.Parent = rig
		ride(rig, centreIndex)
	end

	local l = part(model, "Lava", Vector3.new(CFG.LavaPool, 4, CFG.LavaPool), CFrame.new(c), Color3.fromRGB(230, 70, 10), Enum.Material.Neon)
	local crust = part(model, "LavaCrust", Vector3.new(CFG.LavaPool, 0.2, CFG.LavaPool), CFrame.new(c), Color3.fromRGB(255, 120, 40), Enum.Material.CrackedLava)
	crust.Transparency = 0.35
	local fill = part(model, "LavaFill", Vector3.new(CFG.LavaPool - 0.2, 0.2, CFG.LavaPool - 0.2), CFrame.new(c), Color3.fromRGB(200, 55, 8), Enum.Material.Neon)
	fill.Transparency = 1
	fill.CanCollide = false
	fill.CanTouch = false
	fill.CanQuery = false
	fill.CastShadow = false
	crust.CanCollide = false
	crust.CanTouch = false
	crust.CanQuery = false
	crust.CastShadow = false
	l.CanCollide = false
	l.CanTouch = false
	l.CanQuery = false
	l.CastShadow = false
	local glow = Instance.new("SurfaceLight")
	glow.Face = Enum.NormalId.Top
	glow.Range = 24
	glow.Angle = 120
	glow.Brightness = 3
	glow.Color = Color3.fromRGB(255, 110, 40)
	glow.Parent = l
	local glowPoint = Instance.new("Attachment")
	glowPoint.Name = "LavaGlowPoint"
	glowPoint.Position = Vector3.new(0, l.Size.Y / 2 + 6, 0)
	glowPoint.Parent = l
	local rising = Instance.new("PointLight")
	rising.Name = "LavaGlow"
	rising.Range = CFG.LavaGlowRange
	rising.Brightness = CFG.LavaGlowBrightness
	rising.Shadows = false
	rising.Color = Color3.fromRGB(255, 100, 30)
	rising.Parent = glowPoint
	local heat = Instance.new("ParticleEmitter")
	heat.Name = "Heat"
	heat.Texture = "rbxasset://textures/particles/smoke_main.dds"
	heat.EmissionDirection = Enum.NormalId.Top
	heat.Rate = 8
	heat.Lifetime = NumberRange.new(3, 5)
	heat.Speed = NumberRange.new(2, 4)
	heat.SpreadAngle = Vector2.new(15, 15)
	heat.Color = ColorSequence.new(Color3.fromRGB(90, 60, 55))
	heat.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 1) })
	heat.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 6), NumberSequenceKeypoint.new(1, 14) })
	heat.Parent = l
	local embers = Instance.new("ParticleEmitter")
	embers.EmissionDirection = Enum.NormalId.Top
	embers.Rate = 50
	embers.Lifetime = NumberRange.new(1.5, 3)
	embers.Speed = NumberRange.new(6, 14)
	embers.SpreadAngle = Vector2.new(25, 25)
	embers.Color = ColorSequence.new(Color3.fromRGB(255, 200, 60), Color3.fromRGB(255, 50, 10))
	embers.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 0) })
	embers.LightEmission = 1
	embers.Parent = l
	lava = l
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	model.Parent = arenaFolder
	tower = model
end

local function setLava(y: number)
	L.LavaY = y
	local l = lava
	if l then
		l.CFrame = CFrame.new(CFG.Center.X, y - l.Size.Y / 2, CFG.Center.Z)
		local crust = tower and tower:FindFirstChild("LavaCrust")
		if crust and crust:IsA("BasePart") then
			crust.CFrame = CFrame.new(CFG.Center.X, y + 0.05, CFG.Center.Z)
		end
		local fill = tower and tower:FindFirstChild("LavaFill")
		if fill and fill:IsA("BasePart") then
			local floorTop = CFG.Center.Y + 1
			local slabBottom = y - l.Size.Y
			local height = slabBottom - floorTop
			fill.Transparency = if height > 0.2 then 0 else 1
			if height > 0.2 then
				fill.Size = Vector3.new(CFG.LavaPool - 0.2, height, CFG.LavaPool - 0.2)
				fill.CFrame = CFrame.new(CFG.Center.X, floorTop + height / 2, CFG.Center.Z)
			end
		end
	end
end

local function clearTower()
	if tower then
		tower:Destroy()
	end
	tower, lava = nil, nil
	table.clear(platforms)
	table.clear(pickups)
end

-- Players

local function free(p: Player): boolean
	return A.CanQueue(p) and (p:GetAttribute("VisitFloor") or 1) == CFG.Floor
end

local function placeAtBeacon(p: Player)
	local r = root(p)
	if r then
		r.AssemblyLinearVelocity = Vector3.zero
		local toTower = (Vector3.new(CFG.Center.X, 0, CFG.Center.Z) - Vector3.new(CFG.Beacon.X, 0, CFG.Beacon.Z)).Unit
		local at = CFG.Beacon + toTower * 16 + Vector3.new(0, 4, 0)
		p.Character:PivotTo(CFrame.lookAt(at, Vector3.new(CFG.Center.X, at.Y, CFG.Center.Z)))
	end
end

local function release(p: Player, toBeacon: boolean)
	L.Runners[p] = nil
	if p.Parent and p:GetAttribute("ArenaMode") == "LavaRush" then
		p:SetAttribute("ArenaMode", "Lobby")
		local hum = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.WalkSpeed = GameConfig.WalkSpeed
			restoreJump(hum)
		end
		if toBeacon then
			placeAtBeacon(p)
		end
	end
	if p.Parent then
		personal(p)
	end
end

local function safePlatform(): BasePart?
	local options = {}
	for _, tile in platforms do
		local row, col = tile:GetAttribute("Row"), tile:GetAttribute("Col")
		if tower and tileSafe(tile) and Grid.TileState(tower, row, col, now()) == "Still" then
			table.insert(options, tile)
		end
	end
	if #options == 0 then
		return platforms[1]
	end
	return options[math.random(1, #options)]
end

local function lateOpen(): boolean
	local start = tower and tower:GetAttribute("Start")
	return L.Phase == "Round" and type(start) == "number" and now() < start + CFG.PhaseTime
end

local function enter(p: Player): boolean
	if L.Phase ~= "Round" or not tower or not free(p) then
		return false
	end
	local pl = safePlatform()
	local r = root(p)
	if not pl or not r then
		return false
	end
	L.Queue[p] = nil
	if A.Queue then
		A.Queue[p] = nil
	end
	if A.World then
		A.World.Dismount(p)
	end
	p:SetAttribute("ArenaMode", "LavaRush")
	local hum = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.WalkSpeed = baseWalkSpeed()
		setJump(hum, CFG.RoundJumpPower)
	end
	local existing = L.Runners[p]
	L.Runners[p] = {
		peak = if existing then existing.peak else 0,
		alive = true,
		crowned = false,
		embers = 0,
		enteredAt = now(),
		nextShove = 0,
		shieldUntil = if existing then existing.shieldUntil else 0,
		speedUntil = 0,
		jumpUntil = 0,
		rescue = if existing then existing.rescue else false,
		nextLift = if existing then existing.nextLift else 0,
	}
	pcall(function()
		p:RequestStreamAroundAsync(pl.Position, 2)
	end)
	r = root(p)
	if not r or L.Phase ~= "Round" then
		return false
	end
	r.AssemblyLinearVelocity = Vector3.zero
	local stepIndex = pl:GetAttribute("StepIndex")
	local at = ((if type(stepIndex) == "number" then tileDelta(stepIndex) else CFrame.identity) * pl.CFrame).Position + Vector3.new(0, 4.5, 0)
	p.Character:PivotTo(CFrame.lookAt(at, Vector3.new(CFG.Center.X, at.Y, CFG.Center.Z)))
	personal(p)
	return true
end

local function scorch(p: Player, r: Runner)
	r.alive = false
	local lost = r.embers
	r.embers = 0
	event:FireClient(p, "LavaFX", { Kind = "Scorched" })
	tell(p, if lost > 0 then string.format("🔥 SCORCHED! You dropped %d ember%s.", lost, if lost == 1 then "" else "s") else "🔥 SCORCHED! Watch the lava…")
	if p:GetAttribute("ArenaMode") == "LavaRush" then
		p:SetAttribute("ArenaMode", "Lobby")
		placeAtBeacon(p)
	end
	personal(p)
	if lateOpen() then
		L.Queue[p] = true
		tell(p, "Still phase 1 — dropping you back in!")
		task.delay(2, function()
			if L.Queue[p] and L.Phase == "Round" then
				enter(p)
			end
		end)
	end
end

local function toggleJoin(p: Player)
	if L.Runners[p] and L.Runners[p].alive then
		return
	end
	if L.Queue[p] then
		L.Queue[p] = nil
		p:SetAttribute("LavaOptOut", true)
		tell(p, if GameConfig.PartyMode then "Taking a break — tap 🔥 to jump back into the rounds." else "Left the Lava Rush queue.")
	elseif not free(p) then
		tell(p, "Finish combat or travel first — then join Lava Rush on floor 1.")
	elseif L.Phase == "Round" and lateOpen() then
		p:SetAttribute("LavaOptOut", nil)
		if not enter(p) then
			tell(p, "Couldn't drop you in — try again.")
		end
	else
		L.Queue[p] = true
		p:SetAttribute("LavaOptOut", nil)
		tell(p, "🔥 Queued for Lava Rush! The next round starts soon.")
	end
	personal(p)
	broadcast()
end

local function shove(p: Player)
	local r = L.Runners[p]
	local me = root(p)
	if not r or not r.alive or r.crowned or not me then
		return
	end
	local t = os.clock()
	if t < r.nextShove then
		return
	end
	r.nextShove = t + CFG.ShoveCooldown
	local best: Player? = nil
	local bestDist = CFG.ShoveRange
	for other, o in L.Runners do
		local them = root(other)
		if other ~= p and o.alive and not o.crowned and them then
			local delta = them.Position - me.Position
			local flat = Vector3.new(delta.X, 0, delta.Z)
			if flat.Magnitude < bestDist and math.abs(delta.Y) < 6 and (flat.Magnitude < 0.5 or me.CFrame.LookVector:Dot(flat.Unit) > 0.3) then
				best, bestDist = other, flat.Magnitude
			end
		end
	end
	event:FireClient(p, "LavaFX", { Kind = "Swing" })
	local target = best and L.Runners[best]
	if best and target and now() < target.shieldUntil then
		event:FireClient(p, "LavaFX", { Kind = "Blocked", Position = (root(best) :: BasePart).Position })
		tell(p, "🛡️ " .. best.DisplayName .. "'s bubble shield blocked your shove!")
		return
	end
	if best then
		local them = root(best) :: BasePart
		local dir = Vector3.new(them.Position.X - me.Position.X, 0, them.Position.Z - me.Position.Z)
		dir = if dir.Magnitude > 0.1 then dir.Unit else me.CFrame.LookVector
		event:FireClient(best, "LavaShove", dir * CFG.ShoveSpeed + Vector3.new(0, CFG.ShoveLift, 0))
		event:FireClient(p, "LavaFX", { Kind = "Hit", Position = them.Position })
		tell(best, "💥 " .. p.DisplayName .. " shoved you!")
	end
end

-- Round

local function payout()
	for p, r in L.Runners do
		local d = data(p)
		if p.Parent and d then
			local coins = math.floor(r.peak * CFG.CoinsPerStud)
			local banked = 0
			if r.crowned then
				coins += CFG.CrownCoins
				banked = r.embers * CFG.EmberCoins * 2
			elseif r.alive then
				coins += CFG.SurviveCoins
				banked = r.embers * CFG.EmberCoins
			end
			coins += banked
			if A.RPG and A.RPG.AwardXP then
				A.RPG.AwardXP(p, coins * CFG.XPPerCoin)
			end
			local boosted = A.Pass and A.Pass.Has and A.Pass.Has(p, "DoubleLava") or false
			local withFriend = hasFriendHere(p)
			if withFriend then
				coins = math.floor(coins * (1 + CFG.FriendBonus))
				badge(p, "PlayWithFriend")
			end
			badge(p, "FirstRound")
			if boosted then
				coins *= 2
			end
			local isVip = A.Pass and A.Pass.Has and A.Pass.Has(p, "VIP") or false
			if isVip and GameConfig.Vip then
				coins = math.floor(coins * (1 + GameConfig.Vip.CoinBonus))
			end
			d.Coins = math.min(100000000, d.Coins + coins)
			if A.Season and GameConfig.LavaPass then
				local xp = GameConfig.LavaPass.XP
				A.Season.AddXP(p, xp.Played + (if r.crowned then xp.Crowned elseif r.alive then xp.Survived else 0) + (if r.crowned or r.alive then r.embers * xp.Berry else 0))
			end
			pushStats(p)
			event:FireClient(p, "LavaResult", {
				Outcome = if r.crowned then "CROWNED" elseif r.alive then "SURVIVED" else "SCORCHED",
				Height = math.floor(r.peak),
				Embers = if r.crowned or r.alive then r.embers else 0,
				Doubled = r.crowned,
				Coins = coins,
				Boosted = boosted,
				Friends = withFriend,
				Vip = isVip,
			})
		end
	end
end

-- Tiles wear down while anyone stands on them (they darken, crack and shake on clients) and shatter when worn
-- out, coming back after CampRespawn. Empty tiles slowly recover; a raised tile never wears.
local function updateWear(occupied: { [number]: boolean }, dt: number)
	local grid = tower
	if not grid then
		return
	end
	local t = now()
	local started = Grid.Phase(grid, t) >= 0
	for index, tile in platforms do
		local row, col = tile:GetAttribute("Row"), tile:GetAttribute("Col")
		local w = wear[index] or 0
		local state = Grid.TileState(grid, row, col, t)
		if not started or state ~= "Still" or Grid.Lift(grid, row, col, t) > 0 then
			w = if state == "Still" then math.max(0, w - dt / CFG.CampTime) else 0
		elseif occupied[index] then
			w += dt / CFG.CampTime
		else
			w = math.max(0, w - dt / (CFG.CampTime * 1.5))
		end
		if w >= 1 then
			w = 0
			tile:SetAttribute("CampWarn", t)
			tile:SetAttribute("CampFall", t + 0.15)
			tile:SetAttribute("CampBack", t + 0.75 + CFG.CampRespawn)
		end
		wear[index] = w
		local shown = math.floor(w * 20 + 0.5) / 20
		local current = tile:GetAttribute("Wear")
		if shown > 0 and current ~= shown then
			tile:SetAttribute("Wear", shown)
		elseif shown == 0 and current ~= nil then
			tile:SetAttribute("Wear", nil)
		end
	end
end

-- Spend earned coins to pop your tile up for a while.
local function raiseTile(p: Player)
	local r = L.Runners[p]
	local me = root(p)
	local d = data(p)
	local grid = tower
	if not r or not r.alive or r.crowned or not me or not d or not grid or L.Phase ~= "Round" then
		return
	end
	local t = now()
	if t < r.nextLift then
		tell(p, string.format("⬆️ Raise ready in %ds", math.ceil(r.nextLift - t)))
		return
	end
	if (d.Coins or 0) < CFG.LiftCost then
		tell(p, "⬆️ Raise costs " .. CFG.LiftCost .. " coins. Win rounds to earn more!")
		return
	end
	local row, col = Grid.TileAt(grid, me.Position, t)
	if not row or not col or Grid.TileState(grid, row, col, t) ~= "Still" then
		tell(p, "⬆️ Stand on a solid tile to raise it.")
		return
	end
	d.Coins -= CFG.LiftCost
	pushStats(p)
	r.nextLift = t + CFG.LiftCooldown
	local tile = platforms[(row - 1) * CFG.GridSize + col]
	tile:SetAttribute("LiftStart", t)
	tile:SetAttribute("LiftEnd", t + CFG.LiftTime)
	tile:SetAttribute("LiftHeight", CFG.LiftHeight)
	event:FireClient(p, "LavaFX", { Kind = "Boost", Position = me.Position, Text = "⬆️ RAISED!", Color = Color3.fromRGB(255, 205, 60) })
	tell(p, "⬆️ Your tile is up for " .. CFG.LiftTime .. "s!")
end

local function crownPlayer(p: Player, r: Runner)
	r.crowned = true
	badge(p, "FirstCrown")
	local d = data(p)
	if d then
		d.Crowns = (d.Crowns or 0) + 1
		if d.Crowns >= 10 then
			badge(p, "TenCrowns")
		end
		pushStats(p)
	end
	giveCrownHat(p)
	tell(p, "👑 YOU SURVIVED ALL " .. #CFG.GridSpins .. " PHASES! Embers pay double.")
	local me = root(p)
	if me then
		event:FireClient(p, "LavaFX", { Kind = "Crown", Position = me.Position })
	end
	personal(p)
end

local function lavaFor(t: number): number
	if not tower then
		return CFG.Center.Y + CFG.LavaStart
	end
	local _, gridY = Grid.Pose(tower, t - CFG.LavaLag)
	return gridY - CFG.LavaBelow
end

local function runRound()
	clearTower()
	buildTower()
	applyTheme(tower)
	local started = now()
	local grid = tower :: Model
	grid:SetAttribute("Start", started + CFG.StartDelay)
	setLava(lavaFor(started))
	L.Phase = "Round"
	L.EndsAt = Grid.EndsAt(grid) or (started + 90)
	for p in L.Queue do
		enter(p)
	end
	broadcast()
	workspace.Gravity = if L.Mutator.Id == "LowGravity" then 115 else DEFAULT_GRAVITY
	local lastBroadcast = 0
	clearDrops()
	local dropEvery = if L.Mutator.Id == "DropParty" then CFG.DropPartyEvery else CFG.DropEvery
	local nextDrop = started + CFG.DropFirstAt
	local lastPhase = 0
	local starters = 0
	local roundWinners: { Player } = {}
	while now() < L.EndsAt do
		local dt = Run.Heartbeat:Wait()
		if now() >= nextDrop then
			nextDrop = now() + dropEvery
			spawnDrop()
		end
		setLava(lavaFor(now()))
		local phase = gridPhase()
		if phase ~= lastPhase then
			lastPhase = phase
			for p, r in L.Runners do
				if r.alive and not r.crowned then
					tell(p, if phase == #CFG.GridSpins then "🏁 FINAL PHASE — hold on!" else string.format("Phase %d of %d", phase, #CFG.GridSpins))
				end
			end
		end
		local active = 0
		local occupied: { [number]: boolean } = {}
		local lastActive: Player? = nil
		starters = math.max(starters, count(L.Runners))
		for p, r in L.Runners do
			if not p.Parent then
				L.Runners[p] = nil
				continue
			end
			if not r.alive or r.crowned then
				continue
			end
			if p:GetAttribute("ArenaMode") ~= "LavaRush" then
				r.alive = false
				continue
			end
			local me = root(p)
			if me then
				active += 1
				lastActive = p
				for k = #pickups, 1, -1 do
					local pick = pickups[k]
					if not pick.item.Parent then
						table.remove(pickups, k)
					elseif (pickupPosition(pick.item) - me.Position).Magnitude < pick.radius then
						table.remove(pickups, k)
						pick.take(p, r)
					end
				end
				local h = me.Position.Y - CFG.Center.Y
				if h > r.peak then
					r.peak = math.min(h, crownHeight)
				end
				if me.Position.Y < L.LavaY + 2 and now() - r.enteredAt > 1 then
					if r.rescue then
						r.rescue = false
						local tile = safePlatform()
						local stepIndex = tile and tile:GetAttribute("StepIndex")
						if tile and type(stepIndex) == "number" and p.Character then
							r.enteredAt = now()
							me.AssemblyLinearVelocity = Vector3.zero
							p.Character:PivotTo(CFrame.new((tileDelta(stepIndex) * tile.CFrame).Position + Vector3.new(0, 4.5, 0)))
							tell(p, "🪂 RESCUED! Back on the grid.")
						else
							scorch(p, r)
						end
					else
						scorch(p, r)
					end
				else
					local row, col = Grid.TileAt(tower :: Model, me.Position, now())
					if row and col then
						occupied[(row - 1) * CFG.GridSize + col] = true
					end
				end
			end
		end
		updateWear(occupied, dt)
		if now() - lastBroadcast > 0.5 then
			lastBroadcast = now()
			broadcast()
		end
		if active == 0 and not lateOpen() and next(L.Queue) == nil then
			break
		end
		if starters >= 2 and active == 1 and lastActive and not lateOpen() and next(L.Queue) == nil then
			local winner = lastActive :: Player
			local r = L.Runners[winner]
			if r and r.alive and not r.crowned then
				crownPlayer(winner, r)
				table.insert(roundWinners, winner)
				for other in L.Runners do
					if other.Parent then
						tell(other, "👑 " .. winner.DisplayName .. " is the last one standing!")
					end
				end
			end
			break
		end
	end
	if now() >= L.EndsAt - 0.1 then
		local winners = {}
		for p, r in L.Runners do
			if p.Parent and r.alive and not r.crowned and p:GetAttribute("ArenaMode") == "LavaRush" then
				crownPlayer(p, r)
				table.insert(winners, p.DisplayName)
				table.insert(roundWinners, p)
			end
		end
		if #winners > 0 then
			for p in L.Runners do
				if p.Parent then
					tell(p, "👑 Survivors: " .. table.concat(winners, ", "))
				end
			end
		end
	end
	-- Everyone in the server sees who won (or that the lava did), with confetti over the winners.
	if starters > 0 then
		local names, positions = {}, {}
		for _, p in roundWinners do
			table.insert(names, p.DisplayName)
			local me = root(p)
			if me then
				table.insert(positions, me.Position)
			end
		end
		for _, p in Players:GetPlayers() do
			event:FireClient(p, "LavaWinners", { Names = names, Positions = positions })
		end
	end
end

local function autoQueue()
	if not GameConfig.PartyMode then
		return
	end
	for _, p in Players:GetPlayers() do
		local r = L.Runners[p]
		if not L.Queue[p] and not (r and r.alive) and not p:GetAttribute("LavaOptOut") and data(p) and free(p) then
			L.Queue[p] = true
			personal(p)
		end
	end
end

local function loop()
	while true do
		L.Phase = "Idle"
		broadcast()
		while count(L.Queue) < CFG.MinPlayers do
			autoQueue()
			task.wait(0.5)
		end
		L.Mutator = pickMutator(L.Mutator)
		L.Phase = "Countdown"
		L.EndsAt = now() + CFG.Countdown
		local theme = Themes.Pick(L.Theme)
		L.Theme = theme.Id
		broadcast()
		task.spawn(setTheme, theme.Id)
		for p in L.Queue do
			tell(p, theme.Name .. (if L.Mutator.Id == "Classic" then " · Lava Rush in " .. CFG.Countdown .. "s!" else " · Twist: " .. L.Mutator.Name .. "!"))
		end
		while now() < L.EndsAt do
			autoQueue()
			task.wait(0.5)
		end
		for p in L.Queue do
			if not p.Parent or not free(p) then
				L.Queue[p] = nil
			end
		end
		if next(L.Queue) == nil then
			continue
		end
		local ok, err = pcall(runRound)
		if not ok then
			warn("[LavaRush] round crashed:", err)
		end
		L.Phase = "Results"
		L.EndsAt = now() + CFG.ResultsTime
		pcall(payout)
		broadcast()
		local finished = {}
		for p in L.Runners do
			table.insert(finished, p)
		end
		task.wait(CFG.ResultsTime)
		for _, p in finished do
			release(p, true)
		end
		table.clear(L.Runners)
		workspace.Gravity = DEFAULT_GRAVITY
		setLava(CFG.Center.Y + CFG.LavaStart)
	end
end

-- Fruit hats (cosmetic, bought with coins in the shop).
applyHat = function(p: Player)
	local character = p.Character
	local head = character and character:FindFirstChild("Head")
	if not character or not head or not head:IsA("BasePart") then
		return
	end
	local old = character:FindFirstChild("FruitHat")
	if old then
		old:Destroy()
	end
	local d = data(p)
	local id = d and d.Hat
	if type(id) ~= "string" or id == "" or not FruitModels:FindFirstChild(id) then
		return
	end
	local hat = (FruitModels:FindFirstChild(id) :: Model):Clone()
	hat.Name = "FruitHat"
	local _, size = hat:GetBoundingBox()
	hat:ScaleTo(head.Size.X * 1.15 / math.max(size.X, size.Z))
	local _, scaled = hat:GetBoundingBox()
	hat:PivotTo(head.CFrame * CFrame.new(0, head.Size.Y / 2 + scaled.Y * 0.38, 0))
	for _, part in hat:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = false
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.Massless = true
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = head
			weld.Part1 = part
			weld.Parent = part
		end
	end
	hat.Parent = character
end

-- Island: the old flat floor is hidden so the arena sits on the terrain island, and anything low that would
-- end up out in the sea is removed.
local function islandMode()
	local floorModel = workspace.SkySprout.Floors:FindFirstChild("Floor_" .. CFG.Floor)
	local decor = Instance.new("Model")
	decor.Name = "FruitDecor"
	decor.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	local rng = Random.new(5150)
	local kinds = FruitModels:GetChildren()
	for i = 1, 26 do
		local kind = kinds[(i - 1) % #kinds + 1].Name
		local a = rng:NextNumber(0, 2 * math.pi)
		local onBeach = i <= 10
		local r = if onBeach then rng:NextNumber(CFG.IslandRadius - 40, CFG.IslandRadius - 5) else rng:NextNumber(CFG.IslandRadius + 30, CFG.IslandRadius + 320)
		local scale = if onBeach then rng:NextNumber(5, 8) else rng:NextNumber(9, 18)
		local at = CFG.Center + Vector3.new(math.cos(a) * r, if onBeach then 1.5 * scale - 1 else 0.9 * scale - 6, math.sin(a) * r)
		fruit(kind, scale, CFrame.new(at) * CFrame.Angles(rng:NextNumber(-0.35, 0.35), rng:NextNumber(0, 2 * math.pi), rng:NextNumber(-0.35, 0.35)), decor)
	end
	decor.Parent = floorModel
	local regions = floorModel and floorModel:FindFirstChild("Regions")
	if regions then
		for _, d in regions:GetDescendants() do
			if d:IsA("BasePart") then
				d.Transparency = 1
				d.CanCollide = false
				d.CanQuery = false
				d.CanTouch = false
				d.CastShadow = false
			end
		end
	end
	local scene = floorModel and floorModel:FindFirstChild("Backdrop")
	if scene then
		for _, d in scene:GetChildren() do
			if d:IsA("BasePart") and (d.Name == "EmberPool" or d.Name == "LavaRiver") then
				local flat = Vector3.new(d.Position.X - CFG.Center.X, 0, d.Position.Z - CFG.Center.Z).Magnitude
				if flat > CFG.IslandRadius - 8 then
					d:Destroy()
				end
			end
		end
	end
end

-- Public

function L.HandleAction(p: Player, action: unknown, _value: unknown): boolean
	if action == "LavaJoin" then
		toggleJoin(p)
		return true
	end
	local r = L.Runners[p]
	if r and r.alive and not r.crowned and p:GetAttribute("ArenaMode") == "LavaRush" then
		if action == "LavaLift" then
			raiseTile(p)
			return true
		end
		if action == "Punch" or action == "Heavy" or action == "Kick" then
			shove(p)
			return true
		end
		if action == "Mount" or action == "Queue" or action == "Travel" or action == "RegionTravel" or action == "Boss" then
			tell(p, "Finish your Lava Rush first!")
			return true
		end
	end
	return false
end

-- Studio edit preview: the map is built by scripts, so it only exists while the game runs. BuildPreview builds it
-- into the place so it can be seen and worked on in Studio's edit view; those copies are marked EditPreview and
-- cleared when the game starts. Run from the command bar:
--   require(game.ServerScriptService.SkySproutLavaService).BuildPreview()
local PREVIEW_MODELS = { "LavaRush", "Backdrop", "FruitDecor" }

local function clearPreview()
	local floorModel = workspace.SkySprout.Floors:FindFirstChild("Floor_" .. CFG.Floor)
	if not floorModel then
		return
	end
	for _, child in floorModel:GetChildren() do
		if table.find(PREVIEW_MODELS, child.Name) and child:GetAttribute("EditPreview") then
			child:Destroy()
		end
	end
end

function L.BuildPreview()
	clearPreview()
	buildArena()
	buildBackdrop()
	if GameConfig.PartyMode then
		islandMode()
	end
	buildTower()
	setTheme(L.Theme)
	setLava(CFG.Center.Y + CFG.LavaStart)
	local floorModel = workspace.SkySprout.Floors:FindFirstChild("Floor_" .. CFG.Floor)
	for _, name in PREVIEW_MODELS do
		local model = floorModel and floorModel:FindFirstChild(name)
		if model then
			model:SetAttribute("EditPreview", true)
		end
	end
end

function L.Start(arena: any, remote: RemoteEvent, stats: (Player) -> (), notice: (Player, string) -> ())
	A, event, pushStats, tell = arena, remote, stats, notice
	clearPreview()
	buildArena()
	buildBackdrop()
	if GameConfig.PartyMode then
		islandMode()
		local function scale(character: Model)
			task.defer(function()
				if character.Parent then
					character:ScaleTo(CFG.CharacterScale)
					local p = Players:GetPlayerFromCharacter(character)
					if p then
						applyHat(p)
					end
				end
			end)
		end
		A.OnHat = applyHat
		local function watch(p: Player)
			p.CharacterAdded:Connect(scale)
			if p.Character then
				scale(p.Character)
			end
		end
		Players.PlayerAdded:Connect(watch)
		for _, p in Players:GetPlayers() do
			watch(p)
		end
	end
	buildTower()
	setTheme(L.Theme)
	if Run:IsStudio() then
		workspace:GetAttributeChangedSignal("StudioForceTheme"):Connect(function()
			local id = workspace:GetAttribute("StudioForceTheme")
			if type(id) == "string" and Themes.ById[id] then
				setTheme(id)
				broadcast()
			end
		end)
	end
	setLava(CFG.Center.Y + CFG.LavaStart)
	for _, d in arenaFolder:GetDescendants() do
		if d:IsA("ProximityPrompt") and d:GetAttribute("LavaJoin") then
			d.Triggered:Connect(toggleJoin)
		end
	end
	local function scanFriends(p: Player)
		friends[p] = friends[p] or {}
		for _, o in Players:GetPlayers() do
			if o ~= p then
				local ok, isFriend = pcall(function()
					return p:IsFriendsWith(o.UserId)
				end)
				if ok and isFriend then
					friends[p][o.UserId] = true
					friends[o] = friends[o] or {}
					friends[o][p.UserId] = true
					tell(p, "👥 " .. o.DisplayName .. " is here — friend bonus: +25% coins every round!")
					tell(o, "👥 " .. p.DisplayName .. " joined — friend bonus: +25% coins every round!")
				end
			end
		end
	end
	Players.PlayerAdded:Connect(function(p)
		task.spawn(scanFriends, p)
	end)
	for _, p in Players:GetPlayers() do
		task.spawn(scanFriends, p)
	end
	Players.PlayerRemoving:Connect(function(p)
		friends[p] = nil
		awarded[p] = nil
		L.Queue[p] = nil
		L.Runners[p] = nil
	end)
	Players.PlayerAdded:Connect(function(p)
		task.delay(3, function()
			if p.Parent then
				broadcast()
			end
		end)
	end)
	task.spawn(loop)
	print("Lava Rush ready — floor-is-lava rounds on floor 1.")
end

return L
