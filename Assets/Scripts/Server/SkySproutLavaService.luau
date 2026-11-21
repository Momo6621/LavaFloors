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
local tileColour: (any, number, boolean) -> Color3

local CFG = {
	-- Arena
	Floor = 1,
	Center = Vector3.new(-250, 0, 300),
	Beacon = Vector3.new(-200.7, 0, 262.4),
	MinPlayers = 1,
	Countdown = 4,
	ResultsTime = 3,
	VoteTime = 7, -- vote for the next twist, counted from when results show
	VoteOptions = 3,

	-- Grid
	GridSize = 9,
	GridTile = 8,
	GridGap = 0.15,
	StartRings = 2,
	GridBaseY = 12,
	-- A round is 3 phases (one entry per phase in the lists below). The crown height is GridBaseY + phases * GridRise,
	-- kept just over the crater rim (CraterHeight 80) so the last rise still lifts the winners out of the volcano.
	GridRise = 23,
	PhaseTime = 10,
	StartDelay = 3,
	GridSpins = { 90, -135, 180 },
	GridGrow = { 2, 0, 0 }, -- 5x5 grows to 9x9 in phase 1
	GridShrink = { 0, 2, 1 }, -- back to 5x5 in phase 2, a 3x3 finale in phase 3
	GridDrops = { 4, 3, 2 },
	PillarHeight = 16, -- the basalt pillar on the centre tile that blocks the view across the grid
	PillarLedges = 3, -- stepping ledges spiralling up the pillar to a strawberry on top
	PillarLedgeStep = 4.5, -- height between ledges (a round jump reaches ~5.8)
	RoundJumpPower = 48,
	CharacterScale = 0.62,
	RoundWalkSpeed = 24,
	SpeedRushWalkSpeed = 30,

	-- Lava
	LavaBelow = 7,
	LavaLag = 1,
	LavaPool = 92,
	LavaStart = -6,
	LavaGlowRange = 60,
	LavaGlowBrightness = 2.2,

	-- Island
	IslandRadius = 340,
	SeaLimit = 560,

	-- Stage lights
	StageLights = 4,
	StageLightHeight = 26,
	StageLightReach = 30,

	-- Final showdown: when two climbers are left the lava surges (accelerating) and shoves hit harder.
	ShowdownSurge = 1.4, -- studs per second at the start, growing over time
	ShowdownShove = 1.35,
	ShowdownFromPhase = 2, -- in a 2-player round the showdown starts at this phase

	-- Bots fill small rounds up to BotFillTo climbers (never more than BotMax bots)
	BotFillTo = 4,
	BotMax = 3,
	BotThink = { 0.35, 1.0 }, -- seconds between decisions
	BotMistake = 0.12, -- chance a decision is a random neighbour
	-- Adaptive bots: each round the bots win in a row adds BotEase to their mistake chance (up to BotEaseMax); a real
	-- player winning takes off twice that. Keeps a server of younger players from watching "THE BOTS WIN!" forever.
	BotEase = 0.06,
	BotEaseMax = 0.3,
	BotNames = { "Ember", "Magma", "Cinder", "Flare", "Pumice", "Basalt", "Scoria", "Ash", "Obsidian", "Sparky" },

	-- Anti-cheat: a climber who jumps more than TeleportJump studs in one tick can't grab pickups for a second,
	-- and one who isn't over the grid for OffGridLimit seconds (hovering/flying) is scorched.
	TeleportJump = 12,
	OffGridLimit = 4,

	-- Pick the winner: knocked-out players guess who wins (free, no stake) for a small coin reward.
	PredictCoins = 15,
	-- Personal best: climbing higher than ever before pays a small bonus, so even a lost round can be progress.
	BestCoins = 10,
	-- Cheers: knocked-out players tap a preset emoji (no typing) that floats up on everyone's screen.
	Cheers = { "🔥", "👏", "😂", "😱", "💪", "🎉" },
	CheerCooldown = 1.2,
	-- Lava Chest: every round fills a bar (a bit for playing, more for climbing, surviving or winning). A full bar opens
	-- a chest of coins; every 5th chest is a big one. Fixed rewards, nothing random, nothing to buy.
	ChestGoal = 215, -- about one chest every 6 short rounds (~4.5 min) for an average player, the same pace as before 3-phase rounds
	ChestPlay = 12,
	ChestClimb = 30, -- scaled by how high you got (crown height = all of it)
	ChestSurvive = 15,
	ChestCrown = 30,
	ChestCoins = 100,
	ChestBigEvery = 5,
	ChestBigCoins = 300,
	-- Warm-up Hop: a timed stepping-stone run beside the lobby plaza for anyone waiting on a round. Falling in the
	-- practice lava just sends you back to the start. No coins (nothing to farm); the server's fastest run shows.
	HopFrom = 22, -- studs from the plaza centre to the start pad, sideways
	HopMinTime = 2.5, -- runs faster than this are impossible and ignored
	HopCrackDelay = 0.6, -- a cracked stone drops this long after someone lands on it
	HopCrackBack = 3, -- and comes back after this long
	-- Away: seconds without any input before a player sits out the automatic rounds (published as the workspace
	-- attribute LavaAwayAfter for the client). Any input brings them back.
	AwayAfter = 120,
	-- Underdog shield: knocked out UnderdogAfter rounds in a row (in this server), you start the next round in a
	-- bubble shield for UnderdogShield seconds. A small catch-up for kids who are still learning; resets when you survive.
	UnderdogAfter = 3,
	UnderdogShield = 15,
	-- Server goal: every rise a real player reaches fills one shared bar for the whole server. At GoalRises everyone who
	-- climbed since the last goal gets GoalCoins (fixed, same for all), and a new bar starts. Bots don't count.
	GoalRises = 40,
	GoalCoins = 30,

	-- Shove
	ShoveRange = 9,
	ShoveCooldown = 0.8,
	ShoveSpeed = 66,
	ShoveLift = 18,

	-- Rewards. Scaled to 0.7x when rounds went from 7 phases to 3: a round cycle is now ~44 s instead of ~63 s, so
	-- this keeps coins per minute where they were (it was 3 / 0.15 / 20 / 60).
	EmberCoins = 2,
	CoinsPerStud = 0.105,
	SurviveCoins = 14,
	CrownCoins = 42,
	XPPerCoin = 2,
	FriendBonus = (GameConfig.FriendDeal and GameConfig.FriendDeal.Bonus) or 0.25,

	-- Shield
	ShieldOrbs = 1,
	ShieldTime = 7,

	-- Hot Potato twist: one climber carries a ticking bomb and passes it by touching someone.
	BombTime = 7,
	BombMinLeft = 3,
	BombPassRange = 5,
	BombPassCooldown = 0.8,
	BombGap = 3,
	BombSpeed = 4,
	BombBlast = 70,
	BombLift = 40,

	-- Volcano crater around the arena (radius from the arena centre; the gap faces the town)
	CraterRadius = 100,
	CraterHeight = 80,
	CraterThickness = 16,
	CraterFlare = 0.22,
	CraterFlank = 64,
	CraterSegments = 44,
	CraterGap = 17,
	CraterFallEvery = 5, -- a lava fall on every Nth wall section

	-- Drops
	DropEvery = 14,
	DropPartyEvery = 6,
	DropFirstAt = 14,
	DropMaxLive = 1,
	DropLifetime = 8,
	DropHover = 6, -- studs above the tile top: you have to jump for it
	DropGrabRadius = 2.8,
	DropPickFrom = 3, -- spawn on one of the N safe tiles farthest from every player
	SpeedBoost = 10,
	SpeedTime = 6,
	JumpBoostPower = 64,
	JumpTime = 7,
	EmberBag = 3,

	-- Titles shown over your head, earned by total crowns (highest one you qualify for)
	Titles = {
		{ Crowns = 1, Text = "🔥 Lava Walker", Color = Color3.fromRGB(255, 170, 90) },
		{ Crowns = 5, Text = "🌋 Crater Climber", Color = Color3.fromRGB(255, 120, 60) },
		{ Crowns = 15, Text = "👑 Volcano King", Color = Color3.fromRGB(255, 215, 80) },
		{ Crowns = 40, Text = "💎 Magma Legend", Color = Color3.fromRGB(120, 220, 255) },
		{ Crowns = 100, Text = "⭐ Eternal Flame", Color = Color3.fromRGB(255, 240, 160) },
	},

	-- Redeemable codes: CODE = { Coins = n, Until = optional os.time() expiry }. Server-only, once per account.
	Codes = {
		LAVA = { Coins = 100 },
		VOLCANO = { Coins = 150 },
		ESCAPE = { Coins = 75 },
	},

	-- Daily challenges (three a day, the same for everyone)
	ChallengesPerDay = 3,
	Challenges = {
		{ Id = "Play", Text = "Play %d rounds", Goal = 4, Reward = 40 },
		{ Id = "Survive", Text = "Survive %d rounds", Goal = 2, Reward = 60 },
		{ Id = "Win", Text = "Win %d round", Goal = 1, Reward = 100 },
		{ Id = "Drops", Text = "Grab %d supply drops", Goal = 2, Reward = 60 },
		{ Id = "Berries", Text = "Collect %d strawberries", Goal = 10, Reward = 50 },
		{ Id = "Phase", Text = "Reach phase %d", Goal = 3, Reward = 60 },
		{ Id = "Shoves", Text = "Land %d shoves", Goal = 6, Reward = 50 },
	},

	-- Keep moving
	CampTime = 4,
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
	{ Id = "HotPotato", Name = "💣 Hot Potato", Weight = 3 },
	{ Id = "Duos", Name = "👥 Duos", Weight = 2 },
}
-- Twist vote: when a round ends everyone gets a few twists to pick from; the most votes wins (ties and no votes are
-- settled at random among the options).
type Vote = { options: { Mutator }, votes: { [Player]: string }, endsAt: number }
local vote: Vote? = nil
local votedNext: Mutator? = nil

local function voteCounts(v: Vote): { [string]: number }
	local counts = {}
	for _, m in v.options do
		counts[m.Id] = 0
	end
	for p, id in v.votes do
		if p.Parent and counts[id] then
			counts[id] += 1
		end
	end
	return counts
end

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
	shoves: number,
	drops: number,
	picked: number, -- strawberries picked this round; unlike embers, not lost when you're scorched
	enteredAt: number,
	nextShove: number,
	shieldUntil: number,
	speedUntil: number,
	jumpUntil: number,
	rescue: boolean,
	nextLift: number,
	lastPos: Vector3?,
	blinkUntil: number?,
	offGridSince: number?,
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
	ShowdownAt = 0, -- 0 = no showdown this round
	RoundId = 0, -- counts rounds on this server (analytics funnel sessions)
	Predictions = {} :: { [Player]: string }, -- knocked-out players' free "pick the winner" guesses this round
	LastCheer = setmetatable({}, { __mode = "k" }) :: any, -- [Player] = time of their last cheer (rate limit)
	LossStreak = setmetatable({}, { __mode = "k" }) :: any, -- [Player] = rounds in a row knocked out (this server)
	BotEase = 0, -- extra bot mistake chance after bot wins in a row (see CFG.BotEase)
	Goal = 0, -- rises climbed toward the server goal (CFG.GoalRises)
	GoalHelpers = setmetatable({}, { __mode = "k" }) :: any, -- [Player] = true if they climbed since the last goal
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

-- Analytics (Creator Dashboard). Server-only, never blocks or errors gameplay; Studio playtests aren't recorded.
local AnalyticsService = game:GetService("AnalyticsService")
local function track(fn: () -> ())
	task.spawn(function()
		pcall(fn)
	end)
end
-- Coins in (or out when spent=true): txn is the kind of flow, sku names the specific source or item.
local function logCoins(p: Player, txn: string, amount: number, sku: string?, spent: boolean?)
	local d = data(p)
	if not d or amount <= 0 then
		return
	end
	local balance = d.Coins
	track(function()
		AnalyticsService:LogEconomyEvent(p, if spent then Enum.AnalyticsEconomyFlowType.Sink else Enum.AnalyticsEconomyFlowType.Source, "Coins", amount, balance, txn, sku)
	end)
end
-- First-session funnel (each step counts once per player): 1 Joined, 2 First round started, 3 First round
-- finished, 4 Second round finished, 5 First crown.
local function logOnboarding(p: Player, step: number, name: string)
	track(function()
		AnalyticsService:LogOnboardingFunnelStepEvent(p, step, name)
	end)
end
-- Per-round funnel: 1 Entered, 2 Reached phase 3, 3 Reached the final phase, 4 Crowned.
local function logRound(p: Player, step: number, name: string)
	local session = tostring(L.RoundId)
	track(function()
		AnalyticsService:LogFunnelStepEvent(p, "Round", session, step, name)
	end)
end
local function logEvent(p: Player, name: string, field: string)
	track(function()
		AnalyticsService:LogCustomEvent(p, name, 1, { [Enum.AnalyticsCustomFieldKeys.CustomField01.Name] = field })
	end)
end

-- Weekly Top Climbers: crowns won this week, saved to a per-week OrderedDataStore so the lobby board ranks climbers
-- across every server. Weeks start Monday 00:00 UTC; a fresh board each week gives new players a real shot.
local WEEK_START = 4 * 86400 -- 1 Jan 1970 was a Thursday, so this lands on the first Monday
local function weekNumber(): number
	return (os.time() - WEEK_START) // 604800
end
local function weekCrowns(d: any): number
	return if d and d.WeekNo == weekNumber() then tonumber(d.WeekCrowns) or 0 else 0
end
local weeklyStores: { [number]: OrderedDataStore } = {}
local function weeklyStore(): OrderedDataStore?
	if Run:IsStudio() then
		return nil -- Studio API access is off for this place; the board falls back to this server's climbers
	end
	local w = weekNumber()
	if not weeklyStores[w] then
		local ok, store = pcall(function()
			return game:GetService("DataStoreService"):GetOrderedDataStore("LavaWeeklyCrowns_v1", "W" .. w)
		end)
		if not ok then
			return nil
		end
		weeklyStores[w] = store
	end
	return weeklyStores[w]
