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
local Icons = require(RS:WaitForChild("LavaIcons")) :: any -- Flibpook top bar images

require(RS:WaitForChild("SkySproutWaterClient")).Start()
require(RS:WaitForChild("SkySproutPerception")).Start()
require(RS:WaitForChild("SkySproutRendering")).Start()

local UI = require(RS:WaitForChild("LavaUI")) :: any
-- Dark glass + lava style (see Shared/LavaUI). CREAM is the panel glass and INK the light text on it.
local CREAM = UI.Glass
local INK = UI.Text
local ORANGE = UI.Lava -- the lava accent, so ORANGE buttons follow the world theme (#128; was 255, 122, 40)
local GREEN = Color3.fromRGB(70, 200, 90)
local GOLD = Color3.fromRGB(255, 196, 45)
local RED = Color3.fromRGB(235, 70, 60)
local FONT = Enum.Font.LuckiestGuy

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
			v.BackgroundColor3 = UI.GlassTint -- panel glass follows the world theme (#128)
			v:SetAttribute("ThemeGlass", true)
		elseif v.BackgroundColor3 == Color3.new(1, 1, 1) then
			v.BackgroundColor3 = UI.GlassLightTint -- cards follow the world theme (#128)
			v:SetAttribute("ThemeGlassLight", true)
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
-- Coin and crown pictures from the Flibpook pack (LavaIcons), numbers a size up from the old emoji chip.
local coinIcon: ImageLabel = make("ImageLabel", { Name = "CoinIcon", BackgroundTransparency = 1, Image = Icons.Coin, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 10, 0.5, 0), Size = UDim2.fromOffset(32, 32) }, chip)
local coinBounce: UIScale = make("UIScale", {}, coinIcon)
local coinsText = label(chip, "0", 30, UI.Gold)
coinsText.Position = UDim2.fromOffset(46, 0)
coinsText.Size = UDim2.new(0.6, -46, 1, 0)
coinsText.TextXAlignment = Enum.TextXAlignment.Left
make("ImageLabel", { Name = "CrownIcon", BackgroundTransparency = 1, Image = Icons.Crown, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0.6, 0, 0.5, 0), Size = UDim2.fromOffset(30, 30) }, chip)
local crownsText = label(chip, "0", 28, UI.Gold)
crownsText.Position = UDim2.new(0.6, 34, 0, 0)
crownsText.Size = UDim2.new(0.4, -44, 1, 0)
crownsText.TextXAlignment = Enum.TextXAlignment.Left
local function stats()
	crownsText.Text = tostring(player:GetAttribute("Crowns") or 0)
end
-- Juicy coins: when coins go up the number counts up, the coin gives a little bounce and a gold "+N" floats up beside
-- the panel. Spending (or Roblox's Reduce Motion setting) just sets the number.
local shownCoins: number? = nil
local coinCount = 0 -- the latest count-up; an older one stops when a newer gain arrives
-- A short, quiet ping with each gain (a sound that ships with Roblox, pitched up a little).
local coinSound: Sound = make("Sound", { Name = "CoinPing", SoundId = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.3, PlaybackSpeed = 1.3 }, script)
local function calmMotion(): boolean
	local ok, on = pcall(function()
		return (game:GetService("GuiService") :: any).ReducedMotionEnabled
	end)
	return ok and on == true
end
local function showCoins()
	local target = tonumber(player:GetAttribute("Coins")) or 0
	local from = shownCoins
	shownCoins = target
	coinCount += 1
	if from ~= nil and target > from then
		coinSound:Play()
	end
	if from == nil or target <= from or calmMotion() then
		coinsText.Text = tostring(target)
		return
	end
	local mine = coinCount
	local gained = target - from
	coinBounce.Scale = 1.35
	TweenService:Create(coinBounce, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	local float = label(gui, "+" .. tostring(gained), 26, UI.Gold)
	float.AnchorPoint = Vector2.new(0, 0.5)
	float.Position = UDim2.fromOffset(220, 32)
	float.Size = UDim2.fromOffset(140, 32)
	float.TextXAlignment = Enum.TextXAlignment.Left
	UI.text(float, "body")
	float.TextColor3 = UI.Gold
	local fade = TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(float, fade, { Position = UDim2.fromOffset(220, 12), TextTransparency = 1 }):Play()
	local outline = float:FindFirstChildWhichIsA("UIStroke")
	if outline then
		TweenService:Create(outline, fade, { Transparency = 1 }):Play()
	end
	task.delay(1.05, function()
		float:Destroy()
	end)
	task.spawn(function()
		local started = os.clock()
		while mine == coinCount do
			local a = math.min(1, (os.clock() - started) / 0.6)
			coinsText.Text = tostring(math.floor(from + gained * (1 - (1 - a) ^ 2) + 0.5))
			if a >= 1 then
				break
			end
			task.wait()
		end
	end)
end
player:GetAttributeChangedSignal("Coins"):Connect(showCoins)
player:GetAttributeChangedSignal("Crowns"):Connect(stats)
stats()
showCoins()

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
-- Toasts queue up (#125), like the HUD notice: each stays at least TOAST_MIN seconds while others wait, the last one
-- TOAST_HOLD, and a flood keeps only the newest TOAST_MAX.
local TOAST_MIN, TOAST_HOLD, TOAST_MAX = 1.8, 3.6, 5
local toastQueue: { string } = {}
local toastBusy = false
local function notify(text: string)
	table.insert(toastQueue, text)
	while #toastQueue > TOAST_MAX do
		table.remove(toastQueue, 1)
	end
	if toastBusy then
		return
	end
	toastBusy = true
	task.spawn(function()
		while #toastQueue > 0 do
			toastToken += 1
			toastText.Text = table.remove(toastQueue, 1) :: string
			toast.Visible = true
			local shown = os.clock()
			while os.clock() - shown < TOAST_HOLD and not (#toastQueue > 0 and os.clock() - shown >= TOAST_MIN) do
				task.wait(0.1)
			end
		end
		toast.Visible = false
		toastBusy = false
	end)
end

local shop = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.56), Size = UDim2.new(0.94, 0, 0.82, 0), BackgroundColor3 = CREAM, Visible = false }, gui)
make("UISizeConstraint", { MaxSize = Vector2.new(460, 520) }, shop)
corner(shop, 22)
outline(shop, 4)
local ribbon = make("Frame", { Position = UDim2.fromOffset(0, 0), Size = UDim2.new(1, 0, 0, 56), BackgroundColor3 = ORANGE }, shop)
corner(ribbon, 22)
UI.accentFill(ribbon, 0, 0.3) -- lava ribbon that follows the world theme (#128)
local heading = label(ribbon, "🧤 GLOVES", 28, Color3.new(1, 1, 1))
heading.TextStrokeColor3 = UI.Shadow
heading.TextStrokeTransparency = 0.2
local close = button(ribbon, "X", RED, UDim2.fromOffset(40, 40))
close.AnchorPoint = Vector2.new(1, 0.5)
close.Position = UDim2.new(1, -10, 0.5, 0)
local list = make("ScrollingFrame", { Position = UDim2.fromOffset(12, 66), Size = UDim2.new(1, -24, 1, -110), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 6, ScrollBarImageColor3 = INK, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y }, shop)
make("UIGridLayout", { CellSize = UDim2.new(0.5, -8, 0, 150), CellPadding = UDim2.fromOffset(10, 10), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center }, list)
make("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 8) }, list)
local foot = label(shop, "Gloves, hats and buddies are just for looks. Robux items are optional.", 14, INK:Lerp(CREAM, 0.35))
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
-- Try-on mirror (#140): standing on the mirror stage on the hub deck shows a TRY button on every glove, hat and buddy
-- card; the server puts the item on you for a while. Nothing is saved or bought: buying is the card's own button.
local tryButtons: { TextButton } = {}
local function tryButton(f: Frame, kind: string, id: string)
	local t = button(f, "\u{2728} TRY", Color3.fromRGB(90, 170, 255), UDim2.fromOffset(64, 26))
	t.AnchorPoint = Vector2.new(1, 0)
	t.Position = UDim2.new(1, -6, 0, 6)
	t.TextScaled = true
	t.ZIndex = 4
	t.Visible = player:GetAttribute("OnMirror") == true
	t.Activated:Connect(function()
		event:FireServer("LavaTryOn", { Kind = kind, Id = id })
	end)
	table.insert(tryButtons, t)
end
local function setButton(b: TextButton, text: string, color: Color3)
	b.Text = text
	UI.button(b, color)
	local coin = b:FindFirstChild("CoinIcon")
	if coin and coin:IsA("ImageLabel") then
		coin.Visible = false -- a price button that now says WEAR / ✓ WORN
	end
end
-- The Flibpook coin (as on the coins panel) just left of a label's centred text, instead of 💰. Kept in place when
-- the text or size changes; returns the (re-used) icon.
local function coinBeside(target: TextLabel | TextButton): ImageLabel
	local existing = target:FindFirstChild("CoinIcon")
	if existing and existing:IsA("ImageLabel") then
		existing.Visible = true
		return existing
	end
	local icon: ImageLabel = make("ImageLabel", { Name = "CoinIcon", BackgroundTransparency = 1, Image = Icons.Coin, AnchorPoint = Vector2.new(1, 0.5), Size = UDim2.fromScale(0.62, 0.62), SizeConstraint = Enum.SizeConstraint.RelativeYY }, target)
	local function place()
		local width = target.AbsoluteSize.X
		if width > 0 then
			icon.Position = UDim2.new(0.5 - target.TextBounds.X / width / 2, -3, 0.5, 0)
		end
	end
	target:GetPropertyChangedSignal("TextBounds"):Connect(place)
	target:GetPropertyChangedSignal("AbsoluteSize"):Connect(place)
	task.defer(place)
	return icon
end
local function setPrice(b: TextButton, amount: number, color: Color3)
	setButton(b, tostring(amount), color)
	coinBeside(b)
end

for i, s in C.Skins do
	if not s.Premium then
		local f, b = card(i, s.Color, s.Name)
		tryButton(f, "Skin", s.Id)
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
					setPrice(b, s.Cost, if afford then ORANGE else Color3.fromRGB(170, 150, 140))
				end
			end,
		})
	end
end
local FruitModels = game.ReplicatedStorage:WaitForChild("FruitModels")
for i, h in C.Hats do
	local f, b = card(50 + i, h.Color, h.Name)
	tryButton(f, "Hat", h.Id)
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
				setPrice(b, h.Cost, if afford then ORANGE else Color3.fromRGB(170, 150, 140))
			end
		end,
	})
end

-- Fruit buddies: little fruit pets that float by your shoulder (coins only). Theme buddies (FindIn) aren't sold: the
-- card says which world to find them in.
for i, h in C.Pets or {} do
	local f, b = card(80 + i, h.Color, "🐾 " .. h.Name)
	tryButton(f, "Pet", h.Id)
	local model = FruitModels:FindFirstChild(h.Model or h.Id)
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
		event:FireServer("Pet", id)
	end)
	table.insert(cards, {
		refresh = function()
			if player:GetAttribute("PetStyle") == id then
				setButton(b, "✓ WITH YOU", GREEN)
			elseif player:GetAttribute("OwnsPet" .. id) then
				setButton(b, "BRING", ORANGE)
			elseif h.FindIn then
				setButton(b, "Find in " .. (h.Where or "its world"), Color3.fromRGB(170, 150, 140))
			else
				local afford = (player:GetAttribute("Coins") or 0) >= h.Cost
				setPrice(b, h.Cost, if afford then ORANGE else Color3.fromRGB(170, 150, 140))
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
	local f, b = card(100, Color3.fromRGB(105, 224, 255), "✨ Aurora Gloves")
	tryButton(f, "Skin", "Aurora")
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
for _, attr in { "Coins", "GloveStyle", "HatStyle", "PetStyle", "AuroraPass", "DoubleLavaPass", "VIP", "LavaPassPremium", "TrailPass" } do
	player:GetAttributeChangedSignal(attr):Connect(refreshShop)
end
for _, s in C.Skins do
	player:GetAttributeChangedSignal("Owns" .. s.Id):Connect(refreshShop)
end
for _, h in C.Hats do
	player:GetAttributeChangedSignal("OwnsHat" .. h.Id):Connect(refreshShop)
end
for _, h in C.Pets or {} do
	player:GetAttributeChangedSignal("OwnsPet" .. h.Id):Connect(refreshShop)
end
-- Fruit buddies bob and sway a little (on this screen only; the server keeps them still). Reduce Motion stops it.
game:GetService("RunService").Heartbeat:Connect(function()
	local calm = false
	pcall(function()
		calm = (game:GetService("GuiService") :: any).ReducedMotionEnabled == true
	end)
	local t = os.clock()
	for i, other in Players:GetPlayers() do
		local buddy = other.Character and other.Character:FindFirstChild("FruitBuddy")
		local core = buddy and buddy:FindFirstChild("BuddyCore")
		local weld = core and core:FindFirstChild("BuddyWeld")
		local base = weld and weld:GetAttribute("Base")
		if weld and weld:IsA("Weld") and typeof(base) == "CFrame" then
			local s = base.Position.Y / 1.5 -- follows the character's scale
			weld.C0 = if calm then base else base * CFrame.new(0, math.sin(t * 2.4 + i) * 0.22 * s, 0) * CFrame.Angles(0, math.sin(t * 1.3 + i) * 0.35, 0)
		end
	end
end)
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
	:setImage(Icons.Shop)
	:setLabel(UI.tight("Gloves", ""))
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
	if top == UI.Lava then
		UI.accentFill(bar, 0.2, 0.5) -- lava header bars follow the world theme (#128); other colours stay
	else
		make("UIGradient", { Rotation = 90, Color = ColorSequence.new(top:Lerp(UI.Glass, 0.2), bottom:Lerp(UI.Glass, 0.5)) }, bar)
	end
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
		return tostring(reward.Coins) -- the coin picture is added beside it (coinBeside)
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
	if row.Free and row.Free.Coins then
		coinBeside(freeText)
	end
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
	if row.Premium and row.Premium.Coins then
		coinBeside(premText)
	end
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
	:setImage(Icons.GemPurple)
	:setLabel(UI.tight("Pass", ""))
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
	:setImage(Icons.Crown)
	:setLabel(UI.tight("VIP", ""))
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
builtPanel.Name = "ChallengesPanel" -- unique names so tests can reach the title button by path
challengeBody.Name = "Body"
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
challengeFoot.Size = UDim2.new(0.42, 0, 0, 26)
challengeFoot.TextXAlignment = Enum.TextXAlignment.Left
-- Title picker: cycles through the titles you've unlocked (server list in the "LavaTitles" attribute); the server
-- checks the pick and shows it over your head.
local titleButton = button(challengeBody, "🏷️ Title", UI.LavaDeep, UDim2.new(0.56, 0, 0, 26))
titleButton.Name = "TitleButton"
titleButton.AnchorPoint = Vector2.new(1, 1)
titleButton.Position = UDim2.fromScale(1, 1)
titleButton.TextSize = 15
local function titleInfo(): ({ { Id: string, Text: string } }, string)
	local ok, info = pcall(function()
		local raw = player:GetAttribute("LavaTitles")
		return HttpService:JSONDecode(if type(raw) == "string" then raw else "{}")
	end)
	local list = if ok and type(info) == "table" and type(info.List) == "table" then info.List else {}
	return list, if ok and type(info) == "table" and type(info.Current) == "string" then info.Current else "Auto"
end
local function refreshTitle()
	local list, current = titleInfo()
	local text = "Auto"
	for _, t in list do
		if t.Id == current then
			text = tostring(t.Text)
		end
	end
	titleButton.Text = string.format("🏷️ %s  ▶", text)
end
titleButton.Activated:Connect(function()
	local list, current = titleInfo()
	if #list < 2 then
		return
	end
	local index = 1
	for i, t in list do
		if t.Id == current then
			index = i
		end
	end
	event:FireServer("LavaTitle", tostring(list[index % #list + 1].Id))
end)
player:GetAttributeChangedSignal("LavaTitles"):Connect(refreshTitle)
refreshTitle()
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
		local reward = label(row, "+" .. tostring(c.Reward), 20, UI.Gold)
		reward.AnchorPoint = Vector2.new(1, 0)
		reward.Position = UDim2.new(1, -42, 0, 6)
		reward.Size = UDim2.fromOffset(72, 28)
		reward.TextXAlignment = Enum.TextXAlignment.Right
		make("ImageLabel", { Name = "CoinIcon", BackgroundTransparency = 1, Image = Icons.Coin, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 7), Size = UDim2.fromOffset(26, 26) }, row)
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
	:setImage(Icons.Checkmark)
	:setLabel(UI.tight("Challenges", ""))
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
	eventIcon:setLabel(UI.tight(string.format("%s · +%d%% 💰 · %s", found.Short or found.Name, bonus, when), string.format("%s +%d%%", string.match(found.Short or found.Name, "^(%S+)") or "", bonus)))
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
local goalIcon = Icon.new():setName("ServerGoal"):setImage(Icons.Trophy):setLabel(""):align("Left"):lock():modifyTheme(pill(Color3.fromRGB(235, 90, 20)))
goalIcon:setCaption("Server goal: every rise anyone climbs fills it. Full = coins for all who helped!")
local function refreshGoal()
	local have, size = tonumber(workspace:GetAttribute("LavaGoal")), tonumber(workspace:GetAttribute("LavaGoalSize"))
	if not have or not size or size <= 0 then
		goalIcon:setEnabled(false)
		return
	end
	goalIcon:setLabel(string.format("%d/%d", have, size))
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
	:setImage(Icons.Heart)
	:setLabel(UI.tight("Invite +" .. tostring(FRIEND_DEAL.InviteCoins) .. "💰", UI.short("+" .. tostring(FRIEND_DEAL.InviteCoins), "")))
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

-- Music: free tracks Roblox licenses for experiences (APM Music, from the Creator Store). An island tune in the lobby
-- ("Hawaiian Parkour (b)") and driving drums for the climb ("Natural Disaster", climax version). Both sit in one
-- SoundGroup, so 🔇 mutes them together.
local musicGroup: SoundGroup = make("SoundGroup", { Name = "LavaFloorsMusic", Volume = 1 }, game:GetService("SoundService"))
local music = make("Sound", { Name = "LobbyMusic", SoundId = "rbxassetid://1837792555", Looped = true, Volume = 0.22, SoundGroup = musicGroup }, musicGroup)
music:Play()
-- The climb has its own track: it starts from the top when a round starts, plays a little faster each lava phase and a
-- bit louder in the last one, then fades back to the lobby tune. Everyone hears it, climbers and watchers alike.
do
	local Grid = require(RS:WaitForChild("LavaGrid")) :: any
	local TweenService = game:GetService("TweenService")
	local roundMusic = make("Sound", { Name = "RoundMusic", SoundId = "rbxassetid://9045720005", Looped = true, Volume = 0, SoundGroup = musicGroup }, musicGroup)
	roundMusic:Play()
	-- The drums are ~1.8x as loud as the island tune (PlaybackLoudness 222 vs 123), so the round plays quieter.
	local LOBBY_VOLUME, ROUND_VOLUME, FINAL_VOLUME, SPEED_STEP = 0.22, 0.14, 0.19, 0.05
	local lastPhase = -2
	local roundPhase: string? = nil -- from LavaState; a round can end early (everyone out) while the tower stays up
	event.OnClientEvent:Connect(function(kind: string, v: any)
		if kind == "LavaState" and type(v) == "table" and type(v.Phase) == "string" then
			roundPhase = v.Phase
		end
	end)
	task.spawn(function()
		while true do
			local floors = workspace:FindFirstChild("SkySprout") and workspace.SkySprout:FindFirstChild("Floors")
			local arena = floors and floors:FindFirstChild("Floor_1") and floors.Floor_1:FindFirstChild("LavaRush")
			local tower = arena and arena:FindFirstChild("LavaRushTower")
			local phase = if tower then Grid.Phase(tower, workspace:GetServerTimeNow()) else -1
			local phases = tower and tonumber(tower:GetAttribute("Phases")) or 0
			if phase >= phases or (roundPhase ~= nil and roundPhase ~= "Round") then
				phase = -1 -- the round is over
			end
			if phase ~= lastPhase then
				local starting = phase >= 0 and lastPhase < 0
				lastPhase = phase
				local final = phase >= 0 and phase == phases - 1
				local fade = TweenInfo.new(1.5)
				if phase >= 0 then
					if starting then
						roundMusic.TimePosition = 0 -- the drums build from the top every round
					end
					local goal = { PlaybackSpeed = 1 + SPEED_STEP * phase, Volume = if final then FINAL_VOLUME else ROUND_VOLUME }
					TweenService:Create(roundMusic, fade, goal):Play()
					TweenService:Create(music, fade, { Volume = 0 }):Play()
				else
					TweenService:Create(roundMusic, fade, { Volume = 0, PlaybackSpeed = 1 }):Play()
					TweenService:Create(music, fade, { Volume = LOBBY_VOLUME }):Play()
				end
				music:SetAttribute("Phase", phase)
			end
			task.wait(0.5)
		end
	end)
end
-- Emotes: ten free emotes (Roblox's own animations, so they load in any game) from a top bar button, so kids can wave,
-- cheer and dance without typing. Dances loop until you move; winning the crown plays your victory emote.
local EMOTES = {
	{ Icon = "👋", Name = "Wave", Id = "rbxassetid://507770239", Loop = false },
	{ Icon = "🙌", Name = "Cheer", Id = "rbxassetid://507770677", Loop = false },
	{ Icon = "😂", Name = "Laugh", Id = "rbxassetid://507770818", Loop = false },
	{ Icon = "👉", Name = "Point", Id = "rbxassetid://507770453", Loop = false },
	{ Icon = "💃", Name = "Dance", Id = "rbxassetid://507771019", Loop = true },
	{ Icon = "🕺", Name = "Groove", Id = "rbxassetid://507776043", Loop = true },
	{ Icon = "🎉", Name = "Shuffle", Id = "rbxassetid://507777268", Loop = true }, -- R15Dance3A (#110)
	{ Icon = "👏", Name = "Clap", Id = "rbxassetid://5915693819", Loop = false }, -- EmoteClap
	{ Icon = "😄", Name = "Happy", Id = "rbxassetid://4841405708", Loop = false }, -- emote_happy
	{ Icon = "🎶", Name = "Bop", Id = "rbxassetid://4555808220", Loop = true }, -- "Keeping Time"
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
local emotePanel = make("Frame", { Name = "EmotePanel", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -96), Size = UDim2.fromOffset(312, 290), BackgroundColor3 = CREAM, Visible = false }, gui)
corner(emotePanel, 18)
outline(emotePanel, 2)
make("UIPadding", { PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10), PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }, emotePanel)
local emoteGrid = make("Frame", { Name = "Grid", Size = UDim2.new(1, 0, 1, -46), BackgroundTransparency = 1 }, emotePanel)
make("UIGridLayout", { CellSize = UDim2.new(1 / 3, -8, 0.25, -6), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder }, emoteGrid)
-- Victory emote: the server saves your pick (the "WinEmote" attribute); a tap cycles to the next one and previews it.
local function winEmote()
	local name = player:GetAttribute("WinEmote")
	for _, e in EMOTES do
		if e.Name == name then
			return e
		end
	end
	return EMOTES[2] -- Cheer, the default
end
local winButton = button(emotePanel, "", GOLD, UDim2.new(1, 0, 0, 38))
winButton.Name = "WinEmote"
winButton.AnchorPoint = Vector2.new(0, 1)
winButton.Position = UDim2.fromScale(0, 1)
winButton.TextScaled = true
make("UITextSizeConstraint", { MaxTextSize = 18 }, winButton)
local function refreshWin()
	local e = winEmote()
	winButton.Text = "🏆 When I win: " .. e.Icon .. " " .. e.Name
end
refreshWin()
player:GetAttributeChangedSignal("WinEmote"):Connect(refreshWin)
winButton.Activated:Connect(function()
	local index = table.find(EMOTES, winEmote()) or 2
	local nextOne = EMOTES[index % #EMOTES + 1]
	event:FireServer("LavaWinEmote", nextOne.Name)
	winButton.Text = "🏆 When I win: " .. nextOne.Icon .. " " .. nextOne.Name
	playEmote(nextOne.Id, false) -- a quick preview
end)
for i, e in EMOTES do
	local b = button(emoteGrid, e.Icon .. " " .. e.Name, ORANGE, UDim2.new())
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
	:setLabel(UI.tight("😀 Emotes", "😀"))
	:align("Right")
	:oneClick()
	:modifyTheme(pill(Color3.fromRGB(255, 200, 80)))
	:bindEvent("selected", function()
		emotePanel.Visible = not emotePanel.Visible
	end)

local musicIcon = Icon.new():setName("Music"):setImage(Icons.SoundOn):setLabel(""):align("Right"):oneClick():modifyTheme(pill(Color3.fromRGB(150, 90, 255)))
-- Your choice is saved with your profile (the "MusicOff" attribute), so 🔇 stays off the next time you join.
local musicWords = false -- true inside the ☰ dropdown on narrow screens, where there's room for words
local function musicOn(): boolean
	return musicGroup.Volume > 0
end
local function setMusic(on: boolean)
	musicGroup.Volume = if on then 1 else 0 -- both tracks keep their place; muting just silences the group
	musicIcon:setImage(if on then Icons.SoundOn else Icons.SoundOff)
	musicIcon:setLabel(if musicWords then (if on then "Music on" else "Music off") else "")
end
musicIcon:bindEvent("selected", function()
	local on = not musicOn()
	setMusic(on)
	event:FireServer("LavaMusic", not on)
end)
local function applySavedMusic()
	local off = player:GetAttribute("MusicOff")
	if type(off) == "boolean" then
		setMusic(not off)
	end
end
applySavedMusic()
player:GetAttributeChangedSignal("MusicOff"):Connect(applySavedMusic)

-- 🎥 Top view (#132): an optional camera for rounds, picked with the 🎥 button. It looks down on the whole floor from
-- above (tilted a little so W still moves up the screen), follows the floor as it rises, and puts a big name over
-- every climber (yours in gold) so you can see who is where. Outside a round the camera is normal. The names are
-- drawn on a screen layer and placed over each head every frame.
do
	local RunService = game:GetService("RunService")
	local Grid = require(RS:WaitForChild("LavaGrid")) :: any
	local HEIGHT, BACK = 78, 30 -- studs above and toward the camera from the floor's centre
	local AHEAD = 10 -- aim this far past the centre so the floor sits lower on screen, clear of the HUD (#134)
	local topIcon = Icon.new():setName("TopView"):setLabel("🎥"):align("Right"):setCaption("Top view"):modifyTheme(pill(Color3.fromRGB(120, 200, 255)))
	local wanted = false
	local active = false
	local towerRef: Model? = nil
	local names = make("ScreenGui", { Name = "TopViewNames", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = -1, Enabled = false }, player:WaitForChild("PlayerGui"))
	local tags: { [BasePart]: TextLabel } = {}
	local hidden: { [BillboardGui]: boolean } = {} -- bots' own small labels hidden while top view is on

	local function getTower(): Model?
		if towerRef and towerRef.Parent then
			return towerRef
		end
		local rush = workspace:FindFirstChild("SkySprout")
		rush = rush and rush:FindFirstChild("Floors")
		rush = rush and rush:FindFirstChild("Floor_1")
		rush = rush and rush:FindFirstChild("LavaRush")
		local t = rush and rush:FindFirstChild("LavaRushTower")
		towerRef = if t and t:IsA("Model") then t else nil
		return towerRef
	end

	local function tag(head: BasePart, text: string, mine: boolean)
		if tags[head] then
			return
		end
		-- Sized to the screen (#134): 30 px tall on a desktop window, about 18 px on a phone in landscape.
		local cam = workspace.CurrentCamera
		local h = math.clamp(math.floor((cam and cam.ViewportSize.Y or 560) * 0.045), 18, 30)
		local l = make("TextLabel", { AnchorPoint = Vector2.new(0.5, 1), Size = UDim2.fromOffset(h * 5.7, h), BackgroundTransparency = 1, Font = FONT, Text = text, TextScaled = true, TextColor3 = if mine then UI.Gold else Color3.new(1, 1, 1), TextStrokeColor3 = UI.Shadow, TextStrokeTransparency = 0, ZIndex = if mine then 2 else 1 }, names)
		make("UITextSizeConstraint", { MaxTextSize = math.floor(h * 0.8) }, l)
		tags[head] = l
	end

	local function refreshTags()
		local seen: { [BasePart]: boolean } = {}
		for _, p in Players:GetPlayers() do
			local head = p.Character and p.Character:FindFirstChild("Head")
			if head and head:IsA("BasePart") and p:GetAttribute("ArenaMode") == "LavaRush" then
				seen[head] = true
				tag(head, if p == player then "⭐ YOU" else p.DisplayName, p == player)
			end
		end
		local t = getTower()
		if t then
			for _, m in t:GetChildren() do
				local head = m:IsA("Model") and string.sub(m.Name, 1, 4) == "Bot_" and m:FindFirstChild("Head")
				if head and head:IsA("BasePart") then
					local root = m.PrimaryPart
					if not (root and root:GetAttribute("BotFalling")) then
						seen[head] = true
						tag(head, "🤖 " .. string.sub(m.Name, 5), false)
						local own = head:FindFirstChildOfClass("BillboardGui")
						if own and own.Enabled then
							own.Enabled = false -- the big top-view name replaces the bot's small label (on this screen only)
							hidden[own] = true
						end
					end
				end
			end
		end
		for head, l in tags do
			if not seen[head] or not head.Parent then
				l:Destroy()
				tags[head] = nil
			end
		end
	end

	local function clearTags()
		for head, l in tags do
			l:Destroy()
			tags[head] = nil
		end
		for own in hidden do
			own.Enabled = true
			hidden[own] = nil
		end
	end

	local function step()
		local t = getTower()
		local cam = workspace.CurrentCamera
		if not t or not cam then
			return
		end
		local cx, cz = t:GetAttribute("CenterX"), t:GetAttribute("CenterZ")
		if type(cx) ~= "number" or type(cz) ~= "number" then
			return
		end
		local _, y = Grid.Pose(t, workspace:GetServerTimeNow())
		local centre = Vector3.new(cx, y, cz)
		cam.CameraType = Enum.CameraType.Scriptable
		-- Phones (short landscape screens) back off a bit: their HUD covers more of the height (#134).
		local far = if cam.ViewportSize.Y < 500 then 1.3 else 1
		cam.CFrame = CFrame.lookAt(centre + Vector3.new(0, HEIGHT * far, BACK * far), centre - Vector3.new(0, 0, AHEAD))
	end

	-- Names over climbers: during top view, and also while spectating from above after a knockout (#135; the
	-- spectate script sets the local "LavaSpectatingAbove" attribute). Placed after whichever camera ran this frame.
	local namesOn = false
	local function placeNames()
		local cam = workspace.CurrentCamera
		if not cam then
			return
		end
		for head, l in tags do
			local pos, onScreen = cam:WorldToViewportPoint(head.Position + Vector3.new(0, 2.5, 0))
			l.Visible = onScreen
			l.Position = UDim2.fromOffset(pos.X, pos.Y)
		end
	end
	local function updateNames()
		local should = active or player:GetAttribute("LavaSpectatingAbove") == true
		if should == namesOn then
			return
		end
		namesOn = should
		names.Enabled = should
		if should then
			RunService:BindToRenderStep("LavaTopNames", Enum.RenderPriority.Camera.Value + 2, placeNames)
			task.spawn(function()
				while namesOn do
					refreshTags()
					task.wait(0.3)
				end
				clearTags()
			end)
		else
			RunService:UnbindFromRenderStep("LavaTopNames")
		end
	end
	player:GetAttributeChangedSignal("LavaSpectatingAbove"):Connect(updateNames)

	local function update()
		local should = wanted and player:GetAttribute("ArenaMode") == "LavaRush"
		if should == active then
			return
		end
		active = should
		updateNames()
		if active then
			RunService:BindToRenderStep("LavaTopView", Enum.RenderPriority.Camera.Value + 1, step)
		else
			RunService:UnbindFromRenderStep("LavaTopView")
			-- Hand the camera back to your character, behind it, as at the start of a round.
			local cam = workspace.CurrentCamera
			local character = player.Character
			local hum = character and character:FindFirstChildOfClass("Humanoid")
			local r = character and character:FindFirstChild("HumanoidRootPart")
			if cam then
				cam.CameraType = Enum.CameraType.Custom
				if hum then
					cam.CameraSubject = hum
				end
				if r and r:IsA("BasePart") then
					local look = r.CFrame.LookVector
					cam.CFrame = CFrame.lookAt(r.Position - look * 12 + Vector3.new(0, 5, 0), r.Position + look * 20 + Vector3.new(0, 8, 0))
				end
			end
		end
	end

	-- The choice is saved with your profile (the "TopView" attribute, #133), like the music button. A click that changes
	-- it tells the server; restoring the saved choice on join does neither the notice nor the message.
	topIcon:bindEvent("selected", function()
		wanted = true
		update()
		if player:GetAttribute("TopView") ~= true then
			notify("🎥 Top view on: rounds are shown from above")
			event:FireServer("LavaTopView", true)
		end
	end)
	topIcon:bindEvent("deselected", function()
		wanted = false
		update()
		if player:GetAttribute("TopView") == true then
			notify("🎥 Top view off")
			event:FireServer("LavaTopView", false)
		end
	end)
	player:GetAttributeChangedSignal("ArenaMode"):Connect(update)
	local function applySaved()
		local on = player:GetAttribute("TopView") == true
		if on ~= wanted then
			if on then
				topIcon:select()
			else
				topIcon:deselect()
			end
		end
	end
	applySaved()
	player:GetAttributeChangedSignal("TopView"):Connect(applySaved)
end

-- Bounce pads on the hub deck (#142): landing on a pad (tag "LavaBounce") launches you at its "Bounce" speed with a
-- springy sound and the pad flashing white. Done here because the client owns its character's physics.
task.defer(function()
	local CollectionService = game:GetService("CollectionService")
	local RunService = game:GetService("RunService")
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	local function refresh()
		params.FilterDescendantsInstances = CollectionService:GetTagged("LavaBounce")
	end
	refresh()
	CollectionService:GetInstanceAddedSignal("LavaBounce"):Connect(refresh)
	CollectionService:GetInstanceRemovedSignal("LavaBounce"):Connect(refresh)
	local last = 0
	RunService.Heartbeat:Connect(function()
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local hum = character and character:FindFirstChildOfClass("Humanoid")
		if not root or not root:IsA("BasePart") or not hum or hum.Health <= 0 or os.clock() - last < 0.25 then
			return
		end
		local v = root.AssemblyLinearVelocity
		if v.Y > 2 then
			return
		end
		local hit = workspace:Raycast(root.Position, Vector3.new(0, -(hum.HipHeight + root.Size.Y / 2 + 1), 0), params)
		local pad = hit and hit.Instance
		local power = pad and pad:GetAttribute("Bounce")
		if not pad or type(power) ~= "number" then
			return
		end
		last = os.clock()
		root.AssemblyLinearVelocity = Vector3.new(v.X, power, v.Z)
		hum:ChangeState(Enum.HumanoidStateType.Freefall)
		local s = Instance.new("Sound")
		s.SoundId = "rbxasset://sounds/action_jump.mp3"
		s.PlaybackSpeed = 0.7 + power / 150
		s.Volume = 0.5
		s.Parent = root
		s:Play()
		game:GetService("Debris"):AddItem(s, 2)
		if pad:IsA("BasePart") then
			local colour = pad:GetAttribute("BounceColour") or pad.Color
			pad:SetAttribute("BounceColour", colour)
			pad.Color = Color3.new(1, 1, 1)
			game:GetService("TweenService"):Create(pad, TweenInfo.new(0.35), { Color = colour }):Play()
		end
	end)
end)

-- Try-on mirror (#140): stepping on the mirror stage opens the shop with TRY buttons, and the camera looks out of the
-- mirror at you (shifted so you stand left of the shop panel). Stepping off hands the camera back. No hint pop-up:
-- the TRY buttons and the mirror's sign explain it.
do
	local RunService = game:GetService("RunService")
	local function mirrorCam()
		local view = workspace:GetAttribute("MirrorView")
		local cam = workspace.CurrentCamera
		if typeof(view) == "CFrame" and cam then
			cam.CameraType = Enum.CameraType.Scriptable
			cam.CFrame = view * CFrame.new(4.5, 0, 0)
		end
	end
	local function onMirror()
		local on = player:GetAttribute("OnMirror") == true
		for _, t in tryButtons do
			t.Visible = on
		end
		if on then
			openPanel("")
			shop.Visible = true
			refreshShop()
			RunService:BindToRenderStep("LavaMirror", Enum.RenderPriority.Camera.Value + 1, mirrorCam)
		else
			RunService:UnbindFromRenderStep("LavaMirror")
			local cam = workspace.CurrentCamera
			if cam then
				cam.CameraType = Enum.CameraType.Custom
			end
		end
	end
	player:GetAttributeChangedSignal("OnMirror"):Connect(onMirror)
end

-- Phones and small tablets: Roblox's own buttons take the first ~216 px, so not every button fits. Below MORE_WIDTH the
-- extras (Pass, VIP, the event pill, Invite, Music) go into one ☰ dropdown; the play buttons (Lava Rush, 👀 Watch),
-- Gloves, Challenges, Emotes and the server goal stay on the bar. Measured to fit a 666 px iPhone 7.
local MORE_WIDTH = 900
UI.isCompact() -- waits for the real viewport size
if workspace.CurrentCamera.ViewportSize.X < MORE_WIDTH then
	local extras = {}
	for _, name in { "LavaPass", "Vip", "Event", "Invite", "Music", "TopView" } do
		local icon = Icon.getIcon(name)
		if icon then
			table.insert(extras, icon)
		end
	end
	Icon.new():setName("More"):setImage(Icons.Gear):setLabel(""):align("Left"):setCaption("Pass, VIP, invite and music"):modifyTheme(pill(Color3.fromRGB(120, 110, 140))):setDropdown(extras)
	-- The dropdown has room for words, so its items say what they are.
	local words = { LavaPass = "Lava Pass", Vip = "VIP", Invite = "Invite +" .. tostring(FRIEND_DEAL.InviteCoins) .. "💰", TopView = "🎥 Top view" }
	for name, text in words do
		local icon = Icon.getIcon(name)
		if icon then
			icon:setLabel(text)
		end
	end
	musicWords = true
	setMusic(musicOn())
end
for _, name in { "Gloves", "LavaPass", "Vip", "Challenges", "ServerGoal", "Invite", "Music", "More" } do
	local icon = Icon.getIcon(name)
	if icon then
		icon:setImageScale(Icons.Scale)
	end
end

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
local raiseButton = button(gui, "", Color3.fromRGB(255, 185, 40), UDim2.fromOffset(96, 72))
do -- "⬆️ RAISE" over a coin + 40 row (the Flibpook coin, as on the coins panel, instead of 💰)
	local top = label(raiseButton, "⬆️ RAISE", 18, Color3.new(1, 1, 1))
	top.Size = UDim2.new(1, 0, 0.5, 0)
	top.Position = UDim2.fromScale(0, 0.06)
	UI.text(top, "body")
	local row = make("Frame", { Name = "Cost", BackgroundTransparency = 1, Position = UDim2.fromScale(0, 0.5), Size = UDim2.new(1, 0, 0.42, 0) }, raiseButton)
	make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, row)
	make("ImageLabel", { Name = "CoinIcon", LayoutOrder = 1, BackgroundTransparency = 1, Image = Icons.Coin, Size = UDim2.fromOffset(22, 22) }, row)
	local cost = label(row, "40", 20, Color3.new(1, 1, 1))
	cost.LayoutOrder = 2
	cost.Size = UDim2.new(0, 0, 1, 0)
	cost.AutomaticSize = Enum.AutomaticSize.X
	UI.text(cost, "body")
end
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
		local e = winEmote()
		task.delay(0.3, playEmote, e.Id, e.Loop) -- you won: your victory emote
	end
end)
event:FireServer("Sync")
-- Tell the server the game has loaded here, so it doesn't drop a slow phone into a round from the loading screen
-- (CFG.ReadyWait). Resent until the server sets LavaReady, since a message sent before your save loads is ignored.
task.spawn(function()
	if not game:IsLoaded() then
		game.Loaded:Wait()
	end
	local tries = 0
	while not player:GetAttribute("LavaReady") and tries < 30 do
		event:FireServer("LavaReady")
		tries += 1
		task.wait(2)
	end
end)

-- Title colours follow the round's world theme (#106): the server sets workspace "LavaTheme" at each countdown, and
-- every title gradient in the HUD switches to that theme's TextTop/TextBottom (LavaThemes).
do
	local Themes = require(RS:WaitForChild("LavaThemes")) :: any
	local function applyThemeColors()
		local theme = Themes.Get(workspace:GetAttribute("LavaTheme"))
		local top = theme and theme.TextTop or Color3.fromRGB(255, 240, 170)
		local bottom = theme and theme.TextBottom or Color3.fromRGB(255, 150, 50)
		UI.setTitleColors(top, bottom, player:FindFirstChildOfClass("PlayerGui"))
		-- Borders, panels and lava buttons follow the theme too (#126).
		UI.setThemeColors(theme and theme.UIAccent or UI.Lava, theme and theme.UIGlass or UI.Glass, player:FindFirstChildOfClass("PlayerGui"))
		-- Top bar pills follow the theme too (#130): each icon's pill glass, under one fixed modification id so the next
		-- theme replaces this one. Label colours stay (each icon has its own).
		local glass = theme and theme.UIGlass or UI.Glass
		for _, icon in Icon.getIcons() do
			pcall(function()
				icon:modifyTheme({ { "IconButton", "BackgroundColor3", glass } }, "ThemeGlass")
			end)
		end
	end
	workspace:GetAttributeChangedSignal("LavaTheme"):Connect(applyThemeColors)
	applyThemeColors()
end

-- Jump styles (#110): each jump plays one of the jumps from Roblox's own animation packs, picked at random when you
-- land (Cartoony, Ninja, Superhero, Stylish, Toy, Bubbly, Astronaut, Levitation, Rthro, Robot, Mage, Knight). They're
-- Roblox-owned, so they load in any game. Just a look: jump height and timing don't change. The default Animate script
-- reloads its jump whenever the JumpAnim's AnimationId changes.
do
	local JUMPS = { 742637942, 656117878, 616115533, 616139451, 782847020, 910016857, 891627522, 616008936, 2510197830, 616090535, 707853694, 658409194 }
	local function hook(character: Model)
		local animate = character:WaitForChild("Animate", 10)
		local jumpValue = animate and animate:WaitForChild("jump", 5)
		local anim = jumpValue and jumpValue:FindFirstChildOfClass("Animation")
		local hum = character:WaitForChild("Humanoid", 10)
		if not anim or not hum or not hum:IsA("Humanoid") then
			return
		end
		task.spawn(function()
			local list = {}
			for _, id in JUMPS do
				local a = Instance.new("Animation")
				a.AnimationId = "rbxassetid://" .. id
				table.insert(list, a)
			end
			pcall(function()
				game:GetService("ContentProvider"):PreloadAsync(list)
			end)
		end)
		local function pick()
			anim.AnimationId = "rbxassetid://" .. JUMPS[math.random(#JUMPS)]
		end
		pick()
		hum.StateChanged:Connect(function(_, new)
			if new == Enum.HumanoidStateType.Landed then
				pick()
			end
		end)
	end
	if player.Character then
		task.spawn(hook, player.Character)
	end
	player.CharacterAdded:Connect(function(character)
		task.spawn(hook, character)
	end)
end
