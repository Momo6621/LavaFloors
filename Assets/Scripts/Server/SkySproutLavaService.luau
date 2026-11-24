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
local applyPet: (Player) -> ()
local applyTitle: (Player) -> ()
local wear: { [number]: number } = {}
local decaying: { [number]: boolean } = {} -- tiles crumbling on their own (#136)
local nextDecay = 0
local tileColour: (any, number, boolean) -> Color3

local CFG = {
	-- Arena
	Floor = 1,
	-- The play arena floats 100 studs above the crater (#137, owner's request), with a rocky underside (added when
	-- Y > 20). Everything in the arena is built from this centre.
	Center = Vector3.new(-250, 100, 300),
	-- The hub plaza (#138, owner's request): on a floating deck above and beside the island (175 studs out, y 200, over
	-- the floor's highest phase), so people waiting look down on the climbers through a force field. Players spawn
	-- and come back here. (#137 had it on the ground at -130.7, 0, 209; before that beside the arena at -200.7, 262.4.)
	Beacon = Vector3.new(-110.9, 200, 193.9),
	DeckRadius = 74, -- the hub deck: everything around the plaza (Warm-up Hop, boards, lanterns) fits within ~63 studs
	TryOnSeconds = 30, -- try-on mirror (#140): how long a tried-on glove, hat or buddy stays on
	-- Compass-rose floor on the hub deck (#155): glowing rings (radii from the plaza centre), stone spokes (every
	-- 360/Spokes degrees, alternating long and short) and diamonds where the long spokes cross the rings.
	DeckRings = { 22, 36, 50, 64 },
	DeckSpokes = 16,
	-- Gateway arch on the island side of the deck (#156): studs from the plaza centre, half the opening, pillar height.
	DeckArch = { Distance = 46, HalfWidth = 11, Height = 15 },
	ChampionDistance = 22, -- champion podium (#161): studs behind the plaza centre, away from the island (the mirror is at 36)
	-- Bounce pads on the hub deck (#142): { studs sideways from the plaza (away from the Warm-up Hop), studs toward the
	-- island, launch speed (about speed^2 / 392 studs high: 75 -> 14, 90 -> 21, 105 -> 28), colour }.
	BouncePads = {
		{ 28, 8, 75, Color3.fromRGB(255, 110, 190) },
		{ 34, -4, 90, Color3.fromRGB(90, 230, 210) },
		{ 26, -15, 105, Color3.fromRGB(255, 215, 80) },
	},
	MinPlayers = 1,
	Countdown = 4,
	ResultsTime = 3,
	VoteTime = 7, -- vote for the next twist, counted from when results show
	VoteOptions = 3,
	SurpriseChance = 0.5, -- chance the last vote slot is 🎲 Surprise! (a secret twist not on the ballot, #112)

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
	SlowMoPhaseTime = 13, -- 🐢 Slow-Mo twist: each phase lasts this long, so the whole floor moves 1.3x slower (#103)
	FastForwardPhaseTime = 8, -- ⏩ Fast-Forward twist: shorter phases, the whole floor moves 1.25x faster (#107)
	StartDelay = 3,
	GridSpins = { 90, -135, 180 },
	GridGrow = { 2, 0, 0 }, -- 5x5 grows to 9x9 in phase 1
	GridShrink = { 0, 2, 1 }, -- back to 5x5 in phase 2, a 3x3 finale in phase 3
	GridDrops = { 4, 3, 2 },
	PillarHeight = 16, -- the basalt pillar on the centre tile that blocks the view across the grid
	PillarLedges = 4, -- stepping ledges spiralling up the pillar to a strawberry on top
	PillarLedgeStep = 3.65, -- height between ledges: a round jump reaches ~5.8, and this leaves ~1 stud to spare
	-- clearing the next ledge's edge while moving (4.5 was tested and left too little); the cap is 2.2 above the last
	RoundJumpPower = 48,
	CharacterScale = 0.62,
	-- Fruit buddy (pet): size and place beside the shoulder, in studs for a full-size character (scaled with it).
	PetSize = 1.5,
	BuddyFindCoins = 40, -- bonus rounds: grabbing a lost theme buddy you already own pays this instead (#97)
	PetOffset = Vector3.new(2, 1.5, 0.8),
	RoundWalkSpeed = 24,
	SpeedRushWalkSpeed = 30,
	BouncyJumpPower = 58, -- 🦘 Bouncy twist: everyone's round jump (about 8.6 studs instead of 5.9; #99)
	BigHeadScale = 1.75, -- Big Heads twist: head size multiplier (just a look; bodies, speed and jumps stay the same)

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
	-- Theme bot names (#118): in a themed world the bots are named to match; Sunset uses BotNames.
	BotNamesByTheme = {
		BlueInferno = { "Frosty", "Blizzard", "Glacier", "Sapphire", "Icicle", "Splash" },
		PurpleMoon = { "Luna", "Gloom", "Shadow", "Twilight", "Echo", "Violet" },
		StarryNight = { "Comet", "Nova", "Twinkle", "Orbit", "Stardust", "Meteor" },
		Candy = { "Gumdrop", "Sprinkles", "Taffy", "Jellybean", "Lolly", "Fudge" },
		JadeJungle = { "Fern", "Moss", "Gecko", "Kiwi", "Lily", "Sprout" }, -- #157
	} :: { [string]: { string } },

	-- Anti-cheat: a climber who jumps more than TeleportJump studs in one tick can't grab pickups for a second,
	-- and one who isn't over the grid for OffGridLimit seconds (hovering/flying) is scorched.
	TeleportJump = 12,
	OffGridLimit = 4,
	-- "Why you fell": a shove, blast or tile change counts as the cause if it happened this many seconds before the fall.
	ReasonWindow = 3,

	-- Pick the winner: knocked-out players guess who wins (free, no stake) for a small coin reward.
	PredictCoins = 15,
	-- Personal best: climbing higher than ever before pays a small bonus, so even a lost round can be progress.
	BestCoins = 10,
	-- Cheers: knocked-out players tap a preset emoji (no typing) that floats up on everyone's screen.
	Cheers = { "🔥", "👏", "😂", "😱", "💪", "🎉" },
	CheerCooldown = 1.2,
	GiftBerries = 1, -- strawberries a knocked-out player can send the climber they're watching, once a round
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
	-- Lobby gems: glowing lava crystals hidden around the plaza, crater and island for waiting players to hunt. Each
	-- pays GemCoins once per account; the last one pays GemAllCoins on top. Gem centres, fixed to the current layout
	-- (the first sits over the Warm-up Hop goal, so move it if the hop moves).
	Gems = {
		Vector3.new(-236.5, 10.8, 215.5), -- over the Warm-up Hop goal
		Vector3.new(-217, 3.8, 256.6), -- behind the Top Climbers board
		Vector3.new(-106, 4.8, 115.5), -- under a palm on the island's south side
		Vector3.new(-16.5, 4.8, 330), -- at the foot of a palm out on the island (clears the tall grass)
		Vector3.new(51, 4.6, 264), -- by a palm on the east beach
	},
	GemCoins = 25,
	GemAllCoins = 100,
	GemRadius = 5, -- studs from your root to the gem centre
	-- Backdrop volcano models (Creator Store) ship heavy emitters: one far cone ran 500 fire particles a second. They
	-- sit 400+ studs away, mostly behind the crater wall, so each emitter is capped at this many live particles
	-- (rate x lifetime) to spare low-end phones.
	BackdropParticleCap = 120,
	-- Away: seconds without any input before a player sits out the automatic rounds (published as the workspace
	-- attribute LavaAwayAfter for the client). Any input brings them back.
	AwayAfter = 120,
	-- Loaded first: a new player joins the automatic rounds only once their client says the game has loaded
	-- ("LavaReady"), or after ReadyWait seconds if that never arrives, so a slow phone isn't dropped into a round
	-- (and its first-round bubble) while it's still on the loading screen.
	ReadyWait = 20,
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
	FrenzyShoveCooldown = 0.4, -- 🎯 Shove Frenzy twist: everyone can shove twice as often (#102)
	ShoveSpeed = 66,
	ShoveLift = 18,
	MegaShove = 1.6, -- Mega Shoves twist: shoves fly this much further (bots slide one tile further)
	ShoveMax = 110, -- top horizontal shove speed; the client drops anything over 120 as a bad value
	BlockedNoticeGap = 6, -- seconds between "bubble shield blocked your shove" notices for the same shover and target
	JoinGrace = 2, -- seconds nobody can shove a climber who just landed on the grid (joined late or was rescued)

	-- Rewards. Scaled to 0.7x when rounds went from 7 phases to 3: a round cycle is now ~44 s instead of ~63 s, so
	-- this keeps coins per minute where they were (it was 3 / 0.15 / 20 / 60).
	EmberCoins = 4, -- per strawberry banked (was 2 when there were 6 easy ones in the middle)
	CoinsPerStud = 0.105,
	SurviveCoins = 14,
	CrownCoins = 42,
	FirstCrownCoins = 50, -- once a day (UTC), your first crown pays this on top, the same for everyone (#101)
	EscapePartyMin = 3, -- 🤝 Escape party (#113): this many players crowned in one round...
	EscapePartyCoins = 15, -- ...each get this flat bonus on top
	-- Round milestones (#124): lifetime rounds played -> a thank-you gift, flat and the same for everyone.
	RoundMilestones = { [10] = 25, [25] = 50, [50] = 75, [100] = 100, [250] = 150, [500] = 200, [1000] = 300 } :: { [number]: number },
	XPPerCoin = 2,
	FriendBonus = (GameConfig.FriendDeal and GameConfig.FriendDeal.Bonus) or 0.25,
	FriendSpawnGap = 5, -- joining a friend in the lobby puts you this many studs beside them
	FunAskAfter = 3, -- once a session, after this many finished rounds, ask "Having fun?" (analytics FunRating)

	-- Strawberries: few, and only on the outer ring that grows in during phase 1 and drops away in phase 2, so grabbing
	-- one means running to the edge and getting back in time (risk / reward). Plus the one on top of the pillar.
	Berries = 2, -- owner: scarcer (was 4)

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
	DropEvery = 20, -- was 14: about two fruit drops a round instead of three
	-- Bonus rounds (owner, 2026-11-23): every world theme except Sunset drops fruit this often, about 3-4 a round.
	ThemeDropEvery = 12,
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

	-- The emote your avatar plays when you win a round (picked in the 😀 Emotes panel, saved with your profile).
	WinEmotes = { "Wave", "Cheer", "Laugh", "Point", "Dance", "Groove", "Shuffle", "Clap", "Happy", "Bop" },

	-- Titles shown over your head. Crown titles unlock with total crowns; the others with another achievement (Need).
	-- Players pick which unlocked title to show (the 🏷️ button in the Challenges panel); "Auto" shows the best crown
	-- title, as before.
	Titles = {
		{ Id = "Walker", Crowns = 1, Text = "🔥 Lava Walker", Color = Color3.fromRGB(255, 170, 90) },
		{ Id = "Climber", Crowns = 5, Text = "🌋 Crater Climber", Color = Color3.fromRGB(255, 120, 60) },
		{ Id = "King", Crowns = 15, Text = "👑 Volcano King", Color = Color3.fromRGB(255, 215, 80) },
		{ Id = "Legend", Crowns = 40, Text = "💎 Magma Legend", Color = Color3.fromRGB(120, 220, 255) },
		{ Id = "Eternal", Crowns = 100, Text = "⭐ Eternal Flame", Color = Color3.fromRGB(255, 240, 160) },
		{ Id = "Gems", Need = "Gems", Text = "🔶 Gem Hunter", Color = Color3.fromRGB(255, 150, 60) },
		{ Id = "Chests", Need = "Chests", Text = "🎁 Chest Cracker", Color = Color3.fromRGB(255, 200, 90) },
		{ Id = "Kind", Need = "Gifts", Text = "🍓 Kind Climber", Color = Color3.fromRGB(255, 130, 160) },
		{ Id = "Buddies", Need = "Buddies", Text = "🐾 Buddy Collector", Color = Color3.fromRGB(175, 115, 255) }, -- every theme buddy found (#98)
		{ Id = "Twists", Need = "Twists", Text = "🌀 Twist Tamer", Color = Color3.fromRGB(120, 220, 160) }, -- crowned in TitleTwists different twists (#105)
		{ Id = "Team", Need = "Parties", Text = "🤝 Team Player", Color = Color3.fromRGB(110, 200, 255) }, -- in TitleParties escape parties (#114)
		{ Id = "Traveler", Need = "Worlds", Text = "🌍 World Traveler", Color = Color3.fromRGB(90, 220, 190) }, -- played in every world theme (#123)
	},
	TitleTwists = 5, -- different twists you've been crowned in, for 🌀 Twist Tamer
	TitleParties = 3, -- 🤝 Escape parties you were part of, for 🤝 Team Player
	TitleChests = 5, -- Lava Chests opened for 🎁 Chest Cracker (Gem Hunter needs every lava gem)
	TitleGifts = 5, -- strawberry gifts sent for 🍓 Kind Climber

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
		{ Id = "Buddy", Text = "Grab %d lost buddy", Goal = 1, Reward = 60 }, -- the theme buddy in a bonus round (#98)
		{ Id = "Cheer", Text = "Cheer %d times from the sidelines", Goal = 3, Reward = 30 }, -- (#109)
		{ Id = "Gift", Text = "Send %d strawberry gift", Goal = 1, Reward = 40 }, -- (#109)
		{ Id = "Shield", Text = "Grab %d shield orbs", Goal = 2, Reward = 50 }, -- (#109)
		{ Id = "TwistSurvive", Text = "Survive %d twist rounds", Goal = 2, Reward = 60 }, -- any twist but Classic (#116)
		{ Id = "Vote", Text = "Vote for the next twist %d times", Goal = 3, Reward = 20 }, -- once per ballot (#116)
		{ Id = "Knockouts", Text = "Knock %d climbers off the floor", Goal = 2, Reward = 50 }, -- bots count too (#119)
		{ Id = "Worlds", Text = "Play in %d different worlds", Goal = 3, Reward = 40 }, -- world themes played today (#120)
	},

	-- Keep moving
	CampTime = 4,
	CampRespawn = 6,
	QuickCrumble = 0.6, -- Quick Crumble twist: tiles wear out in this share of CampTime, so keep moving
	-- Random decay (#136, owner's request): every DecayEvery seconds of a round some random solid tiles start to
	-- crack (the same darken/crack/shake warning as standing still) and crumble after DecayWarn, then come back after
	-- CampRespawn. Phase n decays n tiles at a time, at most DecayMax at once, from DecayGrace seconds in.
	DecayEvery = 3,
	DecayWarn = 2.5,
	DecayMax = 4,
	DecayGrace = 4,

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
	{ Id = "BigHeads", Name = "🎈 Big Heads", Weight = 2 },
	{ Id = "MegaShove", Name = "💥 Mega Shoves", Weight = 2 },
	{ Id = "QuickCrumble", Name = "⚡ Quick Crumble", Weight = 1 },
	{ Id = "Bouncy", Name = "🦘 Bouncy", Weight = 2 }, -- everyone jumps higher (CFG.BouncyJumpPower, #99)
	{ Id = "ShoveFrenzy", Name = "🎯 Shove Frenzy", Weight = 2 }, -- shove cooldown halved (CFG.FrenzyShoveCooldown, #102)
	{ Id = "SlowMo", Name = "🐢 Slow-Mo", Weight = 2 }, -- longer phases, a gentler round (CFG.SlowMoPhaseTime, #103)
	{ Id = "FastForward", Name = "⏩ Fast-Forward", Weight = 1 }, -- shorter phases, a harder round (CFG.FastForwardPhaseTime, #107)
	{ Id = "Magnet", Name = "🧲 Magnet Hands", Weight = 2 }, -- shoves pull the other climber toward you instead (#115)
}
-- Twist vote: when a round ends everyone gets a few twists to pick from; the most votes wins (ties and no votes are
-- settled at random among the options).
type Vote = { options: { Mutator }, votes: { [Player]: string }, endsAt: number }
local vote: Vote? = nil
local votedNext: Mutator? = nil
-- 🎲 Surprise! (#112): a vote-only option. If it wins, the next twist is drawn from the ones that weren't on the
-- ballot and stays secret until the countdown.
local SURPRISE: Mutator = { Id = "Surprise", Name = "🎲 Surprise!", Weight = 0 }
local surpriseNext = false

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
	-- What last happened to this climber, for the "why you fell" line (knockoutReason).
	shovedBy: string?,
	shovedByPlayer: Player?, -- who to credit for the "Knockouts" challenge (#119)
	shovedAt: number?,
	blastAt: number?,
	lastRow: number?,
	lastCol: number?,
	lastTileAt: number?,
	bubble: string?, -- "FirstRound" or "Underdog" if a catch-up bubble started this round (CatchUpBubble analytics)
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
	Gifted = {} :: { [Player]: boolean }, -- players who already sent their strawberry gift this round
	SessionRounds = setmetatable({}, { __mode = "k" }) :: any, -- [Player] = rounds finished this session
	Streak = setmetatable({}, { __mode = "k" }) :: any, -- [Player] = rounds survived in a row this session
	FunAsked = setmetatable({}, { __mode = "k" }) :: any, -- [Player] = twist Id while "Having fun?" is open, true once answered
	LastCheer = setmetatable({}, { __mode = "k" }) :: any, -- [Player] = time of their last cheer (rate limit)
	LossStreak = setmetatable({}, { __mode = "k" }) :: any, -- [Player] = rounds in a row knocked out (this server)
	BotEase = 0, -- extra bot mistake chance after bot wins in a row (see CFG.BotEase)
	Goal = 0, -- rises climbed toward the server goal (CFG.GoalRises)
	GoalHelpers = setmetatable({}, { __mode = "k" }) :: any, -- [Player] = true if they climbed since the last goal
	JoinedAt = setmetatable({}, { __mode = "k" }) :: any, -- [Player] = os.clock() when they joined (LoadTime analytics)
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

-- All-time Top Winners (#149, owner's request): every player's total crowns (rounds won) in one ordered data store,
-- shown on a board on the hub deck. Studio has no data store access here, so the board falls back to this server.
local allTime: any = { Top = {}, Written = setmetatable({}, { __mode = "k" }), Store = nil }
if not Run:IsStudio() then
	pcall(function()
		allTime.Store = game:GetService("DataStoreService"):GetOrderedDataStore("LavaAllTimeCrowns_v1")
	end)
end
allTime.Write = function(p: Player, crowns: number)
	local store = allTime.Store
	if not store or crowns <= 0 then
		return
	end
	allTime.Written[p] = crowns
	task.spawn(function()
		pcall(function()
			(store :: OrderedDataStore):SetAsync(tostring(p.UserId), crowns)
		end)
	end)
end
-- The all-time champion (#161): the stored top entry merged with the players here now, or nil before anyone has won.
allTime.Champion = function(): { Id: number, Name: string, Crowns: number }?
	local best: { Id: number, Name: string, Crowns: number }? = nil
	local function consider(id: number, name: string, crowns: number)
		if crowns > 0 and (not best or crowns > best.Crowns) then
			best = { Id = id, Name = name, Crowns = crowns }
		end
	end
	for _, e in allTime.Top do
		consider(e.Id, e.Name, e.Crowns)
	end
	for _, p in Players:GetPlayers() do
		local d = data(p)
		consider(p.UserId, p.DisplayName, d and tonumber(d.Crowns) or 0)
	end
	return best
end
task.spawn(function()
	while true do
		local store = allTime.Store
		if store then
			-- Crowns won before this board existed count too: written the first time a player is seen here.
			for _, p in Players:GetPlayers() do
				local d = data(p)
				local crowns = d and tonumber(d.Crowns) or 0
				if crowns > 0 and allTime.Written[p] == nil then
					allTime.Write(p, crowns)
				end
			end
			local ok, page = pcall(function()
				return (store :: OrderedDataStore):GetSortedAsync(false, 5):GetCurrentPage()
			end)
			if ok and type(page) == "table" then
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
						table.insert(rows, { Id = id, Name = name, Crowns = tonumber(entry.value) or 0 })
					end
				end
				allTime.Top = rows
			end
		end
		task.wait(60)
	end
end)

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
				-- Lava Pass XP for each challenge (#121), so the daily goals also move the pass along.
				local passXP = if A and A.Season and GameConfig.LavaPass then tonumber(GameConfig.LavaPass.XP.Challenge) or 0 else 0
				tell(p, "📋 Challenge complete: " .. string.format(c.Text, c.Goal) .. "! +" .. c.Reward .. " coins" .. (if passXP > 0 then " · +" .. passXP .. " pass XP" else ""))
				if passXP > 0 then
					A.Season.AddXP(p, passXP)
				end
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
	-- Hub deck (#138): when the plaza floats, a round stone deck carries it, with a rocky underside and a glowing force
	-- field all round the edge: you can watch the island below but not jump in or fall off. Lava-coloured, so the
	-- theme pass recolours the force field like the rest of the arena.
	if plazaPos.Y > 20 then
		local deck = Instance.new("Model")
		deck.Name = "HubDeck"
		deck.Parent = arenaFolder
		local R = CFG.DeckRadius
		local slab = part(deck, "DeckFloor", Vector3.new(4, R * 2, R * 2), CFrame.new(plazaPos - Vector3.new(0, 2, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(78, 64, 60), Enum.Material.Slate)
		slab.Shape = Enum.PartType.Cylinder
		local drng = Random.new(138)
		for i = 1, 5 do
			local f = i / 5
			local radius = R * (1 - f) ^ 1.1 + 5
			local rock = part(deck, "DeckUnderside", Vector3.new(9, radius * 2, radius * 2), CFrame.new(plazaPos - Vector3.new(0, 4 + i * 8, 0) + Vector3.new(drng:NextNumber(-3, 3), 0, drng:NextNumber(-3, 3)) * f) * CFrame.Angles(0, drng:NextNumber(0, math.pi), math.rad(90)), Color3.fromRGB(60, 46, 46):Lerp(Color3.fromRGB(38, 28, 30), f), Enum.Material.Basalt)
			rock.Shape = Enum.PartType.Cylinder
			rock.CanCollide, rock.CanQuery, rock.CanTouch = false, false, false
		end
		local SEGMENTS = 40
		for k = 1, SEGMENTS do
			local a = k / SEGMENTS * math.pi * 2
			local out = Vector3.new(math.cos(a), 0, math.sin(a))
			local at = plazaPos + out * R + Vector3.new(0, 6, 0)
			local wall = part(deck, "ForceField", Vector3.new(2 * math.pi * R / SEGMENTS + 0.4, 12, 0.6), CFrame.lookAt(at, at + out), Color3.fromRGB(255, 120, 40), Enum.Material.ForceField)
			wall.Transparency = 0.3
			wall.CastShadow = false
			local rail = part(deck, "ForceFieldRail", Vector3.new(2 * math.pi * R / SEGMENTS + 0.4, 0.35, 0.35), CFrame.lookAt(at + Vector3.new(0, 6, 0), at + out + Vector3.new(0, 6, 0)), Color3.fromRGB(255, 150, 60), Enum.Material.Neon)
			rail.CanCollide, rail.CanQuery, rail.CanTouch, rail.CastShadow = false, false, false, false
		end
		-- Compass-rose floor (#155): concentric glowing rings in the lava colour (so they follow the theme like the force
		-- field), stone spokes and diamonds, all inlaid flush in the deck and walk-through.
		do
			local floorY = plazaPos.Y + 0.06
			local function inlay(name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material): Part
				local piece = part(deck, name, size, cf, color, material)
				piece.CanCollide, piece.CanQuery, piece.CanTouch, piece.CastShadow = false, false, false, false
				return piece
			end
			local function at(angle: number, radius: number): Vector3
				return Vector3.new(plazaPos.X + math.cos(angle) * radius, floorY, plazaPos.Z + math.sin(angle) * radius)
			end
			for _, radius in CFG.DeckRings do
				local pieces = math.max(24, math.floor(radius * 0.9))
				for k = 1, pieces do
					local a0, a1 = (k - 1) / pieces * math.pi * 2, k / pieces * math.pi * 2
					local p0, p1 = at(a0, radius), at(a1, radius)
					local ring = inlay("DeckRing", Vector3.new(0.7, 0.12, (p1 - p0).Magnitude + 0.15), CFrame.lookAt((p0 + p1) / 2, p1), Color3.fromRGB(255, 120, 40), Enum.Material.Neon)
					ring.Transparency = 0.25
				end
			end
			local last = CFG.DeckRings[#CFG.DeckRings]
			for k = 0, CFG.DeckSpokes - 1 do
				local a = k / CFG.DeckSpokes * math.pi * 2
				local long = k % 2 == 0
				local r0, r1 = 16, if long then last else CFG.DeckRings[#CFG.DeckRings - 1]
				local p0, p1 = at(a, r0), at(a, r1)
				inlay("DeckSpoke", Vector3.new(if long then 1.1 else 0.7, 0.1, (p1 - p0).Magnitude), CFrame.lookAt((p0 + p1) / 2, p1), Color3.fromRGB(122, 102, 94), Enum.Material.Marble)
				if long then
					for _, radius in CFG.DeckRings do
						local d = inlay("DeckDiamond", Vector3.new(1.8, 0.14, 1.8), CFrame.new(at(a, radius)) * CFrame.Angles(0, a + math.rad(45), 0), Color3.fromRGB(255, 120, 40), Enum.Material.Neon)
						d.Transparency = 0.1
					end
				end
			end
		end
		-- Colonnade (#159): a slender column with a glowing orb wherever a long spoke meets the outer ring, skipping any
		-- spot within a few studs of a lava gem (they sit on the deck's edge) or the Warm-up Hop's goal.
		do
			local toTower = (Vector3.new(c.X, 0, c.Z) - Vector3.new(plazaPos.X, 0, plazaPos.Z)).Unit
			local side = Vector3.new(-toTower.Z, 0, toTower.X)
			local radius = CFG.DeckRings[#CFG.DeckRings]
			local keepClear = { plazaPos + side * (CFG.HopFrom + 37) } -- the hop's goal pad
			for _, deg in { 140, 195, 250 } do -- the three edge gems (buildGems)
				local g = math.rad(deg)
				table.insert(keepClear, plazaPos + (toTower * math.cos(g) + side * math.sin(g)) * (CFG.DeckRadius - 8))
			end
			for k = 0, CFG.DeckSpokes - 1, 2 do
				local a = k / CFG.DeckSpokes * math.pi * 2
				local foot = Vector3.new(plazaPos.X + math.cos(a) * radius, plazaPos.Y, plazaPos.Z + math.sin(a) * radius)
				local clear = true
				for _, spot in keepClear do
					if (Vector3.new(spot.X, 0, spot.Z) - Vector3.new(foot.X, 0, foot.Z)).Magnitude < 8 then
						clear = false
					end
				end
				if clear then
					part(deck, "ColumnBase", Vector3.new(3, 0.8, 3), CFrame.new(foot + Vector3.new(0, 0.4, 0)) * CFrame.Angles(0, a, 0), Color3.fromRGB(70, 56, 54), Enum.Material.Basalt)
					part(deck, "Column", Vector3.new(1.6, 9, 1.6), CFrame.new(foot + Vector3.new(0, 5.3, 0)) * CFrame.Angles(0, a, 0), Color3.fromRGB(78, 64, 60), Enum.Material.Basalt)
					local cap = part(deck, "ColumnCap", Vector3.new(2.4, 0.5, 2.4), CFrame.new(foot + Vector3.new(0, 10, 0)) * CFrame.Angles(0, a + math.rad(45), 0), Color3.fromRGB(255, 120, 40), Enum.Material.Neon)
					cap.CanCollide, cap.CanQuery, cap.CanTouch = false, false, false
					local orb = part(deck, "ColumnOrb", Vector3.new(1.8, 1.8, 1.8), CFrame.new(foot + Vector3.new(0, 11.4, 0)), Color3.fromRGB(255, 120, 40), Enum.Material.Neon)
					orb.Shape = Enum.PartType.Ball
					orb.CanCollide, orb.CanQuery, orb.CanTouch, orb.CastShadow = false, false, false, false
					local light = Instance.new("PointLight")
					light.Range = 14
					light.Brightness = 1.2
					light.Color = Color3.fromRGB(255, 150, 80)
					light.Parent = orb
				end
			end
		end
		-- Gateway arch (#156): two stone pillars and a half-round arch of wedge stones with a glowing keystone and trim,
		-- standing between the plaza and the force field on the island side, so the walk to the edge frames the island.
		do
			local toward = (Vector3.new(c.X, 0, c.Z) - Vector3.new(plazaPos.X, 0, plazaPos.Z)).Unit
			local across = Vector3.new(-toward.Z, 0, toward.X)
			local arch = CFG.DeckArch
			local base = plazaPos + toward * arch.Distance
			local face = CFrame.lookAt(Vector3.zero, toward).Rotation -- arch faces the island
			local STONE, TRIM = Color3.fromRGB(70, 56, 54), Color3.fromRGB(255, 120, 40)
			for _, sideSign in { -1, 1 } do
				local foot = base + across * (sideSign * (arch.HalfWidth + 1.5))
				part(deck, "ArchPlinth", Vector3.new(5, 1.2, 5), CFrame.new(foot + Vector3.new(0, 0.6, 0)) * face, STONE, Enum.Material.Basalt)
				part(deck, "ArchPillar", Vector3.new(3, arch.Height, 3), CFrame.new(foot + Vector3.new(0, 1.2 + arch.Height / 2, 0)) * face, STONE, Enum.Material.Basalt)
				local trim = part(deck, "ArchTrim", Vector3.new(3.3, 0.4, 3.3), CFrame.new(foot + Vector3.new(0, 1.2 + arch.Height, 0)) * face, TRIM, Enum.Material.Neon)
				trim.CanCollide, trim.CanQuery, trim.CanTouch = false, false, false
			end
			-- The arch: wedge stones on a half circle over the opening, centred at the top of the pillars.
			local centre = base + Vector3.new(0, 1.2 + arch.Height, 0)
			local radius = arch.HalfWidth + 1.5
			local STONES = 13
			for k = 0, STONES - 1 do
				local a0, a1 = k / STONES * math.pi, (k + 1) / STONES * math.pi
				local p0 = centre + across * (math.cos(a0) * radius) + Vector3.new(0, math.sin(a0) * radius, 0)
				local p1 = centre + across * (math.cos(a1) * radius) + Vector3.new(0, math.sin(a1) * radius, 0)
				local mid = (p0 + p1) / 2
				local cf = CFrame.lookAt(mid, mid + toward, (mid - centre).Unit)
				local keystone = k == (STONES - 1) / 2
				local stone = part(deck, if keystone then "ArchKeystone" else "ArchStone", Vector3.new((p1 - p0).Magnitude + 0.1, if keystone then 3.6 else 3, 3), cf, if keystone then TRIM else STONE, if keystone then Enum.Material.Neon else Enum.Material.Basalt)
				stone.CanCollide = false
				-- A thin glowing line along the arch's inner edge.
				local inner = part(deck, "ArchGlow", Vector3.new((p1 - p0).Magnitude * (radius - 1.6) / radius + 0.1, 0.25, 3.1), cf * CFrame.new(0, -1.6, 0), TRIM, Enum.Material.Neon)
				inner.CanCollide, inner.CanQuery, inner.CanTouch, inner.CastShadow = false, false, false, false
			end
		end
		-- Champion podium (#161): three stepped discs behind the plaza with a gold statue of the all-time top
		-- winner (their own avatar, cast in gold) and a sign with their name. Rebuilt when the top spot changes.
		do
			local toward = (Vector3.new(c.X, 0, c.Z) - Vector3.new(plazaPos.X, 0, plazaPos.Z)).Unit
			local at = plazaPos - toward * CFG.ChampionDistance
			local GOLD, STONE = Color3.fromRGB(255, 200, 70), Color3.fromRGB(70, 56, 54)
			local top = at
			for tier = 1, 3 do -- three stepped discs, the top one gold
				local width, height = 11 - tier * 2.5, 0.8
				local disc = part(deck, "ChampionTier", Vector3.new(height, width, width), CFrame.new(top + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)), if tier == 3 then GOLD else STONE, if tier == 3 then Enum.Material.Foil else Enum.Material.Basalt)
				disc.Shape = Enum.PartType.Cylinder
				if tier == 3 then
					disc:SetAttribute("NoTheme", true) -- gold stays gold in every world
				end
				top += Vector3.new(0, height, 0)
			end
			local trim = part(deck, "ChampionGlow", Vector3.new(0.2, 8.8, 8.8), CFrame.new(at + Vector3.new(0, 0.85, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(255, 120, 40), Enum.Material.Neon)
			trim.Shape = Enum.PartType.Cylinder
			trim.CanCollide, trim.CanQuery, trim.CanTouch = false, false, false
			-- The sign floats over the statue, facing the plaza.
			local signPart = part(deck, "ChampionSign", Vector3.new(8, 2, 0.2), CFrame.lookAt(top + Vector3.new(0, 8.5, 0), Vector3.new(plazaPos.X, top.Y + 8.5, plazaPos.Z)), Color3.new(0, 0, 0), Enum.Material.SmoothPlastic)
			signPart.Transparency = 1
			signPart.CanCollide, signPart.CanQuery, signPart.CanTouch = false, false, false
			local gui = Instance.new("SurfaceGui")
			gui.Face = Enum.NormalId.Front
			gui.PixelsPerStud = 40
			gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			gui.LightInfluence = 0
			gui.Parent = signPart
			local label = Instance.new("TextLabel")
			label.BackgroundTransparency = 1
			label.Size = UDim2.fromScale(1, 1)
			label.Font = Enum.Font.LuckiestGuy
			label.TextScaled = true
			label.TextColor3 = Color3.fromRGB(255, 220, 120)
			label.TextStrokeTransparency = 0
			label.Text = "🏆 Win rounds to stand here!"
			label.Parent = gui
			local shownId: number? = nil
			local statue: Model? = nil
			task.spawn(function()
				while deck.Parent do
					local champ = allTime.Champion()
					if champ then
						label.Text = string.format("🏆 CHAMPION: %s · %d wins", champ.Name, champ.Crowns)
						if champ.Id ~= shownId then
							shownId = champ.Id
							local ok, model = pcall(function()
								local desc = Players:GetHumanoidDescriptionFromUserId(champ.Id)
								return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
							end)
							if ok and model then
								if statue then
									statue:Destroy()
								end
								model.Name = "ChampionStatue"
								local hum = model:FindFirstChildOfClass("Humanoid")
								if hum then
									hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
								end
								for _, d in model:GetDescendants() do
									if d:IsA("BasePart") then
										d.Anchored = true
										d.CanCollide = false
										d.CanTouch = false
										d.Material = Enum.Material.Foil
										d.Color = GOLD
										d:SetAttribute("NoTheme", true) -- the theme pass turned it lime in Jade Jungle
										if d:IsA("MeshPart") then
											d.TextureID = ""
										end
									elseif d:IsA("SpecialMesh") then
										d.TextureId = "" -- accessory meshes keep their shape but turn gold too
									elseif d:IsA("Decal") or d:IsA("Texture") or d:IsA("Clothing") or d:IsA("ShirtGraphic") or d:IsA("Script") or d:IsA("LocalScript") then
										d:Destroy() -- clothing and faces would show through the gold (#162)
									end
								end
								local _, size = model:GetBoundingBox()
								model:PivotTo(CFrame.lookAt(top + Vector3.new(0, size.Y / 2, 0), Vector3.new(plazaPos.X, top.Y + size.Y / 2, plazaPos.Z)))
								model.Parent = deck
								statue = model
							end
						end
					end
					task.wait(30)
				end
			end)
		end
		-- Try-on mirror (#140, owner's request): a stage behind the plaza (away from the island) with a tall framed
		-- mirror. Standing on it shows TRY buttons in the shop and turns your camera to look out of the mirror at you.
		local toIsland = (Vector3.new(c.X, 0, c.Z) - Vector3.new(plazaPos.X, 0, plazaPos.Z)).Unit
		local stageAt = plazaPos - toIsland * 36
		local stage = part(deck, "MirrorStage", Vector3.new(0.8, 16, 16), CFrame.new(stageAt + Vector3.new(0, 0.4, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(120, 200, 255), Enum.Material.Glass)
		stage.Shape = Enum.PartType.Cylinder
		stage:SetAttribute("NoTheme", true)
		local mirrorAt = stageAt - toIsland * 10 + Vector3.new(0, 8.5, 0)
		local facing = CFrame.lookAt(mirrorAt, Vector3.new(stageAt.X, mirrorAt.Y, stageAt.Z))
		local glass = part(deck, "Mirror", Vector3.new(12, 15, 0.4), facing, Color3.fromRGB(200, 230, 255), Enum.Material.Glass)
		glass.Reflectance = 0.45
		glass.Transparency = 0.1
		glass:SetAttribute("NoTheme", true)
		for _, bar in { { 0, 7.8, 13, 0.8 }, { 0, -7.8, 13, 0.8 }, { 6.3, 0, 0.8, 16.4 }, { -6.3, 0, 0.8, 16.4 } } do
			local frame = part(deck, "MirrorFrame", Vector3.new(bar[3], bar[4], 0.9), facing * CFrame.new(bar[1], bar[2], 0), Color3.fromRGB(255, 200, 70), Enum.Material.Foil)
			frame:SetAttribute("NoTheme", true)
		end
		local sign = Instance.new("SurfaceGui")
		sign.Face = Enum.NormalId.Front
		sign.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		sign.PixelsPerStud = 40
		local text = Instance.new("TextLabel")
		text.BackgroundTransparency = 1
		text.Size = UDim2.new(1, 0, 0.16, 0)
		text.Font = Enum.Font.LuckiestGuy
		text.TextScaled = true
		text.TextColor3 = Color3.fromRGB(255, 220, 120)
		text.TextStrokeTransparency = 0
		text.Text = "\u{2728} TRY-ON MIRROR \u{2728}"
		text.Parent = sign
		sign.Parent = glass
		workspace:SetAttribute("MirrorStage", stageAt)
		-- The mirror's point of view for the client camera: just in front of the glass, looking at someone on the stage.
		workspace:SetAttribute("MirrorView", CFrame.lookAt(mirrorAt - Vector3.new(0, 3, 0) + toIsland * 1, Vector3.new(stageAt.X, stageAt.Y + 3.5, stageAt.Z)))
		-- Bounce pads (#142): three springy pads on the empty side of the deck (the Warm-up Hop is on the other side),
		-- something to play with between rounds. Each pad's "Bounce" is the launch speed; LavaFloorsUI does the bounce
		-- on the client, which owns its character. Just for fun: no coins, no score.
		local across = Vector3.new(-toIsland.Z, 0, toIsland.X)
		for i, pad in CFG.BouncePads do
			local at = plazaPos - across * pad[1] + toIsland * pad[2]
			local colour = pad[4]
			local base = part(deck, "BounceBase", Vector3.new(1, 9, 9), CFrame.new(at + Vector3.new(0, 0.5, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(70, 56, 54), Enum.Material.Basalt)
			base.Shape = Enum.PartType.Cylinder
			base:SetAttribute("NoTheme", true)
			local top = part(deck, "BouncePad", Vector3.new(0.5, 7.5, 7.5), CFrame.new(at + Vector3.new(0, 1.2, 0)) * CFrame.Angles(0, 0, math.rad(90)), colour, Enum.Material.Neon)
			top.Shape = Enum.PartType.Cylinder
			top:SetAttribute("NoTheme", true)
			top:SetAttribute("Bounce", pad[3])
			top:SetAttribute("BounceIndex", i)
			game:GetService("CollectionService"):AddTag(top, "LavaBounce")
		end
	end
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
		-- live: the round screen (#144) floats 9 studs higher over the walkway, faces the plaza and refreshes every second.
		local function board(name: string, offset: number, title: string, titleColor: Color3, fill: () -> { string }, live: boolean?)
			local at = plazaPos + toward * 10 + side * offset + Vector3.new(0, if live then 14.5 else 5.5, 0)
			local facing = if live then plazaPos else spawnAt
			local slab = part(arenaFolder, name, Vector3.new(13, 8.5, 0.8), CFrame.lookAt(at, Vector3.new(facing.X, at.Y, facing.Z)), Color3.fromRGB(48, 36, 36), Enum.Material.Basalt)
			if not live then
				local post = part(arenaFolder, name .. "Post", Vector3.new(0.8, 1.5, 0.8), CFrame.new(at.X, plazaPos.Y + 0.75, at.Z), Color3.fromRGB(40, 30, 30), Enum.Material.Basalt)
				post.CanCollide = false
			end
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
					task.wait(if live then 1 else 4)
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
		-- Live round screen (#144, the hub watches the game): who is still climbing and how many rises up, so the
		-- deck can follow the round below. Real players only by name; bots are counted on the last line.
		-- Between rounds (#145) it counts down the next round with its twist, and keeps the last round's standings up.
		local lastRound: { string }? = nil
		board("LiveRound", 0, "🔴 LIVE ROUND", Color3.fromRGB(230, 50, 40), function()
			if L.Phase == "Countdown" then
				return { string.format("Next round in %d...", math.max(1, math.ceil(L.EndsAt - now()))), "Twist: " .. tostring(L.Mutator.Name), "", "Look down through the force field", "to watch the climbers!" }
			end
			if L.Phase == "Idle" or next(L.Runners) == nil then
				if lastRound then
					return { "Last round:", lastRound[1] or "", lastRound[2] or "", lastRound[3] or "", "Next round soon!" }
				end
				return { "Waiting for the next round...", "", "Look down through the force field", "to watch the climbers!" }
			end
			local climbers = {}
			for p, r in L.Runners do
				local rises = math.clamp(math.floor((r.peak - 3 - CFG.GridBaseY) / CFG.GridRise + 0.5), 0, #CFG.GridSpins)
				table.insert(climbers, { Name = p.DisplayName, Rises = rises, Crowned = r.crowned, Alive = r.alive })
			end
			table.sort(climbers, function(a, b)
				if a.Crowned ~= b.Crowned then
					return a.Crowned
				end
				if a.Alive ~= b.Alive then
					return a.Alive
				end
				if a.Rises ~= b.Rises then
					return a.Rises > b.Rises
				end
				return a.Name < b.Name
			end)
			local rows = {}
			for i = 1, math.min(4, #climbers) do
				local e = climbers[i]
				local mark = if e.Crowned then "👑" elseif e.Alive then "⬆ " .. e.Rises else "💥 out"
				table.insert(rows, string.format("%s  %s", e.Name, mark))
			end
			if L.Phase == "Results" then
				-- When no player was crowned, the bots still standing won (#150): name them on the last line.
				local anyCrowned = climbers[1] ~= nil and climbers[1].Crowned
				local botsWon = if anyCrowned then {} else aliveBotNames()
				if #botsWon > 0 then
					rows[4] = string.format("👑 %s won!", table.concat(botsWon, ", ", 1, math.min(2, #botsWon)))
				end
				lastRound = rows
				return { "Round over!", rows[1] or "", rows[2] or "", rows[3] or "", rows[4] or "" }
			end
			local botsIn = #aliveBotNames()
			-- The round's twist rides on the last line (#151), so the deck knows why the floor is acting up.
			local twist = tostring(L.Mutator.Name)
			-- Time left in front (#152): surviving until it runs out is how a round is won.
			local left = string.format("⏱ %ds", math.max(0, math.ceil(L.EndsAt - now())))
			rows[5] = if botsIn > 0 then string.format("%s · 🤖 %d bot%s · %s", left, botsIn, if botsIn == 1 then "" else "s", twist) else left .. " · " .. twist
			return rows
		end, true)
		-- All-time Top Winners (#149): raised like the live screen, to its left, over Top Supporters.
		board("AllTimeWinners", -14, "🏆 ALL-TIME WINNERS", Color3.fromRGB(245, 170, 20), function()
			local best: { [number]: { Name: string, Crowns: number } } = {}
			for _, e in allTime.Top do
				best[e.Id] = { Name = e.Name, Crowns = e.Crowns }
			end
			for _, p in Players:GetPlayers() do
				local d = data(p)
				local crowns = d and tonumber(d.Crowns) or 0
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
			for i = 1, math.min(5, #ranked) do
				table.insert(rows, string.format("%d. %s  🏆 %d", i, ranked[i].Name, ranked[i].Crowns))
			end
			if #rows == 0 then
				rows[1] = "Win a round to get on the board!"
			end
			return rows
		end, true)
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
	-- Floating island underside (#137, owner's request): when the arena floats (CFG.Center above the ground), a jagged
	-- rock cone hangs under it with glowing lava cracks, so the hub below looks up at an island, not a flat disc.
	-- Decoration only; the theme pass recolours the rock and the lava glow like the rest of the arena.
	if c.Y > 20 then
		local under = Instance.new("Model")
		under.Name = "IslandUnderside"
		under.Parent = arenaFolder
		local urng = Random.new(137)
		local function decor(piece: BasePart)
			piece.CanCollide = false
			piece.CanQuery = false
			piece.CanTouch = false
		end
		-- TOP reaches past the spire ring (64-90 studs out); the cone starts just under the arena floor, so the rising
		-- lava never shows through the rock.
		local LAYERS, DEPTH, TOP = 8, 90, 100
		local THICK = DEPTH / LAYERS + 3
		for i = 0, LAYERS - 1 do
			local f = i / (LAYERS - 1)
			local radius = TOP * (1 - f) ^ 1.15 + 6
			local drift = Vector3.new(urng:NextNumber(-4, 4), 0, urng:NextNumber(-4, 4)) * f
			local slab = part(under, "UndersideRock", Vector3.new(THICK, radius * 2, radius * 2), CFrame.new(c + drift - Vector3.new(0, 0.2 + THICK / 2 + f * DEPTH, 0)) * CFrame.Angles(0, urng:NextNumber(0, math.pi), math.rad(90)), Color3.fromRGB(64, 48, 46):Lerp(Color3.fromRGB(38, 28, 30), f), Enum.Material.Basalt)
			slab.Shape = Enum.PartType.Cylinder
			decor(slab)
		end
		for k = 1, 16 do
			local a = (k + urng:NextNumber(-0.3, 0.3)) / 16 * math.pi * 2
			local r = urng:NextNumber(50, 96)
			local h = urng:NextNumber(14, 34)
			local drop = (1 - r / TOP) * 40 + urng:NextNumber(2, 10)
			local rock = part(under, "UndersideRock", Vector3.new(urng:NextNumber(9, 18), h, urng:NextNumber(9, 18)), CFrame.new(c + Vector3.new(math.cos(a) * r, -drop - h / 2, math.sin(a) * r)) * CFrame.Angles(urng:NextNumber(-0.3, 0.3), urng:NextNumber(0, math.pi), urng:NextNumber(-0.3, 0.3)), Color3.fromRGB(58, 44, 44), Enum.Material.Basalt)
			decor(rock)
		end
		for k = 1, 12 do
			local a = urng:NextNumber(0, math.pi * 2)
			local f = urng:NextNumber(0.1, 0.75)
			local r = (TOP * (1 - f) ^ 1.15 + 6) + 0.3
			local crack = part(under, "LavaCrack", Vector3.new(0.6, urng:NextNumber(10, 22), 1.4), CFrame.new(c + Vector3.new(math.cos(a) * r, -1 - f * DEPTH, math.sin(a) * r)) * CFrame.Angles(0, -a, urng:NextNumber(-0.5, 0.5)), Color3.fromRGB(255, 110, 30), Enum.Material.Neon)
			decor(crack)
		end
	end
	-- Game pillar (#139, owner's request): a pillar of light from the ground under the island up through its centre to
	-- the sky, shown while a round is on (setGamePillar) so the hub can see a game is taking place. Lava-coloured,
	-- so the theme pass gives it the round's world colour. Hidden (fully transparent) between rounds.
	do
		local HEIGHT = 700
		local mid = Vector3.new(c.X, 2 + HEIGHT / 2, c.Z)
		local core = part(arenaFolder, "GamePillarCore", Vector3.new(HEIGHT, 5, 5), CFrame.new(mid) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(255, 140, 50), Enum.Material.Neon)
		local glow = part(arenaFolder, "GamePillarGlow", Vector3.new(HEIGHT, 14, 14), CFrame.new(mid) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(255, 110, 30), Enum.Material.Neon)
		for _, piece in { core, glow } do
			piece.Shape = Enum.PartType.Cylinder
			piece.CanCollide, piece.CanQuery, piece.CanTouch, piece.CastShadow = false, false, false, false
			piece.Transparency = 1
		end
	end
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

local function makeEmber(parent: Instance, position: Vector3, stepIndex: number, edge: boolean?)
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
			if edge then
				r.edgePicked = (r.edgePicked or 0) + 1 -- risk/reward tuning: see the EdgeBerries analytics event
			end
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
		for _, d in m:GetDescendants() do
			if d:IsA("ParticleEmitter") and d.Rate * d.Lifetime.Max > CFG.BackdropParticleCap then
				d.Rate = CFG.BackdropParticleCap / d.Lifetime.Max
			end
		end
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

-- The bubble you can see; the protection itself is the runner's shieldUntil.
local function showBubble(character: Model, seconds: number)
	local old = character:FindFirstChild("LavaBubble")
	if old then
		old:Destroy()
	end
	local bubble = Instance.new("ForceField")
	bubble.Name = "LavaBubble"
	bubble.Visible = true
	bubble.Parent = character
	task.delay(seconds, function()
		if bubble.Parent then
			bubble:Destroy()
		end
	end)
end

local function grantShield(p: Player, character: Model, r: Runner, position: Vector3, seconds: number?, message: string?)
	local lasts = seconds or CFG.ShieldTime
	-- A shield never cuts a longer one short: a shield orb picked up inside a 15 s underdog or first-round bubble
	-- keeps the bubble (and says nothing, since nothing changed).
	if now() + lasts <= r.shieldUntil then
		if not character:FindFirstChild("LavaBubble") then
			showBubble(character, r.shieldUntil - now())
		end
		event:FireClient(p, "LavaFX", { Kind = "Shield", Position = position })
		return
	end
	r.shieldUntil = now() + lasts
	showBubble(character, lasts)
	event:FireClient(p, "LavaFX", { Kind = "Shield", Position = position })
	tell(p, message or ("🛡️ Bubble shield! Shoves can't move you for " .. lasts .. "s."))
end

local function baseWalkSpeed(): number
	return if L.Mutator.Id == "SpeedRush" then CFG.SpeedRushWalkSpeed else CFG.RoundWalkSpeed
end

local function baseJumpPower(): number
	return if L.Mutator.Id == "Bouncy" then CFG.BouncyJumpPower else CFG.RoundJumpPower
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
			challenge(p, "Shield", 1)
			if p.Character then
				grantShield(p, p.Character, r, at)
			end
		end,
	})
end

-- Theme buddies (GameConfig.Pets entries with FindIn): never sold, found in their world theme's rounds.
local function petDef(id: string): any?
	for _, h in GameConfig.Pets or {} do
		if h.Id == id then
			return h
		end
	end
	return nil
end

-- A buddy's glow: a soft light in its colour, plus flames or sparkles (def.Aura).
local function addAura(parent: BasePart, def: any?)
	if not def or not def.Aura then
		return
	end
	local light = Instance.new("PointLight")
	light.Color = def.Color
	light.Range = 6
	light.Brightness = 1.5
	light.Parent = parent
	if def.Aura == "Fire" then
		local fire = Instance.new("Fire")
		fire.Color = def.Color
		fire.SecondaryColor = Color3.fromRGB(200, 230, 255)
		fire.Size = 2
		fire.Heat = 4
		fire.Parent = parent
	elseif def.Aura == "Sparkles" then
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = def.Color
		sparkles.Parent = parent
	end
end

-- Bonus rounds (#97): in every world theme except Sunset, that theme's lost buddy floats on the floor in a bubble.
-- The first climber to grab it keeps it, and it starts following them; one they already own pays BuddyFindCoins.
local function makeBuddyFind(parent: Instance, position: Vector3, stepIndex: number, def: any)
	local holder = part(parent, "BuddyFind", Vector3.new(3.4, 3.4, 3.4), CFrame.new(position), def.Color, Enum.Material.SmoothPlastic)
	holder.Shape = Enum.PartType.Ball
	holder.Transparency = 1
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	local bubble = part(holder, "Bubble", Vector3.new(3.2, 3.2, 3.2), CFrame.new(position), def.Color, Enum.Material.ForceField)
	bubble.Shape = Enum.PartType.Ball
	bubble.CanCollide = false
	bubble.CanQuery = false
	bubble.CanTouch = false
	fruit(def.Model, 1.4, CFrame.new(position), holder)
	addAura(holder, def)
	ride(holder, stepIndex)
	table.insert(pickups, {
		item = holder,
		radius = 4,
		take = function(p: Player, _r: any)
			holder:Destroy()
			local d = data(p)
			if not d then
				return
			end
			d.OwnedPets = d.OwnedPets or {}
			challenge(p, "Buddy", 1)
			if d.OwnedPets[def.Id] then
				d.Coins = math.min(100000000, d.Coins + CFG.BuddyFindCoins)
				logCoins(p, "Gameplay", CFG.BuddyFindCoins, "BuddyFind")
				pushStats(p)
				tell(p, "🐾 Another " .. def.Name .. "! +" .. CFG.BuddyFindCoins .. " coins")
			else
				d.OwnedPets[def.Id] = true
				d.Pet = def.Id
				pushStats(p)
				applyPet(p)
				applyTitle(p) -- the last one unlocks 🐾 Buddy Collector
				tell(p, "🐾 You found the " .. def.Name .. "! It follows you now.")
				logEvent(p, "BuddyFound", def.Id)
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
local lastBoostId: string? = nil -- variety: the next drop is never the same fruit as the last one

local function pickBoost(): Boost
	if Run:IsStudio() then
		local forced = workspace:GetAttribute("StudioNextDrop")
		for _, b in BOOSTS do
			if b.Id == forced then
				workspace:SetAttribute("StudioNextDrop", nil)
				lastBoostId = b.Id
				return b
			end
		end
	end
	local total = 0
	for _, b in BOOSTS do
		if b.Id ~= lastBoostId then
			total += b.Weight
		end
	end
	local roll = math.random() * total
	for _, b in BOOSTS do
		if b.Id ~= lastBoostId then
			roll -= b.Weight
			if roll <= 0 then
				lastBoostId = b.Id
				return b
			end
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
		setJump(hum, math.max(CFG.JumpBoostPower, baseJumpPower() + 12)) -- still a boost in a Bouncy round
		local jumpUntil = r.jumpUntil
		hum:SetAttribute("LavaJumpUntil", jumpUntil)
		task.delay(CFG.JumpTime, function()
			if hum.Parent and hum:GetAttribute("LavaJumpUntil") == jumpUntil then
				hum:SetAttribute("LavaJumpUntil", nil)
				if p:GetAttribute("ArenaMode") == "LavaRush" then
					setJump(hum, baseJumpPower())
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
	-- The schedule (grid, round end, lava height) all follows this attribute, on the server and every client.
	model:SetAttribute(
		"PhaseTime",
		if L.Mutator.Id == "SlowMo" then CFG.SlowMoPhaseTime elseif L.Mutator.Id == "FastForward" then CFG.FastForwardPhaseTime else CFG.PhaseTime
	)
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
	table.clear(decaying)
	nextDecay = 0
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
			local ledge = part(pillar, "PillarLedge", Vector3.new(3.4, 1, 3.4), base * CFrame.Angles(0, math.rad(60 * (k - 1)), 0) * CFrame.new(5, k * CFG.PillarLedgeStep - 0.5, 0), Color3.fromRGB(160, 116, 84), Enum.Material.Slate) -- lighter than the column so the way up reads at a glance
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
	local edgeTiles = {}
	for index, tile in platforms do
		local row, col = tile:GetAttribute("Row"), tile:GetAttribute("Col")
		if Grid.Ring(size, row, col) > CFG.StartRings and not Grid.IsPillar(model, row, col) then
			table.insert(edgeTiles, index)
		end
	end
	local berryTiles = table.clone(if #edgeTiles > 0 then edgeTiles else startTiles) -- a grid that never grows keeps them inside
	for _ = 1, CFG.Berries do
		local pick = rng:NextInteger(1, #berryTiles)
		local index = table.remove(berryTiles, pick) :: number
		makeEmber(model, platforms[index].Position + Vector3.new(0, 2.6, 0), index, #edgeTiles > 0)
		if #berryTiles == 0 then
			break
		end
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
	-- Bonus rounds (#97): this theme's lost buddy waits out on the outer ring that grows in during phase 1, like the
	-- strawberries, so it's something you go and get rather than spawn on (none in Sunset).
	local findDef: any? = nil
	for _, h in GameConfig.Pets or {} do
		if h.FindIn == L.Theme then
			findDef = h
		end
	end
	if findDef then
		local spots = if #berryTiles > 0 then berryTiles else startTiles
		for _ = 1, 40 do
			local index = spots[rng:NextInteger(1, #spots)]
			if not special[index] then
				special[index] = true
				makeBuddyFind(model, platforms[index].Position + Vector3.new(0, 3.5, 0), index, findDef)
				break
			end
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

-- Big Heads twist: grow (or restore) an R15 head through the Humanoid's HeadScale, so hair and face scale with it.
-- The original value is kept on the Humanoid; fruit hats and the crown are welded to the head, so they are rebuilt
-- to sit on the new size.
local function setBigHead(p: Player, big: boolean)
	local character = p.Character
	local hum = character and character:FindFirstChildOfClass("Humanoid")
	local headScale = hum and hum:FindFirstChild("HeadScale")
	if not character or not hum or not headScale or not headScale:IsA("NumberValue") then
		return
	end
	local base = hum:GetAttribute("LavaBaseHead")
	if big and base == nil then
		hum:SetAttribute("LavaBaseHead", headScale.Value)
		headScale.Value *= CFG.BigHeadScale
	elseif not big and type(base) == "number" then
		headScale.Value = base
		hum:SetAttribute("LavaBaseHead", nil)
	else
		return
	end
	if character:FindFirstChild("FruitHat") then
		applyHat(p)
	end
	if character:FindFirstChild("LavaCrownHat") then
		giveCrownHat(p)
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
		setBigHead(p, false)
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
	local phaseTime = tower and tower:GetAttribute("PhaseTime")
	return L.Phase == "Round" and type(start) == "number" and now() < start + (if type(phaseTime) == "number" then phaseTime else CFG.PhaseTime)
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
		setJump(hum, baseJumpPower())
	end
	if L.Mutator.Id == "BigHeads" then
		setBigHead(p, true)
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
		edgePicked = if existing then existing.edgePicked else 0,
		enteredAt = now(),
		nextShove = 0,
		shieldUntil = if existing then existing.shieldUntil else 0,
		speedUntil = 0,
		jumpUntil = 0,
		rescue = if existing then existing.rescue else false,
		nextLift = if existing then existing.nextLift else 0,
		bubble = if existing then existing.bubble else nil,
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
	-- A brand-new player's first round starts in the same bubble, so nobody is shoved out before they've had a go
	-- (there are no tutorial tips any more; this teaches by play).
	local firstRound = p:GetAttribute("Tutorial") == true
	if runner and (firstRound or (L.LossStreak[p] or 0) >= CFG.UnderdogAfter) and now() >= runner.shieldUntil then
		local message = if firstRound
			then "🫧 First-round bubble! Shoves can't move you for " .. CFG.UnderdogShield .. "s."
			else "🫧 Underdog shield! Tough few rounds, so shoves can't move you for " .. CFG.UnderdogShield .. "s."
		grantShield(p, p.Character, runner, at, CFG.UnderdogShield, message)
		runner.bubble = if firstRound then "FirstRound" else "Underdog"
	elseif runner and now() < runner.shieldUntil and not p.Character:FindFirstChild("LavaBubble") then
		-- Dropped back in on a new character (after a reset) while a bubble is still running: show it again.
		showBubble(p.Character, runner.shieldUntil - now())
	end
	personal(p)
	return true
end

-- Why you fell, with a tip you can use next round: a knockout you understand teaches; an unexplained one just stings.
-- Checked from the most specific cause to the least: a blast, a shove, the tile you were last on, then the lava.
local function knockoutReason(r: Runner): string
	local t = now()
	if r.blastAt and t - r.blastAt < CFG.ReasonWindow + 1 then
		return "💣 The hot potato blew up on you. Pass it on quickly!"
	end
	if r.shovedAt and t - r.shovedAt < CFG.ReasonWindow then
		if L.Mutator.Id == "Magnet" then -- 🧲 Magnet Hands (#115): shoves pull, so say so (#127)
			return "🧲 " .. (r.shovedBy or "Someone") .. " pulled you off. Keep away from the edges!"
		end
		return "💥 " .. (r.shovedBy or "Someone") .. " shoved you off. Keep away from the edges!"
	end
	local grid = tower
	if grid and r.lastRow and r.lastCol and r.lastTileAt and t - r.lastTileAt < CFG.ReasonWindow then
		local index = (r.lastRow - 1) * CFG.GridSize + r.lastCol
		local tile = platforms[index]
		local campFall = tile and tile:GetAttribute("CampFall")
		if type(campFall) == "number" and t - campFall < CFG.ReasonWindow then
			if tile:GetAttribute("DecayFall") == campFall then
				return "🪨 That tile crumbled on its own. Hop off when a tile starts cracking!"
			end
			return "🪨 Your tile crumbled from standing still. Keep moving!"
		end
		local state = Grid.TileState(grid, r.lastRow, r.lastCol, t)
		if state == "Falling" or state == "Gone" or state == "Left" then
			if Grid.Plan(grid).drop[index] ~= nil and state ~= "Left" then
				return "🕳️ That tile dropped away. Step off red tiles in time!"
			end
			return "🧱 The edge was left behind. Move inward when the floor shrinks!"
		end
	end
	return "🌋 You slipped into the lava. Watch your step near the edges!"
end

local function scorch(p: Player, r: Runner)
	r.alive = false
	local lost = r.embers
	r.embers = 0
	event:FireClient(p, "LavaFX", { Kind = "Scorched" })
	tell(p, if lost > 0 then string.format("🔥 SCORCHED! You dropped %d ember%s.", lost, if lost == 1 then "" else "s") else "🔥 SCORCHED! Watch the lava…")
	tell(p, knockoutReason(r))
	-- Knockouts challenge (#119): credit whoever shoved this climber, if it was recent enough to be why they fell.
	local shover = r.shovedByPlayer
	if shover and shover ~= p and shover.Parent and r.shovedAt and now() - r.shovedAt < CFG.ReasonWindow then
		challenge(shover, "Knockouts", 1)
	end
	if p:GetAttribute("ArenaMode") == "LavaRush" then
		p:SetAttribute("ArenaMode", "Lobby")
		-- Back to lobby movement, as release() does at round end; a phase-1 drop-back sets round values again.
		local hum = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.WalkSpeed = GameConfig.WalkSpeed
			restoreJump(hum)
		end
		setBigHead(p, false)
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
-- Duos team names (#122), one per outline colour above: blue, pink, green, yellow, purple, orange.
local TEAM_NAMES = { "💧 Team Splash", "🌸 Team Blossom", "🐸 Team Froggy", "⚡ Team Zap", "🔮 Team Wizard", "🦊 Team Fox" }
local function teamName(team: number): string
	return TEAM_NAMES[(team - 1) % #TEAM_NAMES + 1]
end
local function sameTeam(a: any, b: any): boolean
	local ta, tb = teamOf[a], teamOf[b]
	return ta ~= nil and ta == tb
end

-- Set by the bots section: shoves a bot in front of the player if one is closer than maxDist.
local shoveNearestBot: (Player, Vector3, Vector3, number) -> boolean = function()
	return false
end

-- Shove impact: the shover gets the full hit (sound, burst, 💥 and a short camera kick on their client); everyone
-- else gets a lighter 💥 puff where it landed, so spectators can see who shoved whom.
local function shoveImpact(p: Player, victim: Player?, at: Vector3)
	event:FireClient(p, "LavaFX", { Kind = "Hit", Position = at })
	for _, other in Players:GetPlayers() do
		if other ~= p and other ~= victim then
			event:FireClient(other, "LavaFX", { Kind = "ShoveSeen", Position = at })
		end
	end
end

-- Fair starts: no shoves during the get-ready seconds before the floor moves (so nobody is out before the round
-- begins), and a climber who just landed on the grid can't be shoved for JoinGrace seconds. No notice for the first:
-- tips only come when you're knocked out.
local blockedTold: { [Player]: { [Player]: number } } = setmetatable({}, { __mode = "k" }) :: any -- shover -> target -> os.clock()
local function shove(p: Player)
	local r = L.Runners[p]
	local me = root(p)
	if not r or not r.alive or r.crowned or not me then
		return
	end
	local start = tower and tower:GetAttribute("Start")
	if type(start) == "number" and now() < start then
		return
	end
	local t = os.clock()
	if t < r.nextShove then
		return
	end
	r.nextShove = t + (if L.Mutator.Id == "ShoveFrenzy" then CFG.FrenzyShoveCooldown else CFG.ShoveCooldown)
	local best: Player? = nil
	local bestDist = CFG.ShoveRange
	for other, o in L.Runners do
		local them = root(other)
		if other ~= p and o.alive and not o.crowned and them and not sameTeam(p, other) and now() - o.enteredAt >= CFG.JoinGrace then
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
		-- The blue flash shows every time; the words at most every BlockedNoticeGap seconds per target, so shoving a
		-- shielded kid over and over doesn't flood the notices.
		local told = blockedTold[p] or setmetatable({}, { __mode = "k" }) :: any
		blockedTold[p] = told
		if os.clock() - (told[best] or -math.huge) >= CFG.BlockedNoticeGap then
			told[best] = os.clock()
			tell(p, "🛡️ " .. best.DisplayName .. "'s bubble shield blocked your shove!")
		end
		return
	end
	if best then
		local them = root(best) :: BasePart
		local dir = Vector3.new(them.Position.X - me.Position.X, 0, them.Position.Z - me.Position.Z)
		dir = if dir.Magnitude > 0.1 then dir.Unit else me.CFrame.LookVector
		local magnet = L.Mutator.Id == "Magnet"
		if magnet then
			dir = -dir -- 🧲 Magnet Hands: yank them toward you (and maybe right past you)
		end
		local power = (if L.ShowdownAt > 0 then CFG.ShowdownShove else 1) * (if L.Mutator.Id == "MegaShove" then CFG.MegaShove else 1)
		-- Capped at ShoveMax: the client ignores shoves over 120 studs/s (Mega Shoves in the showdown would pass it).
		local speed = math.min(CFG.ShoveSpeed * power, CFG.ShoveMax)
		event:FireClient(best, "LavaShove", dir * speed + Vector3.new(0, CFG.ShoveLift, 0))
		if target then
			target.shovedBy, target.shovedByPlayer, target.shovedAt = p.DisplayName, p, now()
		end
		shoveImpact(p, best, them.Position)
		tell(best, if magnet then "🧲 " .. p.DisplayName .. " pulled you!" else "💥 " .. p.DisplayName .. " shoved you!")
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
	if hum and holder and holder:GetAttribute("ArenaMode") == "LavaRush" then -- a knocked-out holder keeps lobby speed
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
	hr.blastAt = now()
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
	-- 🤝 Escape party (#113): when enough players escape together, each of them gets a small flat bonus.
	local escaped = 0
	for p, r in L.Runners do
		if r.crowned and p.Parent then
			escaped += 1
		end
	end
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
			-- Round milestones (#124): count every finished round, ever; some counts come with a thank-you gift.
			d.RoundsPlayed = (tonumber(d.RoundsPlayed) or 0) + 1
			local milestone = CFG.RoundMilestones[d.RoundsPlayed]
			if milestone then
				d.Coins = math.min(100000000, d.Coins + milestone)
				logCoins(p, "Gameplay", milestone, "RoundMilestone_" .. d.RoundsPlayed)
				tell(p, "🎉 That was your " .. d.RoundsPlayed .. "th round! Thanks for playing: +" .. milestone .. " coins")
			end
			-- Worlds challenge (#120): remember which world themes you've played in today (saved in Daily.W).
			local daily = dailyState(d)
			daily.W = daily.W or {}
			if not daily.W[L.Theme] then
				daily.W[L.Theme] = true
				challenge(p, "Worlds", 1)
			end
			-- 🌍 World Traveler (#123): every world theme you've ever played in; the last new one unlocks the title.
			d.WorldsSeen = d.WorldsSeen or {}
			if not d.WorldsSeen[L.Theme] then
				d.WorldsSeen[L.Theme] = true
				local seen = 0
				for _, theme in Themes.List do
					if d.WorldsSeen[theme.Id] then
						seen += 1
					end
				end
				if seen == #Themes.List then
					applyTitle(p)
					tell(p, "🏷️ New title: 🌍 World Traveler! Pick it with the 🏷️ button in 📋 Challenges.")
				end
			end
			if r.crowned or r.alive then
				challenge(p, "Survive", 1)
				if L.Mutator.Id ~= "Classic" then
					challenge(p, "TwistSurvive", 1)
				end
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
			-- 🌀 Twist Tamer (#105): remember each twist you've been crowned in; the TitleTwists-th unlocks the title.
			if r.crowned then
				d.TwistWins = d.TwistWins or {}
				if not d.TwistWins[L.Mutator.Id] then
					d.TwistWins[L.Mutator.Id] = true
					local won = 0
					for _ in d.TwistWins do
						won += 1
					end
					if won == CFG.TitleTwists then
						applyTitle(p)
						tell(p, "🏷️ New title: 🌀 Twist Tamer! Pick it with the 🏷️ button in 📋 Challenges.")
					end
				end
			end
			-- First crown of the day (#101): a flat bonus once per UTC day, added after the round multipliers.
			if r.crowned and d.FirstCrownDay ~= today() then
				d.FirstCrownDay = today()
				d.Coins = math.min(100000000, d.Coins + CFG.FirstCrownCoins)
				logCoins(p, "Gameplay", CFG.FirstCrownCoins, "FirstCrownToday")
				tell(p, "👑 First crown today! +" .. CFG.FirstCrownCoins .. " coins")
			end
			if r.crowned and escaped >= CFG.EscapePartyMin then
				d.Coins = math.min(100000000, d.Coins + CFG.EscapePartyCoins)
				logCoins(p, "Gameplay", CFG.EscapePartyCoins, "EscapeParty")
				tell(p, "🤝 Escape party! " .. escaped .. " climbers escaped together: +" .. CFG.EscapePartyCoins .. " coins")
				d.EscapeParties = (tonumber(d.EscapeParties) or 0) + 1
				if d.EscapeParties == CFG.TitleParties then
					applyTitle(p)
					tell(p, "🏷️ New title: 🤝 Team Player! Pick it with the 🏷️ button in 📋 Challenges.")
				end
			end
			-- Lava Chest progress (flat coins, the same for everyone, added after the round multipliers).
			local fill = CFG.ChestPlay + math.floor(math.clamp(r.peak / crownHeight, 0, 1) * CFG.ChestClimb)
				+ (if r.crowned then CFG.ChestCrown elseif r.alive then CFG.ChestSurvive else 0)
			local chestBefore = math.clamp(tonumber(d.Chest) or 0, 0, CFG.ChestGoal - 1)
			local chestAfter = chestBefore + fill
			local chestCoins = 0
			if chestAfter >= CFG.ChestGoal then
				chestAfter -= CFG.ChestGoal
				d.ChestsOpened = (tonumber(d.ChestsOpened) or 0) + 1
				if d.ChestsOpened == CFG.TitleChests then
					applyTitle(p)
					tell(p, "🏷️ New title: 🎁 Chest Cracker! Pick it with the 🏷️ button in 📋 Challenges.")
				end
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
			L.SessionRounds[p] = (L.SessionRounds[p] or 0) + 1
			-- Survival streak: rounds in a row you survived or escaped (this visit only; just for show, no coins).
			local streakWas = L.Streak[p] or 0
			L.Streak[p] = if r.crowned or r.alive then streakWas + 1 else 0
			local askFun = L.SessionRounds[p] == CFG.FunAskAfter and L.FunAsked[p] == nil
			if askFun then
				L.FunAsked[p] = L.Mutator.Id -- the twist this answer is about
			end
			-- Edge strawberries (risk/reward, CFG.Berries): how many this climber grabbed, split by how their round
			-- ended, so the owner can see in Analytics whether going for them is a fair gamble for kids.
			local outcome = if r.crowned then "Crowned" elseif r.alive then "Survived" else "Scorched"
			local edgePicked = r.edgePicked or 0
			track(function()
				AnalyticsService:LogCustomEvent(p, "EdgeBerries", edgePicked, { [Enum.AnalyticsCustomFieldKeys.CustomField01.Name] = outcome })
			end)
			-- Twist outcomes (#129): how each twist and world went for each climber, so the owner can spot a twist that is
			-- too hard for kids (share of Crowned / Survived / Scorched by twist). 17 x 3 x 5 values, far under the cap.
			local twistId, worldId = L.Mutator.Id, L.Theme
			track(function()
				AnalyticsService:LogCustomEvent(p, "TwistOutcome", 1, {
					[Enum.AnalyticsCustomFieldKeys.CustomField01.Name] = "Twist - " .. twistId,
					[Enum.AnalyticsCustomFieldKeys.CustomField02.Name] = "Outcome - " .. outcome,
					[Enum.AnalyticsCustomFieldKeys.CustomField03.Name] = "World - " .. worldId,
				})
			end)
			-- Catch-up bubbles (first round, underdog shield): one event per climber per round, split by bubble and
			-- outcome, so the owner can see how often a struggling kid is unshoveable and whether it helps them.
			local bubble = r.bubble or "None"
			track(function()
				AnalyticsService:LogCustomEvent(p, "CatchUpBubble", 1, { [Enum.AnalyticsCustomFieldKeys.CustomField01.Name] = bubble .. " - " .. outcome })
			end)
			event:FireClient(p, "LavaResult", {
				AskFun = askFun,
				Streak = L.Streak[p],
				StreakWas = streakWas,
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
	local phase = Grid.Phase(grid, t)
	local started = phase >= 0
	local campTime = CFG.CampTime * (if L.Mutator.Id == "QuickCrumble" then CFG.QuickCrumble else 1)
	-- Random decay (#136): pick a few solid tiles to start crumbling on their own.
	local start = grid:GetAttribute("Start")
	if started and type(start) == "number" and t >= start + CFG.DecayGrace and t >= nextDecay then
		nextDecay = t + CFG.DecayEvery
		local busy = 0
		for _ in decaying do
			busy += 1
		end
		local pool = {}
		for index, tile in platforms do
			local row, col = tile:GetAttribute("Row"), tile:GetAttribute("Col")
			local back = tile:GetAttribute("CampBack")
			if not decaying[index] and Grid.TileState(grid, row, col, t) == "Still" and Grid.Lift(grid, row, col, t) <= 0
				and not Grid.IsPillar(grid, row, col) and not (type(back) == "number" and back > t) then
				table.insert(pool, index)
			end
		end
		for _ = 1, math.min(phase + 1, CFG.DecayMax - busy, #pool) do
			decaying[table.remove(pool, math.random(#pool))] = true
		end
	end
	for index, tile in platforms do
		local row, col = tile:GetAttribute("Row"), tile:GetAttribute("Col")
		local w = wear[index] or 0
		local state = Grid.TileState(grid, row, col, t)
		if not started or state ~= "Still" or Grid.Lift(grid, row, col, t) > 0 then
			w = if state == "Still" then math.max(0, w - dt / campTime) else 0
			decaying[index] = nil
		elseif decaying[index] then
			w += dt / CFG.DecayWarn
		elseif occupied[index] then
			w += dt / campTime
		else
			w = math.max(0, w - dt / (campTime * 1.5))
		end
		if w >= 1 then
			w = 0
			tile:SetAttribute("CampWarn", t)
			tile:SetAttribute("CampFall", t + 0.15)
			tile:SetAttribute("CampBack", t + 0.75 + CFG.CampRespawn)
			tile:SetAttribute("DecayFall", if decaying[index] then t + 0.15 else nil) -- for the "why you fell" line
			decaying[index] = nil
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
		allTime.Write(p, d.Crowns)
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
local function titleUnlocked(t: any, d: any, crowns: number): boolean
	if t.Crowns then
		return crowns >= t.Crowns
	elseif not d then
		return false
	elseif t.Need == "Gems" then
		for i = 1, #CFG.Gems do
			if not (d.Gems and d.Gems["G" .. i]) then
				return false
			end
		end
		return true
	elseif t.Need == "Chests" then
		return (tonumber(d.ChestsOpened) or 0) >= CFG.TitleChests
	elseif t.Need == "Gifts" then
		return (tonumber(d.GiftsSent) or 0) >= CFG.TitleGifts
	elseif t.Need == "Worlds" then
		for _, theme in Themes.List do
			if not (d.WorldsSeen and d.WorldsSeen[theme.Id]) then
				return false
			end
		end
		return true
	elseif t.Need == "Parties" then
		return (tonumber(d.EscapeParties) or 0) >= CFG.TitleParties
	elseif t.Need == "Twists" then
		local n = 0
		for _ in d.TwistWins or {} do
			n += 1
		end
		return n >= CFG.TitleTwists
	elseif t.Need == "Buddies" then
		for _, h in GameConfig.Pets or {} do
			if h.FindIn and not (d.OwnedPets and d.OwnedPets[h.Id]) then
				return false
			end
		end
		return true
	end
	return false
end

-- Shows the player's chosen title (d.Title: a title Id, "Auto" for the best crown title, or "None") and publishes
-- the unlocked ones for the picker as the "LavaTitles" attribute (JSON: List of {Id, Text}, Current).
applyTitle = function(p: Player)
	local d = data(p)
	local crowns = tonumber(p:GetAttribute("Crowns")) or 0
	local auto, chosen = nil, nil
	local unlocked = {}
	for _, t in CFG.Titles do
		if titleUnlocked(t, d, crowns) then
			if t.Crowns then
				auto = t
			end
			if d and d.Title == t.Id then
				chosen = t
			end
			table.insert(unlocked, { Id = t.Id, Text = t.Text })
		end
	end
	local pick = if d and type(d.Title) == "string" and d.Title ~= "" then d.Title else "Auto"
	local list = { { Id = "Auto", Text = if auto then "Auto: " .. auto.Text else "Auto" } }
	for _, t in unlocked do
		table.insert(list, t)
	end
	table.insert(list, { Id = "None", Text = "No title" })
	local current = if pick == "None" then "None" elseif chosen then chosen.Id else "Auto"
	p:SetAttribute("LavaTitles", HttpService:JSONEncode({ List = list, Current = current }))
	local best = if current == "None" then nil elseif chosen then chosen else auto
	local character = p.Character
	local head = character and character:FindFirstChild("Head")
	if not head then
		return
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
	if L.Mutator.Id == "BigHeads" then
		-- Built big from the start: changing HeadScale on the finished rig regrows the head a moment later, which
		-- brings the face back and resets the rock material after the golem look is applied.
		desc.HeadScale = CFG.BigHeadScale
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
	-- Into the workspace before anything is welded on or moved: a WeldConstraint is inactive outside it, so eyes and a
	-- hat welded out there stayed at the build spot when the bot was moved.
	model.Parent = towerModel
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
	-- Move the whole model (eyes and hat included) so the root lands on the tile.
	local target = botTileTop(b, now()) * CFrame.new(0, stand, 0)
	model:PivotTo(target * rootPart.CFrame:ToObjectSpace(model:GetPivot()))
	CollectionService:AddTag(rootPart, "LavaBot")
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
				tell(member, if mateName then "👥 DUOS! You're " .. teamName(team) .. " with " .. mateName .. ". Last team standing wins!" else "👥 DUOS! You're " .. teamName(team) .. ", solo this round. Good luck!")
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
	local names = table.clone(CFG.BotNamesByTheme[L.Theme] or CFG.BotNames)
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
	local magnet = L.Mutator.Id == "Magnet"
	if magnet then
		dir = -dir -- 🧲 Magnet Hands: the bot slides toward you instead
	end
	local reach = if L.Mutator.Id == "MegaShove" then 2.6 else 1.6 -- tiles; Mega Shoves pushes a bot one tile further
	local row, col = Grid.TileAt(towerModel, from + dir * CFG.GridTile * reach + Vector3.new(0, 2, 0), now())
	shoveImpact(p, nil, from)
	challenge(p, "Shoves", 1)
	if row and col and walkable(Grid.TileState(towerModel, row, col, now())) then
		setBotTile(b, row, col)
		b.nextThink = now() + 0.6
	else
		killBot(b, (if magnet then "got pulled into the lava by " else "got shoved into the lava by ") .. p.DisplayName .. "!")
		challenge(p, "Knockouts", 1)
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

-- Fade the game pillar (#139) in while a round is on and out after it.
local function setGamePillar(on: boolean)
	local folder = arenaFolder
	if not folder then
		return
	end
	for name, shown in { GamePillarCore = 0.15, GamePillarGlow = 0.8 } do
		local piece = folder:FindFirstChild(name)
		if piece and piece:IsA("BasePart") then
			game:GetService("TweenService"):Create(piece, TweenInfo.new(1.5), { Transparency = if on then shown else 1 }):Play()
		end
	end
end

local function runRound()
	L.RoundId += 1
	table.clear(L.Predictions)
	table.clear(L.Gifted)
	clearTower()
	buildTower()
	applyTheme(tower)
	local started = now()
	local grid = tower :: Model
	grid:SetAttribute("Start", started + CFG.StartDelay)
	setLava(lavaFor(started))
	L.Phase = "Round"
	setGamePillar(true)
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
	local dropEvery = if L.Mutator.Id == "DropParty" then CFG.DropPartyEvery elseif L.Theme ~= "Sunset" then CFG.ThemeDropEvery else CFG.DropEvery
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
				-- Heights above the climb don't count (#153): since the hub moved up onto the deck (#138, 100 studs over
				-- the island), a player entering a round stood on the deck while their area streamed in, and that
				-- counted as reaching the top: full rises, height coins and chest fill before they'd climbed at all.
				if h > r.peak and h <= crownHeight + 12 then
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
						r.lastRow, r.lastCol, r.lastTileAt = row, col, now()
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
						tell(other, "👥 " .. teamName(winner) .. " wins! (" .. table.concat(names, " & ") .. ")")
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
		if not L.Queue[p] and not (r and r.alive) and not p:GetAttribute("LavaOptOut") and p:GetAttribute("LavaReady") and data(p) and free(p) then
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
		local wasSurprise = surpriseNext and wasVoted
		L.Mutator = if votedNext then votedNext else pickMutator(L.Mutator)
		votedNext = nil
		surpriseNext = false
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
		-- Bonus rounds (#96, #97): every theme except Sunset has extra fruit drops and a lost buddy; the countdown says
		-- so in the same notice (no extra pop-up).
		local bonus = if theme.Id ~= "Sunset" then " · 🐾 Bonus round" else ""
		for p in L.Queue do
			tell(p, theme.Name .. bonus .. (if L.Mutator.Id == "Classic" then " · Lava Rush in " .. CFG.Countdown .. "s!" else (if wasSurprise then " · 🎲 Surprise twist: " else " · Twist: ") .. L.Mutator.Name .. "!"))
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
				surpriseNext = wasSurprise
			end
			continue
		end
		local ok, err = pcall(runRound)
		if not ok then
			warn("[LavaRush] round crashed:", err)
		end
		L.Phase = "Results"
		setGamePillar(false)
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
			if #options == CFG.VoteOptions and #pool > 0 and math.random() < CFG.SurpriseChance then
				table.insert(pool, options[#options]) -- the twist it replaces can still be the surprise
				options[#options] = SURPRISE
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
			local winner = if #best > 0 then best[math.random(#best)] else nil
			votedNext = winner
			if winner == SURPRISE then
				-- Draw the secret twist from the ones that weren't on the ballot (never Classic or this round's twist).
				local secret = {}
				for _, m in MUTATORS do
					if m.Id ~= "Classic" and m.Id ~= L.Mutator.Id and not table.find(v.options, m) then
						table.insert(secret, m)
					end
				end
				votedNext = if #secret > 0 then secret[math.random(#secret)] else pickMutator(L.Mutator)
				surpriseNext = true
			end
			vote = nil
			event:FireAllClients("LavaVoteResult", { Id = winner and winner.Id, Name = winner and winner.Name, Votes = bestCount })
			if winner then
				for _, p in Players:GetPlayers() do
					tell(p, "🗳️ Next twist: " .. winner.Name .. (if bestCount > 0 then " (" .. bestCount .. " vote" .. (if bestCount == 1 then "" else "s") .. ")" else ""))
				end
			end
		end
	end
end

-- Fruit hats (cosmetic, bought with coins in the shop).
-- Try-on mirror (#140): items tried on at the mirror stage, per player. A preview only: the saved profile (Skin, Hat,
-- Pet) is never touched, and clearTryOn puts the saved look back.
local tryOn: { [Player]: any } = setmetatable({}, { __mode = "k" }) :: any
local function paintGloves(p: Player, skinId: string?)
	local character = p.Character
	local gloves = character and character:FindFirstChild("ArenaGloves")
	if not gloves then
		return
	end
	local def = GameConfig.Skins[1]
	for _, skin in GameConfig.Skins do
		if skin.Id == skinId then
			def = skin
		end
	end
	for _, g in gloves:GetChildren() do
		if g:IsA("BasePart") and (g.Name == "RightGlove" or g.Name == "LeftGlove") then
			g.Color = def.Color
			g.Material = if def.Material then (Enum.Material :: any)[def.Material] else Enum.Material.SmoothPlastic
		end
	end
end
local function clearTryOn(p: Player)
	if not tryOn[p] then
		return
	end
	tryOn[p] = nil
	applyHat(p)
	applyPet(p)
	local d = data(p)
	paintGloves(p, d and d.Skin)
end

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
	local id = (tryOn[p] and tryOn[p].Hat) or (d and d.Hat)
	-- Remixed hats (#160) name another fruit's Model and repaint it in their own Material and Color.
	local def: any = nil
	for _, h in GameConfig.Hats do
		if h.Id == id then
			def = h
		end
	end
	local modelId = if def and def.Model then def.Model else id
	if type(id) ~= "string" or id == "" or type(modelId) ~= "string" or not FruitModels:FindFirstChild(modelId) then
		return
	end
	local hat = (FruitModels:FindFirstChild(modelId) :: Model):Clone()
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
			if def and def.Material then
				part.Material = (Enum.Material :: any)[def.Material]
				part.Color = def.Color
				if part:IsA("MeshPart") then
					part.TextureID = ""
				end
			end
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = head
			weld.Part1 = part
			weld.Parent = part
		end
	end
	hat.Parent = character
end

-- Fruit buddies (cosmetic pets, bought with coins in the shop): a small fruit with eyes that floats by your
-- shoulder. Welded to the root with a Weld named BuddyWeld so each client can bob it gently (LavaFloorsUI).
applyPet = function(p: Player)
	local character = p.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not character or not root or not root:IsA("BasePart") then
		return
	end
	local old = character:FindFirstChild("FruitBuddy")
	if old then
		old:Destroy()
	end
	local d = data(p)
	local id = (tryOn[p] and tryOn[p].Pet) or (d and d.Pet)
	local def = if type(id) == "string" then petDef(id) else nil
	local modelName = if def and def.Model then def.Model else id -- theme buddies are made from another fruit
	if type(id) ~= "string" or id == "" or type(modelName) ~= "string" or not FruitModels:FindFirstChild(modelName) then
		return
	end
	local s = root.Size.Y / 2 -- 1 for a full-size character
	local pet = (FruitModels:FindFirstChild(modelName) :: Model):Clone()
	pet.Name = "FruitBuddy"
	if def and def.Material then -- a remixed buddy (#163): repainted before the eyes go on
		for _, part in pet:GetDescendants() do
			if part:IsA("BasePart") then
				part.Material = (Enum.Material :: any)[def.Material]
				part.Color = def.Color
				if part:IsA("MeshPart") then
					part.TextureID = ""
				end
			end
		end
	end
	local _, size = pet:GetBoundingBox()
	pet:ScaleTo(CFG.PetSize * s / math.max(size.X, size.Y, size.Z))
	local box, scaled = pet:GetBoundingBox()
	local core = Instance.new("Part")
	core.Name = "BuddyCore"
	core.Size = Vector3.one * 0.2
	core.Transparency = 1
	core.CFrame = box
	core.Parent = pet
	addAura(core, def)
	pet.PrimaryPart = core
	local eyeSize = math.min(scaled.X, scaled.Y) * 0.3
	for _, side in { -1, 1 } do
		local eye = Instance.new("Part")
		eye.Name = "Eye"
		eye.Shape = Enum.PartType.Ball
		eye.Size = Vector3.one * eyeSize
		eye.Color = Color3.new(1, 1, 1)
		eye.Material = Enum.Material.SmoothPlastic
		eye.CFrame = box * CFrame.new(side * scaled.X * 0.17, scaled.Y * 0.1, -scaled.Z * 0.42)
		eye.Parent = pet
		local pupil = Instance.new("Part")
		pupil.Name = "Pupil"
		pupil.Shape = Enum.PartType.Ball
		pupil.Size = Vector3.one * eyeSize * 0.55
		pupil.Color = Color3.fromRGB(30, 20, 20)
		pupil.Material = Enum.Material.SmoothPlastic
		pupil.CFrame = eye.CFrame * CFrame.new(0, 0, -eyeSize * 0.3)
		pupil.Parent = pet
	end
	for _, part in pet:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = false
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.Massless = true
			part.CastShadow = false
			if part ~= core then
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = core
				weld.Part1 = part
				weld.Parent = part
			end
		end
	end
	local offset = CFrame.new(CFG.PetOffset * s)
	pet:PivotTo(root.CFrame * offset)
	local weld = Instance.new("Weld")
	weld.Name = "BuddyWeld"
	weld.Part0 = root
	weld.Part1 = core
	weld.C0 = offset
	weld:SetAttribute("Base", offset)
	weld.Parent = core
	pet.Parent = character
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
		-- On the ground around the island, not up with the floating arena (#137).
		local at = Vector3.new(CFG.Center.X, 0, CFG.Center.Z) + Vector3.new(math.cos(a) * r, if onBeach then 1.5 * scale - 1 else 0.9 * scale - 6, math.sin(a) * r)
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

-- Loaded first (CFG.ReadyWait): mark a player ready for the automatic rounds, once. Logs the analytics custom event
-- LoadTime (seconds from joining to ready; field 1 is a bucket, or "Fallback") so the owner can see how long devices
-- really take and whether ReadyWait fits.
local function markReady(p: Player, how: string)
	if p:GetAttribute("LavaReady") then
		return
	end
	p:SetAttribute("LavaReady", true)
	local joined = L.JoinedAt[p]
	if joined then
		local seconds = math.floor((os.clock() - joined) * 10 + 0.5) / 10
		local bucket = if how == "Fallback" then "Fallback" elseif seconds < 5 then "Under 5s" elseif seconds < 10 then "5-10s" else "10s+"
		track(function()
			AnalyticsService:LogCustomEvent(p, "LoadTime", seconds, { [Enum.AnalyticsCustomFieldKeys.CustomField01.Name] = bucket })
		end)
	end
end

function L.HandleAction(p: Player, action: unknown, _value: unknown): boolean
	if action == "LavaReady" then
		markReady(p, "Client")
		return true
	end
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
			challenge(p, "Cheer", 1)
			for _, other in Players:GetPlayers() do
				event:FireClient(other, "LavaCheer", { Name = p.DisplayName, Emoji = emoji })
			end
		end
		return true
	end
	if action == "LavaFun" then
		-- "Having fun?" answer: 1 😞, 2 😐, 3 😀. Only after the server asked, only once a session; logged with the
		-- round's twist so the owner can see which twists kids enjoy (analytics records nothing in Studio).
		local twist = L.FunAsked[p]
		local value = tonumber(_value)
		if type(twist) == "string" and value and value % 1 == 0 and value >= 1 and value <= 3 then
			L.FunAsked[p] = true
			track(function()
				AnalyticsService:LogCustomEvent(p, "FunRating", value, { [Enum.AnalyticsCustomFieldKeys.CustomField01.Name] = "Twist - " .. twist })
			end)
			tell(p, "💛 Thanks! That helps make LAVA Floors more fun.")
			if Run:IsStudio() then
				print(string.format("[fun] %s rated %d after a %s round", p.Name, value, twist))
			end
		end
		return true
	end
	if action == "LavaMusic" then
		-- The 🎵 / 🔇 button: saved so the music stays the way you left it next time you join.
		local d = data(p)
		if d and type(_value) == "boolean" then
			d.MusicOff = _value
			p:SetAttribute("MusicOff", _value)
		end
		return true
	end
	if action == "LavaTryOn" then
		-- Try-on mirror (#140): on the mirror stage, wear any glove, hat or buddy for TryOnSeconds. Nothing is saved or
		-- bought; buying is still the shop's own button.
		local v = _value
		if p:GetAttribute("OnMirror") == true and type(v) == "table" and type(v.Id) == "string" and #v.Id <= 24 then
			local kind, id = v.Kind, v.Id
			local items = if kind == "Skin" then GameConfig.Skins elseif kind == "Hat" then GameConfig.Hats elseif kind == "Pet" then GameConfig.Pets else nil
			local name: string? = nil
			for _, item in items or {} do
				if item.Id == id then
					name = item.Name
				end
			end
			if name then
				local t = tryOn[p] or { token = 0 }
				tryOn[p] = t
				t[kind] = id
				t.token += 1
				local token = t.token
				if kind == "Hat" then
					applyHat(p)
				elseif kind == "Pet" then
					applyPet(p)
				else
					paintGloves(p, id)
				end
				tell(p, "\u{2728} Trying on " .. name)
				task.delay(CFG.TryOnSeconds, function()
					if tryOn[p] == t and t.token == token then
						clearTryOn(p)
					end
				end)
			end
		end
		return true
	end
	if action == "LavaTopView" then
		-- The 🎥 top view button (#132): saved so the camera mode stays the way you left it next time you join (#133).
		local d = data(p)
		if d and type(_value) == "boolean" then
			d.TopView = _value
			p:SetAttribute("TopView", _value)
		end
		return true
	end
	if action == "LavaWinEmote" then
		-- Pick the emote played when you win: one of CFG.WinEmotes (all free).
		local d = data(p)
		if d and type(_value) == "string" and table.find(CFG.WinEmotes, _value) then
			d.WinEmote = _value
			p:SetAttribute("WinEmote", _value)
		end
		return true
	end
	if action == "LavaTitle" then
		-- Pick which title to show: "Auto", "None" or the Id of a title this player has unlocked.
		local d = data(p)
		if d and type(_value) == "string" and #_value <= 24 then
			local ok = _value == "Auto" or _value == "None"
			local crowns = tonumber(p:GetAttribute("Crowns")) or 0
			for _, t in CFG.Titles do
				if t.Id == _value and titleUnlocked(t, d, crowns) then
					ok = true
				end
			end
			if ok then
				d.Title = _value
				applyTitle(p)
			end
		end
		return true
	end
	if action == "LavaGift" then
		-- Strawberry gift: once a round, someone who is out can send a strawberry to a climber they're watching.
		-- It counts like one picked off the floor (banked only if that climber survives). Never to yourself or a bot.
		local r = L.Runners[p]
		local stillIn = r ~= nil and r.alive and not r.crowned and p:GetAttribute("ArenaMode") == "LavaRush"
		local target = if type(_value) == "number" and _value % 1 == 0 then Players:GetPlayerByUserId(_value) else nil
		local tr = if target then L.Runners[target] else nil
		if L.Phase == "Round" and not stillIn and not L.Gifted[p] and target and target ~= p and tr and tr.alive and not tr.crowned and target:GetAttribute("ArenaMode") == "LavaRush" then
			L.Gifted[p] = true
			challenge(p, "Gift", 1)
			tr.embers += CFG.GiftBerries
			local gd = data(p)
			if gd then
				gd.GiftsSent = (tonumber(gd.GiftsSent) or 0) + 1
				if gd.GiftsSent == CFG.TitleGifts then
					applyTitle(p)
					tell(p, "🏷️ New title: 🍓 Kind Climber! Pick it with the 🏷️ button in 📋 Challenges.")
				end
			end
			local at = root(target)
			if at then
				event:FireClient(target, "LavaFX", { Kind = "Ember", Position = at.Position })
			end
			tell(target, "🍓 " .. p.DisplayName .. " sent you a strawberry! Survive to bank it.")
			tell(p, "🍓 Sent to " .. target.DisplayName .. "! One gift a round.")
			personal(target)
			for _, other in Players:GetPlayers() do
				event:FireClient(other, "LavaCheer", { Name = p.DisplayName .. " → " .. target.DisplayName, Emoji = "🍓" })
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
					if v.votes[p] == nil then
						challenge(p, "Vote", 1) -- the first vote on each ballot counts; changing your mind doesn't
					end
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

-- Lobby gems (CFG.Gems). The server checks who is close enough; each client spins them and hides the ones it has
-- already found (player attribute "LavaGems", a list of ids like "G1,G3").
local function buildGems()
	local floorModel = workspace.SkySprout.Floors:FindFirstChild("Floor_" .. CFG.Floor)
	if not floorModel then
		return
	end
	-- With the hub on a floating deck (#138) the ground can't be reached, so the five gems move onto the deck: over the
	-- Warm-up Hop goal, behind the Top Climbers board and three along the force field. Same ids (G1-G5), so gems a
	-- player already found still count; the pickup check reads the same list.
	if CFG.Beacon.Y > 20 then
		local b = CFG.Beacon
		local toTower = (Vector3.new(CFG.Center.X, 0, CFG.Center.Z) - Vector3.new(b.X, 0, b.Z)).Unit
		local side = Vector3.new(-toTower.Z, 0, toTower.X)
		local spots = {}
		local goal = arenaFolder and arenaFolder:FindFirstChild("HopGoal", true)
		table.insert(spots, if goal and goal:IsA("BasePart") then goal.Position + Vector3.new(0, 6, 0) else b + side * 40 + Vector3.new(0, 6, 0))
		local board = arenaFolder and arenaFolder:FindFirstChild("TopClimbers", true)
		if board and board:IsA("BasePart") then
			local away = Vector3.new(board.Position.X - b.X, 0, board.Position.Z - b.Z).Unit
			table.insert(spots, Vector3.new(board.Position.X, b.Y + 2.5, board.Position.Z) + away * 3)
		else
			table.insert(spots, b - side * 24 + Vector3.new(0, 2.5, 0))
		end
		for _, deg in { 140, 195, 250 } do
			local a = math.rad(deg)
			table.insert(spots, b + (toTower * math.cos(a) + side * math.sin(a)) * (CFG.DeckRadius - 8) + Vector3.new(0, 2.5, 0))
		end
		CFG.Gems = spots
	end
	local old = floorModel:FindFirstChild("LobbyGems")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "LobbyGems"
	for i, at in CFG.Gems do
		local gem = Instance.new("Part")
		gem.Name = "G" .. i
		gem.Size = Vector3.new(1.3, 1.3, 1.3)
		gem.CFrame = CFrame.new(at) * CFrame.Angles(math.rad(45), 0, math.rad(45))
		gem.Material = Enum.Material.Neon
		gem.Color = Color3.fromRGB(255, 120, 40)
		gem.Anchored = true
		gem.CanCollide, gem.CanQuery, gem.CanTouch, gem.CastShadow = false, false, false, false
		gem:SetAttribute("NoTheme", true)
		local light = Instance.new("PointLight")
		light.Color = gem.Color
		light.Range = 9
		light.Brightness = 1.5
		light.Parent = gem
		local sparkle = Instance.new("ParticleEmitter")
		sparkle.Rate = 4
		sparkle.Lifetime = NumberRange.new(0.8, 1.4)
		sparkle.Speed = NumberRange.new(0.5, 1.5)
		sparkle.SpreadAngle = Vector2.new(180, 180)
		sparkle.Size = NumberSequence.new(0.25, 0)
		sparkle.LightEmission = 1
		sparkle.Color = ColorSequence.new(Color3.fromRGB(255, 220, 120), Color3.fromRGB(255, 120, 40))
		sparkle.Parent = gem
		gem.Parent = folder
	end
	folder.Parent = floorModel
end

local function gemList(d: any): (string, number)
	local ids = {}
	for i = 1, #CFG.Gems do
		if d.Gems and d.Gems["G" .. i] then
			table.insert(ids, "G" .. i)
		end
	end
	return table.concat(ids, ","), #ids
end

local function gemLoop()
	while true do
		task.wait(0.25)
		for _, p in Players:GetPlayers() do
			local d = data(p)
			local r = root(p)
			if d and r then
				d.Gems = d.Gems or {}
				local list, found = gemList(d)
				if p:GetAttribute("LavaGems") == nil then
					p:SetAttribute("LavaGems", list)
				end
				for i, at in CFG.Gems do
					local id = "G" .. i
					if not d.Gems[id] and (r.Position - at).Magnitude <= CFG.GemRadius then
						d.Gems[id] = true
						list, found = gemList(d)
						local all = found == #CFG.Gems
						local coins = CFG.GemCoins + (if all then CFG.GemAllCoins else 0)
						d.Coins = math.min(100000000, d.Coins + coins)
						pushStats(p)
						logCoins(p, "Gameplay", coins, if all then "LobbyGemsAll" else "LobbyGem")
						p:SetAttribute("LavaGems", list)
						event:FireClient(p, "LavaFX", { Kind = "Invite", Text = string.format("💎 Gem %d/%d", found, #CFG.Gems), Coins = coins })
						tell(p, if all then string.format("💎 All %d lava gems found! +%d coins", #CFG.Gems, coins)
							else string.format("💎 Lava gem %d/%d! +%d coins. %d more hidden around the hub.", found, #CFG.Gems, coins, #CFG.Gems - found))
						if all then
							applyTitle(p)
							tell(p, "🏷️ New title: 🔶 Gem Hunter! Pick it with the 🏷️ button in 📋 Challenges.")
						end
					end
				end
			end
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
	buildGems()
	buildBackdrop()
	-- New players appear at the hub plaza (#137), where placeAtBeacon also brings everyone back.
	local spawn = workspace:FindFirstChildOfClass("SpawnLocation")
	if spawn then
		local toTower = (Vector3.new(CFG.Center.X, 0, CFG.Center.Z) - Vector3.new(CFG.Beacon.X, 0, CFG.Beacon.Z)).Unit
		local at = CFG.Beacon + toTower * 16
		spawn.CFrame = CFrame.lookAt(at + Vector3.new(0, 2.5, 0), at + toTower + Vector3.new(0, 2.5, 0))
	end
	-- Who is on the try-on mirror stage (#140): "OnMirror" shows the TRY buttons; stepping off ends the try-on.
	task.spawn(function()
		while true do
			task.wait(0.3)
			local stageAt = workspace:GetAttribute("MirrorStage")
			for _, p in Players:GetPlayers() do
				local me = root(p)
				local on = false
				if typeof(stageAt) == "Vector3" and me and p:GetAttribute("ArenaMode") ~= "LavaRush" then
					local flat = Vector3.new(me.Position.X - stageAt.X, 0, me.Position.Z - stageAt.Z).Magnitude
					on = flat <= 8 and math.abs(me.Position.Y - stageAt.Y) < 7
				end
				if (p:GetAttribute("OnMirror") == true) ~= on then
					p:SetAttribute("OnMirror", on)
					if not on then
						clearTryOn(p)
					end
				end
			end
		end
	end)
	-- The old travel code (SkySproutTowerService) puts every new character at the floor's "Spawn" attribute, which the
	-- place saved by the old plaza: point it at the hub too (#138), facing the island.
	local hubFloor = workspace.SkySprout.Floors:FindFirstChild("Floor_" .. CFG.Floor)
	if hubFloor then
		local toTower = (Vector3.new(CFG.Center.X, 0, CFG.Center.Z) - Vector3.new(CFG.Beacon.X, 0, CFG.Beacon.Z)).Unit
		hubFloor:SetAttribute("Spawn", CFG.Beacon + toTower * 16 + Vector3.new(0, 3.6, 0))
		hubFloor:SetAttribute("SpawnLookAt", Vector3.new(CFG.Center.X, 0, CFG.Center.Z))
		-- Its out-of-bounds check sends anyone above MaxExploreHeight (190 in the place) back to the spawn with a
		-- "Returned to floor 1" notice: the hub deck at y 200 must be inside it.
		local limit = tonumber(hubFloor:GetAttribute("MaxExploreHeight")) or 270
		hubFloor:SetAttribute("MaxExploreHeight", math.max(limit, CFG.Beacon.Y + 80))
	end
	if GameConfig.PartyMode then
		islandMode()
		local function scale(character: Model)
			task.defer(function()
				if character.Parent then
					character:ScaleTo(CFG.CharacterScale)
					local p = Players:GetPlayerFromCharacter(character)
					if p then
						applyHat(p)
						applyPet(p)
					end
				end
			end)
		end
		A.OnHat = applyHat
		A.OnPet = applyPet
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
						if flat > CFG.SeaLimit or me.Position.Y < CFG.Beacon.Y - 60 then -- fell off the hub deck (#138) or the sea
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
					-- Studio test players are never friends; the workspace attribute StudioFakeFriends makes them so.
					return (Run:IsStudio() and workspace:GetAttribute("StudioFakeFriends") == true) or p:IsFriendsWith(o.UserId)
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
	-- Spawn with friends: someone who joins a friend appears beside them in the lobby instead of at the spawn, so they
	-- find each other straight away. Only onto solid, non-lava ground, and never into the round: if the friend is
	-- climbing, the newcomer just gets a notice.
	local function note(msg: string) -- Studio-only trace, so tests can see which way it went
		if Run:IsStudio() then
			print("[friends] " .. msg)
		end
	end
	local function spawnNearFriend(p: Player)
		local list = friends[p]
		if not list or next(list) == nil then
			note(p.Name .. " has no friend here")
			return
		end
		if not p.Character then
			p.CharacterAdded:Wait()
		end
		task.wait(1.5) -- after the character is scaled and placed
		local mine = root(p)
		if not p.Parent or not mine or p:GetAttribute("ArenaMode") == "LavaRush" then
			note(p.Name .. " skipped (left, no character, or already climbing)")
			return
		end
		local climbing: Player? = nil
		for _, o in Players:GetPlayers() do
			local theirs = root(o)
			if list[o.UserId] and theirs then
				if o:GetAttribute("ArenaMode") == "LavaRush" then
					climbing = climbing or o
				else
					local params = RaycastParams.new()
					params.FilterType = Enum.RaycastFilterType.Exclude
					params.FilterDescendantsInstances = { o.Character :: Instance, p.Character :: Instance }
					params.RespectCanCollide = true -- look through non-solid parts (the spawn pad) to the ground
					local gap = CFG.FriendSpawnGap
					local misses = {}
					for _, side in { Vector3.new(gap, 0, 0), Vector3.new(-gap, 0, 0), Vector3.new(0, 0, gap), Vector3.new(0, 0, -gap) } do
						local spot = theirs.Position + side
						local hit = workspace:Raycast(spot + Vector3.new(0, 4, 0), Vector3.new(0, -12, 0), params)
						if hit and not string.find(hit.Instance.Name, "Lava") then
							local at = hit.Position + Vector3.new(0, 3.5, 0)
							local character = p.Character :: Model
							character:PivotTo(CFrame.lookAt(at, Vector3.new(theirs.Position.X, at.Y, theirs.Position.Z)))
							tell(p, "👋 You're next to your friend " .. o.DisplayName .. "!")
							tell(o, "👋 " .. p.DisplayName .. " is here, right next to you!")
							note(string.format("%s placed %.1f studs from %s", p.Name, (at - theirs.Position).Magnitude, o.Name))
							return
						end
						table.insert(misses, if hit then hit.Instance.Name else "nothing")
					end
					note(p.Name .. " found no ground beside " .. o.Name .. " (" .. table.concat(misses, ", ") .. ")")
				end
			end
		end
		if climbing then
			tell(p, "👀 Your friend " .. climbing.DisplayName .. " is climbing right now. You'll be in the next round together!")
			p:SetAttribute("LavaWatchFriend", climbing.UserId) -- the client starts spectating and follows them
			note(p.Name .. "'s friend " .. climbing.Name .. " is climbing")
		else
			note(p.Name .. ": no friend with a character in the lobby")
		end
	end
	Players.PlayerAdded:Connect(function(p)
		note(p.Name .. " joined after the start")
		task.spawn(function()
			scanFriends(p)
			spawnNearFriend(p)
		end)
	end)
	-- Players who arrived while the server was still starting (a friend following someone into a fresh server):
	-- everyone after the first joiner goes to an earlier friend, as if they had joined after the start.
	for i, p in Players:GetPlayers() do
		note(p.Name .. " was here at the start (#" .. i .. ")")
		task.spawn(function()
			scanFriends(p)
			if i > 1 then
				spawnNearFriend(p)
			end
		end)
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
	-- Fallback for CFG.ReadyWait: join the rounds anyway if the client's "LavaReady" never arrives.
	local function readyLater(p: Player)
		task.delay(CFG.ReadyWait, function()
			if p.Parent then
				markReady(p, "Fallback")
			end
		end)
	end
	Players.PlayerAdded:Connect(function(p)
		L.JoinedAt[p] = os.clock() -- not for players already here at the start: their join time is unknown
		task.delay(3, function()
			if p.Parent then
				broadcast()
			end
		end)
		readyLater(p)
	end)
	for _, p in Players:GetPlayers() do
		readyLater(p)
	end

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
				p:SetAttribute("Tutorial", d.TutorialDone ~= true) -- still in their first round (no coach cards any more)
				p:SetAttribute("BestHeight", tonumber(d.BestHeight) or 0) -- the 🏅 marker on the climb meter
				p:SetAttribute("WinEmote", table.find(CFG.WinEmotes, d.WinEmote) and d.WinEmote or "Cheer")
				p:SetAttribute("MusicOff", d.MusicOff == true)
				p:SetAttribute("TopView", d.TopView == true)
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
				p:SetAttribute("WinEmote", table.find(CFG.WinEmotes, d.WinEmote) and d.WinEmote or "Cheer")
				p:SetAttribute("MusicOff", d.MusicOff == true)
				p:SetAttribute("TopView", d.TopView == true)
			end
		end)
	end
	for _, p in Players:GetPlayers() do
		task.spawn(checkReferral, p)
	end
	task.spawn(gemLoop)
	task.spawn(loop)
	print("Lava Rush ready — floor-is-lava rounds on floor 1.")
end

return L