end
local weeklyTop: { { Id: number, Name: string, Crowns: number } } = {}
local weeklyTopWeek = -1
local weeklyNames: { [number]: string } = {}
local function refreshWeeklyTop()
	local store = weeklyStore()
	if not store then
		return
	end
	local ok, page = pcall(function()
		return (store :: OrderedDataStore):GetSortedAsync(false, 5):GetCurrentPage()
	end)
	if not ok or type(page) ~= "table" then
		return
	end
	local rows = {}
	for _, entry in page do
		local id = tonumber(entry.key)
		if id then
			local name = weeklyNames[id]
			if not name then
				local okName, n = pcall(Players.GetNameFromUserIdAsync, Players, id)
				name = if okName and type(n) == "string" then n else "Climber"
				weeklyNames[id] = name
			end
			table.insert(rows, { Id = id, Name = name :: string, Crowns = tonumber(entry.value) or 0 })
		end
	end
	weeklyTop = rows
	weeklyTopWeek = weekNumber()
end
task.spawn(function()
	while true do
		refreshWeeklyTop()
		task.wait(60)
	end
end)
local function addWeekCrown(p: Player, d: any)
	local w = weekNumber()
	if d.WeekNo ~= w then
		d.WeekNo = w
		d.WeekCrowns = 0
	end
	d.WeekCrowns = math.min(100000, (tonumber(d.WeekCrowns) or 0) + 1)
	local count = d.WeekCrowns
	local store = weeklyStore()
	if store then
		task.spawn(function()
			pcall(function()
				(store :: OrderedDataStore):SetAsync(tostring(p.UserId), count)
			end)
		end)
	end
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

-- Floor tiles are a sculpted stone slab (Creator Store mesh kept in ReplicatedStorage.TileMesh) tinted by the theme;
-- falls back to a plain block if the template is missing.
local function tilePart(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3): BasePart
	local template = game.ReplicatedStorage:FindFirstChild("TileMesh")
	if not template or not template:IsA("MeshPart") then
		return part(parent, name, size, cf, color, Enum.Material.Slate)
	end
	local tile = template:Clone()
	tile.Name = name
	tile.Anchored = true
	tile.Size = size
	tile.CFrame = cf
	tile.Color = color
	tile.Material = Enum.Material.Slate
	tile.Parent = parent
	return tile
end

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

local aliveBotNames: () -> { string } = function()
	return {}
end
local aliveBotCount: () -> number = function()
	return 0
end
local function aliveCount(): number
	local n = aliveBotCount()
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
		Showdown = L.ShowdownAt > 0,
		Contenders = if L.Phase == "Round" then (function()
			local names = aliveBotNames()
			for p, r in L.Runners do
				if r.alive and not r.crowned and p.Parent and p:GetAttribute("ArenaMode") == "LavaRush" then
					table.insert(names, p.DisplayName)
				end
			end
			table.sort(names)
			return names
		end)() else nil,
	}
	for _, p in Players:GetPlayers() do
		event:FireClient(p, "LavaState", payload)
	end
end


-- Daily challenges: everyone gets the same few challenges each day (picked from CFG.Challenges by the date).
-- Progress is saved on the profile; finishing one pays its coins straight away. The list is sent to the client as
-- the player's "Challenges" attribute (JSON).
local HttpService = game:GetService("HttpService")

local function today(): number
	return math.floor(os.time() / 86400)
end

