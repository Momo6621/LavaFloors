--!strict
-- Main HUD: coins, shop, Lava Pass, VIP, invite, music and shove button.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local CAS = game:GetService("ContextActionService")
local TweenService = game:GetService("TweenService")
local MPS = game:GetService("MarketplaceService")

local player = Players.LocalPlayer
local event = RS:WaitForChild("ArenaEvent") :: RemoteEvent
local C = require(RS:WaitForChild("SkySproutConfig")) :: any
local Icon = require(RS:WaitForChild("Icon")) :: any

require(RS:WaitForChild("SkySproutWaterClient")).Start()
require(RS:WaitForChild("SkySproutPerception")).Start()
require(RS:WaitForChild("SkySproutRendering")).Start()

local UI = require(RS:WaitForChild("LavaUI")) :: any
-- Dark glass + lava style (see Shared/LavaUI). CREAM is the panel glass and INK the light text on it.
local CREAM = UI.Glass
local INK = UI.Text
local ORANGE = Color3.fromRGB(255, 122, 40)
local GREEN = Color3.fromRGB(70, 200, 90)
local GOLD = Color3.fromRGB(255, 196, 45)
local RED = Color3.fromRGB(235, 70, 60)
local FONT = Enum.Font.FredokaOne

local function make(className: string, props: { [string]: any }, parent: Instance?): any
	local inst = Instance.new(className :: any)
	for k, v in props do
		(inst :: any)[k] = v
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end
local function corner(v: Instance, r: number)
	make("UICorner", { CornerRadius = UDim.new(0, r) }, v)
	if v:IsA("GuiObject") and not v:IsA("GuiButton") then
		if v.BackgroundColor3 == UI.Glass then
			v.BackgroundTransparency = UI.GlassTransparency
		elseif v.BackgroundColor3 == Color3.new(1, 1, 1) then
			v.BackgroundColor3 = UI.GlassLight
			v.BackgroundTransparency = 0.08
		end
	end
end
local function outline(v: Instance, thickness: number, color: Color3?)
	if v:IsA("GuiObject") then
		UI.lavaStroke(v, math.min(thickness, 2.5), color)
	end
end
local function label(parent: Instance, text: string, size: number, color: Color3?): TextLabel
	return make("TextLabel", { BackgroundTransparency = 1, Font = FONT, Text = text, TextSize = size, TextColor3 = color or INK, Size = UDim2.fromScale(1, 1) }, parent)
end

local click = make("Sound", { SoundId = "rbxasset://sounds/clickfast.wav", Volume = 0.45 }, script)
local function button(parent: Instance, text: string, color: Color3, size: UDim2): TextButton
	local b: TextButton = make("TextButton", { Size = size, BackgroundColor3 = color, AutoButtonColor = false, Font = FONT, Text = text, TextSize = 18 }, parent)
	corner(b, 12)
	UI.button(b, color)
	local scale = make("UIScale", {}, b)
	local function to(v: number, t: number?)
		TweenService:Create(scale, TweenInfo.new(t or 0.14, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = v }):Play()
	end
	b.MouseEnter:Connect(function()
		to(1.06)
	end)
	b.MouseLeave:Connect(function()
		to(1)
	end)
	b.MouseButton1Down:Connect(function()
		to(0.92, 0.06)
	end)
	b.MouseButton1Up:Connect(function()
		to(1.06)
	end)
	b.Activated:Connect(function()
		click:Play()
	end)
	return b
end

