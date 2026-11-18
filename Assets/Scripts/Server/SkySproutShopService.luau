--!strict
-- Coin packs and the daily reward.
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")
local C = require(game.ReplicatedStorage.SkySproutConfig) :: any
local Profiles = require(script.Parent.SkySproutProfiles) :: any

local S = {}
local A: any
local stats: (Player) -> ()
local tell: (Player, string) -> ()

local PACKS = { Coins500 = 500, Coins2000 = 2000, Coins6000 = 6000 }

local function packFor(productId: number): number?
	for key, coins in PACKS do
		local id = C.ProductIds and C.ProductIds[key]
		if type(id) == "number" and id > 0 and id == productId then
			return coins
		end
	end
	return nil
end

local function recorded(data: any, purchaseId: string): boolean
	for _, id in data.Receipts do
		if id == purchaseId then
			return true
		end
	end
	return false
end

function S.ProcessReceipt(receipt: any): Enum.ProductPurchaseDecision
	local p = Players:GetPlayerByUserId(receipt.PlayerId)
	local session = p and Profiles.Sessions[p]
	local coins = packFor(receipt.ProductId)
	if not p or not session or not coins then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local d = session.Data
	local purchaseId = tostring(receipt.PurchaseId)
	if not recorded(d, purchaseId) then
		d.Coins = math.min(100000000, d.Coins + coins)
		table.insert(d.Receipts, purchaseId)
		while #d.Receipts > 60 do
			table.remove(d.Receipts, 1)
		end
		stats(p)
		tell(p, string.format("💰 +%d coins! Thanks for supporting LAVA Floors.", coins))
	end
	if Profiles.save(p, false) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

local DAILY = { 25, 50, 75, 100, 150, 200, 300 }

local function daily(p: Player)
	local started = os.clock()
	while p.Parent == Players and not Profiles.Sessions[p] and os.clock() - started < 60 do
		task.wait(1)
	end
	local session = Profiles.Sessions[p]
	if not session or p.Parent ~= Players then
		return
	end
	local d = session.Data
	local today = math.floor(os.time() / 86400)
	if d.LastDaily == today then
		return
	end
	local streak = if d.LastDaily == today - 1 then math.min((d.DailyStreak or 0) + 1, #DAILY) else 1
	local reward = DAILY[streak]
	d.LastDaily = today
	d.DailyStreak = streak
	d.Coins = math.min(100000000, d.Coins + reward)
	stats(p)
	task.wait(4)
	if p.Parent == Players then
		tell(p, string.format("🎁 Day %d daily reward: +%d coins!%s", streak, reward, if streak < #DAILY then " Come back tomorrow for more." else " Max streak!"))
	end
end

function S.Start(arena: any, pushStats: (Player) -> (), notice: (Player, string) -> ())
	A = arena
	stats = pushStats
	tell = notice
	MarketplaceService.ProcessReceipt = S.ProcessReceipt
	Players.PlayerAdded:Connect(function(p)
		task.spawn(daily, p)
	end)
	for _, p in Players:GetPlayers() do
		task.spawn(daily, p)
	end
	if RunService:IsStudio() then
		local function watch(p: Player)
			p:GetAttributeChangedSignal("StudioTestReceipt"):Connect(function()
				local raw = p:GetAttribute("StudioTestReceipt")
				if type(raw) ~= "string" then
					return
				end
				local product, purchase = raw:match("^(%d+):(.+)$")
				if product then
					local result = S.ProcessReceipt({ PlayerId = p.UserId, ProductId = tonumber(product), PurchaseId = purchase })
					p:SetAttribute("StudioTestReceiptResult", result.Name)
				end
			end)
		end
		Players.PlayerAdded:Connect(watch)
		for _, p in Players:GetPlayers() do
			watch(p)
		end
	end
end

return S