local function todaysChallenges(): { any }
	local pool = table.clone(CFG.Challenges)
	local rng = Random.new(today() * 7919 + 17)
	for i = #pool, 2, -1 do
		local j = rng:NextInteger(1, i)
		pool[i], pool[j] = pool[j], pool[i]
	end
	local list = {}
	for i = 1, math.min(CFG.ChallengesPerDay, #pool) do
		table.insert(list, pool[i])
	end
	return list
end

local function dailyState(d: any): any
	if type(d.Daily) ~= "table" or d.Daily.Day ~= today() then
		d.Daily = { Day = today(), P = {}, C = {} }
	end
	return d.Daily
end

local function pushChallenges(p: Player)
	local d = data(p)
	if not d then
		return
	end
	local daily = dailyState(d)
	local out = {}
	for _, c in todaysChallenges() do
		table.insert(out, {
			Id = c.Id,
			Text = string.format(c.Text, c.Goal),
			Goal = c.Goal,
			Progress = math.min(c.Goal, daily.P[c.Id] or 0),
			Reward = c.Reward,
			Done = daily.C[c.Id] == true,
		})
	end
	p:SetAttribute("Challenges", HttpService:JSONEncode({ Day = today(), List = out }))
end

-- Record progress: amount is added, or for "best" challenges (like reaching a phase) it is the new best.
local function challenge(p: Player, id: string, amount: number, best: boolean?)
	local d = data(p)
	if not d then
		return
	end
	local daily = dailyState(d)
	for _, c in todaysChallenges() do
		if c.Id == id and not daily.C[id] then
			local now = daily.P[id] or 0
			daily.P[id] = if best then math.max(now, amount) else now + amount
			if daily.P[id] >= c.Goal then
				daily.C[id] = true
				d.Coins = math.min(100000000, d.Coins + c.Reward)
				logCoins(p, "Gameplay", c.Reward, "Challenge_" .. id)
				pushStats(p)
				event:FireClient(p, "LavaFX", { Kind = "Invite", Text = "📋 Challenge done!", Coins = c.Reward })
				tell(p, "📋 Challenge complete: " .. string.format(c.Text, c.Goal) .. "! +" .. c.Reward .. " coins")
			end
			pushChallenges(p)
			return
		end
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
		board("TopClimbers", 13, "🏆 WEEKLY TOP CLIMBERS", Color3.fromRGB(235, 90, 20), function()
			-- This week's crowns: the all-server top (when the data store answers) merged with everyone here now.
			local best: { [number]: { Name: string, Crowns: number } } = {}
			if weeklyTopWeek == weekNumber() then
				for _, e in weeklyTop do
					best[e.Id] = { Name = e.Name, Crowns = e.Crowns }
				end
			end
			for _, p in Players:GetPlayers() do
				local crowns = weekCrowns(data(p))
				local e = best[p.UserId]
				if e then
					e.Name = p.DisplayName
					e.Crowns = math.max(e.Crowns, crowns)
				elseif crowns > 0 then
					best[p.UserId] = { Name = p.DisplayName, Crowns = crowns }
				end
			end
			local ranked = {}
			for _, e in best do
				table.insert(ranked, e)
			end
			table.sort(ranked, function(a, b)
				if a.Crowns ~= b.Crowns then
					return a.Crowns > b.Crowns
				end
				return a.Name < b.Name
			end)
			local rows = {}
			for i = 1, math.min(4, #ranked) do
				table.insert(rows, string.format("%d. %s  👑 %d", i, ranked[i].Name, ranked[i].Crowns))
			end
			if #rows == 0 then
				rows[1] = "Win a round to get on the board!"
			end
			local left = 604800 - (os.time() - WEEK_START) % 604800
			rows[5] = string.format("⏳ New week in %dd %dh", left // 86400, (left % 86400) // 3600)
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

		-- Warm-up Hop (CFG.HopFrom): stepping stones over a pool of practice lava beside the plaza. The clock runs
		-- from leaving the green pad to touching the gold one; falling in sends you back to the green pad.
		local hop = Instance.new("Model")
		hop.Name = "WarmupHop"
		hop.Parent = arenaFolder
		local base = plazaPos + side * CFG.HopFrom
		local function at(s: number, t: number, y: number): Vector3
			return base + side * s + toward * t + Vector3.new(0, y, 0)
		end
		local turn = CFrame.lookAt(Vector3.zero, side).Rotation
		local startPad = part(hop, "HopStart", Vector3.new(8, 1, 8), CFrame.new(at(0, 0, 2.5)) * turn, Color3.fromRGB(70, 160, 90), Enum.Material.Slate)
		local goalPad = part(hop, "HopGoal", Vector3.new(7, 1, 7), CFrame.new(at(37, 0, 8.5)) * turn, Color3.fromRGB(255, 190, 60), Enum.Material.Slate)
		-- The route is a little puzzle, not a staircase: a round pillar, a fork where one stone is cracked (it drops away
		-- a moment after you land, like a worn tile in a round), a narrow beam, a step up, and a second fork.
		local cracked: { BasePart } = {}
		local upright = CFrame.Angles(0, 0, math.rad(90)) -- stands a cylinder's axis up
		-- size is (across, thickness, along the course); a round piece is a disc size.X wide.
		local function piece(name: string, s: number, t: number, top: number, size: Vector3, round: boolean?, crack: boolean?)
			local centre = at(s, t, top - size.Y / 2)
			local colour = if crack then Color3.fromRGB(150, 96, 70) else Color3.fromRGB(72, 54, 52)
			local material = if crack then Enum.Material.Cobblestone else Enum.Material.Basalt
			local p = if round
				then part(hop, name, Vector3.new(size.Y, size.X, size.X), CFrame.new(centre) * upright, colour, material)
				else part(hop, name, size, CFrame.new(centre) * turn, colour, material)
			if round then
				p.Shape = Enum.PartType.Cylinder
			end
			local height = top - size.Y - 2
			if height > 0.2 then
				local width = math.min(size.X, size.Z) * 0.6
				local c = part(hop, "HopColumn", Vector3.new(width, height, width), CFrame.new(at(s, t, 2 + height / 2)) * turn, Color3.fromRGB(40, 30, 30), Enum.Material.Basalt)
				c.CanCollide = false
				c.CanTouch = false
			end
			if crack then
				-- The same ⚠ the round's warning tiles carry, so the hint isn't colour alone.
				local mark = Instance.new("SurfaceGui")
				mark.Face = Enum.NormalId.Top
				mark.CanvasSize = Vector2.new(200, 200) -- square canvas, like the round's warning tiles, so the ⚠ fills the stone
				mark.LightInfluence = 0
				mark.Parent = p
				local warn = Instance.new("TextLabel")
				warn.BackgroundTransparency = 1
				warn.Size = UDim2.fromScale(1, 1)
				warn.Font = Enum.Font.FredokaOne
				warn.TextScaled = true
				warn.TextColor3 = Color3.fromRGB(30, 8, 8)
				warn.Text = "⚠"
				warn.Parent = mark
				local outline = Instance.new("UIStroke")
				outline.Thickness = 6
				outline.Color = Color3.new(1, 1, 1)
				outline.Parent = warn
				table.insert(cracked, p)
			end
		end
		piece("HopStone", 7.5, 0, 4, Vector3.new(4, 1, 4), true) -- round pillar
		piece("HopCracked", 12.5, 3, 5, Vector3.new(3.4, 1, 3.4), false, true) -- fork 1: cracked
		piece("HopStone", 12.5, -3, 5, Vector3.new(3.4, 1, 3.4)) -- fork 1: solid
		piece("HopStone", 19.5, -3, 5.5, Vector3.new(1.6, 1, 7)) -- narrow beam
		piece("HopStone", 26, 0, 6.5, Vector3.new(3.2, 1, 3.2)) -- step up
		piece("HopCracked", 30.5, 3, 7.5, Vector3.new(3.2, 1, 3.2), false, true) -- fork 2: cracked
		piece("HopStone", 30.5, -2.5, 8, Vector3.new(3.2, 1, 3.2)) -- fork 2: solid
		local goalColumn = part(hop, "HopColumn", Vector3.new(5, 6, 5), CFrame.new(at(37, 0, 5)) * turn, Color3.fromRGB(40, 30, 30), Enum.Material.Basalt)
		goalColumn.CanTouch = false
		local pool = part(hop, "HopLava", Vector3.new(14, 0.5, 29.5), CFrame.new(at(18.75, 0, 2.1)) * turn, Color3.fromRGB(235, 80, 15), Enum.Material.Neon)
		pool.CanCollide = false
		pool.CastShadow = false
		for _, edge in { -1, 1 } do
			local lip = part(hop, "HopLip", Vector3.new(1.2, 0.8, 31.5), CFrame.new(at(18.75, edge * 7.6, 2.2)) * turn, Color3.fromRGB(40, 30, 30), Enum.Material.Basalt)
			lip.CanCollide = false
			lip.CanTouch = false
		end
		local poolGlow = Instance.new("SurfaceLight")
		poolGlow.Face = Enum.NormalId.Top
		poolGlow.Range = 14
		poolGlow.Brightness = 2
		poolGlow.Color = Color3.fromRGB(255, 120, 40)
		poolGlow.Parent = pool
		local function sign(on: BasePart, height: number, first: string, second: string): TextLabel
			local bb = Instance.new("BillboardGui")
			bb.Size = UDim2.fromOffset(230, 64)
			bb.StudsOffset = Vector3.new(0, height, 0)
			bb.MaxDistance = 120
			bb.Parent = on
			local labels = {}
			for i, t in { first, second } do
				local l = Instance.new("TextLabel")
				l.BackgroundTransparency = 1
				l.Size = UDim2.new(1, 0, if i == 1 then 0.58 else 0.42, 0)
				l.Position = UDim2.fromScale(0, if i == 1 then 0 else 0.58)
				l.Font = Enum.Font.FredokaOne
				l.TextScaled = true
				l.TextColor3 = if i == 1 then Color3.fromRGB(255, 190, 70) else Color3.new(1, 1, 1)
				l.Text = t
				local stroke = Instance.new("UIStroke")
				stroke.Thickness = 2
				stroke.Color = Color3.fromRGB(60, 15, 0)
				stroke.Parent = l
				l.Parent = bb
				labels[i] = l
			end
			return labels[2]
		end
		sign(startPad, 5, "🔥 WARM-UP HOP", "Cracked stones drop! Falling is safe")
		local recordLabel = sign(goalPad, 5, "🏁 FINISH", "Be the first to finish!")

		local started: { [Player]: number } = setmetatable({}, { __mode = "k" }) :: any
		local best: { [Player]: number } = setmetatable({}, { __mode = "k" }) :: any
		local sentBack: { [Player]: number } = setmetatable({}, { __mode = "k" }) :: any
		local record = { Name = "", Time = math.huge }
		local function hopper(hit: BasePart): (Player?, BasePart?)
			local model: Instance? = hit.Parent
			if model and model:IsA("Accessory") then
				model = model.Parent
			end
			local p = if model and model:IsA("Model") then Players:GetPlayerFromCharacter(model) else nil
			if not p or p:GetAttribute("ArenaMode") == "LavaRush" then
				return nil, nil
			end
			local hum = (model :: Instance):FindFirstChildOfClass("Humanoid")
			if not hum or hum.Health <= 0 then
				return nil, nil
			end
			return p, root(p)
		end
		-- The clock starts the moment you leave the green pad: while you're over it, it keeps resetting.
		task.spawn(function()
			while hop.Parent do
				for _, p in Players:GetPlayers() do
					local r = root(p)
					if r and p:GetAttribute("ArenaMode") ~= "LavaRush" then
						local rel = startPad.CFrame:PointToObjectSpace(r.Position)
						if math.abs(rel.X) < 4.5 and math.abs(rel.Z) < 4.5 and rel.Y > 0 and rel.Y < 8 then
							started[p] = now()
						end
					end
				end
				task.wait(0.1)
			end
		end)
		goalPad.Touched:Connect(function(hit)
			local p, r = hopper(hit)
			local t0 = if p then started[p] else nil
			if not p or not r or not t0 then
				return
			end
			started[p] = nil
			local t = now() - t0
			if t < CFG.HopMinTime then
				return
			end
			local prev = best[p]
			local text = string.format("⏱ %.1fs", t)
			if prev == nil or t < prev then
				best[p] = t
			end
			if t < record.Time then
				record.Time = t
				record.Name = p.DisplayName
				recordLabel.Text = string.format("🏆 Fastest: %s %.1fs", record.Name, record.Time)
				text ..= "  🏆 SERVER RECORD!"
			elseif prev and t < prev then
				text ..= "  NEW BEST!"
			end
			event:FireClient(p, "LavaFX", { Kind = "Boost", Position = r.Position, Text = text, Color = Color3.fromRGB(255, 205, 60) })
		end)
		pool.Touched:Connect(function(hit)
			local p, r = hopper(hit)
			if not p or not r then
				return
			end
			local last = sentBack[p]
			if last and os.clock() - last < 0.75 then
				return
			end
			sentBack[p] = os.clock()
			started[p] = nil
			r.AssemblyLinearVelocity = Vector3.zero
			local char = p.Character
			if char then
				char:PivotTo(CFrame.lookAt(at(0, 0, 6), at(10, 0, 6)))
			end
		end)
		-- Cracked stones drop away HopCrackDelay seconds after someone lands on them and come back HopCrackBack later.
		for _, stoneCracked in cracked do
			local dropping = false
			stoneCracked.Touched:Connect(function(hit)
				if dropping or not hopper(hit) then
					return
				end
				dropping = true
				task.delay(CFG.HopCrackDelay, function()
					-- Fade the ⚠ text rather than toggling SurfaceGui.Enabled: the client's perception module resets
					-- Enabled on every floor-1 SurfaceGui to its original value, so a server-side toggle never shows.
					local mark = stoneCracked:FindFirstChildOfClass("SurfaceGui")
					local warn = mark and mark:FindFirstChildOfClass("TextLabel")
					stoneCracked.Transparency = 0.8
					stoneCracked.CanCollide = false
					if warn then
						warn.TextTransparency = 1
					end
					task.wait(CFG.HopCrackBack)
					stoneCracked.Transparency = 0
					stoneCracked.CanCollide = true
					if warn then
						warn.TextTransparency = 0
					end
					dropping = false
				end)
			end)
		end
	end

	-- A glowing lava strip across the middle of the arena floor, under the floating grid. It runs side to side as
	-- seen from the lobby and shows through the holes as tiles break. Lava-coloured, so the themes recolour it.
	do
		local toward = (Vector3.new(c.X, 0, c.Z) - Vector3.new(CFG.Beacon.X, 0, CFG.Beacon.Z)).Unit
		local across = CFrame.lookAt(c + Vector3.new(0, 1.05, 0), c + Vector3.new(0, 1.05, 0) + Vector3.new(-toward.Z, 0, toward.X))
		local core = part(arenaFolder, "LavaStrip", Vector3.new(7, 0.3, 74), across, Color3.fromRGB(235, 80, 15), Enum.Material.Neon)
		local crust = part(arenaFolder, "LavaStripCrust", Vector3.new(7.2, 0.12, 74.2), across * CFrame.new(0, 0.2, 0), Color3.fromRGB(255, 120, 40), Enum.Material.CrackedLava)
		crust.Transparency = 0.4
		for _, edge in { -1, 1 } do
			local lip = part(arenaFolder, "LavaStripEdge", Vector3.new(1.2, 0.6, 74.4), across * CFrame.new(edge * 4, 0.1, 0), Color3.fromRGB(40, 30, 30), Enum.Material.Basalt)
			lip.CanCollide = false
		end
		for _, piece in { core, crust } do
			piece.CanCollide = false
			piece.CanQuery = false
			piece.CanTouch = false
			piece.CastShadow = false
		end
		local glow = Instance.new("SurfaceLight")
		glow.Face = Enum.NormalId.Top
		glow.Range = 18
		glow.Angle = 150
		glow.Brightness = 3
		glow.Color = Color3.fromRGB(255, 120, 40)
		glow.Parent = core
		local sparks = Instance.new("ParticleEmitter")
		sparks.Rate = 14
		sparks.Lifetime = NumberRange.new(1, 2)
		sparks.Speed = NumberRange.new(2, 5)
		sparks.EmissionDirection = Enum.NormalId.Top
		sparks.SpreadAngle = Vector2.new(20, 20)
		sparks.Color = ColorSequence.new(Color3.fromRGB(255, 200, 60), Color3.fromRGB(255, 70, 10))
		sparks.Size = NumberSequence.new(0.5, 0)
		sparks.LightEmission = 1
		sparks.Parent = core
	end

	local scenery = Instance.new("Model")
	scenery.Name = "Volcanic"
	scenery.Parent = arenaFolder
	local scorch = part(scenery, "ScorchedGround", Vector3.new(0.2, 160, 160), CFrame.new(c + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(58, 46, 44), Enum.Material.Ground)
	scorch.Shape = Enum.PartType.Cylinder
	local rng = Random.new(2026)
	local toTown = math.atan2(CFG.Beacon.Z - c.Z, CFG.Beacon.X - c.X)
	local fromTown = (Vector3.new(c.X, 0, c.Z) - Vector3.new(CFG.Beacon.X, 0, CFG.Beacon.Z)).Unit
	local hopMiddle = Vector3.new(CFG.Beacon.X, 0, CFG.Beacon.Z) + Vector3.new(-fromTown.Z, 0, fromTown.X) * (CFG.HopFrom + 20)
	local avoid = { Vector3.new(-328, 0, 262), Vector3.new(-207, 0, 431), hopMiddle }
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
		if placed >= 16 then
			break
		end
		local angle = rng:NextNumber(0, math.pi * 2)
		local off = math.abs(math.atan2(math.sin(angle - toTown), math.cos(angle - toTown)))
		local radius = rng:NextNumber(64, 90)
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

	-- Volcano crater: a ring of jagged rock walls around the lobby and the lava vent, opening a little wider as it
	-- climbs, with glowing lava veins and a glowing rim. The grid climbs the inside of the crater and the last rise
	-- lifts it just over the rim. A wide gap faces the town so players can walk out and explore the island.
	local crater = Instance.new("Model")
	crater.Name = "Crater"
	crater:SetAttribute("RimY", c.Y + CFG.CraterHeight)
	crater.Parent = scenery
	local craterRng = Random.new(1815)
	local segments = CFG.CraterSegments
	local gapHalf = math.rad(CFG.CraterGap)
	local rockColours = { Color3.fromRGB(56, 44, 46), Color3.fromRGB(66, 52, 52), Color3.fromRGB(46, 38, 42) }
	local function rock(name: string, size: Vector3, cf: CFrame, colour: Color3, material: Enum.Material): BasePart
		local p = part(crater, name, size, cf, colour, material)
		p.CastShadow = false
		return p
	end
	for i = 0, segments - 1 do
		local angle = (i + 0.5) / segments * math.pi * 2
		local off = math.abs(math.atan2(math.sin(angle - toTown), math.cos(angle - toTown)))
		if off < gapHalf then
			continue
		end
		-- Walls shrink toward the gap so the opening looks like a broken-down section of the rim.
		local taper = math.clamp((off - gapHalf) / math.rad(20), 0.25, 1)
		local height = CFG.CraterHeight * taper * craterRng:NextNumber(0.9, 1.08)
		local dir = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local tiers = 4
		local tierHeight = height / tiers
		local outerRadius = CFG.CraterRadius
		local hasFall = i % CFG.CraterFallEvery == 2 and taper >= 1
		for k = 0, tiers - 1 do
			local radius = CFG.CraterRadius + k * tierHeight * CFG.CraterFlare
			local width = 2 * math.pi * radius / segments * 1.3
			local thick = CFG.CraterThickness
			local y = c.Y + tierHeight * (k + 0.5)
			local at = c + dir * (radius + thick / 2) + Vector3.new(0, y - c.Y, 0)
			local face = CFrame.lookAt(at, Vector3.new(c.X, at.Y, c.Z))
				* CFrame.Angles(math.rad(craterRng:NextNumber(-6, 2)), 0, math.rad(craterRng:NextNumber(-4, 4)))
			local colour = rockColours[craterRng:NextInteger(1, #rockColours)]
			rock("CraterWall", Vector3.new(width, tierHeight * 1.15, thick), face, colour, if k % 2 == 0 then Enum.Material.Basalt else Enum.Material.Slate)
			outerRadius = radius + thick
			if craterRng:NextNumber() < 0.3 then
				-- A glowing lava vein down the inside face.
				local vein = rock("LavaVein", Vector3.new(craterRng:NextNumber(0.8, 1.6), tierHeight * craterRng:NextNumber(0.6, 1.1), 0.6),
					face * CFrame.new(craterRng:NextNumber(-width / 3, width / 3), 0, -thick / 2 - 0.05) * CFrame.Angles(0, 0, math.rad(craterRng:NextNumber(-25, 25))),
					Color3.fromRGB(255, 95, 25), Enum.Material.Neon)
				vein.CanCollide = false
			end
			if hasFall then
				local flat = CFrame.lookAt(at, Vector3.new(c.X, at.Y, c.Z))
				local fall = rock("LavaFall", Vector3.new(width * 0.32, tierHeight * 1.08, 0.5), flat * CFrame.new(0, 0, -thick / 2 - 0.4), Color3.fromRGB(255, 105, 25), Enum.Material.Neon)
				fall.CanCollide = false
				fall.CanQuery = false
				fall.CanTouch = false
				if k == 0 then
					local poolAt = c + dir * (CFG.CraterRadius - 5) + Vector3.new(0, 0.3, 0)
					local pool = rock("LavaFallPool", Vector3.new(0.4, 13, 13), CFrame.new(poolAt) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(255, 95, 20), Enum.Material.Neon)
					pool.Shape = Enum.PartType.Cylinder
					pool.CanCollide = false
					pool.CanQuery = false
					pool.CanTouch = false
					local glow = Instance.new("PointLight")
					glow.Color = Color3.fromRGB(255, 120, 40)
					glow.Range = 26
					glow.Brightness = 2
					glow.Parent = pool
					local splash = Instance.new("ParticleEmitter")
					splash.Texture = "rbxasset://textures/particles/smoke_main.dds"
					splash.EmissionDirection = Enum.NormalId.Right
					splash.Rate = 6
					splash.Lifetime = NumberRange.new(2, 3.5)
					splash.Speed = NumberRange.new(4, 8)
					splash.SpreadAngle = Vector2.new(25, 25)
					splash.Color = ColorSequence.new(Color3.fromRGB(255, 150, 80), Color3.fromRGB(90, 70, 70))
					splash.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1) })
					splash.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 4), NumberSequenceKeypoint.new(1, 11) })
					splash.Parent = pool
				end
			end
			if k == tiers - 1 then
				-- The rim glows like lava is lapping at the lip: the way out.
				local rim = rock("CraterRim", Vector3.new(width * 0.85, 0.8, 2.2), face * CFrame.new(0, tierHeight * 0.55, -thick / 2 + 1), Color3.fromRGB(255, 120, 40), Enum.Material.Neon)
				rim.CanCollide = false
			end
		end
		-- Outer flank: a slope down to the ground so the crater reads as a volcano from the island.
		local flankHeight = height * 0.92
		local flankDepth = CFG.CraterFlank
		local flankWidth = 2 * math.pi * (outerRadius + flankDepth) / segments * 1.15
		local flankAt = c + dir * (outerRadius - 4 + flankDepth / 2) + Vector3.new(0, flankHeight / 2, 0)
		local flank = Instance.new("WedgePart")
		flank.Name = "CraterFlank"
		flank.Anchored = true
		flank.Size = Vector3.new(flankWidth, flankHeight, flankDepth)
		-- A wedge's tall face is at its back (+Z), so look outward: tall side hugs the wall, slope runs down and out.
		flank.CFrame = CFrame.lookAt(flankAt, flankAt + dir)
		flank.Color = rockColours[craterRng:NextInteger(1, #rockColours)]
		flank.Material = Enum.Material.Basalt
		flank.CastShadow = false
		flank.TopSurface = Enum.SurfaceType.Smooth
		flank.BottomSurface = Enum.SurfaceType.Smooth
		flank.Parent = crater
	end
	-- A slow column of smoke and ash above the crater, visible from anywhere on the island.
	-- Off to the far side of the rim, so it never clouds the overhead spectator view of the grid.
	local plumeAt = c + Vector3.new(-math.cos(toTown), 0, -math.sin(toTown)) * (CFG.CraterRadius + 10) + Vector3.new(0, CFG.CraterHeight + 20, 0)
	local plume = part(crater, "Plume", Vector3.new(1, 1, 1), CFrame.new(plumeAt), Color3.new(0, 0, 0), Enum.Material.SmoothPlastic)
	plume.Transparency = 1
	plume.CanCollide = false
	plume.CanQuery = false
	plume.CanTouch = false
	local smokeColumn = Instance.new("ParticleEmitter")
	smokeColumn.Name = "Smoke"
	smokeColumn.Texture = "rbxasset://textures/particles/smoke_main.dds"
	smokeColumn.Rate = 3
	smokeColumn.Lifetime = NumberRange.new(14, 20)
	smokeColumn.Speed = NumberRange.new(5, 8)
	smokeColumn.SpreadAngle = Vector2.new(18, 18)
	smokeColumn.Rotation = NumberRange.new(0, 360)
	smokeColumn.RotSpeed = NumberRange.new(-6, 6)
	smokeColumn.Color = ColorSequence.new(Color3.fromRGB(120, 90, 85), Color3.fromRGB(60, 52, 55))
	smokeColumn.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.15, 0.45), NumberSequenceKeypoint.new(1, 1) })
	smokeColumn.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 30), NumberSequenceKeypoint.new(1, 70) })
	smokeColumn.Parent = plume
	local ash = Instance.new("ParticleEmitter")
	ash.Name = "Ash"
	ash.Rate = 12
	ash.Lifetime = NumberRange.new(4, 7)
	ash.Speed = NumberRange.new(8, 16)
	ash.SpreadAngle = Vector2.new(40, 40)
	ash.Color = ColorSequence.new(Color3.fromRGB(255, 190, 80), Color3.fromRGB(255, 60, 10))
	ash.LightEmission = 1
	ash.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.4), NumberSequenceKeypoint.new(1, 0) })
	ash.Acceleration = Vector3.new(0, -6, 0)
	ash.Parent = plume
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
			r.picked += 1
			challenge(p, "Berries", 1)
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