local gui = make("ScreenGui", { Name = "LavaFloorsUI", ResetOnSpawn = false, DisplayOrder = 6, ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, player:WaitForChild("PlayerGui"))
UI.fitScreen(gui)

local chip = make("Frame", { Position = UDim2.fromOffset(12, 8), Size = UDim2.fromOffset(200, 48), BackgroundColor3 = CREAM }, gui)
corner(chip, 16)
outline(chip, 3)
local coinsText = label(chip, "💰 0", 26, UI.Gold)
coinsText.Position = UDim2.fromOffset(14, 0)
coinsText.Size = UDim2.new(0.62, -14, 1, 0)
coinsText.TextXAlignment = Enum.TextXAlignment.Left
local crownsText = label(chip, "👑 0", 22, UI.Gold)
crownsText.Position = UDim2.new(0.62, 0, 0, 0)
crownsText.Size = UDim2.new(0.38, -12, 1, 0)
crownsText.TextXAlignment = Enum.TextXAlignment.Right
local function stats()
	coinsText.Text = "💰 " .. tostring(player:GetAttribute("Coins") or 0)
	crownsText.Text = "👑 " .. tostring(player:GetAttribute("Crowns") or 0)
end
player:GetAttributeChangedSignal("Coins"):Connect(stats)
player:GetAttributeChangedSignal("Crowns"):Connect(stats)
stats()

local boostChip = make("Frame", { Position = UDim2.fromOffset(12, 62), Size = UDim2.fromOffset(200, 28), BackgroundColor3 = CREAM, Visible = false }, gui)
corner(boostChip, 14)
outline(boostChip, 2, GREEN)
local boostText = label(boostChip, "", 16)
boostText.TextColor3 = GREEN:Lerp(Color3.new(1, 1, 1), 0.35)
local function friendBoost()
	local cfg = (require(game.ReplicatedStorage:WaitForChild("SkySproutConfig")) :: any).FriendDeal
	local pct = math.floor(((cfg and cfg.Bonus) or 0.25) * 100)
	boostText.Text = "👥 Friend boost +" .. pct .. "% coins"
	boostChip.Visible = player:GetAttribute("FriendBoost") == true
end
player:GetAttributeChangedSignal("FriendBoost"):Connect(friendBoost)
friendBoost()

local toast = make("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 116), Size = UDim2.fromOffset(0, 40), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = CREAM, Visible = false }, gui)
corner(toast, 20)
outline(toast, 3)
make("UIPadding", { PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16) }, toast)
local toastText = label(toast, "", 18)
toastText.AutomaticSize = Enum.AutomaticSize.X
toastText.Size = UDim2.fromScale(0, 1)
local toastToken = 0
local function notify(text: string)
	toastToken += 1
	local token = toastToken
	toastText.Text = text
	toast.Visible = true
	task.delay(3.6, function()
		if toastToken == token then
			toast.Visible = false
		end
	end)
end

local shop = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.56), Size = UDim2.new(0.94, 0, 0.82, 0), BackgroundColor3 = CREAM, Visible = false }, gui)
make("UISizeConstraint", { MaxSize = Vector2.new(460, 520) }, shop)
corner(shop, 22)
outline(shop, 4)
local ribbon = make("Frame", { Position = UDim2.fromOffset(0, 0), Size = UDim2.new(1, 0, 0, 56), BackgroundColor3 = ORANGE }, shop)
corner(ribbon, 22)
make("UIGradient", { Rotation = 90, Color = ColorSequence.new(UI.Lava, UI.LavaDeep:Lerp(UI.Glass, 0.3)) }, ribbon)
local heading = label(ribbon, "🧤 GLOVES", 28, Color3.new(1, 1, 1))
heading.TextStrokeColor3 = UI.Shadow
heading.TextStrokeTransparency = 0.2
local close = button(ribbon, "X", RED, UDim2.fromOffset(40, 40))
close.AnchorPoint = Vector2.new(1, 0.5)
close.Position = UDim2.new(1, -10, 0.5, 0)
local list = make("ScrollingFrame", { Position = UDim2.fromOffset(12, 66), Size = UDim2.new(1, -24, 1, -110), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 6, ScrollBarImageColor3 = INK, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y }, shop)
make("UIGridLayout", { CellSize = UDim2.new(0.5, -8, 0, 150), CellPadding = UDim2.fromOffset(10, 10), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center }, list)
make("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 8) }, list)
local foot = label(shop, "Gloves and hats are just for looks. Robux items are optional.", 14, INK:Lerp(CREAM, 0.35))
foot.AnchorPoint = Vector2.new(0.5, 1)
foot.Position = UDim2.new(0.5, 0, 1, -10)
foot.Size = UDim2.new(1, -24, 0, 26)
foot.TextWrapped = true

local openPanel: (string) -> ()
local challengePanel: Frame
local refreshChallenges: () -> ()
type Card = { refresh: () -> () }
local cards: { Card } = {}
local function card(order: number, swatch: Color3, title: string): (Frame, TextButton)
	local f: Frame = make("Frame", { LayoutOrder = order, BackgroundColor3 = Color3.new(1, 1, 1) }, list)
	corner(f, 16)
	outline(f, 3)
	local dot = make("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 10), Size = UDim2.fromOffset(52, 52), BackgroundColor3 = swatch }, f)
	corner(dot, 26)
	outline(dot, 3)
	local name = label(f, title, 17)
	name.Position = UDim2.fromOffset(6, 66)
	name.Size = UDim2.new(1, -12, 0, 24)
	name.TextScaled = true
	make("UITextSizeConstraint", { MaxTextSize = 18 }, name)
	local b = button(f, "", ORANGE, UDim2.new(1, -20, 0, 40))
	b.AnchorPoint = Vector2.new(0.5, 1)
	b.Position = UDim2.new(0.5, 0, 1, -10)
	b.TextScaled = true
	make("UITextSizeConstraint", { MaxTextSize = 18 }, b)
	make("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }, b)
	return f, b
end
local function setButton(b: TextButton, text: string, color: Color3)
	b.Text = text
	UI.button(b, color)
end

for i, s in C.Skins do
	if not s.Premium then
		local _, b = card(i, s.Color, s.Name)
		local id = s.Id
		b.Activated:Connect(function()
			event:FireServer("Skin", id)
		end)
		table.insert(cards, {
			refresh = function()
				if player:GetAttribute("GloveStyle") == id then
					setButton(b, "✓ WORN", GREEN)
				elseif player:GetAttribute("Owns" .. id) then
					setButton(b, "WEAR", ORANGE)
				else
					local afford = (player:GetAttribute("Coins") or 0) >= s.Cost
					setButton(b, "💰 " .. s.Cost, if afford then ORANGE else Color3.fromRGB(170, 150, 140))
				end
			end,
		})
	end
end
local FruitModels = game.ReplicatedStorage:WaitForChild("FruitModels")
for i, h in C.Hats do
	local f, b = card(50 + i, h.Color, h.Name)
	local model = FruitModels:FindFirstChild(h.Id)
	if model then
		local view: ViewportFrame = make("ViewportFrame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 4), Size = UDim2.fromOffset(64, 64), BackgroundTransparency = 1, ZIndex = 3 }, f)
		local copy = model:Clone()
		copy:PivotTo(CFrame.new())
		copy.Parent = view
		local _, size = copy:GetBoundingBox()
		local cam: Camera = make("Camera", { FieldOfView = 30 }, view)
		cam.CFrame = CFrame.lookAt(Vector3.new(0, size.Y * 0.3, size.Magnitude * 2.1), Vector3.zero)
		view.CurrentCamera = cam
	end
	local id = h.Id
	b.Activated:Connect(function()
		if h.VipOnly and not player:GetAttribute("VIP") then
			openPanel("VIP")
		elseif h.PassOnly and not player:GetAttribute("OwnsHat" .. id) then
			openPanel("Pass")
		else
			event:FireServer("Hat", id)
		end
	end)
	table.insert(cards, {
		refresh = function()
			if player:GetAttribute("HatStyle") == id then
				setButton(b, "✓ ON", GREEN)
			elseif player:GetAttribute("OwnsHat" .. id) or (h.VipOnly and player:GetAttribute("VIP")) then
				setButton(b, "WEAR", ORANGE)
			elseif h.VipOnly then
				setButton(b, "⭐ VIP", GOLD)
			elseif h.PassOnly then
				setButton(b, "🎟️ PASS", Color3.fromRGB(150, 90, 255))
			else
				local afford = (player:GetAttribute("Coins") or 0) >= h.Cost
				setButton(b, "💰 " .. h.Cost, if afford then ORANGE else Color3.fromRGB(170, 150, 140))
			end
		end,
	})
end

local function price(id: number, kind: Enum.InfoType, b: TextButton, prefix: string)
	task.spawn(function()
		local ok, info = pcall(function()
			return MPS:GetProductInfo(id, kind)
		end)
		if ok and type(info) == "table" and info.PriceInRobux then
			b.Text = prefix .. "R$ " .. info.PriceInRobux
		end
	end)
end
if (C.PassId or 0) > 0 then
	local _, b = card(100, Color3.fromRGB(105, 224, 255), "✨ Aurora Gloves")
	b.Activated:Connect(function()
		if player:GetAttribute("AuroraPass") then
			event:FireServer("Skin", "Aurora")
		else
			MPS:PromptGamePassPurchase(player, C.PassId)
		end
	end)
	table.insert(cards, {
		refresh = function()
			if player:GetAttribute("GloveStyle") == "Aurora" then
				setButton(b, "✓ WORN", GREEN)
			elseif player:GetAttribute("AuroraPass") then
				setButton(b, "WEAR", ORANGE)
			else
				setButton(b, "R$", GOLD)
				price(C.PassId, Enum.InfoType.GamePass, b, "")
			end
		end,
	})
end
if (C.TrailPassId or 0) > 0 then
	local _, b = card(99, Color3.fromRGB(255, 150, 40), "🔥 Flame Trail")
	b.Activated:Connect(function()
		if not player:GetAttribute("TrailPass") then
			MPS:PromptGamePassPurchase(player, C.TrailPassId)
		end
	end)
	table.insert(cards, {
		refresh = function()
			if player:GetAttribute("TrailPass") then
				setButton(b, "✓ OWNED", GREEN)
			else
				setButton(b, "R$", GOLD)
				price(C.TrailPassId, Enum.InfoType.GamePass, b, "")
			end
		end,
	})
end
if (C.DoubleLavaPassId or 0) > 0 then
	local _, b = card(101, Color3.fromRGB(255, 90, 30), "🔥 2x Lava Coins")
	b.Activated:Connect(function()
		if not player:GetAttribute("DoubleLavaPass") then
			MPS:PromptGamePassPurchase(player, C.DoubleLavaPassId)
		end
	end)
	table.insert(cards, {
		refresh = function()
			if player:GetAttribute("DoubleLavaPass") then
				setButton(b, "✓ OWNED", GREEN)
			else
				setButton(b, "R$", GOLD)
				price(C.DoubleLavaPassId, Enum.InfoType.GamePass, b, "")
			end
		end,
	})
end
local AdService = game:GetService("AdService")
local adCard: Frame? = nil
if (C.ProductIds and C.ProductIds.Coins100 or 0) > 0 then
	local f, b = card(199, Color3.fromRGB(90, 200, 255), "📺 Free 100 coins")
	setButton(b, "WATCH AD", Color3.fromRGB(60, 160, 240))
	b.Activated:Connect(function()
		event:FireServer("WatchAd")
	end)
	f.Visible = false
	adCard = f
end
local function checkAd()
	local f = adCard
	if not f then
		return
	end
	task.spawn(function()
		local ok, result = pcall(function()
			return AdService:GetAdAvailabilityNowAsync(Enum.AdFormat.RewardedVideo)
		end)
		f.Visible = ok and result and result.AdAvailabilityResult == Enum.AdAvailabilityResult.IsAvailable or false
	end)
end
for i, tip in { { "Tip25", 25 }, { "Tip100", 100 }, { "Tip500", 500 }, { "Tip1000", 1000 } } do
	local id = C.ProductIds and C.ProductIds[tip[1]] or 0
	if id > 0 then
		local _, b = card(300 + i, Color3.fromRGB(255, 90, 150), "💖 Tip " .. tip[2])
		setButton(b, "R$ " .. tip[2], Color3.fromRGB(235, 60, 130))
		b.Activated:Connect(function()
			MPS:PromptProductPurchase(player, id)
		end)
	end
end
for i, pack in { { "Coins100", 100 }, { "Coins500", 500 }, { "Coins2000", 2000 }, { "Coins6000", 6000 } } do
	local id = C.ProductIds and C.ProductIds[pack[1]] or 0
	if id > 0 then
		local _, b = card(200 + i, GOLD, "💰 " .. pack[2] .. " coins")
		setButton(b, "R$", GOLD)
		price(id, Enum.InfoType.Product, b, "")
		b.Activated:Connect(function()
			MPS:PromptProductPurchase(player, id)
		end)
	end
end
local function refreshShop()
	for _, c in cards do
		c.refresh()
	end
end
for _, attr in { "Coins", "GloveStyle", "HatStyle", "AuroraPass", "DoubleLavaPass", "VIP", "LavaPassPremium", "TrailPass" } do
	player:GetAttributeChangedSignal(attr):Connect(refreshShop)
end
for _, s in C.Skins do
	player:GetAttributeChangedSignal("Owns" .. s.Id):Connect(refreshShop)
end
for _, h in C.Hats do
	player:GetAttributeChangedSignal("OwnsHat" .. h.Id):Connect(refreshShop)
end
refreshShop()

local shopScale = make("UIScale", {}, shop)
local function setShop(open: boolean)
	if open then
		checkAd()
		shop.Visible = true
		shopScale.Scale = 0.85
		TweenService:Create(shopScale, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	else
		shop.Visible = false
	end
end
close.Activated:Connect(function()
	setShop(false)
end)

Icon.new()
	:setName("Gloves")
	:setLabel(UI.short("🧤 Gloves", "🧤"))
	:align("Left")
	:oneClick()
	:modifyTheme(UI.pill(Color3.fromRGB(255, 160, 40)))
	:bindEvent("selected", function()
		setShop(not shop.Visible)
	end)

local function pill(color: Color3): { any }
	return UI.pill(color)
end

-- Lava Pass and VIP panels

local FRUIT_ICON = { Strawberry = "🍓", Banana = "🍌", Pineapple = "🍍", Watermelon = "🍉", Coconut = "🥥", Blueberry = "🫐", DragonFruit = "🐉", StarFruit = "🌟", GoldenApple = "🍎" }
local PURPLE = Color3.fromRGB(150, 90, 255)

local function panel(title: string, top: Color3, bottom: Color3): (Frame, Frame)
	local f: Frame = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.56), Size = UDim2.new(0.94, 0, 0.82, 0), BackgroundColor3 = CREAM, Visible = false }, gui)
	make("UISizeConstraint", { MaxSize = Vector2.new(560, 440) }, f)
	corner(f, 22)
	outline(f, 4)
	local bar = make("Frame", { Size = UDim2.new(1, 0, 0, 56), BackgroundColor3 = top }, f)
	corner(bar, 22)
	make("UIGradient", { Rotation = 90, Color = ColorSequence.new(top:Lerp(UI.Glass, 0.2), bottom:Lerp(UI.Glass, 0.5)) }, bar)
	local head = label(bar, title, 28, Color3.new(1, 1, 1))
	head.TextStrokeColor3 = UI.Shadow
	head.TextStrokeTransparency = 0.2
	local x = button(bar, "X", RED, UDim2.fromOffset(40, 40))
	x.AnchorPoint = Vector2.new(1, 0.5)
	x.Position = UDim2.new(1, -10, 0.5, 0)
	x.Activated:Connect(function()
		f.Visible = false
	end)
	local body = make("Frame", { Position = UDim2.fromOffset(12, 66), Size = UDim2.new(1, -24, 1, -78), BackgroundTransparency = 1 }, f)
	return f, body
end

local function rewardText(reward: any): string
	if reward.Coins then
		return "💰 " .. reward.Coins
	elseif reward.Hat then
		return (FRUIT_ICON[reward.Hat] or "🎩") .. " Hat"
	end
	return "?"
end

local function claimedSet(attr: string): { [number]: boolean }
	local out = {}
	for n in string.gmatch(tostring(player:GetAttribute(attr) or ""), "%d+") do
		out[tonumber(n) :: number] = true
	end
	return out
end

local passPanel, passBody = panel("🎟️ LAVA PASS", Color3.fromRGB(175, 110, 255), Color3.fromRGB(110, 60, 220))
local xpBack = make("Frame", { Size = UDim2.new(1, -150, 0, 26), BackgroundColor3 = UI.GlassLight }, passBody)
corner(xpBack, 13)
outline(xpBack, 3)
local xpFill = make("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = PURPLE }, xpBack)
corner(xpFill, 13)
local xpText = label(xpBack, "", 16, Color3.new(1, 1, 1))
xpText.TextStrokeColor3 = UI.Shadow
xpText.TextStrokeTransparency = 0.3
local premiumButton = button(passBody, "⭐ PREMIUM", GOLD, UDim2.fromOffset(140, 30))
premiumButton.AnchorPoint = Vector2.new(1, 0)
premiumButton.Position = UDim2.new(1, 0, 0, -2)
premiumButton.TextSize = 16
premiumButton.Activated:Connect(function()
	if (C.LavaPassPremiumId or 0) > 0 and not player:GetAttribute("LavaPassPremium") then
		MPS:PromptGamePassPurchase(player, C.LavaPassPremiumId)
	elseif (C.LavaPassPremiumId or 0) <= 0 then
		notify("Lava Pass Premium isn't on sale yet.")
	end
end)
local track = make("ScrollingFrame", { Position = UDim2.fromOffset(0, 40), Size = UDim2.new(1, 0, 1, -40), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 6, ScrollBarImageColor3 = INK, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.X, ScrollingDirection = Enum.ScrollingDirection.X }, passBody)
make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, track)
make("UIPadding", { PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4), PaddingTop = UDim.new(0, 4) }, track)
type TierCard = { freeButton: TextButton, premButton: TextButton, frame: Frame }
local tierCards: { TierCard } = {}
for tier, row in (C.LavaPass and C.LavaPass.Tiers or {}) do
	local f: Frame = make("Frame", { LayoutOrder = tier, Size = UDim2.new(0, 112, 1, -14), BackgroundColor3 = Color3.new(1, 1, 1) }, track)
	corner(f, 14)
	outline(f, 3)
	local n = label(f, "Tier " .. tier, 18)
	n.Size = UDim2.new(1, 0, 0, 26)
	local freeText = label(f, rewardText(row.Free), 18)
	freeText.Position = UDim2.fromOffset(0, 30)
	freeText.Size = UDim2.new(1, 0, 0, 26)
	local freeButton = button(f, "", ORANGE, UDim2.new(1, -14, 0, 32))
	freeButton.Position = UDim2.fromOffset(7, 58)
	freeButton.TextSize = 15
	local line = make("Frame", { Position = UDim2.new(0, 8, 0, 98), Size = UDim2.new(1, -16, 0, 2), BackgroundColor3 = INK:Lerp(CREAM, 0.6), BorderSizePixel = 0 }, f)
	local premTag = label(f, "⭐ Premium", 13, PURPLE)
	premTag.Position = UDim2.fromOffset(0, 104)
	premTag.Size = UDim2.new(1, 0, 0, 18)
	local premText = label(f, rewardText(row.Premium), 18)
	premText.Position = UDim2.fromOffset(0, 122)
	premText.Size = UDim2.new(1, 0, 0, 26)
	local premButton = button(f, "", PURPLE, UDim2.new(1, -14, 0, 32))
	premButton.Position = UDim2.fromOffset(7, 150)
	premButton.TextSize = 15
	freeButton.Activated:Connect(function()
		event:FireServer("PassClaim", { Tier = tier, Track = "Free" })
	end)
	premButton.Activated:Connect(function()
		if player:GetAttribute("LavaPassPremium") then
			event:FireServer("PassClaim", { Tier = tier, Track = "Premium" })
		elseif (C.LavaPassPremiumId or 0) > 0 then
			MPS:PromptGamePassPurchase(player, C.LavaPassPremiumId)
		end
	end)
	local _ = line
	table.insert(tierCards, { freeButton = freeButton, premButton = premButton, frame = f })
end
local function refreshPass()
	local xp = player:GetAttribute("PassXP") or 0
	local per = C.LavaPass and C.LavaPass.XPPerTier or 100
	local tier = player:GetAttribute("PassTier") or 0
	local maxed = tier >= #tierCards
	xpFill.Size = UDim2.fromScale(if maxed then 1 else (xp % per) / per, 1)
	xpText.Text = if maxed then "MAX TIER!" else string.format("Tier %d  •  %d / %d XP", tier, xp % per, per)
	local premium = player:GetAttribute("LavaPassPremium") == true
	setButton(premiumButton, if premium then "⭐ PREMIUM ✓" else "⭐ PREMIUM", if premium then GREEN else GOLD)
	local freeDone, premDone = claimedSet("PassFreeClaimed"), claimedSet("PassPremClaimed")
	for i, c in tierCards do
		local unlocked = tier >= i
		if freeDone[i] then
			setButton(c.freeButton, "✓", GREEN)
		elseif unlocked then
			setButton(c.freeButton, "CLAIM", ORANGE)
		else
			setButton(c.freeButton, "🔒", Color3.fromRGB(170, 150, 140))
		end
		if premDone[i] then
			setButton(c.premButton, "✓", GREEN)
		elseif not premium then
			setButton(c.premButton, "🔒 ⭐", Color3.fromRGB(170, 150, 140))
		elseif unlocked then
			setButton(c.premButton, "CLAIM", PURPLE)
		else
			setButton(c.premButton, "🔒", Color3.fromRGB(170, 150, 140))
		end
	end
end
for _, attr in { "PassXP", "PassTier", "PassFreeClaimed", "PassPremClaimed", "LavaPassPremium" } do
	player:GetAttributeChangedSignal(attr):Connect(refreshPass)
end
refreshPass()

local vipPanel, vipBody = panel("⭐ VIP", Color3.fromRGB(255, 215, 70), Color3.fromRGB(240, 150, 20))
local perks = label(vipBody, "⭐  VIP tag over your head and in chat\n🍎  Golden Apple hat (VIP only)\n🎁  Double daily rewards\n💰  +25% coins every round\n✨  Golden shimmer\n\nJust for looks and comfort. Everything else in LAVA Floors can be earned by playing.", 20)
perks.Size = UDim2.new(1, 0, 1, -60)
perks.TextWrapped = true
perks.TextYAlignment = Enum.TextYAlignment.Top
local vipButton = button(vipBody, "SUBSCRIBE", GOLD, UDim2.new(1, 0, 0, 48))
vipButton.AnchorPoint = Vector2.new(0, 1)
vipButton.Position = UDim2.fromScale(0, 1)
vipButton.TextSize = 24
local function refreshVip()
	if player:GetAttribute("VIP") then
		setButton(vipButton, "⭐ YOU'RE VIP — THANK YOU!", GREEN)
	elseif (C.VipPassId or 0) > 0 then
		setButton(vipButton, "GET VIP", GOLD)
		price(C.VipPassId, Enum.InfoType.GamePass, vipButton, "GET VIP · ")
	elseif type(C.VipSubscriptionId) == "string" and C.VipSubscriptionId ~= "" then
		setButton(vipButton, "SUBSCRIBE", GOLD)
	else
		setButton(vipButton, "COMING SOON", Color3.fromRGB(170, 150, 140))
	end
end
vipButton.Activated:Connect(function()
	if player:GetAttribute("VIP") then
		return
	end
	if (C.VipPassId or 0) > 0 then
		MPS:PromptGamePassPurchase(player, C.VipPassId)
	elseif type(C.VipSubscriptionId) == "string" and C.VipSubscriptionId ~= "" then
		pcall(function()
			MPS:PromptSubscriptionPurchase(player, C.VipSubscriptionId)
		end)
	end
end)
player:GetAttributeChangedSignal("VIP"):Connect(refreshVip)
refreshVip()

openPanel = function(which: string)
	shop.Visible = false
	passPanel.Visible = which == "Pass"
	vipPanel.Visible = which == "VIP"
	challengePanel.Visible = which == "Challenges"
	if which == "Challenges" then
		refreshChallenges()
	end
	if which == "Pass" then
		refreshPass()
	end
end

Icon.new()
	:setName("LavaPass")
	:setLabel(UI.short("🎟️ Pass", "🎟️"))
	:align("Left")
	:oneClick()
	:modifyTheme(pill(PURPLE))
	:bindEvent("selected", function()
		if passPanel.Visible then
			passPanel.Visible = false
		else
			openPanel("Pass")
		end
	end)
Icon.new()
	:setName("Vip")
	:setLabel(UI.short("⭐ VIP", "⭐"))
	:align("Left")
	:oneClick()
	:modifyTheme(pill(Color3.fromRGB(240, 170, 20)))
	:bindEvent("selected", function()
		if vipPanel.Visible then
			vipPanel.Visible = false
		else
			openPanel("VIP")
		end
	end)

-- Daily challenges panel: three challenges with progress bars, from the server's "Challenges" attribute.
local HttpService = game:GetService("HttpService")
local builtPanel, challengeBody = panel("📋 DAILY CHALLENGES", UI.Lava, UI.LavaDeep)
challengePanel = builtPanel
local challengeList = make("Frame", { Size = UDim2.new(1, 0, 1, -92), BackgroundTransparency = 1 }, challengeBody)
-- Codes: type one in and redeem it (the server checks it and pays once per account).
local codeRow = make("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, -30), Size = UDim2.new(1, 0, 0, 48), BackgroundTransparency = 1 }, challengeBody)
local codeBox: TextBox = make("TextBox", {
	Size = UDim2.new(1, -140, 1, 0),
	BackgroundColor3 = UI.GlassLight,
	BackgroundTransparency = 0.08,
	Font = FONT,
	TextSize = 20,
	TextColor3 = UI.Text,
	PlaceholderText = "🎁 Enter a code",
	PlaceholderColor3 = UI.Muted,
	Text = "",
	ClearTextOnFocus = false,
}, codeRow)
corner(codeBox, 12)
outline(codeBox, 2)
local redeem = button(codeRow, "REDEEM", GREEN, UDim2.new(0, 128, 1, 0))
redeem.AnchorPoint = Vector2.new(1, 0)
redeem.Position = UDim2.fromScale(1, 0)
redeem.TextSize = 20
redeem.Activated:Connect(function()
	local code = codeBox.Text
	if #code > 0 then
		event:FireServer("RedeemCode", code)
		codeBox.Text = ""
	end
end)
make("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }, challengeList)
local challengeFoot = label(challengeBody, "", 15, INK:Lerp(CREAM, 0.35))
challengeFoot.AnchorPoint = Vector2.new(0, 1)
challengeFoot.Position = UDim2.fromScale(0, 1)
challengeFoot.Size = UDim2.new(1, 0, 0, 26)
refreshChallenges = function()
	for _, c in challengeList:GetChildren() do
		if c:IsA("Frame") then
			c:Destroy()
		end
	end
	local raw = player:GetAttribute("Challenges")
	local ok, info = pcall(function()
		return HttpService:JSONDecode(if type(raw) == "string" then raw else "{}")
	end)
	local list = if ok and type(info) == "table" and type(info.List) == "table" then info.List else {}
	for i, c in list do
		local row: Frame = make("Frame", { LayoutOrder = i, Size = UDim2.new(1, 0, 0, 70), BackgroundColor3 = Color3.new(1, 1, 1) }, challengeList)
		corner(row, 14)
		outline(row, 2, if c.Done then GREEN else nil)
		local text = label(row, (if c.Done then "✅ " else "") .. tostring(c.Text), 20)
		text.Position = UDim2.fromOffset(14, 6)
		text.Size = UDim2.new(1, -120, 0, 28)
		text.TextXAlignment = Enum.TextXAlignment.Left
		local reward = label(row, "+" .. tostring(c.Reward) .. " 💰", 20, UI.Gold)
		reward.AnchorPoint = Vector2.new(1, 0)
		reward.Position = UDim2.new(1, -14, 0, 6)
		reward.Size = UDim2.fromOffset(100, 28)
		reward.TextXAlignment = Enum.TextXAlignment.Right
		local back = make("Frame", { Position = UDim2.fromOffset(14, 42), Size = UDim2.new(1, -28, 0, 14), BackgroundColor3 = UI.Glass, BackgroundTransparency = 0.2 }, row)
		corner(back, 7)
		local frac = math.clamp((tonumber(c.Progress) or 0) / math.max(1, tonumber(c.Goal) or 1), 0, 1)
		local fill = make("Frame", { Size = UDim2.fromScale(frac, 1), BackgroundColor3 = if c.Done then GREEN else UI.Lava, BorderSizePixel = 0 }, back)
		make("UICorner", { CornerRadius = UDim.new(0, 7) }, fill)
		local count = label(back, string.format("%d / %d", tonumber(c.Progress) or 0, tonumber(c.Goal) or 0), 12)
		count.ZIndex = 3
	end
	local secs = 86400 - (os.time() % 86400)
	challengeFoot.Text = string.format("New challenges in %dh %dm", math.floor(secs / 3600), math.floor(secs % 3600 / 60))
end
player:GetAttributeChangedSignal("Challenges"):Connect(refreshChallenges)
refreshChallenges()
Icon.new()
	:setName("Challenges")
	:setLabel(UI.short("📋 Challenges", "📋"))
	:align("Left")
	:oneClick()
	:modifyTheme(pill(UI.Lava))
	:bindEvent("selected", function()
		if challengePanel.Visible then
			challengePanel.Visible = false
		else
			openPanel("Challenges")
		end
	end)

-- Seasonal event pill: shows the running event, its coin bonus and how long is left.
local eventIcon = Icon.new():setName("Event"):setLabel(""):align("Left"):lock():modifyTheme(pill(UI.Gold))
local function refreshEvent()
	local id = workspace:GetAttribute("LavaEvent")
	local ends = workspace:GetAttribute("LavaEventEnds")
	local found = nil
	for _, e in C.Events or {} do
		if e.Id == id then
			found = e
		end
	end
	if not found then
		eventIcon:setEnabled(false)
		return
	end
	local left = if type(ends) == "number" then math.max(0, ends - os.time()) else 0
	local days = math.floor(left / 86400)
	local when = if days >= 1 then days .. "d" else math.floor(left / 3600) .. "h"
	local bonus = math.floor((found.CoinBonus or 0) * 100)
	eventIcon:setLabel(UI.short(string.format("%s · +%d%% 💰 · %s", found.Short or found.Name, bonus, when), string.format("%s +%d%%", string.match(found.Short or found.Name, "^(%S+)") or "", bonus)))
	eventIcon:setEnabled(true)
end
workspace:GetAttributeChangedSignal("LavaEvent"):Connect(refreshEvent)
workspace:GetAttributeChangedSignal("LavaEventEnds"):Connect(refreshEvent)
refreshEvent()
task.spawn(function()
	while true do
		task.wait(60)
		refreshEvent()
	end
end)

-- Server goal pill: the shared bar every climber in this server fills together (rises reached).
-- Always the short label: the left side of the top bar is already full on laptop-sized windows.
local goalIcon = Icon.new():setName("ServerGoal"):setLabel(""):align("Left"):lock():modifyTheme(pill(Color3.fromRGB(235, 90, 20)))
goalIcon:setCaption("Server goal: every rise anyone climbs fills it. Full = coins for all who helped!")
local function refreshGoal()
	local have, size = tonumber(workspace:GetAttribute("LavaGoal")), tonumber(workspace:GetAttribute("LavaGoalSize"))
	if not have or not size or size <= 0 then
		goalIcon:setEnabled(false)
		return
	end
	goalIcon:setLabel(string.format("🌋 %d/%d", have, size))
	goalIcon:setEnabled(true)
end
workspace:GetAttributeChangedSignal("LavaGoal"):Connect(refreshGoal)
workspace:GetAttributeChangedSignal("LavaGoalSize"):Connect(refreshGoal)
refreshGoal()

-- VIP chat tag
local TextChatService = game:GetService("TextChatService")
TextChatService.OnIncomingMessage = function(message: TextChatMessage)
	local props = Instance.new("TextChatMessageProperties")
	local source = message.TextSource
	local who = source and Players:GetPlayerByUserId(source.UserId)
	if who and who:GetAttribute("VIP") then
		props.PrefixText = '<font color="#FFD24A">[⭐ VIP]</font> ' .. message.PrefixText
	end
	return props
end

local SocialService = game:GetService("SocialService")
local FRIEND_DEAL = (require(game.ReplicatedStorage:WaitForChild("SkySproutConfig")) :: any).FriendDeal
	or { InviteCoins = 150, Bonus = 0.25 }
Icon.new()
	:setName("Invite")
	:setLabel(UI.short("👥 Invite +" .. tostring(FRIEND_DEAL.InviteCoins) .. "💰", "👥 +" .. tostring(FRIEND_DEAL.InviteCoins)))
	:align("Right")
	:oneClick()
	:setCaption(string.format("Invite a friend: you BOTH get %d coins • Play together: +%d%% coins", FRIEND_DEAL.InviteCoins, math.floor(FRIEND_DEAL.Bonus * 100)))
	:modifyTheme(pill(Color3.fromRGB(70, 190, 90)))
	:bindEvent("selected", function()
		local ok, can = pcall(function()
			return SocialService:CanSendGameInviteAsync(player)
		end)
		if ok and can then
			notify(string.format("🎁 Friends who join from your invite: you both get %d coins!", FRIEND_DEAL.InviteCoins))
			pcall(function()
				local options = Instance.new("ExperienceInviteOptions")
				options.PromptMessage = string.format("Escape the volcano together! You both get %d coins when they join.", FRIEND_DEAL.InviteCoins)
				SocialService:PromptGameInvite(player, options)
			end)
		else
			notify("Invites aren't available here — share the game with your friends!")
		end
	end)

local music = make("Sound", { Name = "LavaFloorsMusic", SoundId = "rbxassetid://1837768107", Looped = true, Volume = 0.22 }, game:GetService("SoundService"))
music:Play()
-- Emotes: six free emotes (Roblox's own default animations) from a top bar button, so kids can wave, cheer and
-- dance without typing. Dances loop until you move; winning the crown plays a cheer automatically.
local EMOTES = {
	{ Icon = "👋", Name = "Wave", Id = "rbxassetid://507770239", Loop = false },
	{ Icon = "🙌", Name = "Cheer", Id = "rbxassetid://507770677", Loop = false },
	{ Icon = "😂", Name = "Laugh", Id = "rbxassetid://507770818", Loop = false },
	{ Icon = "👉", Name = "Point", Id = "rbxassetid://507770453", Loop = false },
	{ Icon = "💃", Name = "Dance", Id = "rbxassetid://507771019", Loop = true },
	{ Icon = "🕺", Name = "Groove", Id = "rbxassetid://507776043", Loop = true },
}
local emoteTrack: AnimationTrack? = nil
local function playEmote(id: string, loop: boolean)
	local character = player.Character
	local hum = character and character:FindFirstChildOfClass("Humanoid")
	if not hum then
		return
	end
	local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator")
	animator.Parent = hum
	if emoteTrack then
		emoteTrack:Stop(0.2)
	end
	local animation = Instance.new("Animation")
	animation.AnimationId = id
	local ok, track = pcall(function()
		return (animator :: Animator):LoadAnimation(animation)
	end)
	if ok and track then
		track.Priority = Enum.AnimationPriority.Action
		track.Looped = loop
		track:Play(0.2)
		emoteTrack = track
	end
end
game:GetService("RunService").Heartbeat:Connect(function()
	local track = emoteTrack
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if track and track.IsPlaying and track.Looped and hum and hum.MoveDirection.Magnitude > 0.1 then
		track:Stop(0.3) -- moving ends a dance
		emoteTrack = nil
	end
end)
local emotePanel = make("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -96), Size = UDim2.fromOffset(312, 132), BackgroundColor3 = CREAM, Visible = false }, gui)
corner(emotePanel, 18)
outline(emotePanel, 2)
make("UIPadding", { PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10), PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }, emotePanel)
make("UIGridLayout", { CellSize = UDim2.new(1 / 3, -8, 0.5, -5), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder }, emotePanel)
for i, e in EMOTES do
	local b = button(emotePanel, e.Icon .. " " .. e.Name, ORANGE, UDim2.new())
	b.LayoutOrder = i
	b.TextScaled = true
	make("UITextSizeConstraint", { MaxTextSize = 18 }, b)
	make("UIPadding", { PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4) }, b)
	b.Activated:Connect(function()
		playEmote(e.Id, e.Loop)
		emotePanel.Visible = false
	end)
end
Icon.new()
	:setName("Emotes")
	:setLabel(UI.short("😀 Emotes", "😀"))
	:align("Right")
	:oneClick()
	:modifyTheme(pill(Color3.fromRGB(255, 200, 80)))
	:bindEvent("selected", function()
		emotePanel.Visible = not emotePanel.Visible
	end)

local musicIcon = Icon.new():setName("Music"):setLabel("🎵"):align("Right"):oneClick():modifyTheme(pill(Color3.fromRGB(150, 90, 255)))
musicIcon:bindEvent("selected", function()
	if music.Playing then
		music:Pause()
		musicIcon:setLabel("🔇")
	else
		music:Resume()
		musicIcon:setLabel("🎵")
	end
end)

local function shove()
	event:FireServer("Punch")
end
UIS.InputBegan:Connect(function(input, processed)
	if processed or shop.Visible or UIS:GetFocusedTextBox() then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		shove()
	end
end)
CAS:BindAction("LavaShove", function(_, state)
	if state == Enum.UserInputState.Begin and not shop.Visible then
		shove()
	end
	return Enum.ContextActionResult.Sink
end, false, Enum.KeyCode.ButtonR2)
if UIS.TouchEnabled then
	local b = button(gui, "💥\nSHOVE", RED, UDim2.fromOffset(96, 96))
	b.AnchorPoint = Vector2.new(1, 1)
	-- Clear of the climb meter on the right edge, and above Roblox's jump button (which is bigger on tablets).
	b.Position = UDim2.new(1, -64, 1, if UI.isCompact() then -150 else -250)
	b.Name = "ShoveButton"
	b.TextSize = 20
	(b:FindFirstChildOfClass("UICorner") :: UICorner).CornerRadius = UDim.new(0, 48)
	b.Activated:Connect(shove)
end

local function raise()
	event:FireServer("LavaLift")
end
CAS:BindAction("LavaRaise", function(_, state)
	if state == Enum.UserInputState.Begin and not shop.Visible then
		raise()
	end
	return Enum.ContextActionResult.Sink
end, false, Enum.KeyCode.E, Enum.KeyCode.ButtonY)
local raiseButton = button(gui, "⬆️ RAISE" .. string.char(10) .. "40 💰", Color3.fromRGB(255, 185, 40), UDim2.fromOffset(96, 72))
raiseButton.AnchorPoint = Vector2.new(1, 1)
raiseButton.Position = if UIS.TouchEnabled then UDim2.new(1, -172, 1, if UI.isCompact() then -150 else -250) else UDim2.new(1, -24, 1, -150)
raiseButton.TextSize = 18
raiseButton.Visible = false
raiseButton.Activated:Connect(raise)
local function showRaise()
	local inRound = player:GetAttribute("ArenaMode") == "LavaRush"
	raiseButton.Visible = inRound
	local shoveButton = gui:FindFirstChild("ShoveButton")
	if shoveButton and shoveButton:IsA("GuiObject") then
		shoveButton.Visible = inRound -- shoving only does something in a round
	end
end
player:GetAttributeChangedSignal("ArenaMode"):Connect(showRaise)
showRaise()

local function cameraBehind()
	task.wait(0.4)
	local character = player.Character
	local r = character and character:FindFirstChild("HumanoidRootPart")
	local cam = workspace.CurrentCamera
	if r and r:IsA("BasePart") and cam then
		local look = r.CFrame.LookVector
		cam.CFrame = CFrame.lookAt(r.Position - look * 12 + Vector3.new(0, 5, 0), r.Position + look * 20 + Vector3.new(0, 8, 0))
	end
end
player.CharacterAdded:Connect(function()
	task.wait(1)
	cameraBehind()
end)
player:GetAttributeChangedSignal("ArenaMode"):Connect(function()
	local mode = player:GetAttribute("ArenaMode")
	if mode == "Lobby" or mode == "LavaRush" then
		cameraBehind()
	end
end)
task.spawn(function()
	task.wait(1.5)
	cameraBehind()
end)

event.OnClientEvent:Connect(function(kind: string, v: any)
	if kind == "Notice" and type(v) == "string" then
		notify(v)
	elseif kind == "LavaFX" and type(v) == "table" and v.Kind == "Crown" and v.Mine then
		task.delay(0.3, playEmote, EMOTES[2].Id, false) -- you won: cheer!
	end
end)
event:FireServer("Sync")
