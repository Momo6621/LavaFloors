--!strict
-- Game passes (Aurora, 2x Lava Coins).
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")
local C = require(game.ReplicatedStorage.SkySproutConfig) :: any
local Profiles = require(script.Parent.SkySproutProfiles) :: any

local P = {}
local PASSES = { Aurora = "PassId", DoubleLava = "DoubleLavaPassId" }
local owned: { [string]: { [Player]: boolean } } = { Aurora = {}, DoubleLava = {} }
local A: any
local tell: (Player, string) -> ()

local function passId(key: string): number
	local id = C[PASSES[key]]
	return if type(id) == "number" and id > 0 then id else 0
end

function P.Has(p: Player, key: string): boolean
	if owned[key] and owned[key][p] == true then
		return true
	end
	return RunService:IsStudio() and p:GetAttribute("StudioGrant" .. key) == true
end

function P.Owns(p: Player): boolean
	return P.Has(p, "Aurora")
end

local function publish(p: Player)
	if p.Parent ~= Players then
		return
	end
	p:SetAttribute("AuroraPass", P.Has(p, "Aurora"))
	p:SetAttribute("DoubleLavaPass", P.Has(p, "DoubleLava"))
	if owned.Aurora[p] == false and not P.Has(p, "Aurora") then
		local started = os.clock()
		while p.Parent == Players and not Profiles.Sessions[p] and os.clock() - started < 60 do
			task.wait(1)
		end
		local s = Profiles.Sessions[p]
		if s and s.Data.Skin == "Aurora" then
			A.HandleAction(p, "Skin", "Mint")
		end
	end
end

local function lookup(p: Player)
	for key in PASSES do
		local id = passId(key)
		if id == 0 then
			owned[key][p] = false
		else
			for attempt = 1, 3 do
				local ok, result = pcall(function()
					return MarketplaceService:UserOwnsGamePassAsync(p.UserId, id)
				end)
				if ok then
					owned[key][p] = result == true
					break
				end
				task.wait(attempt * 2)
			end
		end
	end
	publish(p)
end

function P.Start(arena: any, notice: (Player, string) -> ())
	A = arena
	tell = notice
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(p: Player, id: number, purchased: boolean)
		if not purchased or p.Parent ~= Players then
			return
		end
		if id == passId("Aurora") then
			owned.Aurora[p] = true
			publish(p)
			tell(p, "✨ Aurora Gloves unlocked. Thank you for supporting LAVA Floors!")
			A.HandleAction(p, "Skin", "Aurora")
		elseif id == passId("DoubleLava") then
			owned.DoubleLava[p] = true
			publish(p)
			tell(p, "🔥 2x Lava Coins active! Every Lava Rush payout is doubled. Thank you!")
		end
	end)
	local function added(p: Player)
		task.spawn(lookup, p)
		if RunService:IsStudio() then
			for key in PASSES do
				p:GetAttributeChangedSignal("StudioGrant" .. key):Connect(function()
					publish(p)
				end)
			end
		end
	end
	Players.PlayerAdded:Connect(added)
	for _, p in Players:GetPlayers() do
		added(p)
	end
	Players.PlayerRemoving:Connect(function(p)
		for key in PASSES do
			owned[key][p] = nil
		end
	end)
end

return P
