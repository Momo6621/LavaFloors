--!strict
-- Game passes (Aurora, 2x Lava Coins, Lava Pass premium) and the VIP subscription.
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")
local C = require(game.ReplicatedStorage.SkySproutConfig) :: any
local Profiles = require(script.Parent.SkySproutProfiles) :: any

local P = {}
local PASSES = { Aurora = "PassId", DoubleLava = "DoubleLavaPassId", LavaPass = "LavaPassPremiumId" }
local owned: { [string]: { [Player]: boolean } } = { Aurora = {}, DoubleLava = {}, LavaPass = {} }
local vip: { [Player]: boolean } = {}
local A: any
local tell: (Player, string) -> ()

local function passId(key: string): number
	local id = C[PASSES[key]]
	return if type(id) == "number" and id > 0 then id else 0
end

local function subscriptionId(): string?
	local id = C.VipSubscriptionId
	return if type(id) == "string" and id ~= "" then id else nil
end

function P.Has(p: Player, key: string): boolean
	if key == "VIP" and vip[p] == true then
		return true
	end
	if owned[key] and owned[key][p] == true then
		return true
	end
	return RunService:IsStudio() and p:GetAttribute("StudioGrant" .. key) == true
end

function P.Owns(p: Player): boolean
	return P.Has(p, "Aurora")
end

-- VIP look: a gold "⭐ VIP" tag over the head and a soft golden shimmer.
local function vipLook(p: Player)
	local character = p.Character
	local head = character and character:FindFirstChild("Head")
	if not character or not head then
		return
	end
	local tag = head:FindFirstChild("VipTag")
	local shimmer = character:FindFirstChild("HumanoidRootPart") and character.HumanoidRootPart:FindFirstChild("VipShimmer")
	if not P.Has(p, "VIP") then
		if tag then
			tag:Destroy()
		end
		if shimmer then
			shimmer:Destroy()
		end
		return
	end
	if not tag then
		tag = Instance.new("BillboardGui")
		tag.Name = "VipTag"
		tag.Size = UDim2.fromOffset(90, 26)
		tag.StudsOffset = Vector3.new(0, 2.6, 0)
		tag.MaxDistance = 60
		tag.Parent = head
		local text = Instance.new("TextLabel")
		text.BackgroundTransparency = 1
		text.Size = UDim2.fromScale(1, 1)
		text.Font = Enum.Font.FredokaOne
		text.TextScaled = true
		text.Text = "⭐ VIP"
		text.TextColor3 = Color3.fromRGB(255, 215, 70)
		text.TextStrokeTransparency = 0.2
		text.TextStrokeColor3 = Color3.fromRGB(90, 50, 0)
		text.Parent = tag
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root and not shimmer then
		local e = Instance.new("ParticleEmitter")
		e.Name = "VipShimmer"
		e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		e.Color = ColorSequence.new(Color3.fromRGB(255, 230, 120), Color3.fromRGB(255, 180, 40))
		e.Rate = 6
		e.Lifetime = NumberRange.new(0.8, 1.4)
		e.Speed = NumberRange.new(1, 2)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Size = NumberSequence.new(0.35, 0)
		e.LightEmission = 1
		e.Parent = root
	end
end

local function publish(p: Player)
	if p.Parent ~= Players then
		return
	end
	p:SetAttribute("AuroraPass", P.Has(p, "Aurora"))
	p:SetAttribute("DoubleLavaPass", P.Has(p, "DoubleLava"))
	p:SetAttribute("LavaPassPremium", P.Has(p, "LavaPass"))
	p:SetAttribute("VIP", P.Has(p, "VIP"))
	vipLook(p)
	if not P.Has(p, "VIP") then
		task.spawn(function()
			local s = Profiles.Sessions[p]
			if s and C.Vip and s.Data.Hat == C.Vip.Hat then
				A.HandleAction(p, "Hat", C.Vip.Hat) -- takes the VIP hat off when VIP ends
			end
		end)
	end
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

local function checkVip(p: Player)
	local id = subscriptionId()
	if not id then
		vip[p] = false
		publish(p)
		return
	end
	for attempt = 1, 3 do
		local ok, status = pcall(function()
			return MarketplaceService:GetUserSubscriptionStatusAsync(p, id)
		end)
		if ok and type(status) == "table" then
			vip[p] = status.IsSubscribed == true
			break
		end
		task.wait(attempt * 2)
	end
	publish(p)
end

function P.Start(arena: any, notice: (Player, string) -> ())
	A = arena
	tell = notice
	Players.UserSubscriptionStatusChanged:Connect(function(p: Player, id: string)
		if id == subscriptionId() then
			checkVip(p)
			if vip[p] then
				tell(p, "⭐ Welcome to VIP! Thank you for supporting LAVA Floors.")
			end
		end
	end)
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
		elseif id == passId("LavaPass") then
			owned.LavaPass[p] = true
			publish(p)
			tell(p, "🎟️ Lava Pass Premium unlocked! Claim your premium rewards in the Pass menu.")
		end
	end)
	local function added(p: Player)
		task.spawn(lookup, p)
		task.spawn(checkVip, p)
		p.CharacterAdded:Connect(function()
			task.wait(0.5)
			vipLook(p)
		end)
		if RunService:IsStudio() then
			for key in PASSES do
				p:GetAttributeChangedSignal("StudioGrant" .. key):Connect(function()
					publish(p)
				end)
			end
			p:GetAttributeChangedSignal("StudioGrantVIP"):Connect(function()
				vip[p] = p:GetAttribute("StudioGrantVIP") == true
				publish(p)
			end)
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
		vip[p] = nil
	end)
end

return P
