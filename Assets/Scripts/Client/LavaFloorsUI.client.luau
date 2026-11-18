--!strict
-- Main HUD: coins, shop, invite, music and shove button.
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

local CREAM = Color3.fromRGB(255, 247, 232)
local INK = Color3.fromRGB(62, 28, 14)
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
end
local function outline(v: Instance, thickness: number, color: Color3?)
	make("UIStroke", { Thickness = thickness, Color = color or INK, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, v)
end
local function label(parent: Instance, text: string, size: number, color: Color3?): TextLabel
	return make("TextLabel", { BackgroundTransparency = 1, Font = FONT, Text = text, TextSize = size, TextColor3 = color or INK, Size = UDim2.fromScale(1, 1) }, parent)
end

local click = make("Sound", { SoundId = "rbxasset://sounds/clickfast.wav", Volume = 0.45 }, script)
local function button(parent: Instance, text: string, color: Color3, size: UDim2): TextButton
	local b: TextButton = make("TextButton", { Size = size, BackgroundColor3 = color, AutoButtonColor = false, Font = FONT, Text = text, TextSize = 18, TextColor3 = Color3.new(1, 1, 1), TextStrokeColor3 = INK, TextStrokeTransparency = 0.35 }, parent)
	corner(b, 12)
	outline(b, 3, color:Lerp(Color3.new(), 0.5))
	make("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(210, 210, 210)) }, b)
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

local chip = make("Frame", { Position = UDim2.fromOffset(12, 8), Size = UDim2.fromOffset(200, 48), BackgroundColor3 = CREAM }, gui)
corner(chip, 16)
outline(chip, 3)
local coinsText = label(chip, "💰 0", 26)
coinsText.Position = UDim2.fromOffset(14, 0)
coinsText.Size = UDim2.new(0.62, -14, 1, 0)
coinsText.TextXAlignment = Enum.TextXAlignment.Left
local crownsText = label(chip, "👑 0", 22)
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
make("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(255, 160, 60), Color3.fromRGB(240, 90, 30)) }, ribbon)
local heading = label(ribbon, "🧤 GLOVES", 28, Color3.new(1, 1, 1))
heading.TextStrokeColor3 = INK
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
	b.BackgroundColor3 = color
	local s = b:FindFirstChildOfClass("UIStroke")
	if s then
		s.Color = color:Lerp(Color3.new(), 0.5)
	end
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
		event:FireServer("Hat", id)
	end)
	table.insert(cards, {
		refresh = function()
			if player:GetAttribute("HatStyle") == id then
				setButton(b, "✓ ON", GREEN)
			elseif player:GetAttribute("OwnsHat" .. id) then
				setButton(b, "WEAR", ORANGE)
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
for i, pack in { { "Coins500", 500 }, { "Coins2000", 2000 }, { "Coins6000", 6000 } } do
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
for _, attr in { "Coins", "GloveStyle", "HatStyle", "AuroraPass", "DoubleLavaPass" } do
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
	:setLabel("🧤 Gloves")
	:align("Left")
	:oneClick()
	:modifyTheme({
		{ "IconButton", "BackgroundColor3", Color3.fromRGB(255, 160, 40) },
		{ "IconButton", "BackgroundTransparency", 0 },
		{ "IconLabel", "TextColor3", Color3.new(1, 1, 1) },
		{ "IconLabel", "FontFace", Font.fromEnum(Enum.Font.FredokaOne) },
	})
	:bindEvent("selected", function()
		setShop(not shop.Visible)
	end)

local function pill(color: Color3): { any }
	return {
		{ "IconButton", "BackgroundColor3", color },
		{ "IconButton", "BackgroundTransparency", 0 },
		{ "IconLabel", "TextColor3", Color3.new(1, 1, 1) },
		{ "IconLabel", "FontFace", Font.fromEnum(Enum.Font.FredokaOne) },
	}
end

local SocialService = game:GetService("SocialService")
Icon.new()
	:setName("Invite")
	:setLabel("👥 Invite")
	:align("Right")
	:oneClick()
	:setCaption("Friends here = +25% coins")
	:modifyTheme(pill(Color3.fromRGB(70, 190, 90)))
	:bindEvent("selected", function()
		local ok, can = pcall(function()
			return SocialService:CanSendGameInviteAsync(player)
		end)
		if ok and can then
			pcall(function()
				SocialService:PromptGameInvite(player)
			end)
		else
			notify("Invites aren't available here — share the game with your friends!")
		end
	end)

local music = make("Sound", { Name = "LavaFloorsMusic", SoundId = "rbxassetid://1837768107", Looped = true, Volume = 0.22 }, game:GetService("SoundService"))
music:Play()
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
	b.Position = UDim2.new(1, -24, 1, -150)
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
raiseButton.Position = if UIS.TouchEnabled then UDim2.new(1, -132, 1, -150) else UDim2.new(1, -24, 1, -150)
raiseButton.TextSize = 18
raiseButton.Visible = false
raiseButton.Activated:Connect(raise)
local function showRaise()
	raiseButton.Visible = player:GetAttribute("ArenaMode") == "LavaRush"
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
	end
end)
event:FireServer("Sync")
