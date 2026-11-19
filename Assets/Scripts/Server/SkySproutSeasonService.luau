--!strict
-- Lava Pass: a season track. Everyone earns XP by playing and claims the free rewards; Lava Pass Premium (a game
-- pass) also unlocks the premium rewards, including pass-only hats. Nothing on either track is random.
local Players = game:GetService("Players")
local C = require(game.ReplicatedStorage.SkySproutConfig) :: any
local Profiles = require(script.Parent.SkySproutProfiles) :: any

local S = {}
local A: any
local stats: (Player) -> ()
local tell: (Player, string) -> ()

local function data(p: Player): any
	local session = Profiles.Sessions[p]
	return session and session.Data
end

local function tierOf(xp: number): number
	return math.min(#C.LavaPass.Tiers, math.floor(xp / C.LavaPass.XPPerTier))
end

local function claimedList(track: { [string]: boolean }): string
	local out = {}
	for tier = 1, #C.LavaPass.Tiers do
		if track[tostring(tier)] then
			table.insert(out, tier)
		end
	end
	return table.concat(out, ",")
end

function S.Publish(p: Player)
	local d = data(p)
	if not d then
		return
	end
	p:SetAttribute("PassXP", d.PassXP or 0)
	p:SetAttribute("PassTier", tierOf(d.PassXP or 0))
	p:SetAttribute("PassFreeClaimed", claimedList(d.PassFree or {}))
	p:SetAttribute("PassPremClaimed", claimedList(d.PassPrem or {}))
end

function S.AddXP(p: Player, amount: number)
	local d = data(p)
	if not d or amount <= 0 then
		return
	end
	local before = tierOf(d.PassXP or 0)
	d.PassXP = math.min(1000000, (d.PassXP or 0) + math.floor(amount))
	local after = tierOf(d.PassXP)
	S.Publish(p)
	if after > before then
		tell(p, string.format("🎟️ Lava Pass tier %d unlocked! Open the Pass to claim it.", after))
	end
end

local function grant(p: Player, d: any, reward: any): string
	if reward.Coins then
		d.Coins = math.min(100000000, d.Coins + reward.Coins)
		return "+" .. reward.Coins .. " coins"
	elseif reward.Hat then
		d.OwnedHats[reward.Hat] = true
		for _, h in C.Hats do
			if h.Id == reward.Hat then
				return h.Name
			end
		end
		return reward.Hat
	end
	return "reward"
end

function S.Claim(p: Player, value: unknown)
	local d = data(p)
	if not d or type(value) ~= "table" then
		return
	end
	local tier, track = (value :: any).Tier, (value :: any).Track
	if type(tier) ~= "number" or tier ~= math.floor(tier) or tier < 1 or tier > #C.LavaPass.Tiers then
		return
	end
	if track ~= "Free" and track ~= "Premium" then
		return
	end
	if tierOf(d.PassXP or 0) < tier then
		tell(p, "🎟️ Keep playing to reach tier " .. tier .. ".")
		return
	end
	if track == "Premium" and not (A.Pass and A.Pass.Has(p, "LavaPass")) then
		tell(p, "🎟️ Premium rewards need Lava Pass Premium.")
		return
	end
	local claimed = if track == "Free" then d.PassFree else d.PassPrem
	if claimed[tostring(tier)] then
		return
	end
	claimed[tostring(tier)] = true
	local what = grant(p, d, C.LavaPass.Tiers[tier][track])
	stats(p)
	S.Publish(p)
	tell(p, string.format("🎟️ Tier %d %s: %s!", tier, if track == "Free" then "reward" else "premium reward", what))
end

function S.Start(arena: any, pushStats: (Player) -> (), notice: (Player, string) -> ())
	A = arena
	stats = pushStats
	tell = notice
	local function added(p: Player)
		task.spawn(function()
			local started = os.clock()
			while p.Parent == Players and not Profiles.Sessions[p] and os.clock() - started < 60 do
				task.wait(1)
			end
			S.Publish(p)
		end)
	end
	Players.PlayerAdded:Connect(added)
	for _, p in Players:GetPlayers() do
		added(p)
	end
end

return S