-- Floor tiles are shades of the world's one hue: the centre is brightest, outer rings a little deeper, and the
-- checker only changes lightness.
tileColour = function(theme: any, ring: number, light: boolean): Color3
	local t = ring / math.max(1, (CFG.GridSize - 1) / 2)
	local colour = Color3.fromHSV(theme.TileHue or 0.05, 0.5 + 0.16 * t, 0.84 - 0.24 * t)
	return if light then colour:Lerp(Color3.new(1, 1, 1), 0.1) else colour
end

local function themeColor(d: Instance, theme: any)
	local ring = d:GetAttribute("TileRing")
	if type(ring) == "number" and d:IsA("BasePart") then
		d.Color = tileColour(theme, ring, d:GetAttribute("TileLight") == true)
		return
	end
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

local function grantShield(p: Player, character: Model, r: Runner, position: Vector3, seconds: number?, message: string?)
	local lasts = seconds or CFG.ShieldTime
	r.shieldUntil = now() + lasts
	local old = character:FindFirstChild("LavaBubble")
	if old then
		old:Destroy()
	end
	local bubble = Instance.new("ForceField")
	bubble.Name = "LavaBubble"
	bubble.Visible = true
	bubble.Parent = character
	task.delay(lasts, function()
		if bubble.Parent then
			bubble:Destroy()
		end
	end)
	event:FireClient(p, "LavaFX", { Kind = "Shield", Position = position })
	tell(p, message or ("🛡️ Bubble shield! Shoves can't move you for " .. lasts .. "s."))
end

local function baseWalkSpeed(): number
	return if L.Mutator.Id == "SpeedRush" then CFG.SpeedRushWalkSpeed else CFG.RoundWalkSpeed
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
	r.drops += 1
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
	-- Score each tile by how far it is from the closest climber, then pick among the farthest few.
	local climbers = {}
	for p, r in L.Runners do
		local me = r.alive and not r.crowned and root(p)
		if me then
			table.insert(climbers, me.Position)
		end
	end
	local scored = {}
	for _, tile in candidates do
		local at = (tileDelta(tile:GetAttribute("StepIndex") :: number) * tile.CFrame).Position
		local nearest = math.huge
		for _, pos in climbers do
			nearest = math.min(nearest, Vector2.new(pos.X - at.X, pos.Z - at.Z).Magnitude)
		end
		table.insert(scored, { tile = tile, score = nearest + math.random() * 3 })
	end
	table.sort(scored, function(a, b)
		return a.score > b.score
	end)
	local step = scored[math.random(1, math.min(CFG.DropPickFrom, #scored))].tile
	local stepIndex = step:GetAttribute("StepIndex") :: number
	local boost = pickBoost()
	local born = now()
	local tileTop = step.Position + Vector3.new(0, step.Size.Y / 2, 0)
	local landAt = tileTop + Vector3.new(0, CFG.DropHover, 0)
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
	for _, d in drop:GetDescendants() do
		if d:IsA("BasePart") then
			d:SetAttribute("BobPivot", landAt)
		end
	end
	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Name = "Sparkle"
	sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkle.Color = ColorSequence.new(Color3.new(1, 1, 1), boost.Color)
	sparkle.LightEmission = 1
	sparkle.Rate = 18
	sparkle.Lifetime = NumberRange.new(0.6, 1.1)
	sparkle.Speed = NumberRange.new(1.5, 3)
	sparkle.SpreadAngle = Vector2.new(180, 180)
	sparkle.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) })
	sparkle.Parent = crate
	-- Clients pop it in with a bright flash (no parachute).
	crate:SetAttribute("SpawnFlash", true)
	crate:SetAttribute("FlashColor", boost.Color)
	local icon = Instance.new("BillboardGui")
	icon.Size = UDim2.fromOffset(52, 52)
	icon.StudsOffset = Vector3.new(0, 2.6, 0)
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
	local pillar = part(drop, "LightPillar", Vector3.new(36, 1.4, 1.4), CFrame.new(tileTop + Vector3.new(0, 18, 0)) * CFrame.Angles(0, 0, math.rad(90)), boost.Color, Enum.Material.Neon)
	pillar.Shape = Enum.PartType.Cylinder
	pillar.Transparency = 0.6
	pillar.CanCollide = false
	pillar.CanQuery = false
	pillar.CanTouch = false
	pillar.CastShadow = false
	for _, timed in { ring, pillar } do
		timed:SetAttribute("BornAt", born)
		timed:SetAttribute("Lifetime", CFG.DropLifetime)
	end
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
		radius = CFG.DropGrabRadius,
		take = function(p: Player, r: any)
			if taken or L.Phase ~= "Round" then
				return
			end
			taken = true
			local at = pickupPosition(crate)
			finish()
			applyBoost(p, r, boost, at)
			challenge(p, "Drops", 1)
			logEvent(p, "DropGrabbed", boost.Id)
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
	-- A jewelled gold crown (Creator Store model, kept in ReplicatedStorage.CrownModel) sized to the head.
	local template = game.ReplicatedStorage:FindFirstChild("CrownModel")
	if not template or not template:IsA("Model") then
		return
	end
	local hat = template:Clone()
	hat.Name = "LavaCrownHat"
	local _, size = hat:GetBoundingBox()
	hat:ScaleTo(head.Size.X * 1.25 / math.max(size.X, size.Z))
	local _, scaled = hat:GetBoundingBox()
	hat:PivotTo(head.CFrame * CFrame.new(0, head.Size.Y / 2 + scaled.Y * 0.4, 0))
	for _, piece in hat:GetDescendants() do
		if piece:IsA("BasePart") then
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
	end
	local shine = Instance.new("ParticleEmitter")
	shine.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	shine.Color = ColorSequence.new(Color3.fromRGB(255, 240, 160))
	shine.LightEmission = 1
	shine.Rate = 6
	shine.Lifetime = NumberRange.new(0.5, 0.9)
	shine.Speed = NumberRange.new(0.5, 1.5)
	shine.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) })
	shine.Parent = hat.PrimaryPart
	hat.Parent = character
	task.delay(120, function()
		if hat.Parent then
			hat:Destroy()
		end
	end)
end

-- Grid


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
	model:SetAttribute("Pillar", true)
	model:SetAttribute("PillarTop", CFG.PillarHeight + 0.8) -- cap height above the tile; LavaGrid.TileAt uses it

	table.clear(wear)
	local size = CFG.GridSize
	for row = 1, size do
		for col = 1, size do
			local index = (row - 1) * size + col
			local ring, light = Grid.Ring(size, row, col), (row + col) % 2 == 1
			local tile = tilePart(model, "Tile" .. index, Vector3.new(CFG.GridTile, 1.2, CFG.GridTile), Grid.TileCFrame(model, row, col, -math.huge), tileColour(Themes.Get(L.Theme), ring, light))
			tile:SetAttribute("TileRing", ring)
			tile:SetAttribute("TileLight", light)
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
	-- Centre pillar: a basalt column standing on the centre tile. It rides the tile (rises and spins with the floor)
	-- and blocks the view across the grid, so you can't always see who's coming round the other side. It fills most
	-- of its tile; it's left out of camera checks so the camera doesn't jump in front of it.
	do
		local centreIndex = (size * size + 1) / 2
		local base = platforms[centreIndex].CFrame * CFrame.new(0, 0.6, 0)
		local upright = CFrame.Angles(0, 0, math.rad(90)) -- stands a cylinder's axis up
		local pillar = Instance.new("Model")
		pillar.Name = "CentrePillar"
		pillar.Parent = model
		local h = CFG.PillarHeight
		local pieces = {
			part(pillar, "PillarFoot", Vector3.new(2.5, 7.6, 7.6), base * CFrame.new(0, 1.25, 0) * upright, Color3.fromRGB(40, 32, 36), Enum.Material.Basalt),
			part(pillar, "Pillar", Vector3.new(h - 2.5, 6.4, 6.4), base * CFrame.new(0, 2.5 + (h - 2.5) / 2, 0) * upright, Color3.fromRGB(56, 46, 50), Enum.Material.Basalt),
			part(pillar, "PillarCap", Vector3.new(0.8, 6.8, 6.8), base * CFrame.new(0, h + 0.4, 0) * upright, Color3.fromRGB(255, 120, 40), Enum.Material.Neon),
		}
		for _, piece in pieces do
			piece.Shape = Enum.PartType.Cylinder
			piece.CanQuery = false
			piece.CanTouch = false
		end
		-- King of the Pillar: three ledges spiral up the side (60 degrees apart, so each hop clears the column) to
		-- a strawberry on the cap. Standing up there wears the centre tile like anywhere else, so nobody can camp it.
		for k = 1, CFG.PillarLedges do
			local ledge = part(pillar, "PillarLedge", Vector3.new(2.6, 1, 2.6), base * CFrame.Angles(0, math.rad(60 * (k - 1)), 0) * CFrame.new(4.6, k * CFG.PillarLedgeStep - 0.5, 0), Color3.fromRGB(160, 116, 84), Enum.Material.Slate) -- lighter than the column so the way up reads at a glance
			ledge.CanQuery = false
			ledge.CanTouch = false
		end
		ride(pillar, centreIndex)
		makeEmber(model, (base * CFrame.new(0, h + 0.8 + 2.2, 0)).Position, centreIndex)
	end

	local startTiles = {}
	for index, tile in platforms do
		local row, col = tile:GetAttribute("Row"), tile:GetAttribute("Col")
		if Grid.Ring(size, row, col) <= CFG.StartRings and not Grid.IsPillar(model, row, col) then
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
		spot.Brightness = 1.5
		spot.Shadows = true
		spot.Color = Color3.fromRGB(255, 160, 80)
		spot.Parent = rig
		ride(rig, centreIndex)
	end

	local l = part(model, "Lava", Vector3.new(CFG.LavaPool, 4, CFG.LavaPool), CFrame.new(c), Color3.fromRGB(230, 70, 10), Enum.Material.Neon)
	local crust = part(model, "LavaCrust", Vector3.new(CFG.LavaPool, 0.2, CFG.LavaPool), CFrame.new(c), Color3.fromRGB(255, 120, 40), Enum.Material.CrackedLava)
	crust.Transparency = 0.62
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
		shoves = if existing then existing.shoves else 0,
		drops = if existing then existing.drops else 0,
		picked = if existing then existing.picked else 0,
		enteredAt = now(),
		nextShove = 0,
		shieldUntil = if existing then existing.shieldUntil else 0,
		speedUntil = 0,
		jumpUntil = 0,
		rescue = if existing then existing.rescue else false,
		nextLift = if existing then existing.nextLift else 0,
	}
	logOnboarding(p, 2, "FirstRoundStarted")
	logRound(p, 1, "Entered")
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
	local runner = L.Runners[p]
	if runner and (L.LossStreak[p] or 0) >= CFG.UnderdogAfter and now() >= runner.shieldUntil then
		grantShield(p, p.Character, runner, at, CFG.UnderdogShield, "🫧 Underdog shield! Tough few rounds, so shoves can't move you for " .. CFG.UnderdogShield .. "s.")
	end
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


-- Duos twist: everyone is paired (friends first, then other players, then bots), teammates share an outline colour and
-- can't shove each other, and the last team standing wins: both teammates are crowned.
local teamOf: { [any]: number } = {} -- Player or Bot -> team number
local TEAM_COLOURS = {
	Color3.fromRGB(80, 200, 255), Color3.fromRGB(255, 120, 200), Color3.fromRGB(120, 255, 140),
	Color3.fromRGB(255, 210, 70), Color3.fromRGB(190, 130, 255), Color3.fromRGB(255, 140, 70),
}
local function sameTeam(a: any, b: any): boolean
	local ta, tb = teamOf[a], teamOf[b]
	return ta ~= nil and ta == tb
end

