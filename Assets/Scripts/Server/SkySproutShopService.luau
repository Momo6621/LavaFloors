--!strict
-- Coin packs, supporter tips, the rewarded ad and the daily reward.
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")
local DataStoreService = game:GetService("DataStoreService")
local AdService = game:GetService("AdService")
local C = require(game.ReplicatedStorage.SkySproutConfig) :: any
local Profiles = require(script.Parent.SkySproutProfiles) :: any

local S = {}
local A: any
local stats: (Player) -> ()
local tell: (Player, string) -> ()

local PACKS = { Coins100 = 100, Coins500 = 500, Coins2000 = 2000, Coins6000 = 6000 }

local function tipFor(productId: number): number?
	for key, robux in C.Tips or {} do
		local id = C.ProductIds and C.ProductIds[key]
		if type(id) == "number" and id > 0 and id == productId then
			return robux
		end
	end
	return nil
end

-- Top supporters (all time, across servers).
local supporters: OrderedDataStore? = nil
pcall(function()
	supporters = DataStoreService:GetOrderedDataStore("LavaSupporters_v1")
end)
local topCache: { { Name: string, Amount: number } } = {}
local nameCache: { [number]: string } = {}

function S.TopSupporters(): { { Name: string, Amount: number } }
	return topCache
end

local function refreshTop()
	local store = supporters
	if not store then
		return
	end
	local ok, pages = pcall(function()
		return store:GetSortedAsync(false, 6)
	end)
	if not ok or not pages then
		return
	end
	local fresh = {}
	for _, entry in pages:GetCurrentPage() do
		local userId = tonumber(entry.key)
		if userId then
			local name = nameCache[userId]
			if not name then
				local okName, result = pcall(function()
					return Players:GetNameFromUserIdAsync(userId)
				end)
				name = if okName then result else "Supporter"
				nameCache[userId] = name
			end
			table.insert(fresh, { Name = name :: string, Amount = entry.value })
		end
	end
	topCache = fresh
end

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
	local tip = tipFor(receipt.ProductId)
	if not p or not session or not (coins or tip) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local d = session.Data
	local purchaseId = tostring(receipt.PurchaseId)
	if not recorded(d, purchaseId) then
		table.insert(d.Receipts, purchaseId)
		while #d.Receipts > 60 do
			table.remove(d.Receipts, 1)
		end
		if coins then
			d.Coins = math.min(100000000, d.Coins + coins)
			local balance = d.Coins
			task.spawn(pcall, function()
				game:GetService("AnalyticsService"):LogEconomyEvent(p, Enum.AnalyticsEconomyFlowType.Source, "Coins", coins, balance, Enum.AnalyticsEconomyTransactionType.IAP.Name, "CoinPack_" .. tostring(receipt.ProductId))
			end)
			stats(p)
			tell(p, string.format("💰 +%d coins! Thanks for supporting LAVA Floors.", coins))
		elseif tip then
			d.Tipped = (d.Tipped or 0) + tip
			local store = supporters
			if store then
				task.spawn(function()
					pcall(function()
						store:SetAsync(tostring(p.UserId), d.Tipped)
					end)
					refreshTop()
				end)
			end
			tell(p, string.format("💖 Thank you for the %d Robux tip! You're on the supporters board.", tip))
		end
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
	local vipWait = os.clock()
	while p.Parent == Players and p:GetAttribute("VIP") == nil and os.clock() - vipWait < 10 do
		task.wait(0.5)
	end
	local isVip = p:GetAttribute("VIP") == true
	local reward = DAILY[streak] * (if isVip and C.Vip then C.Vip.DailyMultiplier else 1)
	d.LastDaily = today
	d.DailyStreak = streak
	d.Coins = math.min(100000000, d.Coins + reward)
	local dailyBalance = d.Coins
	task.spawn(pcall, function()
		game:GetService("AnalyticsService"):LogEconomyEvent(p, Enum.AnalyticsEconomyFlowType.Source, "Coins", reward, dailyBalance, Enum.AnalyticsEconomyTransactionType.TimedReward.Name, "DailyStreak_" .. tostring(streak))
	end)
	stats(p)
	task.wait(4)
	if p.Parent == Players then
		tell(p, string.format("🎁 Day %d daily reward: +%d coins%s!%s", streak, reward, if isVip then " (⭐ VIP x2)" else "", if streak < #DAILY then " Come back tomorrow for more." else " Max streak!"))
	end
end

-- Rewarded video: watch a short ad for the 100-coin pack. Roblox only serves these to eligible players in
-- eligible games; the client hides the button unless an ad is available.
local lastAd: { [Player]: number } = {}
function S.ShowAd(p: Player)
	local id = C.ProductIds and C.ProductIds.Coins100
	if type(id) ~= "number" or id <= 0 or os.clock() - (lastAd[p] or 0) < 20 then
		return
	end
	lastAd[p] = os.clock()
	local ok, result = pcall(function()
		local reward = AdService:CreateAdRewardFromDevProductId(id)
		return AdService:ShowRewardedVideoAdAsync(p, reward)
	end)
	if not ok then
		tell(p, "📺 No ad available right now. Try again later!")
	elseif result ~= Enum.ShowAdResult.ShowCompleted then
		tell(p, "📺 Watch the whole ad to get the coins.")
	end
end

function S.Start(arena: any, pushStats: (Player) -> (), notice: (Player, string) -> ())
	A = arena
	stats = pushStats
	tell = notice
	MarketplaceService.ProcessReceipt = S.ProcessReceipt
	task.spawn(function()
		while true do
			refreshTop()
			task.wait(60)
		end
	end)
	Players.PlayerRemoving:Connect(function(p)
		lastAd[p] = nil
	end)
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