-- Set by the bots section: shoves a bot in front of the player if one is closer than maxDist.
local shoveNearestBot: (Player, Vector3, Vector3, number) -> boolean = function()
	return false
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
		if other ~= p and o.alive and not o.crowned and them and not sameTeam(p, other) then
			local delta = them.Position - me.Position
			local flat = Vector3.new(delta.X, 0, delta.Z)
			if flat.Magnitude < bestDist and math.abs(delta.Y) < 6 and (flat.Magnitude < 0.5 or me.CFrame.LookVector:Dot(flat.Unit) > 0.3) then
				best, bestDist = other, flat.Magnitude
			end
		end
	end
	event:FireClient(p, "LavaFX", { Kind = "Swing" })
	if shoveNearestBot(p, me.Position, me.CFrame.LookVector, bestDist) then
		r.shoves += 1
		return
	end
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
		local power = if L.ShowdownAt > 0 then CFG.ShowdownShove else 1
		event:FireClient(best, "LavaShove", dir * CFG.ShoveSpeed * power + Vector3.new(0, CFG.ShoveLift, 0))
		event:FireClient(p, "LavaFX", { Kind = "Hit", Position = them.Position })
		tell(best, "💥 " .. p.DisplayName .. " shoved you!")
		challenge(p, "Shoves", 1)
		r.shoves += 1
	end
end

-- Hot Potato: a ticking bomb rides on one climber's head. Touch someone to pass it on; whoever holds it when it
-- blows gets launched off the grid (a bubble shield soaks the blast). The holder runs a little faster to chase.

type Bomb = { holder: Player?, endsAt: number, passedAt: number, from: Player?, nextAt: number, model: Model?, label: TextLabel?, shown: string }
local bomb: Bomb = { holder = nil, endsAt = 0, passedAt = 0, from = nil, nextAt = 0, model = nil, label = nil, shown = "" }

local function dropBombLook()
	if bomb.model then
		bomb.model:Destroy()
	end
	bomb.model, bomb.label, bomb.shown = nil, nil, ""
	local holder = bomb.holder
	local character = holder and holder.Character
	local glow = character and character:FindFirstChild("BombGlow")
	if glow then
		glow:Destroy()
	end
	local hum = character and character:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.WalkSpeed = baseWalkSpeed()
	end
end

local function bombLook(p: Player)
	local character = p.Character
	local head = character and character:FindFirstChild("Head")
	if not character or not head or not head:IsA("BasePart") then
		return
	end
	local model = Instance.new("Model")
	model.Name = "LavaBomb"
	local ball = Instance.new("Part")
	ball.Name = "Ball"
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.new(1.8, 1.8, 1.8)
	ball.Color = Color3.fromRGB(35, 30, 40)
	ball.Material = Enum.Material.SmoothPlastic
	ball.CanCollide, ball.CanQuery, ball.CanTouch, ball.Massless = false, false, false, true
	ball.CFrame = head.CFrame * CFrame.new(0, 2.4, 0)
	ball.Parent = model
	local fuse = Instance.new("Part")
	fuse.Name = "Fuse"
	fuse.Size = Vector3.new(0.25, 0.6, 0.25)
	fuse.Color = Color3.fromRGB(255, 170, 60)
	fuse.Material = Enum.Material.Neon
	fuse.CanCollide, fuse.CanQuery, fuse.CanTouch, fuse.Massless = false, false, false, true
	fuse.CFrame = ball.CFrame * CFrame.new(0, 1.1, 0)
	fuse.Parent = model
	local sparks = Instance.new("ParticleEmitter")
	sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparks.Color = ColorSequence.new(Color3.fromRGB(255, 240, 150), Color3.fromRGB(255, 90, 20))
	sparks.LightEmission = 1
	sparks.Rate = 30
	sparks.Lifetime = NumberRange.new(0.2, 0.45)
	sparks.Speed = NumberRange.new(3, 6)
	sparks.SpreadAngle = Vector2.new(60, 60)
	sparks.Size = NumberSequence.new(0.35, 0)
	sparks.Parent = fuse
	for _, piece in { ball, fuse } do
		local weld = Instance.new("WeldConstraint")
		weld.Part0, weld.Part1 = piece, head
		weld.Parent = piece
	end
	local tag = Instance.new("BillboardGui")
	tag.Size = UDim2.fromOffset(70, 34)
	tag.StudsOffset = Vector3.new(0, 2, 0)
	tag.AlwaysOnTop = true
	tag.Parent = ball
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 235, 120)
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = Color3.fromRGB(90, 10, 0)
	label.Text = ""
	label.Parent = tag
	model.Parent = character
	local glow = Instance.new("Highlight")
	glow.Name = "BombGlow"
	glow.FillColor = Color3.fromRGB(255, 60, 30)
	glow.FillTransparency = 0.65
	glow.OutlineColor = Color3.fromRGB(255, 200, 60)
	glow.Parent = character
	local hum = character:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.WalkSpeed = baseWalkSpeed() + CFG.BombSpeed
	end
	bomb.model, bomb.label = model, label
end

local function giveBomb(p: Player, from: Player?)
	dropBombLook()
	bomb.holder, bomb.from, bomb.passedAt = p, from, now()
	bomb.endsAt = math.max(bomb.endsAt, now() + CFG.BombMinLeft)
	bombLook(p)
	local me = root(p)
	event:FireClient(p, "LavaFX", { Kind = "Bomb", Position = me and me.Position })
	if from then
		tell(p, "💣 " .. from.DisplayName .. " passed you the bomb! Tag someone fast!")
		tell(from, "✅ Passed it to " .. p.DisplayName .. "!")
	else
		tell(p, "💣 You have the bomb! Touch someone to pass it!")
	end
end

local function resetBomb()
	dropBombLook()
	bomb.holder, bomb.from, bomb.endsAt, bomb.nextAt = nil, nil, 0, 0
end

local function bombTick(active: number)
	local holder = bomb.holder
	local hr = holder and L.Runners[holder]
	if holder and (not hr or not hr.alive or hr.crowned or not holder.Parent or not root(holder)) then
		dropBombLook()
		bomb.holder, bomb.nextAt = nil, now() + CFG.BombGap
		holder = nil
	end
	if not holder or not hr then
		if active >= 2 and gridPhase() >= 1 and now() >= bomb.nextAt then
			local pool = {}
			for p, r in L.Runners do
				if r.alive and not r.crowned and root(p) then
					table.insert(pool, p)
				end
			end
			if #pool >= 2 then
				bomb.endsAt = now() + CFG.BombTime
				giveBomb(pool[math.random(#pool)], nil)
			end
		end
		return
	end
	local holderPlayer = holder :: Player
	local me = root(holderPlayer) :: BasePart
	if not bomb.model or bomb.model.Parent ~= holderPlayer.Character then
		dropBombLook()
		bombLook(holderPlayer) -- respawned or rescued: put the bomb back on
	end
	local left = math.max(0, bomb.endsAt - now())
	local text = string.format("💣 %d", math.ceil(left))
	if bomb.label and text ~= bomb.shown then
		bomb.shown = text
		bomb.label.Text = text
		bomb.label.TextColor3 = if left <= 3 then Color3.fromRGB(255, 80, 60) else Color3.fromRGB(255, 235, 120)
	end
	if now() - bomb.passedAt >= CFG.BombPassCooldown then
		for other, o in L.Runners do
			local them = root(other)
			if other ~= holderPlayer and o.alive and not o.crowned and them and (other ~= bomb.from or now() - bomb.passedAt > 2) then
				local delta = them.Position - me.Position
				if Vector3.new(delta.X, 0, delta.Z).Magnitude < CFG.BombPassRange and math.abs(delta.Y) < 5 then
					giveBomb(other, holderPlayer)
					return
				end
			end
		end
	end
	if left > 0 then
		return
	end
	-- BOOM
	local at = me.Position
	dropBombLook()
	bomb.holder, bomb.from, bomb.nextAt = nil, nil, now() + CFG.BombGap
	for p in L.Runners do
		if p.Parent then
			event:FireClient(p, "LavaFX", { Kind = "Boom", Position = at })
		end
	end
	if now() < hr.shieldUntil then
		tell(holderPlayer, "🛡️ Your bubble shield soaked the blast!")
		return
	end
	local centre = CFG.Center
	local out = Vector3.new(at.X - centre.X, 0, at.Z - centre.Z)
	out = if out.Magnitude > 0.5 then out.Unit else Vector3.new(math.random() - 0.5, 0, math.random() - 0.5).Unit
	event:FireClient(holderPlayer, "LavaShove", out * CFG.BombBlast + Vector3.new(0, CFG.BombLift, 0))
	for p in L.Runners do
		if p.Parent then
			tell(p, if p == holderPlayer then "💥 BOOM! The bomb went off in your hands!" else "💥 BOOM! " .. holderPlayer.DisplayName .. " got blasted!")
		end
	end
end

-- Round


-- Seasonal events (GameConfig.Events): the one running today, if any. Studio can force one with the workspace
-- attribute StudioForceEvent. The id is published as workspace attribute "LavaEvent" with its end time.
local function eventEnd(e: any, t: number): number
	local d = os.date("!*t", t)
	local year = d.year
	if e.To[1] < e.From[1] and d.month >= e.From[1] then
		year += 1
	end
	local ends = os.time({ year = year, month = e.To[1], day = e.To[2], hour = 23, min = 59, sec = 59 })
	if ends < t then
		ends = os.time({ year = year + 1, month = e.To[1], day = e.To[2], hour = 23, min = 59, sec = 59 })
	end
	return ends
end

local function activeEvent(): any?
	local forced = if Run:IsStudio() then workspace:GetAttribute("StudioForceEvent") else nil
	for _, e in GameConfig.Events or {} do
		if forced == e.Id then
			return e
		end
	end
	local d = os.date("!*t", os.time())
	local md = d.month * 100 + d.day
	for _, e in GameConfig.Events or {} do
		local from, to = e.From[1] * 100 + e.From[2], e.To[1] * 100 + e.To[2]
		local inside = if from <= to then md >= from and md <= to else md >= from or md <= to
		if inside then
			return e
		end
	end
	return nil
end

local function publishEvent()
	local e = activeEvent()
	workspace:SetAttribute("LavaEvent", e and e.Id)
	workspace:SetAttribute("LavaEventEnds", e and eventEnd(e, os.time()))
end

local function payout()
	for p, r in L.Runners do
		local d = data(p)
		if p.Parent and d then
			if not d.TutorialDone then
				d.TutorialDone = true
				p:SetAttribute("Tutorial", false)
				logOnboarding(p, 3, "FirstRoundFinished")
			else
				logOnboarding(p, 4, "SecondRoundFinished")
			end
			challenge(p, "Play", 1)
			if r.crowned or r.alive then
				challenge(p, "Survive", 1)
			end
			L.LossStreak[p] = if r.crowned or r.alive then 0 else (L.LossStreak[p] or 0) + 1
			if r.crowned then
				challenge(p, "Win", 1)
			end
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
			local height = math.floor(r.peak)
			local prevBest = tonumber(d.BestHeight) or 0
			local newBest = height > prevBest
			if newBest then
				d.BestHeight = height
				p:SetAttribute("BestHeight", height)
				coins += CFG.BestCoins
				logEvent(p, "PersonalBest", if prevBest == 0 then "First" else "Beaten")
			end
			if A.RPG and A.RPG.AwardXP then
				A.RPG.AwardXP(p, coins * CFG.XPPerCoin)
			end
			local boosted = A.Pass and A.Pass.Has and A.Pass.Has(p, "DoubleLava") or false
			local withFriend = hasFriendHere(p)
			if withFriend then
				coins = math.floor(coins * (1 + CFG.FriendBonus))
				badge(p, "PlayWithFriend")
			end
			local season = activeEvent()
			if season and season.CoinBonus then
				coins = math.floor(coins * (1 + season.CoinBonus))
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
			logCoins(p, "Gameplay", coins, "RoundPayout")
			-- Lava Chest progress (flat coins, the same for everyone, added after the round multipliers).
			local fill = CFG.ChestPlay + math.floor(math.clamp(r.peak / crownHeight, 0, 1) * CFG.ChestClimb)
				+ (if r.crowned then CFG.ChestCrown elseif r.alive then CFG.ChestSurvive else 0)
			local chestBefore = math.clamp(tonumber(d.Chest) or 0, 0, CFG.ChestGoal - 1)
			local chestAfter = chestBefore + fill
			local chestCoins = 0
			if chestAfter >= CFG.ChestGoal then
				chestAfter -= CFG.ChestGoal
				d.ChestsOpened = (tonumber(d.ChestsOpened) or 0) + 1
				chestCoins = if d.ChestsOpened % CFG.ChestBigEvery == 0 then CFG.ChestBigCoins else CFG.ChestCoins
				d.Coins = math.min(100000000, d.Coins + chestCoins)
				logCoins(p, "Gameplay", chestCoins, "LavaChest")
			end
			d.Chest = math.min(chestAfter, CFG.ChestGoal - 1)
			local opened = tonumber(d.ChestsOpened) or 0
			-- Near miss: how many rises were left when you went out (your character stands ~3 studs above its tile).
			local reached = math.clamp(math.floor((r.peak - 3 - CFG.GridBaseY) / CFG.GridRise + 0.5), 0, #CFG.GridSpins)
			if reached > 0 then
				L.Goal += reached
				L.GoalHelpers[p] = true
			end
			if A.Season and GameConfig.LavaPass then
				local xp = GameConfig.LavaPass.XP
				A.Season.AddXP(p, xp.Played + (if r.crowned then xp.Crowned elseif r.alive then xp.Survived else 0) + (if r.crowned or r.alive then r.embers * xp.Berry else 0))
			end
			pushStats(p)
			event:FireClient(p, "LavaResult", {
				Outcome = if r.crowned then "CROWNED" elseif r.alive then "SURVIVED" else "SCORCHED",
				Height = height,
				Best = tonumber(d.BestHeight) or height,
				NewBest = newBest,
				PrevBest = prevBest,
				RisesLeft = #CFG.GridSpins - reached,
				Chest = {
					Before = chestBefore,
					After = d.Chest,
					Fill = fill,
					Goal = CFG.ChestGoal,
					Opened = chestCoins,
					BigIn = CFG.ChestBigEvery - opened % CFG.ChestBigEvery,
				},
				Embers = if r.crowned or r.alive then r.embers else 0,
				Doubled = r.crowned,
				Coins = coins,
				Boosted = boosted,
				Friends = withFriend,
				Vip = isVip,
			})
		end
	end
	-- Server goal (CFG.GoalRises): when the server's climbers have filled the shared bar, everyone who helped since the
	-- last one gets the same fixed coins. Published as workspace attributes LavaGoal / LavaGoalSize for the top bar.
	if L.Goal >= CFG.GoalRises then
		L.Goal = math.min(L.Goal - CFG.GoalRises, CFG.GoalRises - 1)
		for p in L.GoalHelpers do
			local d = data(p)
			if p.Parent and d then
				d.Coins = math.min(100000000, d.Coins + CFG.GoalCoins)
				logCoins(p, "Gameplay", CFG.GoalCoins, "ServerGoal")
				pushStats(p)
				event:FireClient(p, "LavaFX", { Kind = "Invite", Text = "🌋 Server goal!", Coins = CFG.GoalCoins })
			end
		end
		table.clear(L.GoalHelpers)
		for _, p in Players:GetPlayers() do
			tell(p, "🌋 Server goal reached! Everyone who climbed gets +" .. CFG.GoalCoins .. " coins. Next bar starts now!")
		end
	end
	workspace:SetAttribute("LavaGoal", L.Goal)
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
	logCoins(p, "ContextualPurchase", CFG.LiftCost, "RaiseTile", true)
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
	logOnboarding(p, 5, "FirstCrown")
	logRound(p, 4, "Crowned")
	badge(p, "FirstCrown")
	local d = data(p)
	if d then
		d.Crowns = (d.Crowns or 0) + 1
		addWeekCrown(p, d)
		if d.Crowns >= 10 then
			badge(p, "TenCrowns")
		end
		pushStats(p)
	end
	giveCrownHat(p)
	tell(p, "👑 YOU SURVIVED ALL " .. #CFG.GridSpins .. " PHASES! Embers pay double.")
	local me = root(p)
	if me then
		for _, other in Players:GetPlayers() do
			event:FireClient(other, "LavaFX", { Kind = "Crown", Position = me.Position, Mine = other == p })
		end
	end
	personal(p)
end

-- Title tag: the best title your crowns have earned, floating over your head everywhere.
local function applyTitle(p: Player)
	local character = p.Character
	local head = character and character:FindFirstChild("Head")
	if not head then
		return
	end
	local crowns = tonumber(p:GetAttribute("Crowns")) or 0
	local best = nil
	for _, t in CFG.Titles do
		if crowns >= t.Crowns then
			best = t
		end
	end
	local tag = head:FindFirstChild("LavaTitle")
	if not best then
		if tag then
			tag:Destroy()
		end
		return
	end
	if not tag then
		tag = Instance.new("BillboardGui")
		tag.Name = "LavaTitle"
		tag.Size = UDim2.fromOffset(150, 22)
		tag.StudsOffset = Vector3.new(0, 1.9, 0)
		tag.MaxDistance = 70
		tag.Parent = head
		local text = Instance.new("TextLabel")
		text.Name = "Text"
		text.BackgroundTransparency = 1
		text.Size = UDim2.fromScale(1, 1)
		text.Font = Enum.Font.FredokaOne
		text.TextScaled = true
		text.TextStrokeTransparency = 0.25
		text.TextStrokeColor3 = Color3.fromRGB(30, 10, 0)
		text.Parent = tag
	end
	local text = tag:FindFirstChild("Text") :: TextLabel
	text.Text = best.Text
	text.TextColor3 = best.Color
end

local function lavaFor(t: number): number
	if not tower then
		return CFG.Center.Y + CFG.LavaStart
	end
	local _, gridY = Grid.Pose(tower, t - CFG.LavaLag)
	return gridY - CFG.LavaBelow
end


-- Bots: when a round starts with only a few real climbers, rock-named bots fill it up so it never feels empty.
-- Tiles only move on clients, so a bot is a tile index plus a stand height: the server decides where it hops,
-- when it falls and when it is shoved, and every client draws it riding its moving tile (tag "LavaBot").
type Bot = { name: string, model: Model, root: BasePart, row: number, col: number, alive: boolean, nextThink: number, stand: number }
local bots: { Bot } = {}
local botStarters = 0
aliveBotNames = function()
	local names = {}
	for _, b in bots do
		if b.alive then
			table.insert(names, "🤖 " .. b.name)
		end
	end
	return names
end
aliveBotCount = function()
	local n = 0
	for _, b in bots do
		if b.alive then
			n += 1
		end
	end
	return n
end

local function botTileTop(b: Bot, t: number): CFrame
	local half = 0.6
	return Grid.TileCFrame(tower :: Model, b.row, b.col, t) * CFrame.new(0, half, 0)
end

local function botPosition(b: Bot): Vector3
	return (botTileTop(b, now()) * CFrame.new(0, b.stand, 0)).Position
end

local function aliveBots(): number
	local n = 0
	for _, b in bots do
		if b.alive then
			n += 1
		end
	end
	return n
end

local function setBotTile(b: Bot, row: number, col: number)
	b.row, b.col = row, col
	b.root:SetAttribute("BotRow", row)
	b.root:SetAttribute("BotCol", col)
	b.root:SetAttribute("BotHopAt", now())
end

local function killBot(b: Bot, how: string)
	if not b.alive then
		return
	end
	b.alive = false
	local at = botPosition(b)
	b.root:SetAttribute("BotFalling", now())
	for _, p in Players:GetPlayers() do
		event:FireClient(p, "LavaFX", { Kind = "BotOut", Position = at, Text = "🤖 " .. b.name })
	end
	for p in L.Runners do
		if p.Parent then
			tell(p, "🔥 🤖 " .. b.name .. " " .. how)
		end
	end
	local model = b.model
	task.delay(1.6, function()
		model:Destroy()
	end)
end

local function walkable(state: string): boolean
	return state == "Still" or state == "Warning" or state == "Growing"
end

local function makeBot(name: string, row: number, col: number): Bot?
	local towerModel = tower
	if not towerModel then
		return nil
	end
	local desc = Instance.new("HumanoidDescription")
	local skin = Color3.fromHSV(math.random(), 0.25, 0.9)
	for _, k in { "HeadColor", "LeftArmColor", "RightArmColor", "TorsoColor", "LeftLegColor", "RightLegColor" } do
		(desc :: any)[k] = skin
	end
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	end)
	if not ok or not model or not tower or tower ~= towerModel then
		return nil
	end
	model.Name = "Bot_" .. name
	pcall(function()
		model:ScaleTo(CFG.CharacterScale)
	end)
	local hum = model:FindFirstChildOfClass("Humanoid")
	local rootPart = model:FindFirstChild("HumanoidRootPart")
	if not hum or not rootPart or not rootPart:IsA("BasePart") then
		model:Destroy()
		return nil
	end
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
	rootPart.Anchored = true
	-- Lava-rock golem look: basalt body in a random rock shade, glowing ember eyes and a fruit hat, so bots are
	-- easy to tell apart from players at a glance.
	local rockShade = Color3.fromHSV(0.02 + math.random() * 0.05, 0.35 + math.random() * 0.2, 0.22 + math.random() * 0.12)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.Massless = true
			if d ~= rootPart then
				d.Material = Enum.Material.Basalt
				d.Color = rockShade
				d:SetAttribute("NoTheme", true)
			end
		elseif d:IsA("Decal") and d.Name == "face" then
			d:Destroy()
		end
	end
	local head = model:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		for side = -1, 1, 2 do
			local eye = Instance.new("Part")
			eye.Name = "EmberEye"
			eye.Shape = Enum.PartType.Ball
			eye.Material = Enum.Material.Neon
			eye.Color = Color3.fromRGB(255, 150, 40)
			eye.Size = Vector3.one * head.Size.Y * 0.18
			eye.CanCollide, eye.CanQuery, eye.CanTouch, eye.Massless, eye.CastShadow = false, false, false, true, false
			eye.CFrame = head.CFrame * CFrame.new(side * head.Size.X * 0.2, head.Size.Y * 0.08, -head.Size.Z * 0.48)
			local weld = Instance.new("WeldConstraint")
			weld.Part0, weld.Part1 = head, eye
			weld.Parent = eye
			eye.Parent = model
		end
		local hats = { "Strawberry", "Banana", "Pineapple", "Watermelon", "Coconut", "Blueberry" }
		local template = FruitModels:FindFirstChild(hats[math.random(#hats)])
		if template and template:IsA("Model") then
			local hat = template:Clone()
			hat.Name = "BotHat"
			local _, size = hat:GetBoundingBox()
			hat:ScaleTo(head.Size.X * 1.1 / math.max(size.X, size.Z))
			local _, scaled = hat:GetBoundingBox()
			hat:PivotTo(head.CFrame * CFrame.new(0, head.Size.Y / 2 + scaled.Y * 0.35, 0))
			for _, piece in hat:GetDescendants() do
				if piece:IsA("BasePart") then
					piece.Anchored = false
					piece.CanCollide, piece.CanQuery, piece.CanTouch, piece.Massless = false, false, false, true
					piece:SetAttribute("NoTheme", true)
					local weld = Instance.new("WeldConstraint")
					weld.Part0, weld.Part1 = head, piece
					weld.Parent = piece
				end
			end
			hat.Parent = model
		end
		local tag = Instance.new("BillboardGui")
		tag.Size = UDim2.fromOffset(110, 24)
		tag.StudsOffset = Vector3.new(0, 1.8, 0)
		tag.MaxDistance = 90
		tag.Parent = head
		local text = Instance.new("TextLabel")
		text.BackgroundTransparency = 1
		text.Size = UDim2.fromScale(1, 1)
		text.Font = Enum.Font.FredokaOne
		text.TextScaled = true
		text.Text = "🤖 " .. name
		text.TextColor3 = Color3.fromRGB(255, 225, 190)
		text.TextStrokeTransparency = 0.3
		text.Parent = tag
	end
	local stand = hum.HipHeight + rootPart.Size.Y / 2
	local b: Bot = { name = name, model = model, root = rootPart, row = row, col = col, alive = true, nextThink = now() + 1 + math.random(), stand = stand }
	rootPart:SetAttribute("BotStand", stand)
	rootPart:SetAttribute("BotYaw", math.random() * math.pi * 2)
	setBotTile(b, row, col)
	rootPart.CFrame = botTileTop(b, now()) * CFrame.new(0, stand, 0)
	CollectionService:AddTag(rootPart, "LavaBot")
	model.Parent = towerModel
	return b
end

local function assignTeams()
	table.clear(teamOf)
	local players = {}
	for p, r in L.Runners do
		if p.Parent and r.alive then
			table.insert(players, p)
		end
	end
	local pending = {}
	local used = {}
	-- Friends first.
	for _, p in players do
		if not used[p] then
			for _, q in players do
				if q ~= p and not used[q] and friends[p] and friends[p][q.UserId] then
					table.insert(pending, { p, q })
					used[p], used[q] = true, true
					break
				end
			end
		end
	end
	local rest = {}
	for _, p in players do
		if not used[p] then
			table.insert(rest, p)
		end
	end
	for _, b in bots do
		if b.alive then
			table.insert(rest, b)
		end
	end
	for i = 1, #rest, 2 do
		table.insert(pending, { rest[i], rest[i + 1] })
	end
	for team, pair in pending do
		local colour = TEAM_COLOURS[(team - 1) % #TEAM_COLOURS + 1]
		for i, member in pair do
			teamOf[member] = team
			local model = if typeof(member) == "Instance" then member.Character else member.model
			if model then
				local glow = model:FindFirstChild("TeamGlow") or Instance.new("Highlight")
				glow.Name = "TeamGlow"
				glow.OutlineColor = colour
				glow.FillColor = colour
				glow.FillTransparency = 0.8
				glow.DepthMode = Enum.HighlightDepthMode.Occluded
				glow.Parent = model
			end
			local mate = pair[3 - i]
			if typeof(member) == "Instance" then
				local mateName = if mate == nil then nil elseif typeof(mate) == "Instance" then mate.DisplayName else "🤖 " .. mate.name
				tell(member, if mateName then "👥 DUOS! Your teammate: " .. mateName .. " — last team standing wins!" else "👥 DUOS! You're solo this round — good luck!")
			end
		end
	end
end

local function clearTeams()
	for member in teamOf do
		local model = if typeof(member) == "Instance" then member.Character else member.model
		local glow = model and model:FindFirstChild("TeamGlow")
		if glow then
			glow:Destroy()
		end
	end
	table.clear(teamOf)
end

local spawnBotsOnly: () -> ()
local function spawnBots()
	spawnBotsOnly()
	if L.Mutator.Id == "Duos" then
		assignTeams()
	end
end

spawnBotsOnly = function()
	table.clear(bots)
	local real = count(L.Runners)
	local want = if real > 0 then math.clamp(CFG.BotFillTo - real, 0, CFG.BotMax) else 0
	botStarters = want
	if want == 0 or not tower then
		return
	end
	local names = table.clone(CFG.BotNames)
	local size = CFG.GridSize
	local spots = {}
	for row = 1, size do
		for col = 1, size do
			if Grid.Ring(size, row, col) <= CFG.StartRings and Grid.TileState(tower, row, col, now()) == "Still" and not Grid.IsPillar(tower, row, col) then
				table.insert(spots, { row, col })
			end
		end
	end
	for _ = 1, want do
		if #spots == 0 or #names == 0 then
			break
		end
		local spot = table.remove(spots, math.random(#spots))
		local name = table.remove(names, math.random(#names))
		local b = makeBot(name, spot[1], spot[2])
		if b then
			table.insert(bots, b)
		end
	end
end

-- Pick the best tile among the bot's own and its eight neighbours; sometimes make a mistake.
local function botThink(b: Bot, t: number, taken: { [number]: boolean })
	local towerModel = tower :: Model
	local size = CFG.GridSize
	local best, bestScore = nil, -math.huge
	local options = {}
	for dr = -1, 1 do
		for dc = -1, 1 do
			local r, c = b.row + dr, b.col + dc
			if r >= 1 and r <= size and c >= 1 and c <= size then
				local state = Grid.TileState(towerModel, r, c, t)
				if walkable(state) and not Grid.IsPillar(towerModel, r, c) then
					local here = dr == 0 and dc == 0
					local score = if state == "Still" then 3 else -5
					score -= 4 * (Grid.Crumble(towerModel, r, c, t) or 0)
					score -= 0.6 * Grid.Ring(size, r, c)
					if Grid.Safe(towerModel, r, c, t) then
						score += 1.5
					end
					if not here and taken[(r - 1) * size + c] then
						score -= 3
					end
					if here then
						score += 0.8
					end
					score += math.random() * 0.6
					table.insert(options, { r, c })
					if score > bestScore then
						best, bestScore = { r, c }, score
					end
				end
			end
		end
	end
	if #options > 0 and math.random() < CFG.BotMistake + L.BotEase then
		best = options[math.random(#options)]
	end
	if best and (best[1] ~= b.row or best[2] ~= b.col) then
		setBotTile(b, best[1], best[2])
	end
end

-- Runs every frame of a round: falls, lava and thinking. Returns how many bots are still up.
local function botTick(t: number, occupied: { [number]: boolean }): (number, Bot?)
	if not tower then
		return 0, nil
	end
	local towerModel = tower :: Model
	local size = CFG.GridSize
	local alive, last = 0, nil
	local taken = {}
	for _, b in bots do
		if b.alive then
			taken[(b.row - 1) * size + b.col] = true
		end
	end
	for _, b in bots do
		if b.alive then
			local state = Grid.TileState(towerModel, b.row, b.col, t)
			local top = botTileTop(b, t).Position.Y
			if state == "Falling" or state == "Gone" or state == "Hidden" then
				killBot(b, "fell with the floor!")
			elseif top < L.LavaY + 0.5 then
				killBot(b, "got caught by the lava!")
			else
				if t >= b.nextThink then
					b.nextThink = t + CFG.BotThink[1] + math.random() * (CFG.BotThink[2] - CFG.BotThink[1])
					botThink(b, t, taken)
				end
				occupied[(b.row - 1) * size + b.col] = true
				alive += 1
				last = b
			end
		end
	end
	return alive, last
end

-- A player's shove reaches a bot: knock it a tile or two that way, or off the grid if there's nothing there.
local function shoveBot(p: Player, b: Bot, dir: Vector3)
	local towerModel = tower :: Model
	local from = botPosition(b)
	local row, col = Grid.TileAt(towerModel, from + dir * CFG.GridTile * 1.6 + Vector3.new(0, 2, 0), now())
	event:FireClient(p, "LavaFX", { Kind = "Hit", Position = from })
	challenge(p, "Shoves", 1)
	if row and col and walkable(Grid.TileState(towerModel, row, col, now())) then
		setBotTile(b, row, col)
		b.nextThink = now() + 0.6
	else
		killBot(b, "got shoved into the lava by " .. p.DisplayName .. "!")
	end
end

shoveNearestBot = function(p: Player, from: Vector3, look: Vector3, maxDist: number): boolean
	if not tower then
		return false
	end
	local best, bestDist = nil, maxDist
	for _, b in bots do
		if b.alive and not sameTeam(p, b) then
			local delta = botPosition(b) - from
			local flat = Vector3.new(delta.X, 0, delta.Z)
			if flat.Magnitude < bestDist and math.abs(delta.Y) < 6 and (flat.Magnitude < 0.5 or look:Dot(flat.Unit) > 0.3) then
				best, bestDist = b, flat.Magnitude
			end
		end
	end
	if not best then
		return false
	end
	local delta = botPosition(best) - from
	local dir = Vector3.new(delta.X, 0, delta.Z)
	shoveBot(p, best, if dir.Magnitude > 0.1 then dir.Unit else Vector3.new(look.X, 0, look.Z).Unit)
	return true
end

local function runRound()
	L.RoundId += 1
	table.clear(L.Predictions)
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
	clearTeams()
	task.spawn(spawnBots)
	broadcast()
	workspace.Gravity = if L.Mutator.Id == "LowGravity" then 115 else DEFAULT_GRAVITY
	local lastBroadcast = 0
	clearDrops()
	resetBomb()
	local dropEvery = if L.Mutator.Id == "DropParty" then CFG.DropPartyEvery else CFG.DropEvery
	local nextDrop = started + CFG.DropFirstAt
	local lastPhase = 0
	local starters = 0
	local roundWinners: { Player } = {}
	local botWinners: { string } = {}
	L.ShowdownAt = 0
	while now() < L.EndsAt do
		local dt = Run.Heartbeat:Wait()
		if now() >= nextDrop then
			nextDrop = now() + dropEvery
			spawnDrop()
		end
		local surge = 0
		if L.ShowdownAt > 0 then
			local since = now() - L.ShowdownAt
			surge = CFG.ShowdownSurge * since + 0.06 * since * since
		end
		setLava(lavaFor(now()) + surge)
		local phase = gridPhase()
		if phase ~= lastPhase then
			lastPhase = phase
			for p, r in L.Runners do
				if r.alive and not r.crowned then
					tell(p, if phase == #CFG.GridSpins then "🏁 FINAL PHASE — hold on!" else string.format("Phase %d of %d", phase, #CFG.GridSpins))
					challenge(p, "Phase", phase, true)
					if phase == #CFG.GridSpins then
						logRound(p, 3, "FinalPhase")
					elseif phase == 2 then
						logRound(p, 2, "Phase2")
					end
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
				-- The client owns its character's position: a sudden jump means a teleport, so no pickups for a moment.
				if r.lastPos and (me.Position - r.lastPos).Magnitude > CFG.TeleportJump then
					r.blinkUntil = now() + 1
				end
				r.lastPos = me.Position
				local canPick = now() >= (r.blinkUntil or 0)
				for k = #pickups, 1, -1 do
					local pick = pickups[k]
					if not pick.item.Parent then
						table.remove(pickups, k)
					elseif canPick and (pickupPosition(pick.item) - me.Position).Magnitude < pick.radius then
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
							r.lastPos = nil -- our own teleport, not a cheat
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
						r.offGridSince = nil
					elseif not lateOpen() then
						-- Not over the grid: a real fall reaches the lava in a second or two, so a long stay means hovering.
						r.offGridSince = r.offGridSince or now()
						if now() - (r.offGridSince :: number) > CFG.OffGridLimit then
							r.offGridSince = nil
							scorch(p, r)
						end
					end
				end
			end
		end
		local playersActive = active
		local botsUp, lastBot = botTick(now(), occupied)
		active += botsUp
		starters = math.max(starters, count(L.Runners) + botStarters)
		updateWear(occupied, dt)
		if L.Mutator.Id == "HotPotato" then
			bombTick(playersActive)
		end
		if now() - lastBroadcast > 0.5 then
			lastBroadcast = now()
			broadcast()
		end
		if playersActive == 0 and not lateOpen() and next(L.Queue) == nil then
			-- No real climbers left: any bots still standing take the round.
			for _, b in bots do
				if b.alive then
					table.insert(botWinners, "🤖 " .. b.name)
				end
			end
			break
		end
		local duos = L.Mutator.Id == "Duos" and next(teamOf) ~= nil
		local aliveTeams: { [number]: boolean } = {}
		local teamsLeft = 0
		if duos then
			for p, r in L.Runners do
				if r.alive and not r.crowned and p:GetAttribute("ArenaMode") == "LavaRush" and teamOf[p] then
					aliveTeams[teamOf[p]] = true
				end
			end
			for _, b in bots do
				if b.alive and teamOf[b] then
					aliveTeams[teamOf[b]] = true
				end
			end
			for _ in aliveTeams do
				teamsLeft += 1
			end
			if teamsLeft == 1 and not lateOpen() and next(L.Queue) == nil then
				local winner = next(aliveTeams)
				local names = {}
				for p, r in L.Runners do
					if teamOf[p] == winner and p.Parent and not r.crowned then
						crownPlayer(p, r)
						table.insert(roundWinners, p)
						table.insert(names, p.DisplayName)
					end
				end
				for _, b in bots do
					if teamOf[b] == winner then
						table.insert(botWinners, "🤖 " .. b.name)
						table.insert(names, "🤖 " .. b.name)
					end
				end
				for other in L.Runners do
					if other.Parent then
						tell(other, "👥 Team " .. table.concat(names, " & ") .. " wins!")
					end
				end
				break
			end
		end
		if L.ShowdownAt == 0 and not lateOpen() and (if duos then teamsLeft == 2 else active == 2) and (starters >= 3 or gridPhase() >= CFG.ShowdownFromPhase) then
			L.ShowdownAt = now()
			local names = {}
			for p, r in L.Runners do
				if r.alive and not r.crowned and p:GetAttribute("ArenaMode") == "LavaRush" then
					table.insert(names, p.DisplayName)
				end
			end
			for _, b in bots do
				if b.alive then
					table.insert(names, "🤖 " .. b.name)
				end
			end
			for _, p in Players:GetPlayers() do
				event:FireClient(p, "LavaFX", { Kind = "Showdown", Names = names })
			end
			broadcast()
		end
		if not duos and starters >= 2 and active == 1 and botsUp == 0 and lastActive and not lateOpen() and next(L.Queue) == nil then
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
	resetBomb()
	if now() >= L.EndsAt - 0.1 then
		local winners = {}
		for p, r in L.Runners do
			if p.Parent and r.alive and not r.crowned and p:GetAttribute("ArenaMode") == "LavaRush" then
				crownPlayer(p, r)
				table.insert(winners, p.DisplayName)
				table.insert(roundWinners, p)
			end
		end
		for _, b in bots do
			if b.alive and not table.find(botWinners, "🤖 " .. b.name) then
				table.insert(botWinners, "🤖 " .. b.name)
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
		for _, n in botWinners do
			table.insert(names, n)
		end
		-- Adaptive bots (CFG.BotEase): clumsier after each bot win in a row, sharper again when a real player wins.
		-- Published as the workspace attribute LavaBotEase so it can be checked in Studio.
		if #roundWinners > 0 then
			L.BotEase = math.max(0, L.BotEase - CFG.BotEase * 2)
		elseif #botWinners > 0 then
			L.BotEase = math.min(CFG.BotEaseMax, L.BotEase + CFG.BotEase)
		end
		workspace:SetAttribute("LavaBotEase", L.BotEase)
		-- Round awards: a shout-out for what players did, so those who didn't win still get named on the banner.
		-- Real players only, one award each, only for something they actually did, and only with 2+ players.
		-- No coins: it's recognition, not a reward, so there's nothing to farm.
		local awards = {}
		local climbers = 0
		for p in L.Runners do
			if p.Parent then
				climbers += 1
			end
		end
		if climbers >= 2 then
			local given: { [Player]: boolean } = {}
			local function award(icon: string, title: string, score: (Runner) -> number)
				local top: Player?, topScore = nil, 0
				for p, r in L.Runners do
					if p.Parent and not given[p] then
						local s = score(r)
						if s > topScore or (s > 0 and s == topScore and top and p.UserId < top.UserId) then
							top, topScore = p, s
						end
					end
				end
				if top then
					given[top] = true
					table.insert(awards, { Icon = icon, Title = title, Name = top.DisplayName })
				end
			end
			award("🧗", "Top Climber", function(r)
				return if r.crowned then 0 else math.floor(r.peak)
			end)
			award("💪", "Shove Champ", function(r)
				return r.shoves
			end)
			award("🍓", "Berry Picker", function(r)
				return r.picked
			end)
			award("🍍", "Fruit Grabber", function(r)
				return r.drops
			end)
		end
		for _, p in Players:GetPlayers() do
			event:FireClient(p, "LavaWinners", { Names = names, Positions = positions, Awards = awards })
		end
		for p, pick in L.Predictions do
			local d = data(p)
			if p.Parent and d then
				if table.find(names, pick) then
					d.Coins = math.min(100000000, d.Coins + CFG.PredictCoins)
					pushStats(p)
					logCoins(p, "Gameplay", CFG.PredictCoins, "Prediction")
					event:FireClient(p, "LavaFX", { Kind = "Invite", Text = "🔮 You called it!", Coins = CFG.PredictCoins })
					tell(p, "🔮 You called it! " .. pick .. " won: +" .. CFG.PredictCoins .. " coins")
				else
					tell(p, "🔮 Not this time: " .. pick .. " didn't win. Try again next round!")
				end
			end
		end
		table.clear(L.Predictions)
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
		local wasVoted = votedNext ~= nil
		L.Mutator = if votedNext then votedNext else pickMutator(L.Mutator)
		votedNext = nil
		local forcedTwist = if Run:IsStudio() then workspace:GetAttribute("StudioForceMutator") else nil
		for _, m in MUTATORS do
			if m.Id == forcedTwist then
				L.Mutator = m
			end
		end
		L.Phase = "Countdown"
		L.EndsAt = now() + CFG.Countdown
		local theme = Themes.Pick(L.Theme)
		publishEvent()
		local season = activeEvent()
		if season and season.Theme and Themes.ById[season.Theme] and math.random() < 0.5 then
			theme = Themes.ById[season.Theme]
		end
		local forcedTheme = if Run:IsStudio() then workspace:GetAttribute("StudioForceTheme") else nil
		if type(forcedTheme) == "string" and Themes.ById[forcedTheme] then
			theme = Themes.ById[forcedTheme]
		end
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
			if wasVoted then
				votedNext = L.Mutator -- nobody was ready this time: keep the voted twist for the next round that starts
			end
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
		do
			local pool = {}
			for _, m in MUTATORS do
				if m.Id ~= L.Mutator.Id then
					table.insert(pool, m)
				end
			end
			local options = {}
			while #options < CFG.VoteOptions and #pool > 0 do
				table.insert(options, table.remove(pool, math.random(#pool)))
			end
			local v: Vote = { options = options, votes = {}, endsAt = now() + CFG.VoteTime }
			vote = v
			local payload = { Options = {}, EndsAt = v.endsAt }
			for _, m in options do
				table.insert(payload.Options, { Id = m.Id, Name = m.Name })
			end
			event:FireAllClients("LavaVote", payload)
		end
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
		local v = vote
		if v then
			while now() < v.endsAt do
				task.wait(0.2)
			end
			local counts = voteCounts(v)
			local best, bestCount = {}, -1
			for _, m in v.options do
				local c = counts[m.Id]
				if c > bestCount then
					best, bestCount = { m }, c
				elseif c == bestCount then
					table.insert(best, m)
				end
			end
			votedNext = if #best > 0 then best[math.random(#best)] else nil
			vote = nil
			event:FireAllClients("LavaVoteResult", { Id = votedNext and votedNext.Id, Name = votedNext and votedNext.Name, Votes = bestCount })
			if votedNext then
				for _, p in Players:GetPlayers() do
					tell(p, "🗳️ Next twist: " .. votedNext.Name .. (if bestCount > 0 then " (" .. bestCount .. " vote" .. (if bestCount == 1 then "" else "s") .. ")" else ""))
				end
			end
		end
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
	local terrainOnly = RaycastParams.new()
	terrainOnly.FilterType = Enum.RaycastFilterType.Include
	terrainOnly.FilterDescendantsInstances = { workspace.Terrain }
	if scene then
		for _, d in scene:GetChildren() do
			if d:IsA("BasePart") and (d.Name == "EmberPool" or d.Name == "LavaRiver") then
				-- Sit lava on the island's surface; drop pieces that would be in the sea (coves) or deep in a hill.
				local hit = workspace:Raycast(Vector3.new(d.Position.X, 150, d.Position.Z), Vector3.new(0, -220, 0), terrainOnly)
				if not hit or hit.Material == Enum.Material.Water or hit.Position.Y > d.Position.Y + 6 then
					d:Destroy()
				else
					d.CFrame += Vector3.new(0, hit.Position.Y + 0.25 - d.Position.Y, 0)
				end
			end
		end
	end
end

-- Public

function L.HandleAction(p: Player, action: unknown, _value: unknown): boolean
	if action == "LavaJoin" then
		p:SetAttribute("LavaAway", nil)
		toggleJoin(p)
		return true
	end
	-- Away: after CFG.AwayAfter seconds with no input the client asks to sit the player out of the automatic rounds,
	-- so nobody is dropped in to fall off while they're gone. Never mid-climb, and never over a player's own choice
	-- to sit out. Their first input afterwards sends "LavaBack" and puts them back in the queue.
	if action == "LavaAway" then
		local r = L.Runners[p]
		if GameConfig.PartyMode and not (r and r.alive) and not p:GetAttribute("LavaOptOut") then
			L.Queue[p] = nil
			p:SetAttribute("LavaOptOut", true)
			p:SetAttribute("LavaAway", true)
			tell(p, "💤 You've been away, so you're sitting out. Move to jump back in!")
			logEvent(p, "Away", "Benched")
			personal(p)
			broadcast()
		end
		return true
	end
	if action == "LavaBack" then
		if p:GetAttribute("LavaAway") then
			p:SetAttribute("LavaAway", nil)
			p:SetAttribute("LavaOptOut", nil)
			tell(p, "🔥 Welcome back! You're in the next round.")
			personal(p)
			broadcast()
		end
		return true
	end
	if action == "RedeemCode" then
		local d = data(p)
		local code = if type(_value) == "string" then string.upper((string.gsub(_value, "%s", ""))) else ""
		if not d or #code == 0 or #code > 20 then
			return true
		end
		local info = CFG.Codes[code]
		d.Redeemed = d.Redeemed or {}
		if not info or (info.Until and os.time() > info.Until) then
			tell(p, "❌ That code doesn't work. Check the spelling!")
		elseif d.Redeemed[code] then
			tell(p, "✅ You already used " .. code .. ".")
		else
			d.Redeemed[code] = true
			d.Coins = math.min(100000000, d.Coins + info.Coins)
			logCoins(p, "Code", info.Coins, code)
			pushStats(p)
			event:FireClient(p, "LavaFX", { Kind = "Invite", Text = "🎁 Code " .. code, Coins = info.Coins })
			tell(p, "🎁 Code " .. code .. " redeemed: +" .. info.Coins .. " coins!")
		end
		return true
	end
	if action == "LavaCheer" then
		-- Only players who are out can cheer, only during a round, one of the preset emoji, and not too often.
		local r = L.Runners[p]
		local stillIn = r ~= nil and r.alive and not r.crowned and p:GetAttribute("ArenaMode") == "LavaRush"
		local i = tonumber(_value)
		local emoji = if i and i % 1 == 0 then CFG.Cheers[i] else nil
		if L.Phase == "Round" and not stillIn and emoji and now() >= (L.LastCheer[p] or 0) + CFG.CheerCooldown then
			L.LastCheer[p] = now()
			for _, other in Players:GetPlayers() do
				event:FireClient(other, "LavaCheer", { Name = p.DisplayName, Emoji = emoji })
			end
		end
		return true
	end
	if action == "LavaPredict" then
		local r = L.Runners[p]
		local stillIn = r ~= nil and r.alive and not r.crowned and p:GetAttribute("ArenaMode") == "LavaRush"
		if L.Phase == "Round" and not stillIn and not L.Predictions[p] and type(_value) == "string" then
			local names = aliveBotNames()
			for other, o in L.Runners do
				if o.alive and not o.crowned and other.Parent and other:GetAttribute("ArenaMode") == "LavaRush" then
					table.insert(names, other.DisplayName)
				end
			end
			if #names >= 2 and table.find(names, _value) then
				L.Predictions[p] = _value
				logEvent(p, "Prediction", if string.sub(_value, 1, 4) == "🤖" then "Bot" else "Player")
				tell(p, "🔮 You picked " .. _value .. ". +" .. CFG.PredictCoins .. " coins if they win!")
			end
		end
		return true
	end
	if action == "LavaVote" then
		local v = vote
		if v and now() < v.endsAt and type(_value) == "string" then
			for _, m in v.options do
				if m.Id == _value then
					v.votes[p] = m.Id
					logEvent(p, "TwistVote", m.Id)
					event:FireAllClients("LavaVoteCounts", voteCounts(v))
					break
				end
			end
		end
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
	workspace:SetAttribute("LavaAwayAfter", CFG.AwayAfter)
	workspace:SetAttribute("LavaGoal", 0)
	workspace:SetAttribute("LavaGoalSize", CFG.GoalRises)
	publishEvent()
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
		-- Sea limit: anyone who swims (or falls) too far from the island is brought back to the lobby.
		task.spawn(function()
			while true do
				task.wait(1)
				for _, p in Players:GetPlayers() do
					local me = root(p)
					if me and p:GetAttribute("ArenaMode") ~= "LavaRush" then
						local flat = Vector3.new(me.Position.X - CFG.Center.X, 0, me.Position.Z - CFG.Center.Z).Magnitude
						if flat > CFG.SeaLimit or me.Position.Y < -40 then
							me.AssemblyLinearVelocity = Vector3.zero
							placeAtBeacon(p)
							tell(p, "🌊 Too far out to sea! Back to the lobby.")
						end
					end
				end
			end
		end)
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
					p:SetAttribute("FriendBoost", true)
					o:SetAttribute("FriendBoost", true)
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
		task.defer(function()
			for _, o in Players:GetPlayers() do
				o:SetAttribute("FriendBoost", hasFriendHere(o))
			end
		end)
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

	-- Friend deal. Roblox fills Player:GetJoinData().ReferredByPlayerId when someone joins from an invite (the server
	-- reads it, so clients can't fake it). The new player gets a one-time welcome gift; the inviter gets coins once
	-- per new player, capped per day, and only for accounts a few days old so alt accounts can't farm it. If the
	-- inviter isn't in this server the reward waits in a small DataStore queue until they next join.
	local deal = GameConfig.FriendDeal
	local inviteStore = if Run:IsStudio() then nil else game:GetService("DataStoreService"):GetDataStore("LavaFloorsInvites")
	local function today(): number
		return math.floor(os.time() / 86400)
	end
	local function waitData(p: Player): any
		for _ = 1, 40 do
			local d = data(p)
			if d or not p.Parent then
				return d
			end
			task.wait(0.5)
		end
		return nil
	end
	local function coinFX(p: Player, text: string, amount: number)
		event:FireClient(p, "LavaFX", { Kind = "Invite", Text = text, Coins = amount })
	end
	local function rewardInviter(inviter: Player, inviteeId: number, inviteeName: string)
		local d = data(inviter)
		if not d or table.find(d.Invited, inviteeId) then
			return
		end
		table.insert(d.Invited, inviteeId)
		if #d.Invited > 200 then
			table.remove(d.Invited, 1)
		end
		if d.InviteDay ~= today() then
			d.InviteDay, d.InviteToday = today(), 0
		end
		if d.InviteToday >= deal.DailyCap then
			tell(inviter, "👥 " .. inviteeName .. " joined from your invite! (You've had today's " .. deal.DailyCap .. " invite rewards.)")
			return
		end
		d.InviteToday += 1
		d.Coins = math.min(100000000, d.Coins + deal.InviteCoins)
		logCoins(inviter, "Gameplay", deal.InviteCoins, "InviteReward")
		pushStats(inviter)
		coinFX(inviter, "👥 " .. inviteeName .. " joined!", deal.InviteCoins)
		tell(inviter, "🎉 " .. inviteeName .. " joined from your invite! +" .. deal.InviteCoins .. " coins")
	end
	local function setBoost(p: Player)
		if p.Parent then
			p:SetAttribute("FriendBoost", hasFriendHere(p))
		end
	end
	local function link(a: Player, b: Player)
		friends[a] = friends[a] or {}
		friends[b] = friends[b] or {}
		friends[a][b.UserId] = true
		friends[b][a.UserId] = true
		setBoost(a)
		setBoost(b)
	end
	local function claimQueued(p: Player)
		if not inviteStore then
			return
		end
		local queued = nil
		pcall(function()
			inviteStore:UpdateAsync("i_" .. p.UserId, function(old)
				queued = old
				return if type(old) == "table" and #old > 0 then {} else nil
			end)
		end)
		if type(queued) == "table" then
			for _, entry in queued do
				if type(entry) == "table" and type(entry.Id) == "number" then
					rewardInviter(p, entry.Id, tostring(entry.Name or "A friend"))
				end
			end
		end
	end
	local function checkReferral(p: Player)
		local d = waitData(p)
		if not d then
			return
		end
		claimQueued(p)
		-- The referral can take a moment to show up after joining.
		local referrer = 0
		for _ = 1, 10 do
			local ok, join = pcall(function()
				return p:GetJoinData()
			end)
			local id = if ok and type(join) == "table" then tonumber(join.ReferredByPlayerId) else nil
			if Run:IsStudio() then
				id = tonumber(workspace:GetAttribute("StudioFakeReferrer")) or id
			end
			if id and id ~= 0 then
				referrer = id
				break
			end
			if not p.Parent then
				return
			end
			task.wait(1)
		end
		if referrer == 0 or referrer == p.UserId then
			return
		end
		local inviter = Players:GetPlayerByUserId(referrer)
		if not d.WelcomeClaimed then
			d.WelcomeClaimed = true
			d.Coins = math.min(100000000, d.Coins + deal.WelcomeCoins)
			logCoins(p, "Onboarding", deal.WelcomeCoins, "WelcomeGift")
			pushStats(p)
			coinFX(p, "🎁 Welcome gift!", deal.WelcomeCoins)
			tell(p, "🎁 You joined from " .. (if inviter then inviter.DisplayName .. "'s" else "a friend's") .. " invite: +" .. deal.WelcomeCoins .. " coins!")
		end
		if inviter then
			link(inviter, p) -- you count as friends for the play-together bonus, even if you aren't Roblox friends yet
			tell(p, "👥 Play with " .. inviter.DisplayName .. " for +" .. math.floor(deal.Bonus * 100) .. "% coins every round!")
		end
		if p.AccountAge < deal.MinAccountAgeDays and not Run:IsStudio() then
			return
		end
		if inviter then
			rewardInviter(inviter, p.UserId, p.DisplayName)
		elseif inviteStore then
			pcall(function()
				inviteStore:UpdateAsync("i_" .. referrer, function(old)
					local list = if type(old) == "table" then old else {}
					for _, entry in list do
						if type(entry) == "table" and entry.Id == p.UserId then
							return nil
						end
					end
					if #list >= 50 then
						return nil
					end
					table.insert(list, { Id = p.UserId, Name = p.DisplayName })
					return list
				end)
			end)
		end
	end
	local function titleWatch(p: Player)
		p:GetAttributeChangedSignal("Crowns"):Connect(function()
			applyTitle(p)
		end)
		p.CharacterAdded:Connect(function(character)
			character:WaitForChild("Head", 10)
			task.wait(0.5)
			applyTitle(p)
		end)
		applyTitle(p)
	end
	Players.PlayerAdded:Connect(titleWatch)
	for _, p in Players:GetPlayers() do
		titleWatch(p)
	end
	Players.PlayerAdded:Connect(function(p)
		task.spawn(checkReferral, p)
		task.spawn(function()
			local d = waitData(p)
			if d then
				pushChallenges(p)
				p:SetAttribute("Tutorial", d.TutorialDone ~= true) -- first-round coach cards for new players
				p:SetAttribute("BestHeight", tonumber(d.BestHeight) or 0) -- the 🏅 marker on the climb meter
				logOnboarding(p, 1, "Joined")
			end
		end)
	end)
	for _, p in Players:GetPlayers() do
		task.spawn(function()
			local d = waitData(p)
			if d then
				pushChallenges(p)
				p:SetAttribute("Tutorial", d.TutorialDone ~= true)
				p:SetAttribute("BestHeight", tonumber(d.BestHeight) or 0)
			end
		end)
	end
	for _, p in Players:GetPlayers() do
		task.spawn(checkReferral, p)
	end
	task.spawn(loop)
	print("Lava Rush ready — floor-is-lava rounds on floor 1.")
end

return L
