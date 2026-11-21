--!strict
-- Lava Rush client: round HUD, effects, shove input and the moving grid.

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Run = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local GuiService = game:GetService("GuiService")
local LavaThemes = require(RS:WaitForChild("LavaThemes")) :: any
local Grid = require(RS:WaitForChild("LavaGrid")) :: any

local player = Players.LocalPlayer
local event = RS:WaitForChild("ArenaEvent") :: RemoteEvent

local FONT = Enum.Font.FredokaOne
local TITLE = Color3.fromRGB(255, 245, 140)
local ORANGE = Color3.fromRGB(255, 150, 40)
local STROKE = Color3.fromRGB(60, 15, 0)

type State = { Showdown: boolean?, Phase: string, EndsAt: number, Mutator: string?, Theme: string?, Queued: number, Running: number, LavaY: number, BaseY: number, CrownY: number, GridPhase: number?, GridPhases: number?, Alive: number? }
type Me = { Queued: boolean, Running: boolean, Crowned: boolean, Embers: number, Peak: number }

local state: State = { Phase = "Idle", EndsAt = 0, Queued = 0, Running = 0, LavaY = -100, BaseY = 0, CrownY = 160 }
local me: Me = { Queued = false, Running = false, Crowned = false, Embers = 0, Peak = 0 }

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

local function stroked(inst: Instance, thickness: number?)
	make("UIStroke", { Thickness = thickness or 2, Color = STROKE }, inst)
end

local sounds: { [string]: Sound } = {}
for name, id in {
	Ember = "rbxassetid://93529351909119",
	Crown = "rbxassetid://1836473422",
	Scorch = "rbxassetid://116330889947483",
	Beep = "rbxassetid://7743999789",
	Shove = "rbxassetid://92357564819100",
	Rise = "rbxassetid://140334012603496",
} do
	sounds[name] = make("Sound", { Name = "LavaRush_" .. name, SoundId = id, Volume = 0.6 }, SoundService)
end
local function play(name: string, pitch: number?)
	local s = sounds[name]
	if s then
		s.PlaybackSpeed = pitch or 1
		SoundService:PlayLocalSound(s)
	end
end

local gui = make("ScreenGui", { Name = "LavaRushHUD", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 5 }, player:WaitForChild("PlayerGui"))

local tint: Frame = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(255, 40, 0), BackgroundTransparency = 1, BorderSizePixel = 0, Active = false }, gui)

local Icon = require(RS:WaitForChild("Icon"))

local Config = require(RS:WaitForChild("SkySproutConfig")) :: any
local Perception = require(RS:WaitForChild("SkySproutPerception")) :: any
local moodNow: string? = nil
local UI = require(RS:WaitForChild("LavaUI")) :: any
-- Low-end mode: phones/tablets and low graphics settings get about half the ambient effects (parallax, ash,
-- sparks, fountains) so the frame rate holds up. Gameplay effects are unchanged.
local LOW_END = (function(): boolean
	if game:GetService("UserInputService").TouchEnabled then
		return true
	end
	local ok, quality = pcall(function()
		return UserSettings().GameSettings.SavedQualityLevel
	end)
	return ok and quality ~= Enum.SavedQualitySetting.Automatic and quality.Value <= 3
end)()
local EFFECTS = if LOW_END then 0.5 else 1
-- Comfort: Roblox's own Reduce Motion setting (Settings > Accessibility) turns off camera shake, the FOV kick, speed
-- streaks, tile wobble and blinking warnings here. Warnings stay on, just steady.
local GuiService = game:GetService("GuiService")
local function readReducedMotion(): boolean
	local ok, on = pcall(function()
		return (GuiService :: any).ReducedMotionEnabled
	end)
	return ok and on == true
end
local REDUCED_MOTION = readReducedMotion()
pcall(function()
	GuiService:GetPropertyChangedSignal("ReducedMotionEnabled"):Connect(function()
		REDUCED_MOTION = readReducedMotion()
	end)
end)
local function fieryPill(color: Color3): { any }
	return UI.pill(color)
end
UI.fitScreen(gui)
-- The title pill is decoration: only on screens tall and wide enough that the top bar doesn't overflow
-- (at ~1130 px wide it pushed itself under the right-hand group).
if not UI.isCompact() and workspace.CurrentCamera.ViewportSize.X >= 1280 then
	Icon.new():setName("LavaFloorsTitle"):setLabel("🔥 " .. Config.GameTitle):align("Left"):lock():modifyTheme(fieryPill(Color3.fromRGB(255, 120, 40)))
end

local rushIcon = Icon.new()
	:setName("LavaRush")
	:setLabel("🔥 Lava Rush")
	:align("Right")
	:oneClick()
	:setCaption("Floor-is-lava rounds • Attack = shove")
	:modifyTheme(fieryPill(Color3.fromRGB(235, 60, 40)))
rushIcon:bindEvent("selected", function()
	event:FireServer("LavaJoin")
end)
local notified = false
local lastLabel: string? = nil
local lastEnabled: boolean? = nil

local panel: Frame = make("Frame", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 96),
	Size = UDim2.new(1, -24, 0, 70),
	BackgroundColor3 = Color3.new(1, 1, 1),
	BackgroundTransparency = 0,
	Visible = false,
}, gui)
make("UISizeConstraint", { MaxSize = Vector2.new(460, 70) }, panel)
make("UICorner", { CornerRadius = UDim.new(0, 16) }, panel)
make("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(255, 150, 40), Color3.fromRGB(235, 60, 25)) }, panel)
make("UIStroke", { Thickness = 4, Color = Color3.fromRGB(110, 25, 5), ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, panel)
local title: TextLabel = make("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -24, 0, 32), Font = FONT, TextScaled = true, TextColor3 = TITLE, Text = "" }, panel)
stroked(title)
local info: TextLabel = make("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 40), Size = UDim2.new(1, -24, 0, 24), Font = FONT, TextScaled = true, TextColor3 = Color3.new(1, 1, 1), Text = "" }, panel)
stroked(info)
UI.glass(panel, 16)
UI.text(title, "title")
UI.text(info, "body")

-- End-of-round cards stack in one column (winner banner on top, your result under it) that starts just below the
-- notice strip, so the notice, banner and result never cover each other. The column shrinks to fit short screens.
local NOTICE_BOTTOM = 156 -- the notice toast in LavaFloorsUI sits at 116..156 below the top bar
local NOTICE_GAP = 18 -- space between that toast and the first end-of-round card
local endStack: Frame = make("Frame", {
	Name = "EndStack",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, NOTICE_BOTTOM + NOTICE_GAP),
	Size = UDim2.new(1, -24, 0, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1,
}, gui)
local END_GAP = 20 -- space between the end-of-round cards, so the banner and result card read as separate cards
make("UIListLayout", { FillDirection = Enum.FillDirection.Vertical, HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, END_GAP) }, endStack)
local endScale: UIScale = make("UIScale", {}, endStack)
local endBottomReserve = 0 -- screen kept free at the bottom (the twist vote card while it shows); set further down

local result: Frame = make("Frame", {
	LayoutOrder = 2,
	Size = UDim2.new(1, 0, 0, 210),
	BackgroundColor3 = Color3.new(1, 1, 1),
	Visible = false,
}, endStack)
make("UISizeConstraint", { MaxSize = Vector2.new(380, 210) }, result)
make("UICorner", { CornerRadius = UDim.new(0, 20) }, result)
make("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(255, 150, 40), Color3.fromRGB(235, 60, 25)) }, result)
make("UIStroke", { Thickness = 5, Color = Color3.fromRGB(110, 25, 5), ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, result)
local resultTitle: TextLabel = make("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(10, 10), Size = UDim2.new(1, -20, 0, 60), Font = FONT, TextScaled = true, TextColor3 = TITLE, Text = "" }, result)
stroked(resultTitle, 3)
local resultBody: TextLabel = make("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(10, 76), Size = UDim2.new(1, -20, 0, 80), Font = FONT, TextScaled = true, TextColor3 = Color3.new(1, 1, 1), Text = "" }, result)
stroked(resultBody)
UI.glass(result, 20)
UI.text(resultTitle, "title")
UI.text(resultBody, "body")

-- Lava Chest bar: fills a little every round and pops a chest of coins when full. It always says how close the next
-- chest is, which is where "one more round" comes from.
local chestTrack: Frame = make("Frame", { Name = "ChestBar", BackgroundColor3 = Color3.fromRGB(40, 15, 10), BackgroundTransparency = 0.2, Position = UDim2.fromOffset(14, 166), Size = UDim2.new(1, -28, 0, 32), Visible = false }, result)
make("UICorner", { CornerRadius = UDim.new(1, 0) }, chestTrack)
make("UIStroke", { Thickness = 2, Color = Color3.fromRGB(255, 200, 90), Transparency = 0.3 }, chestTrack)
local chestFill: Frame = make("Frame", { Name = "Fill", BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.fromScale(0, 1), BorderSizePixel = 0 }, chestTrack)
make("UICorner", { CornerRadius = UDim.new(1, 0) }, chestFill)
make("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(255, 225, 90), Color3.fromRGB(255, 120, 30)) }, chestFill)
local chestLabel: TextLabel = make("TextLabel", { Name = "Label", BackgroundTransparency = 1, Position = UDim2.fromOffset(10, 3), Size = UDim2.new(1, -20, 1, -6), Font = FONT, TextScaled = true, TextColor3 = Color3.new(1, 1, 1), Text = "", ZIndex = 2 }, chestTrack)
stroked(chestLabel, 1.5)
local chestBounce: UIScale = make("UIScale", {}, chestTrack)
local chestShown = 0
local function chestRestText(chest: any): string
	local goal = math.max(1, tonumber(chest.Goal) or 100)
	local after = tonumber(chest.After) or 0
	local perRound = math.max(1, tonumber(chest.Fill) or 25)
	local rounds = math.max(1, math.ceil((goal - after) / perRound))
	local big = if tonumber(chest.BigIn) == 1 then "BIG chest" else "chest"
	return string.format("🎁 %d%% · %s", math.floor(after / goal * 100), if rounds == 1 then "one more round to the " .. big .. "!" else "about " .. rounds .. " rounds to the " .. big)
end
local function showChest(chest: any)
	chestTrack.Visible = type(chest) == "table"
	if type(chest) ~= "table" then
		return
	end
	chestShown += 1
	local my = chestShown
	local goal = math.max(1, tonumber(chest.Goal) or 100)
	local before, after = (tonumber(chest.Before) or 0) / goal, (tonumber(chest.After) or 0) / goal
	local opened = tonumber(chest.Opened) or 0
	chestFill.Size = UDim2.fromScale(before, 1)
	chestLabel.Text = string.format("🎁 Lava Chest +%d", tonumber(chest.Fill) or 0)
	task.delay(0.6, function()
		if my ~= chestShown then
			return
		end
		if opened > 0 then
			TweenService:Create(chestFill, TweenInfo.new(0.6, Enum.EasingStyle.Quad), { Size = UDim2.fromScale(1, 1) }):Play()
			task.wait(0.7)
			play("Crown", 1.1)
			chestBounce.Scale = 1.25 -- pop() is declared further down, so bounce locally
			TweenService:Create(chestBounce, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
			chestLabel.Text = string.format("🎁 CHEST OPEN! +%d coins%s", opened, if opened >= 300 then " (BIG!)" else "")
			task.wait(1.6)
			chestFill.Size = UDim2.fromScale(0, 1)
		end
		if my ~= chestShown then
			return
		end
		TweenService:Create(chestFill, TweenInfo.new(0.7, Enum.EasingStyle.Quad), { Size = UDim2.fromScale(after, 1) }):Play()
		task.wait(0.8)
		chestFill.Size = UDim2.fromScale(after, 1) -- land exactly, even if the tween was skipped
		chestLabel.Text = chestRestText(chest)
	end)
end

local banner: Frame = make("Frame", {
	LayoutOrder = 1,
	Size = UDim2.new(1, 0, 0, 120),
	BackgroundColor3 = Color3.new(1, 1, 1),
	Visible = false,
}, endStack)

local function fitEndStack()
	-- Work in the HUD's own (screen-fit scaled) units so phones line up with the scaled notice strip.
	local fitScale = gui:FindFirstChild("ScreenFit")
	local fit = if fitScale and fitScale:IsA("UIScale") then fitScale.Scale else 1
	local top = GuiService:GetGuiInset().Y / fit + NOTICE_BOTTOM + NOTICE_GAP
	endStack.Position = UDim2.new(0.5, 0, 0, top)
	local need = (if banner.Visible then banner.Size.Y.Offset else 0) + (if result.Visible then 210 else 0) + (if banner.Visible and result.Visible then END_GAP else 0)
	local room = workspace.CurrentCamera.ViewportSize.Y / fit - top - 12 - endBottomReserve
	endScale.Scale = if need > 0 then math.clamp(room / need, 0.45, 1) else 1
end
banner:GetPropertyChangedSignal("Visible"):Connect(fitEndStack)
result:GetPropertyChangedSignal("Visible"):Connect(fitEndStack)
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fitEndStack)
make("UISizeConstraint", { MaxSize = Vector2.new(520, 190) }, banner)
make("UICorner", { CornerRadius = UDim.new(0, 22) }, banner)
make("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(255, 225, 80), Color3.fromRGB(255, 150, 30)) }, banner)
make("UIStroke", { Thickness = 5, Color = Color3.fromRGB(120, 60, 0), ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, banner)
local bannerTitle: TextLabel = make("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(10, 8), Size = UDim2.new(1, -20, 0, 54), Font = FONT, TextScaled = true, TextColor3 = Color3.new(1, 1, 1), Text = "" }, banner)
stroked(bannerTitle, 3)
local bannerNames: TextLabel = make("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(10, 64), Size = UDim2.new(1, -20, 0, 44), Font = FONT, TextScaled = true, TextColor3 = Color3.new(1, 1, 1), Text = "" }, banner)
stroked(bannerNames)
-- Round awards (Top Climber, Shove Champ, ...): a third line, only when the server sends some.
local bannerAwards: TextLabel = make("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(10, 110), Size = UDim2.new(1, -20, 0, 70), Font = FONT, TextScaled = true, TextColor3 = Color3.new(1, 1, 1), Text = "", Visible = false }, banner)
stroked(bannerAwards)
UI.glass(banner, 22, UI.Gold)
UI.text(bannerTitle, "title")
UI.text(bannerNames, "body")
UI.text(bannerAwards, "body")
local showWinnerCam: (names: { any }, positions: { any }) -> () = function() end -- set in the Spectate section

-- Final showdown announcement: a big glass card in the middle of the screen for a few seconds.
-- First-round coach cards: a new player's first round walks them through the basics, one tip every few seconds.
local coachCard: Frame = make("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.7),
	Size = UDim2.new(0.9, 0, 0, 74),
	Visible = false,
	ZIndex = 5,
}, gui)
make("UISizeConstraint", { MaxSize = Vector2.new(560, 74) }, coachCard)
local coachStep: TextLabel = make("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 4), Size = UDim2.new(1, -24, 0, 22), Font = FONT, TextScaled = true, Text = "", ZIndex = 6 }, coachCard)
local coachText: TextLabel = make("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 28), Size = UDim2.new(1, -24, 0, 40), Font = FONT, TextScaled = true, TextWrapped = true, Text = "", ZIndex = 6 }, coachCard)
UI.glass(coachCard, 18, UI.Gold)
UI.text(coachStep, "title")
UI.text(coachText, "body")
if UI.isCompact() then
	-- Phones: keep the coach card between the thumbstick (bottom left) and the Raise / Shove buttons (right).
	coachCard.Position = UDim2.fromScale(0.425, 0.7)
	coachCard.Size = UDim2.new(0.45, 0, 0, 74)
end
local coachRunning = false
local function runCoach()
	if coachRunning or player:GetAttribute("Tutorial") ~= true then
		return
	end
	coachRunning = true
	local touch = game:GetService("UserInputService").TouchEnabled
	local tips = {
		"🌋 Climb out of the volcano! Stay on the floor while the lava rises below.",
		"🔴 Tiles that glow red or crack are about to fall. Keep moving!",
		if touch then "💥 Tap SHOVE to push rivals toward the edge." else "🖱️ Click to shove rivals toward the edge.",
		"🍍 Jump into floating fruit for power-ups!",
		"🗿 Climb the pillar's ledges to grab the strawberry on top!",
		"👑 Be the last one standing to win the crown!",
	}
	task.spawn(function()
		for i, tip in tips do
			if player:GetAttribute("Tutorial") ~= true or (state.Phase ~= "Countdown" and state.Phase ~= "Round") then
				break
			end
			coachStep.Text = string.format("NEW HERE? TIP %d / %d", i, #tips)
			coachText.Text = tip
			coachCard.Visible = true
			local bounce = coachCard:FindFirstChild("Pop") or Instance.new("UIScale") -- pop() is declared further down
			bounce.Name = "Pop"
			bounce.Parent = coachCard;
			(bounce :: UIScale).Scale = 1.15
			TweenService:Create(bounce, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Scale = 1 }):Play()
			task.wait(5)
		end
		coachCard.Visible = false
		coachRunning = false
	end)
end

local showdownCard: Frame = make("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.42), -- low enough to clear the notice toast under the top bar
	Size = UDim2.new(0.9, 0, 0, 110),
	Visible = false,
	ZIndex = 5,
}, gui)
make("UISizeConstraint", { MaxSize = Vector2.new(560, 110) }, showdownCard)
local showdownTitle: TextLabel = make("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(10, 6), Size = UDim2.new(1, -20, 0, 60), Font = FONT, TextScaled = true, Text = "", ZIndex = 6 }, showdownCard)
local showdownNames: TextLabel = make("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(10, 68), Size = UDim2.new(1, -20, 0, 34), Font = FONT, TextScaled = true, Text = "", ZIndex = 6 }, showdownCard)
UI.glass(showdownCard, 22, UI.Lava)
UI.text(showdownTitle, "title")
UI.text(showdownNames, "body")

-- Twist vote: a glass card along the bottom with one button per twist and live counts.
local voteCard: Frame = make("Frame", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -70),
	Size = UDim2.new(0.94, 0, 0, 104),
	Visible = false,
	ZIndex = 4,
}, gui)
make("UISizeConstraint", { MaxSize = Vector2.new(600, 104) }, voteCard)
-- While the vote shows, the end-of-round cards keep clear of it (its 104 px, the 70 px under it and an 18 px gap).
voteCard:GetPropertyChangedSignal("Visible"):Connect(function()
	endBottomReserve = if voteCard.Visible then 104 + 70 + 18 else 0
	fitEndStack()
end)
local voteTitle: TextLabel = make("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -20, 0, 28), Font = FONT, TextScaled = true, Text = "🗳️ VOTE THE NEXT TWIST", ZIndex = 5 }, voteCard)
UI.glass(voteCard, 18)
UI.text(voteTitle, "title")
local voteRow: Frame = make("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(10, 38), Size = UDim2.new(1, -20, 0, 56), ZIndex = 5 }, voteCard)
make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, voteRow)
local voteButtons: { [string]: TextButton } = {}
local voteNames: { [string]: string } = {}
local myVote: string? = nil
local voteEndsAt = 0
-- Controller players: true when the last input came from a gamepad.
local function usingGamepad(): boolean
	return string.sub(game:GetService("UserInputService"):GetLastInputType().Name, 1, 7) == "Gamepad"
end
-- When the vote card opens for a controller player, put the selection on the first option so the D-pad and A vote
-- straight away (otherwise they'd have to find Roblox's UI selection mode first).
local function selectFirstVote()
	if not usingGamepad() then
		return
	end
	local first: TextButton? = nil
	for _, b in voteButtons do
		if not first or b.LayoutOrder < first.LayoutOrder then
			first = b
		end
	end
	if first then
		GuiService.SelectedObject = first
	end
end

-- Pick the winner: while you're out, tap one of the climbers still standing; if they win you get a few coins.
local predictCard: Frame = make("Frame", {
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 16, 0.55, 0),
	Size = UDim2.fromOffset(220, 40),
	AutomaticSize = Enum.AutomaticSize.Y,
	Visible = false,
	ZIndex = 4,
}, gui)
UI.glass(predictCard, 16)
make("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 10), PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }, predictCard)
make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, predictCard)
local predictTitle: TextLabel = make("TextLabel", { LayoutOrder = 0, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 22), Font = FONT, TextScaled = true, Text = "🔮 WHO WILL WIN?", ZIndex = 5 }, predictCard)
UI.text(predictTitle, "title")
local predictHint: TextLabel = make("TextLabel", { LayoutOrder = 1, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 16), Font = FONT, TextScaled = true, Text = "", ZIndex = 5 }, predictCard)
UI.text(predictHint, "muted")
local predictButtons: { TextButton } = {}
local predictShown = ""
local myPrediction: string? = nil
-- Cheers: while you're out, tap an emoji to cheer the climbers; it floats up on everyone's screen with your name.
-- Preset emoji only (no typing), and the server limits how often each player can send one.
local CHEERS = { "🔥", "👏", "😂", "😱", "💪", "🎉" }
local cheerBar: Frame = make("Frame", {
	Name = "CheerBar",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -80), -- 22 px above the spectate bar (it was 8 px and read as one block)
	Size = UDim2.fromOffset(#CHEERS * 50 + 6, 52),
	Visible = false,
	ZIndex = 4,
}, gui)
UI.glass(cheerBar, 18)
make("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6), PaddingTop = UDim.new(0, 5), PaddingBottom = UDim.new(0, 5) }, cheerBar)
make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }, cheerBar)
local cheerReadyAt = 0
for i, emoji in CHEERS do
	local b: TextButton = make("TextButton", { Name = "Cheer" .. i, LayoutOrder = i, Size = UDim2.fromOffset(44, 42), Font = FONT, TextScaled = true, Text = emoji, ZIndex = 5 }, cheerBar)
	make("UICorner", { CornerRadius = UDim.new(0, 12) }, b)
	UI.button(b, UI.Lava)
	b.Activated:Connect(function()
		if os.clock() >= cheerReadyAt then
			cheerReadyAt = os.clock() + 1.2
			event:FireServer("LavaCheer", i)
		end
	end)
end
-- 🍓 Gift: once a round, send a strawberry to the climber you're following (◀ ▶ on the spectate bar). Shown only
-- while following a player who is still climbing; the server checks everything again.
local giftButton: TextButton = make("TextButton", { Name = "Gift", LayoutOrder = #CHEERS + 1, Size = UDim2.fromOffset(104, 42), Font = FONT, TextScaled = true, Text = "🍓 Gift", Visible = false, ZIndex = 5 }, cheerBar)
make("UICorner", { CornerRadius = UDim.new(0, 12) }, giftButton)
UI.button(giftButton, UI.LavaDeep)
local giftSent = false
local giftTarget: number? = nil
local function setGiftTarget(userId: number?)
	giftTarget = userId
	local show = userId ~= nil and not giftSent
	giftButton.Visible = show
	cheerBar.Size = UDim2.fromOffset(#CHEERS * 50 + 6 + (if show then 110 else 0), 52)
end
local function sendGift()
	if giftTarget and not giftSent then
		giftSent = true
		event:FireServer("LavaGift", giftTarget)
		setGiftTarget(nil)
	end
end
giftButton.Activated:Connect(sendGift)
local cheerFeed: Frame = make("Frame", { Name = "CheerFeed", BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -56, 0.92, 0), Size = UDim2.fromOffset(150, 260), ZIndex = 4 }, gui)
local liveCheers = 0
local function showCheer(name: string, emoji: string)
	if liveCheers >= 10 then
		return
	end
	liveCheers += 1
	local start = UDim2.new(0.3 + math.random() * 0.5, 0, 1, 0)
	local bubble: Frame = make("Frame", { Name = "CheerBubble", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 1), Position = start, Size = UDim2.fromOffset(110, 64), ZIndex = 4 }, cheerFeed)
	local icon: TextLabel = make("TextLabel", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 44), Font = FONT, TextScaled = true, Text = emoji, ZIndex = 4 }, bubble)
	local tag: TextLabel = make("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 44), Size = UDim2.new(1, 0, 0, 18), Font = FONT, TextScaled = true, Text = name, TextColor3 = Color3.new(1, 1, 1), ZIndex = 4 }, bubble)
	local outline: UIStroke = make("UIStroke", { Thickness = 1.5, Color = STROKE }, tag)
	local info = TweenInfo.new(2.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	-- Floats up and drifts a little; with Reduce Motion it just fades where it appeared.
	local finish = if REDUCED_MOTION then start else start + UDim2.fromOffset(math.random(-20, 20), -190)
	TweenService:Create(bubble, info, { Position = finish }):Play()
	TweenService:Create(icon, info, { TextTransparency = 1 }):Play()
	TweenService:Create(tag, info, { TextTransparency = 1 }):Play()
	TweenService:Create(outline, info, { Transparency = 1 }):Play()
	task.delay(2.5, function()
		bubble:Destroy()
		liveCheers -= 1
	end)
end

local function refreshPredict()
	cheerBar.Visible = state.Phase == "Round" and not me.Running
	if state.Phase ~= "Round" then
		myPrediction = nil
		giftSent = false
	end
	local names = {}
	for _, n in (if type((state :: any).Contenders) == "table" then (state :: any).Contenders else {}) do
		if n ~= player.DisplayName then -- the list can lag a moment behind your own knock-out
			table.insert(names, n)
		end
	end
	local show = state.Phase == "Round" and not me.Running and #names >= 2 and #names <= 8
	predictCard.Visible = show
	if not show then
		return
	end
	predictHint.Text = if myPrediction then "Your pick: " .. myPrediction else string.format("Free pick · +%d 💰 if right", 15)
	local key = table.concat(names, "|") .. "|" .. tostring(myPrediction)
	if key == predictShown then
		return
	end
	predictShown = key
	for _, b in predictButtons do
		b:Destroy()
	end
	table.clear(predictButtons)
	for i, name in names do
		local b: TextButton = make("TextButton", { LayoutOrder = 1 + i, Size = UDim2.new(1, 0, 0, 30), AutoButtonColor = false, Font = FONT, TextScaled = true, Text = tostring(name), ZIndex = 5 }, predictCard)
		make("UICorner", { CornerRadius = UDim.new(0, 10) }, b)
		make("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6), PaddingTop = UDim.new(0, 3), PaddingBottom = UDim.new(0, 3) }, b)
		UI.button(b, if myPrediction == name then Color3.fromRGB(70, 200, 90) else UI.Lava)
		b.AutoButtonColor = false
		b.Active = myPrediction == nil
		b.Activated:Connect(function()
			if myPrediction == nil then
				myPrediction = name
				event:FireServer("LavaPredict", name)
				predictShown = ""
				refreshPredict()
			end
		end)
		table.insert(predictButtons, b)
	end
end

local spectateLabel: TextLabel = make("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -24),
	Size = UDim2.fromOffset(420, 34),
	BackgroundTransparency = 1,
	Font = FONT,
	TextScaled = true,
	TextColor3 = Color3.new(1, 1, 1),
	Text = "👀 Spectating from above · next round soon",
	Visible = false,
}, gui)
stroked(spectateLabel)
make("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14), PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4) }, spectateLabel)
UI.glass(spectateLabel, 17)
UI.text(spectateLabel, "body")
-- ◀ ▶ either side of the spectate bar: cycle between the overhead view and following one climber (set up in Spectate).
local spectateButtons: { TextButton } = {}
for i, arrow in { "◀", "▶" } do
	local b: TextButton = make("TextButton", {
		Name = if i == 1 then "FollowPrev" else "FollowNext",
		AnchorPoint = Vector2.new(if i == 1 then 1 else 0, 0.5),
		Position = UDim2.new(if i == 1 then 0 else 1, if i == 1 then -8 else 8, 0.5, 0),
		Size = UDim2.fromOffset(46, 46),
		Font = FONT,
		TextScaled = true,
		Text = arrow,
		TextColor3 = Color3.new(1, 1, 1),
		BackgroundColor3 = Color3.fromRGB(40, 20, 12),
		AutoButtonColor = true,
	}, spectateLabel)
	make("UICorner", { CornerRadius = UDim.new(1, 0) }, b)
	stroked(b)
	local hint: TextLabel = make("TextLabel", {
		Name = "PadHint",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 1, 2),
		Size = UDim2.fromOffset(34, 16),
		BackgroundTransparency = 1,
		Font = FONT,
		TextScaled = true,
		Text = if i == 1 then "L1" else "R1",
		TextColor3 = Color3.new(1, 1, 1),
		Visible = false,
	}, b)
	stroked(hint)
	table.insert(spectateButtons, b)
end
-- Controller hints: L1 / R1 under the follow arrows and (X) on the gift button while a gamepad is in use (the
-- buttons themselves are bound while spectating, see startSpectate).
local function refreshPadHints()
	local pad = usingGamepad()
	for _, b in spectateButtons do
		local hint = b:FindFirstChild("PadHint")
		if hint and hint:IsA("TextLabel") then
			hint.Visible = pad
		end
	end
	giftButton.Text = if pad then "🍓 Gift (X)" else "🍓 Gift"
end
game:GetService("UserInputService").LastInputTypeChanged:Connect(refreshPadHints)
refreshPadHints()

local function pop(target: GuiObject)
	local scale = target:FindFirstChildOfClass("UIScale") or make("UIScale", {}, target)
	scale.Scale = 1.2
	TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Scale = 1 }):Play()
end

-- Camera shake (strength, seconds); the real one is set up with the eruption effects below. A no-op until then, in
-- case an event arrives while the script is still loading.
local rumble: (number, number?) -> () = function(_: number, _: number?) end

local function burst(position: Vector3, colors: ColorSequence, amount: number, speed: number)
	local anchor: Part = make("Part", { Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, Transparency = 1, Size = Vector3.one, CFrame = CFrame.new(position) }, workspace)
	local e: ParticleEmitter = make("ParticleEmitter", {
		Rate = 0,
		Lifetime = NumberRange.new(0.8, 2.2),
		Speed = NumberRange.new(speed * 0.5, speed),
		SpreadAngle = Vector2.new(180, 180),
		Acceleration = Vector3.new(0, -25, 0),
		Size = NumberSequence.new(0.6, 0),
		LightEmission = 0.8,
		Color = colors,
	}, anchor)
	e:Emit(amount)
	Debris:AddItem(anchor, 3)
end

local function floatText(position: Vector3, text: string)
	local anchor: Part = make("Part", { Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, Transparency = 1, Size = Vector3.one, CFrame = CFrame.new(position) }, workspace)
	local bb = make("BillboardGui", { Size = UDim2.fromOffset(120, 44), AlwaysOnTop = true }, anchor)
	local l: TextLabel = make("TextLabel", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Font = FONT, TextScaled = true, TextColor3 = ORANGE, Text = text }, bb)
	stroked(l)
	TweenService:Create(anchor, TweenInfo.new(0.9), { CFrame = CFrame.new(position + Vector3.new(0, 5, 0)) }):Play()
	TweenService:Create(l, TweenInfo.new(0.9), { TextTransparency = 1 }):Play()
	Debris:AddItem(anchor, 1)
end

local FIRE = ColorSequence.new(Color3.fromRGB(255, 220, 80), Color3.fromRGB(255, 60, 10))
local boostWave: (Vector3, Color3) -> ()
local SHIELD = ColorSequence.new(Color3.fromRGB(150, 220, 255), Color3.fromRGB(60, 140, 255))
local PARTY = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 220, 60)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(80, 200, 255)),
})

local lastBeep = -1
event.OnClientEvent:Connect(function(kind: string, v: any)
	if kind == "LavaState" then
		local wasPhase = state.Phase
		state = v
		if state.Phase == "Countdown" or state.Phase == "Round" then
			runCoach()
		end
		refreshPredict()
		if state.Phase == "Round" and wasPhase ~= "Round" and (me.Queued or me.Running) then
			play("Beep", 1.5)
		end
	elseif kind == "LavaMe" then
		local wasRunning = me.Running
		me = v
		refreshPredict()
		if me.Running and not wasRunning then
			result.Visible = false
		end
	elseif kind == "LavaShove" then
		local r = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local h = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if r and r:IsA("BasePart") and h and typeof(v) == "Vector3" and v.Magnitude < 120 then
			h:ChangeState(Enum.HumanoidStateType.Freefall)
			local attachment = make("Attachment", { Name = "LavaShoveAttachment" }, r)
			make("LinearVelocity", {
				Name = "LavaShove",
				Attachment0 = attachment,
				MaxForce = 1e6,
				VelocityConstraintMode = Enum.VelocityConstraintMode.Vector,
				RelativeTo = Enum.ActuatorRelativeTo.World,
				VectorVelocity = v,
			}, r)
			Debris:AddItem(r:FindFirstChild("LavaShove") :: Instance, 0.18)
			Debris:AddItem(attachment, 0.2)
			play("Shove", 0.9)
			tint.BackgroundTransparency = 0.6
			-- You got shoved: a firm camera jolt and a short buzz on a controller, so the hit is felt, not just seen.
			rumble(0.4, 0.35)
			local haptics = game:GetService("HapticService")
			if haptics:IsVibrationSupported(Enum.UserInputType.Gamepad1) then
				haptics:SetMotor(Enum.UserInputType.Gamepad1, Enum.VibrationMotor.Large, 0.5)
				task.delay(0.15, function()
					haptics:SetMotor(Enum.UserInputType.Gamepad1, Enum.VibrationMotor.Large, 0)
				end)
			end
		end
	elseif kind == "LavaFX" then
		if v.Kind == "Ember" then
			play("Ember", 1 + math.random() * 0.2)
			if v.Position then
				floatText(v.Position, "+1 🍓")
				burst(v.Position, FIRE, 20, 12)
			end
		elseif v.Kind == "Scorched" then
			play("Scorch")
			tint.BackgroundTransparency = 0.25
		elseif v.Kind == "Hit" then
			-- Your shove landed: sound, burst, a 💥 over them and a small camera kick.
			play("Shove", 1.2)
			if v.Position then
				burst(v.Position, FIRE, 12, 18)
				floatText(v.Position + Vector3.new(0, 2.5, 0), "💥")
			end
			rumble(0.15, 0.2)
		elseif v.Kind == "ShoveSeen" then
			-- Someone else's shove landed nearby: a lighter puff and 💥 so it's clear what happened.
			local cam = workspace.CurrentCamera
			if v.Position and cam and (cam.CFrame.Position - v.Position).Magnitude < 160 then
				burst(v.Position, FIRE, 8, 14)
				floatText(v.Position + Vector3.new(0, 2.5, 0), "💥")
			end
		elseif v.Kind == "Shield" then
			play("Crown", 1.6)
			if v.Position then
				burst(v.Position, SHIELD, 40, 14)
			end
		elseif v.Kind == "Blocked" then
			play("Shove", 0.6)
			if v.Position then
				burst(v.Position, SHIELD, 16, 10)
				floatText(v.Position + Vector3.new(0, 2, 0), "🛡️ BLOCKED")
			end
		elseif v.Kind == "Boost" then
			play("Crown", 1.35)
			if v.Position then
				local c = if typeof(v.Color) == "Color3" then v.Color else ORANGE
				burst(v.Position, ColorSequence.new(Color3.new(1, 1, 1), c), 80, 26)
				floatText(v.Position + Vector3.new(0, 2, 0), tostring(v.Text or "BOOST!"))
				boostWave(v.Position, c)
			end
			pop(title)
		elseif v.Kind == "Bomb" then
			play("Beep", 2)
			tint.BackgroundTransparency = 0.55
			if v.Position then
				floatText(v.Position + Vector3.new(0, 3, 0), "💣 YOU'RE IT!")
				burst(v.Position + Vector3.new(0, 3, 0), FIRE, 24, 10)
			end
		elseif v.Kind == "Boom" then
			play("Scorch", 0.8)
			if v.Position then
				burst(v.Position, FIRE, 140, 45)
				burst(v.Position, ColorSequence.new(Color3.fromRGB(80, 70, 70), Color3.fromRGB(30, 25, 25)), 40, 18)
				local r = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
				if r and r:IsA("BasePart") and (r.Position - v.Position).Magnitude < 40 then
					tint.BackgroundTransparency = 0.35
				end
			end
		elseif v.Kind == "Showdown" then
			-- Two left: a big lava-gold announcement, a horn and a red flash.
			local names = if type(v.Names) == "table" then v.Names else {}
			showdownTitle.Text = "⚔️ FINAL SHOWDOWN"
			showdownNames.Text = if #names == 2 then string.format("%s  vs  %s", tostring(names[1]), tostring(names[2])) else "Last two standing!"
			showdownCard.Visible = true
			pop(showdownCard)
			play("Crown", 0.7)
			play("Rise", 0.8)
			tint.BackgroundTransparency = 0.45
			task.delay(2.8, function()
				showdownCard.Visible = false
			end)
		elseif v.Kind == "BotOut" then
			if v.Position then
				burst(v.Position, FIRE, 50, 20)
				floatText(v.Position + Vector3.new(0, 3, 0), tostring(v.Text or "🤖") .. " is out!")
			end
		elseif v.Kind == "Invite" then
			-- Invite deal paid out: a gold burst over your head and the amount floating up.
			play("Crown", 1.2)
			local r = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if r and r:IsA("BasePart") then
				burst(r.Position + Vector3.new(0, 3, 0), ColorSequence.new(Color3.fromRGB(255, 240, 150), Color3.fromRGB(255, 190, 40)), 70, 22)
				floatText(r.Position + Vector3.new(0, 4, 0), string.format("%s +%d 💰", tostring(v.Text or ""), tonumber(v.Coins) or 0))
			end
			pop(title)
		elseif v.Kind == "Crown" then
			play("Crown", if v.Mine then 1 else 1.15)
			if v.Position then
				local at: Vector3 = v.Position
				burst(at + Vector3.new(0, 3, 0), PARTY, 160, 40)
				-- A gold pillar of light and three fireworks over the winner.
				local pillar = Instance.new("Part")
				pillar.Shape = Enum.PartType.Cylinder
				pillar.Material = Enum.Material.Neon
				pillar.Color = Color3.fromRGB(255, 215, 90)
				pillar.Anchored = true
				pillar.CanCollide = false
				pillar.CanQuery = false
				pillar.CanTouch = false
				pillar.CastShadow = false
				pillar.Size = Vector3.new(60, 4, 4)
				pillar.CFrame = CFrame.new(at + Vector3.new(0, 30, 0)) * CFrame.Angles(0, 0, math.rad(90))
				pillar.Transparency = 0.3
				pillar.Parent = workspace
				TweenService:Create(pillar, TweenInfo.new(1.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(60, 0.3, 0.3), Transparency = 1 }):Play()
				Debris:AddItem(pillar, 1.7)
				for i = 1, 3 do
					task.delay(0.25 * i, function()
						local sky = at + Vector3.new((math.random() - 0.5) * 16, 14 + math.random() * 8, (math.random() - 0.5) * 16)
						burst(sky, ColorSequence.new(Color3.fromHSV(math.random(), 0.6, 1), Color3.fromRGB(255, 230, 120)), 90, 30)
						play("Shove", 1.6 + math.random() * 0.3)
					end)
				end
			end
		end
	elseif kind == "LavaVote" then
		for _, b in voteButtons do
			b:Destroy()
		end
		table.clear(voteButtons)
		table.clear(voteNames)
		myVote = nil
		voteEndsAt = tonumber(v.EndsAt) or 0
		local options = if type(v.Options) == "table" then v.Options else {}
		for i, o in options do
			local id, name = tostring(o.Id), tostring(o.Name)
			local b: TextButton = make("TextButton", {
				LayoutOrder = i,
				Size = UDim2.new(1 / math.max(1, #options), -8, 1, 0),
				AutoButtonColor = false,
				Font = FONT,
				TextScaled = true,
				Text = name,
				ZIndex = 6,
			}, voteRow)
			make("UICorner", { CornerRadius = UDim.new(0, 12) }, b)
			make("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6), PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4) }, b)
			UI.button(b, UI.Lava)
			make("UITextSizeConstraint", { MaxTextSize = 22 }, b)
			b.Activated:Connect(function()
				myVote = id
				event:FireServer("LavaVote", id)
				for otherId, other in voteButtons do
					UI.button(other, if otherId == id then Color3.fromRGB(70, 200, 90) else UI.Lava)
				end
				play("Beep", 1.4)
			end)
			voteButtons[id] = b
			voteNames[id] = name
		end
		if UI.isCompact() then
			-- Phones can't fit results and the vote at once: show the results first, then swap to the vote.
			voteCard.Visible = false
			task.delay(2.5, function()
				if #options > 0 and workspace:GetServerTimeNow() < voteEndsAt then
					banner.Visible = false
					result.Visible = false
					voteCard.Visible = true
					pop(voteCard)
					selectFirstVote()
				end
			end)
		else
			voteCard.Visible = #options > 0
			pop(voteCard)
			selectFirstVote()
		end
	elseif kind == "LavaVoteCounts" then
		if type(v) == "table" then
			for id, b in voteButtons do
				local n = tonumber(v[id]) or 0
				b.Text = if n > 0 then string.format("%s  ·  %d", voteNames[id] or id, n) else (voteNames[id] or id)
			end
		end
	elseif kind == "LavaVoteResult" then
		voteCard.Visible = false
		local selected = GuiService.SelectedObject
		if selected and selected:IsDescendantOf(voteCard) then
			GuiService.SelectedObject = nil -- hand the controller back to the character
		end
		if v.Id and myVote == v.Id then
			play("Crown", 1.6)
		end
	elseif kind == "LavaWinners" then
		-- The round is over: clear mid-round cards so they don't sit on top of the winner banner and result card.
		showdownCard.Visible = false
		coachCard.Visible = false
		local names = if type(v.Names) == "table" then v.Names else {}
		local onlyBots = #names > 0
		for _, n in names do
			if string.sub(tostring(n), 1, 4) ~= "🤖" then
				onlyBots = false
			end
		end
		bannerTitle.Text = if #names == 0 then "🌋 THE LAVA WINS!" elseif onlyBots then "🤖 THE BOTS WIN!" elseif #names == 1 then "🌋 ESCAPED THE VOLCANO!" else "🌋 THEY ESCAPED!"
		bannerNames.Text = if #names == 0 then "Nobody survived this time" else table.concat(names, "  •  ")
		local awards = {}
		if type(v.Awards) == "table" then
			for _, a in v.Awards do
				if type(a) == "table" and type(a.Icon) == "string" and type(a.Title) == "string" and type(a.Name) == "string" then
					-- Long display names would wrap an award across two lines, so they're cut to 12 characters.
					local name = a.Name
					local cut = utf8.offset(name, 12)
					if (utf8.len(name) or 0) > 12 and cut then
						name = string.sub(name, 1, cut - 1) .. "…"
					end
					table.insert(awards, a.Icon .. " " .. a.Title .. ": " .. name)
				end
			end
		end
		-- Two awards per line so the text stays readable on phones.
		local lines = {}
		for i = 1, #awards, 2 do
			table.insert(lines, if awards[i + 1] then awards[i] .. "   " .. awards[i + 1] else awards[i])
		end
		bannerAwards.Text = table.concat(lines, "\n")
		bannerAwards.Size = UDim2.new(1, -20, 0, if #lines > 1 then 70 else 38)
		bannerAwards.Visible = #awards > 0
		banner.Size = UDim2.new(1, 0, 0, if #lines > 1 then 190 elseif #lines == 1 then 158 else 120)
		banner.Visible = true
		fitEndStack()
		pop(banner)
		play("Crown", 1.1)
		if type(v.Positions) == "table" then
			for _, at in v.Positions do
				if typeof(at) == "Vector3" then
					burst(at + Vector3.new(0, 4, 0), PARTY, 120, 36)
				end
			end
			showWinnerCam(names, v.Positions)
		end
		task.delay(5, function()
			banner.Visible = false
		end)
	elseif kind == "LavaCheer" then
		if type(v) == "table" and state.Phase == "Round" and type(v.Name) == "string" and type(v.Emoji) == "string" then
			showCheer(v.Name, v.Emoji)
		end
	elseif kind == "LavaResult" then
		resultTitle.Text = if v.Outcome == "CROWNED" then "👑 ESCAPED!" elseif v.Outcome == "SURVIVED" then "🔥 SURVIVED!" else "💀 SCORCHED"
		local titleGradient = resultTitle:FindFirstChild("TitleGradient")
		if titleGradient and titleGradient:IsA("UIGradient") then
			titleGradient.Enabled = v.Outcome ~= "SCORCHED"
		end
		resultTitle.TextColor3 = if v.Outcome == "SCORCHED" then Color3.fromRGB(255, 140, 120) else Color3.new(1, 1, 1)
		local emberLine = if v.Embers > 0 then string.format("\n%d embers banked%s", v.Embers, if v.Doubled then " (x2!)" else "") else ""
		local bestLine = if v.NewBest and (tonumber(v.PrevBest) or 0) > 0 then string.format("\n🏅 NEW BEST! %d (was %d)", v.Height, v.PrevBest)
			elseif v.NewBest then "\n🏅 First best: " .. tostring(v.Height) .. ". Beat it next round!"
			elseif type(v.Best) == "number" then string.format("\nYour best: %d", v.Best)
			else ""
		resultBody.Text = string.format("Height %d  •  +%d coins%s%s%s%s", v.Height, v.Coins, if v.Boosted then " (2x)" else "", if v.Friends then " 👥+25%" else "", emberLine, bestLine)
		if v.NewBest and (tonumber(v.PrevBest) or 0) > 0 then
			play("Crown", 1.2)
		end
		local left = tonumber(v.RisesLeft)
		if v.Outcome == "SCORCHED" and left and left >= 1 and left <= 2 then
			resultTitle.Text = if left == 1 then "😱 SO CLOSE! 1 rise left" else "😱 SO CLOSE! 2 rises left"
		end
		showChest(v.Chest)
		result.Visible = true
		pop(result)
		local shownFor = chestShown
		task.delay(if type(v.Chest) == "table" and (tonumber(v.Chest.Opened) or 0) > 0 then 7 else 5.5, function()
			if shownFor == chestShown then
				result.Visible = false
			end
		end)
	end
end)

-- Round HUD

local function rootPart(): BasePart?
	local r = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	return if r and r:IsA("BasePart") then r else nil
end

local lavaSoundFor: Instance? = nil
-- Flowing lava: soft glow layers scroll across the lava top in different directions (local-only textures).
type FlowLayer = { Studs: number, Colour: Color3, Transparency: number, Flow: Vector2 }
local LAVA_FLOW: { FlowLayer } = {
	{ Studs = 18, Colour = Color3.fromRGB(255, 225, 120), Transparency = 0.35, Flow = Vector2.new(1.6, 0.6) },
	{ Studs = 31, Colour = Color3.fromRGB(255, 150, 40), Transparency = 0.45, Flow = Vector2.new(-0.7, -1.1) },
}
local lavaFlow: { Texture } = {}
Run.RenderStepped:Connect(function(dt)
	local t = workspace:GetServerTimeNow()
	local left = math.max(0, state.EndsAt - t)
	local onFloor1 = (player:GetAttribute("VisitFloor") or 1) == 1
	local mode = player:GetAttribute("ArenaMode")
	local inRush = mode == "LavaRush" and me.Running

	local joinable = state.Phase == "Round" and state.LavaY < state.BaseY + 40
	-- Short labels on phones: the long "✅ Queued" pushed the right-hand top bar group over the server-goal pill.
	local label = if me.Queued then UI.short("✅ Queued", "✅") elseif joinable then UI.short("🔥 Jump in!", "🔥 Go!") else UI.short("🔥 Lava Rush", "🔥")
	local enabled = onFloor1 and not inRush and (mode == "Lobby" or me.Queued)
	if enabled ~= lastEnabled then
		lastEnabled = enabled
		rushIcon:setEnabled(enabled)
	end
	if label ~= lastLabel then
		lastLabel = label
		rushIcon:setLabel(label)
	end
	local opportunity = (state.Phase == "Countdown" or joinable) and not me.Queued and not inRush
	if opportunity and not notified then
		notified = true
		rushIcon:notify()
	elseif not opportunity and notified then
		notified = false
		rushIcon:clearNotices()
	end

	panel.Visible = inRush or me.Queued
	if panel.Visible then
		local hud = player.PlayerGui:FindFirstChild("SkySproutHUD")
		local notice = hud and hud:FindFirstChild("Notice")
		if notice and notice:IsA("GuiObject") then
			local top = GuiService:GetGuiInset().Y + notice.Position.Y.Offset + notice.Size.Y.Offset + 6
			if panel.Position.Y.Offset ~= top then
				panel.Position = UDim2.new(0.5, 0, 0, top)
			end
		end
		if state.Phase == "Countdown" then
			local secs = math.ceil(left)
			local twist = state.Mutator
			title.Text = if twist and twist ~= "Classic" then string.format("%s IN %d", string.upper(twist), secs) else string.format("🔥 LAVA RUSH STARTS IN %d", secs)
			local shoveTip = if game:GetService("UserInputService").TouchEnabled then "💥 Tap SHOVE to push rivals" else "🖱️ Click to SHOVE rivals"
			local tips = { shoveTip,"🌀 The floor spins, grows, then rises — stay on!", "🛡️ Blue bubbles block shoves", "🔴 Red tiles fall or get left behind — move!", "🍉 Stay on one tile too long and it cracks!", "⬆️ Press E or tap RAISE to pop your tile up (40 coins)", "🏆 Get to the middle and survive every phase!", "🎁 Grab falling crates for boosts!", "💣 Hot Potato: touch someone to pass the bomb!" }
			info.Text = string.format("%s%d climber%s ready  •  %s", if state.Theme then state.Theme .. "  •  " else "", state.Queued, if state.Queued == 1 then "" else "s", tips[math.floor(t / 2.5) % #tips + 1])
			if secs <= 3 and secs > 0 and secs ~= lastBeep then
				lastBeep = secs
				play("Beep")
				pop(title)
			end
		elseif state.Phase == "Round" then
			lastBeep = -1
			local whole = math.floor(left)
			local twist = state.Mutator
			title.Text = string.format("%s  %d:%02d", if twist and twist ~= "Classic" then twist else "🔥 LAVA RUSH", whole // 60, whole % 60)
			local r = rootPart()
			if inRush and r then
				local gap = math.max(0, math.floor((r.Position.Y - 3) - state.LavaY))
				local phase, phases = state.GridPhase or 0, state.GridPhases or 0
				local stage = if phase <= 0 then "Get ready!" else string.format("Phase %d/%d", phase, phases)
				-- No lava-distance count: with 3 big rises it changed too fast to be useful (the red tint still warns you).
				info.Text = string.format("%s  •  👥 %d left  •  🍓 %d", stage, state.Alive or 0, me.Embers)
				local target = if gap < 10 then 0.6 + 0.4 * (gap / 10) else 1
				tint.BackgroundTransparency += (target - tint.BackgroundTransparency) * math.min(1, dt * 8)
			else
				info.Text = "Dropping you in…"
			end
		else
			title.Text = "🔥 LAVA RUSH"
			info.Text = if state.Phase == "Results" then "Round over — next one soon!" else "Waiting for climbers… invite a friend!"
		end
	end
	if not inRush then
		tint.BackgroundTransparency += (1 - tint.BackgroundTransparency) * math.min(1, dt * 4)
	end

	local floors = workspace:FindFirstChild("SkySprout") and workspace.SkySprout:FindFirstChild("Floors")
	local floor1 = floors and floors:FindFirstChild("Floor_1")
	local arena = floor1 and floor1:FindFirstChild("LavaRush")
	local tower = arena and arena:FindFirstChild("LavaRushTower")
	local lava = tower and tower:FindFirstChild("Lava")
	if lava and lava ~= lavaSoundFor then
		lavaSoundFor = lava
		make("Sound", { SoundId = "rbxassetid://318794788", Looped = true, Volume = 0.7, RollOffMinDistance = 20, RollOffMaxDistance = 140, Playing = true }, lava)
		table.clear(lavaFlow)
		for _, layer in LAVA_FLOW do
			local texture = Instance.new("Texture")
			texture.Name = "LavaFlow"
			texture.Face = Enum.NormalId.Top
			texture.Texture = "rbxasset://textures/particles/smoke_main.dds"
			texture.StudsPerTileU = layer.Studs
			texture.StudsPerTileV = layer.Studs
			texture.Color3 = layer.Colour
			texture.Transparency = layer.Transparency
			texture.Parent = lava
			table.insert(lavaFlow, texture)
		end
	end
	if lava then
		for i, texture in lavaFlow do
			local layer = LAVA_FLOW[i]
			texture.OffsetStudsU = (texture.OffsetStudsU + layer.Flow.X * dt) % layer.Studs
			texture.OffsetStudsV = (texture.OffsetStudsV + layer.Flow.Y * dt) % layer.Studs
		end
	end

	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local arenaFloor = arena and arena:FindFirstChild("ArenaFloor")
	local near = root ~= nil and arenaFloor ~= nil and root:IsA("BasePart") and arenaFloor:IsA("BasePart")
		and (root.Position - arenaFloor.Position).Magnitude < 150
	local wantMood: string? = if onFloor1 and (inRush or near) then "Lava" else nil
	if wantMood ~= moodNow and Perception.SetMood then
		moodNow = wantMood
		Perception.SetMood(wantMood)
	end
	if lava then
		-- The lava's lights bleach the tiles to near-white once it's just below the floor, so fade them as it closes in.
		-- The lava itself still glows, and the red warning plates still carry the danger.
		local closeness = 1
		if tower and lava:IsA("BasePart") then
			local _, floorY = Grid.Pose(tower, t)
			local gap = floorY - (lava.Position.Y + lava.Size.Y / 2)
			closeness = math.clamp((gap - 4) / 18, 0.25, 1)
		end
		local light = lava:FindFirstChildOfClass("SurfaceLight")
		if light then
			light.Brightness = (3 + math.noise(t * 2.3, 0.5) * 1.6) * closeness
		end
		local point = lava:FindFirstChild("LavaGlowPoint")
		local rising = point and point:FindFirstChild("LavaGlow")
		if rising and rising:IsA("PointLight") then
			rising.Brightness = (2.2 + math.noise(t * 1.1, 3.7) * 0.9) * closeness
		end
	end

	local theme = LavaThemes.Get(workspace:GetAttribute("LavaTheme"))
	local night = moodNow ~= nil and (theme.Clock < 6 or theme.Clock > 19)
	for _, other in Players:GetPlayers() do
		local char = other.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if hrp then
			local glowLight = hrp:FindFirstChild("ClimberGlow")
			if not glowLight and night then
				glowLight = make("PointLight", { Name = "ClimberGlow", Range = 12, Brightness = 0.9, Shadows = false }, hrp)
			end
			if glowLight and glowLight:IsA("PointLight") then
				glowLight.Enabled = night
				glowLight.Color = (theme.Moon or Color3.new(1, 1, 1)):Lerp(Color3.new(1, 1, 1), 0.5)
			end
		end
	end
	local volcanic = arena and arena:FindFirstChild("Volcanic")
	if volcanic and moodNow then
		for i, vent in volcanic:GetChildren() do
			local glow = vent.Name == "LavaVent" and vent:FindFirstChild("VentGlow")
			if glow and glow:IsA("PointLight") then
				glow.Brightness = 2.5 + math.noise(t * 3, i * 7.1) * 1.5
			end
		end
	end

end)

-- Moving grid

local wearTile: (BasePart, CFrame, number?, string, number) -> CFrame

type Rider = { tower: Instance?, tile: Instance? }
local riders: { [BasePart]: Rider } = {}
-- Grabbing a drop: a flat shockwave ring rolls out across the floor and a column of light shoots up, both in the
-- boost's colour.
boostWave = function(at: Vector3, colour: Color3)
	local wave = Instance.new("Part")
	wave.Shape = Enum.PartType.Cylinder
	wave.Material = Enum.Material.Neon
	wave.Color = colour
	wave.Anchored = true
	wave.CanCollide = false
	wave.CanQuery = false
	wave.CanTouch = false
	wave.CastShadow = false
	wave.Size = Vector3.new(0.2, 2, 2)
	wave.CFrame = CFrame.new(at - Vector3.new(0, 4.5, 0)) * CFrame.Angles(0, 0, math.rad(90))
	wave.Transparency = 0.2
	wave.Parent = workspace
	TweenService:Create(wave, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(0.2, 22, 22), Transparency = 1 }):Play()
	Debris:AddItem(wave, 0.6)
	local column = Instance.new("Part")
	column.Shape = Enum.PartType.Cylinder
	column.Material = Enum.Material.Neon
	column.Color = colour
	column.Anchored = true
	column.CanCollide = false
	column.CanQuery = false
	column.CanTouch = false
	column.CastShadow = false
	column.Size = Vector3.new(30, 3, 3)
	column.CFrame = CFrame.new(at + Vector3.new(0, 11, 0)) * CFrame.Angles(0, 0, math.rad(90))
	column.Transparency = 0.15
	column.Parent = workspace
	TweenService:Create(column, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(40, 0.2, 0.2), Transparency = 1 }):Play()
	Debris:AddItem(column, 0.5)
end

-- Fruit crates appear with a bright flash: a white-hot ball that blooms out in the boost's colour, sparks and a
-- quick burst of light.
local function spawnFlash(crate: BasePart)
	task.wait(0.05) -- let the grid move it onto its tile first
	if not crate.Parent then
		return
	end
	local at = crate.Position
	local tint = crate:GetAttribute("FlashColor")
	local colour = if typeof(tint) == "Color3" then tint else Color3.fromRGB(255, 230, 120)
	local ball = Instance.new("Part")
	ball.Shape = Enum.PartType.Ball
	ball.Material = Enum.Material.Neon
	ball.Color = Color3.new(1, 1, 1)
	ball.Size = Vector3.new(1, 1, 1)
	ball.CFrame = CFrame.new(at)
	ball.Anchored = true
	ball.CanCollide = false
	ball.CanQuery = false
	ball.CanTouch = false
	ball.CastShadow = false
	ball.Parent = workspace
	local light = Instance.new("PointLight")
	light.Color = colour
	light.Range = 24
	light.Brightness = 8
	light.Parent = ball
	local info = TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(ball, info, { Size = Vector3.new(9, 9, 9), Transparency = 1, Color = colour }):Play()
	TweenService:Create(light, info, { Brightness = 0 }):Play()
	Debris:AddItem(ball, 0.5)
	burst(at, ColorSequence.new(Color3.new(1, 1, 1), colour), 40, 22)
	local character = player.Character
	local me = character and character:FindFirstChild("HumanoidRootPart")
	if me and me:IsA("BasePart") and (me.Position - at).Magnitude < 80 then
		play("Crown", 1.8)
	end
end

local function addRider(item: Instance)
	if item:IsA("BasePart") then
		riders[item] = { tower = item:FindFirstAncestor("LavaRushTower"), tile = nil }
		if item:GetAttribute("SpawnFlash") then
			task.spawn(spawnFlash, item)
		end
	end
end
for _, item in CollectionService:GetTagged("LavaRider") do
	addRider(item)
end
CollectionService:GetInstanceAddedSignal("LavaRider"):Connect(addRider)
CollectionService:GetInstanceRemovedSignal("LavaRider"):Connect(function(item)
	riders[item :: BasePart] = nil
end)

-- Wear: a tile darkens, cracks and shakes as it wears out, then shatters into chunks that tumble into the lava.
local CRACKED = Color3.fromRGB(70, 52, 48)
local WHITE = Color3.new(1, 1, 1)
type Look = { color: Color3, material: Enum.Material, broken: boolean }
local looks: { [BasePart]: Look } = {}

local function shatter(tile: BasePart, at: CFrame)
	local size = tile.Size
	local character = player.Character
	local me = character and character:FindFirstChild("HumanoidRootPart")
	if me and me:IsA("BasePart") and (me.Position - at.Position).Magnitude < 70 then
		play("Shove", 0.55)
	end
	for gx = -1, 1 do
		for gz = -1, 1 do
			local chunk = Instance.new("Part")
			chunk.Size = Vector3.new(size.X / 3 - 0.15, size.Y, size.Z / 3 - 0.15)
			chunk.CFrame = at * CFrame.new(gx * size.X / 3, 0, gz * size.Z / 3) * CFrame.Angles(math.random() * 0.3, math.random() * 0.6, math.random() * 0.3)
			chunk.Color = CRACKED:Lerp(looks[tile] and looks[tile].color or tile.Color, 0.35)
			chunk.Material = Enum.Material.Slate
			chunk.CanCollide = false
			chunk.CanQuery = false
			chunk.CanTouch = false
			chunk.CastShadow = false
			chunk.AssemblyLinearVelocity = Vector3.new(gx * 9 + (math.random() - 0.5) * 6, math.random() * 8, gz * 9 + (math.random() - 0.5) * 6)
			chunk.AssemblyAngularVelocity = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 10
			chunk.Parent = workspace
			Debris:AddItem(chunk, 2.5)
		end
	end
	burst(at.Position, ColorSequence.new(Color3.fromRGB(255, 200, 120), Color3.fromRGB(120, 90, 80)), 26, 14)
end

wearTile = function(tile: BasePart, moved: CFrame, crumble: number?, state: string, t: number): CFrame
	local look = looks[tile]
	if not look then
		look = { color = tile.Color, material = tile.Material, broken = false }
		looks[tile] = look
	end
	if state == "Falling" or state == "Gone" then
		if not look.broken then
			look.broken = true
			if state == "Falling" then
				shatter(tile, moved)
			end
		end
		tile.LocalTransparencyModifier = 1
		return moved
	end
	look.broken = false
	tile.LocalTransparencyModifier = 0
	if crumble and crumble > 0 then
		local w = math.min(1, crumble)
		tile.Color = look.color:Lerp(CRACKED, w * 0.75)
		tile.Material = if w > 0.66 then Enum.Material.CrackedLava elseif w > 0.33 then Enum.Material.Cobblestone else Enum.Material.Slate
		if w > 0.66 and not REDUCED_MOTION then
			local shake = (w - 0.66) * 0.5
			moved *= CFrame.new(math.noise(t * 20, tile.Position.X) * shake, 0, math.noise(t * 20, tile.Position.Z) * shake)
				* CFrame.Angles(math.noise(t * 15, 1) * shake * 0.2, 0, math.noise(t * 15, 2) * shake * 0.2)
		end
	elseif tile.Material ~= look.material then
		tile.Color = look.color
		tile.Material = look.material
	else
		look.color = tile.Color -- not worn: follow the server's colour (the world theme recolours tiles)
	end
	return moved
end

local standingOn: BasePart? = nil
local standingCFrame: CFrame? = nil
local footParams = OverlapParams.new()
local pillarTower: Instance? = nil
local function tileUnderFeet(): BasePart?
	local character = player.Character
	local r = character and character:FindFirstChild("HumanoidRootPart")
	local h = character and character:FindFirstChildOfClass("Humanoid")
	if not (r and r:IsA("BasePart") and h) or h.FloorMaterial == Enum.Material.Air then
		return nil
	end
	footParams.FilterDescendantsInstances = { character }
	for _, hit in workspace:GetPartBoundsInBox(r.CFrame * CFrame.new(0, -3.2, 0), Vector3.new(2, 1.6, 2), footParams) do
		if string.match(hit.Name, "^Tile%d+$") and CollectionService:HasTag(hit, "LavaRider") then
			return hit
		end
	end
	-- The centre pillar and its ledges are left out of spatial queries (so the camera ignores them), so check them by
	-- shape: standing on one means riding the centre tile, which they move with exactly.
	if player:GetAttribute("ArenaMode") ~= "LavaRush" then
		return nil
	end
	if not (pillarTower and pillarTower.Parent) then
		pillarTower = workspace:FindFirstChild("LavaRushTower", true) -- only searched again after the tower is rebuilt
	end
	local tower = pillarTower
	local pillar = tower and tower:FindFirstChild("CentrePillar")
	if pillar then
		local feet = r.Position - Vector3.new(0, 3.2, 0)
		for _, piece in pillar:GetChildren() do
			if piece:IsA("Part") then
				local size = piece.Size
				local top = if piece.Shape == Enum.PartType.Cylinder then size.X / 2 else size.Y / 2
				local half = if piece.Shape == Enum.PartType.Cylinder then Vector2.new(size.Y / 2, size.Y / 2) else Vector2.new(size.X / 2, size.Z / 2)
				local flat = Vector3.new(feet.X - piece.Position.X, 0, feet.Z - piece.Position.Z)
				local rel = piece.CFrame:VectorToObjectSpace(flat)
				local inside = if piece.Shape == Enum.PartType.Cylinder then flat.Magnitude <= half.X + 0.8 else math.abs(rel.X) <= half.X + 0.8 and math.abs(rel.Z) <= half.Y + 0.8
				local above = feet.Y - (piece.Position.Y + top)
				if inside and above > -1 and above < 1.6 then
					local size9 = tower:GetAttribute("Size")
					local index = if type(size9) == "number" then (size9 * size9 + 1) / 2 else 41
					return tower:FindFirstChild("Tile" .. index) :: BasePart?
				end
			end
		end
	end
	return nil
end

-- Your own tile cracking: a low crack when the tile under you is half worn, and a lower one with a short gamepad buzz
-- when it's about to break. Your character usually hides that tile from the camera, so the warning shouldn't be
-- visual only (Xbox Accessibility Guideline 103: key cues through more than one sense).
local HapticService = game:GetService("HapticService")
local crackHeard: { [BasePart]: number } = setmetatable({}, { __mode = "k" }) :: any -- tile -> crack stage already played
local function buzz()
	pcall(function()
		if HapticService:IsVibrationSupported(Enum.UserInputType.Gamepad1) then
			HapticService:SetMotor(Enum.UserInputType.Gamepad1, Enum.VibrationMotor.Small, 0.6)
			task.delay(0.18, function()
				HapticService:SetMotor(Enum.UserInputType.Gamepad1, Enum.VibrationMotor.Small, 0)
			end)
		end
	end)
end
local function crackCue(tile: BasePart?)
	local tower = tile and tile.Parent
	local row, col = if tile then tile:GetAttribute("Row") else nil, if tile then tile:GetAttribute("Col") else nil
	if not tile or not tower or type(row) ~= "number" or type(col) ~= "number" then
		return
	end
	local worn = Grid.Crumble(tower, row, col, workspace:GetServerTimeNow()) or 0
	local stage = if worn >= 0.85 then 2 elseif worn >= 0.5 then 1 else 0
	if stage == 0 then
		crackHeard[tile] = nil
	elseif stage > (crackHeard[tile] or 0) then
		crackHeard[tile] = stage
		play("Shove", if stage == 2 then 0.32 else 0.42)
		if stage == 2 then
			buzz()
		end
	end
end

-- A ⚠ symbol on each red warning plate, so the warning doesn't rely on colour alone (red on orange is hard to tell
-- apart with red-green colour blindness). Made locally the first time a plate is seen.
local warnMarks: { [BasePart]: SurfaceGui } = {}
local function warnMark(plate: BasePart): SurfaceGui
	local mark = warnMarks[plate]
	if mark then
		return mark
	end
	mark = Instance.new("SurfaceGui")
	mark.Name = "WarnMark"
	mark.Face = Enum.NormalId.Top
	mark.CanvasSize = Vector2.new(200, 200)
	mark.LightInfluence = 0
	mark.Enabled = false
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = FONT
	label.TextScaled = true
	label.Text = "⚠"
	label.TextColor3 = Color3.fromRGB(30, 8, 8)
	label.Parent = mark
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 6
	stroke.Color = Color3.new(1, 1, 1)
	stroke.Parent = label
	mark.Parent = plate
	warnMarks[plate] = mark
	return mark
end

Run.PreSimulation:Connect(function()
	local t = workspace:GetServerTimeNow()
	local blink = REDUCED_MOTION or math.floor(t * 8) % 2 == 0
	for item, info in riders do
		if not item.Parent then
			riders[item] = nil
			continue
		end
		local stepIndex = item:GetAttribute("RideStep")
		local rest = item:GetAttribute("RestCFrame")
		if type(stepIndex) ~= "number" or typeof(rest) ~= "CFrame" then
			continue
		end
		local towerModel = info.tower
		if not info.tile and towerModel then
			info.tile = towerModel:FindFirstChild("Tile" .. stepIndex)
		end
		local tile = info.tile
		if not tile or not towerModel then
			continue
		end
		local delta = Grid.Delta(towerModel, tile, t)
		local moved = delta * rest
		local pivot = item:GetAttribute("BobPivot")
		if typeof(pivot) == "Vector3" then
			local around = delta * CFrame.new(pivot)
			moved = around * CFrame.new(0, math.sin(t * 3) * 0.45, 0) * CFrame.Angles(0, t * 2.4, 0) * around:Inverse() * moved
		end
		local bornAt, lifetime = item:GetAttribute("BornAt"), item:GetAttribute("Lifetime")
		if type(bornAt) == "number" and type(lifetime) == "number" then
			local left = math.clamp(1 - (t - bornAt) / lifetime, 0, 1)
			local hurry = left < 0.3 and math.floor(t * 8) % 2 == 0
			if item.Name == "LandingRing" then
				local d = 1.2 + 3.6 * left
				item.Size = Vector3.new(0.15, d, d)
				item.Transparency = if hurry then 0.85 else 0.35
			elseif item.Name == "LightPillar" then
				item.Transparency = if hurry then 0.9 else 0.55 + math.sin(t * 6) * 0.12
			end
		end
		local fall = Grid.FallLift(item, t)
		if fall > 0 then
			moved += Vector3.new(0, fall, 0)
		end
		local row, col = tile:GetAttribute("Row"), tile:GetAttribute("Col")
		local state, crumble = "Still", nil
		if type(row) == "number" and type(col) == "number" then
			state = Grid.TileState(towerModel, row, col, t)
			crumble = Grid.Crumble(towerModel, row, col, t)
		end
		local broken = state == "Falling" or state == "Gone"
		if item == tile then
			moved = wearTile(tile, moved, crumble, state, t)
		elseif item.Name == "LiftGlow" or item.Name == "WarnPlate" then
			item.LocalTransparencyModifier = if broken then 1 else 0
		elseif item.Name == "TileCap" then
			-- The bevel cap follows its tile: lighter when fresh, the same cracked colour as it wears.
			item.LocalTransparencyModifier = if broken then 1 else 0
			local capColour = tile.Color:Lerp(WHITE, if crumble and crumble > 0 then 0.04 else 0.16)
			if item.Color ~= capColour then
				item.Color = capColour
			end
			if item.Material ~= tile.Material then
				item.Material = tile.Material
			end
		end
		item.CFrame = if CollectionService:HasTag(item, "LavaEmber") then moved * CFrame.Angles(0, t * 3, 0) else moved
		if item.Name == "WarnPlate" then
			-- Red only for rings about to be left behind; tiles that break show wear and cracks instead.
			local warning = state == "Warning" and crumble == nil and not broken
			item.Transparency = if warning then (if blink then 0.05 else 0.6) else 1
			warnMark(item).Enabled = warning
		end
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	-- Anchored tiles moved by CFrame don't carry characters, so carry ours with the tile under our feet.
	if standingOn and standingCFrame and standingOn.Parent and root and root:IsA("BasePart") then
		local carried = standingOn.CFrame * standingCFrame:Inverse() * root.CFrame
		if (carried.Position - root.Position).Magnitude < 8 then
			root.CFrame = carried
		end
	end
	standingOn = tileUnderFeet()
	standingCFrame = if standingOn then standingOn.CFrame else nil
	crackCue(standingOn)
end)

-- Climb parallax: local-only rocks, clouds and light streaks drift down past the grid in three depth layers,
-- faster up close and slower far away, so the floor feels like it is climbing. They rush while the grid rises.

type Layer = { Count: number, Radius: NumberRange, Span: number, Drift: number, Rush: number }
type Floater = { part: BasePart, layer: Layer, angle: number, radius: number, y: number, spin: number }

local LAYERS: { [string]: Layer } = {
	Streak = { Count = if REDUCED_MOTION then 0 else math.ceil(70 * EFFECTS), Radius = NumberRange.new(54, 95), Span = 70, Drift = 18, Rush = 13 },
	Rock = { Count = math.ceil(28 * EFFECTS), Radius = NumberRange.new(66, 94), Span = 110, Drift = 8, Rush = 5.5 },
	Cloud = { Count = math.ceil(18 * EFFECTS), Radius = NumberRange.new(150, 230), Span = 160, Drift = 3, Rush = 2.2 },
}
local FOV_KICK = 9 -- extra field of view at full rush, the classic "speeding up" cue
local fovApplied = 0

local climbFolder: Folder? = nil
local floaters: { Floater } = {}
local climbTheme: string? = nil
local lastGridY: number? = nil
local rush = 0

local function floaterColour(kind: string, hue: number): Color3
	if kind == "Streak" then
		return Color3.fromHSV(hue, 0.35, 1)
	elseif kind == "Rock" then
		return Color3.fromHSV(hue, 0.3 + math.random() * 0.15, 0.22 + math.random() * 0.12)
	end
	return Color3.fromHSV(hue, 0.12, 1)
end

local function makeFloater(kind: string, layer: Layer, hue: number, parent: Instance): BasePart
	local p = Instance.new("Part")
	p.Name = kind
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Color = floaterColour(kind, hue)
	if kind == "Streak" then
		p.Material = Enum.Material.Neon
		p.Size = Vector3.new(0.35, 5 + math.random() * 6, 0.35)
		p.Transparency = 0.45
	elseif kind == "Rock" then
		p.Material = Enum.Material.Basalt
		local s = 4 + math.random() * 7
		p.Size = Vector3.new(s, s * (0.6 + math.random() * 0.5), s * (0.7 + math.random() * 0.5))
	else
		p.Shape = Enum.PartType.Ball
		p.Material = Enum.Material.SmoothPlastic
		local s = 30 + math.random() * 30
		p.Size = Vector3.new(s, s * 0.22, s * 0.7)
		p.Transparency = 0.7
	end
	p.Parent = parent
	return p
end

local function clearClimb()
	if climbFolder then
		climbFolder:Destroy()
	end
	climbFolder = nil
	table.clear(floaters)
	climbTheme = nil
	lastGridY = nil
	rush = 0
	workspace.CurrentCamera.FieldOfView -= fovApplied
	fovApplied = 0
end

local function buildClimb(gridY: number)
	clearClimb()
	local folder = Instance.new("Folder")
	folder.Name = "ClimbParallax"
	folder.Parent = workspace.CurrentCamera
	climbFolder = folder
	climbTheme = workspace:GetAttribute("LavaTheme")
	local hue = LavaThemes.Get(climbTheme).TileHue or 0.05
	for kind, layer in LAYERS do
		for _ = 1, layer.Count do
			table.insert(floaters, {
				part = makeFloater(kind, layer, hue, folder),
				layer = layer,
				angle = math.random() * math.pi * 2,
				radius = layer.Radius.Min + math.random() * (layer.Radius.Max - layer.Radius.Min),
				y = gridY + (math.random() * 2 - 1) * layer.Span,
				spin = (math.random() * 2 - 1) * 0.6,
			})
		end
	end
end

Run.RenderStepped:Connect(function(dt: number)
	local floors = workspace:FindFirstChild("SkySprout") and workspace.SkySprout:FindFirstChild("Floors")
	local arena = floors and floors:FindFirstChild("Floor_1") and floors.Floor_1:FindFirstChild("LavaRush")
	local tower = arena and arena:FindFirstChild("LavaRushTower")
	local t = workspace:GetServerTimeNow()
	local phase = if tower then Grid.Phase(tower, t) else -1
	local phases = if tower then tower:GetAttribute("Phases") else nil
	if not tower or phase < 0 or type(phases) ~= "number" or phase >= phases then
		if climbFolder then
			clearClimb()
		end
		return
	end
	local _, gridY = Grid.Pose(tower, t)
	if not climbFolder then
		buildClimb(gridY)
	end
	local themeNow = workspace:GetAttribute("LavaTheme")
	if themeNow ~= climbTheme then
		climbTheme = themeNow
		local hue = LavaThemes.Get(themeNow).TileHue or 0.05
		for _, f in floaters do
			f.part.Color = floaterColour(f.part.Name, hue)
		end
	end
	-- How fast the grid is climbing right now (0 between rises), smoothed so the rush eases in and out.
	local climbing = if lastGridY and dt > 0 then math.max(0, (gridY - lastGridY) / dt) else 0
	lastGridY = gridY
	rush += (climbing - rush) * math.min(1, dt * 5)
	local camera = workspace.CurrentCamera
	local kick = if REDUCED_MOTION then 0 else math.clamp(rush / 5, 0, 1) * FOV_KICK
	camera.FieldOfView += kick - fovApplied
	fovApplied = kick
	local cx, cz = tower:GetAttribute("CenterX"), tower:GetAttribute("CenterZ")
	if type(cx) ~= "number" or type(cz) ~= "number" then
		return
	end
	local cameraPos = camera.CFrame.Position
	local cameraY = cameraPos.Y
	local centreY = math.max(gridY, cameraY - 10)
	for _, f in floaters do
		local layer = f.layer
		f.y -= (layer.Drift + rush * layer.Rush) * dt
		if f.y < centreY - layer.Span then
			f.y += layer.Span * 2
			f.angle = math.random() * math.pi * 2
		elseif f.y > centreY + layer.Span then
			f.y -= layer.Span * 2
		end
		local pos = Vector3.new(cx + math.cos(f.angle) * f.radius, f.y, cz + math.sin(f.angle) * f.radius)
		if f.part.Name == "Streak" then
			-- Streaks stretch with the rush, like speed lines.
			f.part.Size = Vector3.new(0.4, math.clamp(8 + rush * 3, 8, 40), 0.4)
			-- Fade streaks that pass close to the camera so they never cut across the view.
			local close = math.clamp((40 - (pos - cameraPos).Magnitude) / 25, 0, 1)
			f.part.Transparency = math.min(1, math.clamp(0.5 - rush * 0.06, 0.15, 0.5) + close * 0.85)
			f.part.CFrame = CFrame.new(pos)
		elseif f.part.Name == "Cloud" then
			f.part.CFrame = CFrame.new(pos) * CFrame.Angles(0, f.angle, 0)
		else
			f.part.CFrame = CFrame.new(pos) * CFrame.Angles(t * f.spin, t * f.spin * 0.7, 0)
		end
	end
end)

-- Spectate

local UIS = game:GetService("UserInputService")
local spectating = false
local spectateAutoEnded = 0 -- when the round (not the player) last ended spectating
local function stopSpectate(byPlayer: boolean?)
	if not spectating then
		return
	end
	spectating = false
	if not byPlayer then
		spectateAutoEnded = os.clock()
	end
	spectateLabel.Visible = false
	setGiftTarget(nil)
	game:GetService("ContextActionService"):UnbindAction("LavaFollowPad")
	Run:UnbindFromRenderStep("LavaSpectate")
	workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
end
-- Follow a climber: the ◀ ▶ buttons cycle through everyone still climbing (players and bots); nil = overhead view.
local OVERHEAD_TEXT = "👀 Spectating from above · next round soon"
local followKey: string? = nil
local function climbers(towerModel: Instance): { { key: string, name: string, root: BasePart } }
	local list = {}
	for _, other in Players:GetPlayers() do
		local r = other.Character and other.Character:FindFirstChild("HumanoidRootPart")
		if other ~= player and other:GetAttribute("ArenaMode") == "LavaRush" and r and r:IsA("BasePart") then
			table.insert(list, { key = "P" .. other.UserId, name = other.DisplayName, root = r })
		end
	end
	for _, m in towerModel:GetChildren() do
		if m:IsA("Model") and string.sub(m.Name, 1, 4) == "Bot_" then
			local r = m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart")
			if r then
				table.insert(list, { key = m.Name, name = "🤖 " .. string.sub(m.Name, 5), root = r })
			end
		end
	end
	return list
end
local function cycleFollow(step: number)
	local floors = workspace:FindFirstChild("SkySprout") and workspace.SkySprout:FindFirstChild("Floors")
	local towerModel = floors and floors:FindFirstChild("LavaRushTower", true)
	if not towerModel then
		return
	end
	local list = climbers(towerModel)
	local index = 0 -- 0 = overhead
	for i, c in list do
		if c.key == followKey then
			index = i
		end
	end
	index = (index + step) % (#list + 1)
	followKey = if index == 0 then nil else list[index].key
	spectateLabel.Text = if index == 0 then OVERHEAD_TEXT else "👀 Watching " .. list[index].name
	local key = followKey
	setGiftTarget(if key and string.sub(key, 1, 1) == "P" then tonumber(string.sub(key, 2)) else nil)
end
spectateButtons[1].Activated:Connect(function()
	cycleFollow(-1)
end)
spectateButtons[2].Activated:Connect(function()
	cycleFollow(1)
end)

local function startSpectate()
	if spectating then
		return
	end
	spectating = true
	followKey = nil
	spectateLabel.Text = OVERHEAD_TEXT
	setGiftTarget(nil)
	-- Controller: L1 / R1 switch who you follow and X sends the strawberry gift, without UI selection mode.
	game:GetService("ContextActionService"):BindAction("LavaFollowPad", function(_, inputState, input)
		if inputState ~= Enum.UserInputState.Begin then
			return Enum.ContextActionResult.Pass
		end
		if input.KeyCode == Enum.KeyCode.ButtonL1 then
			cycleFollow(-1)
		elseif input.KeyCode == Enum.KeyCode.ButtonR1 then
			cycleFollow(1)
		elseif input.KeyCode == Enum.KeyCode.ButtonX and giftButton.Visible then
			sendGift()
		else
			return Enum.ContextActionResult.Pass
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.ButtonL1, Enum.KeyCode.ButtonR1, Enum.KeyCode.ButtonX)
	spectateLabel.Visible = true
	local started = os.clock()
	Run:BindToRenderStep("LavaSpectate", Enum.RenderPriority.Camera.Value + 1, function()
		local floors = workspace:FindFirstChild("SkySprout") and workspace.SkySprout:FindFirstChild("Floors")
		local arena = floors and floors:FindFirstChild("Floor_1") and floors.Floor_1:FindFirstChild("LavaRush")
		local towerModel = arena and arena:FindFirstChild("LavaRushTower")
		local size = towerModel and towerModel:GetAttribute("Size")
		local centre = towerModel and type(size) == "number" and towerModel:FindFirstChild("Tile" .. (size * size + 1) / 2)
		if not centre or not centre:IsA("BasePart") or state.Phase ~= "Round" then
			stopSpectate()
			return
		end
		local cam = workspace.CurrentCamera
		if followKey then
			-- Chase camera: just outside the followed climber, looking back across the floor at them.
			local target
			for _, c in climbers(towerModel) do
				if c.key == followKey then
					target = c
				end
			end
			if target then
				local at = target.root.Position
				local out = Vector3.new(at.X - centre.Position.X, 0, at.Z - centre.Position.Z)
				out = if out.Magnitude > 1 then out.Unit else Vector3.new(0, 0, 1)
				local goal = CFrame.lookAt(at + out * 13 + Vector3.new(0, 8, 0), at + Vector3.new(0, 1.5, 0))
				cam.CameraType = Enum.CameraType.Scriptable
				cam.CFrame = cam.CFrame:Lerp(goal, if REDUCED_MOTION then 1 else 0.15)
				return
			end
			-- They're out of the round: back to the overhead view.
			followKey = nil
			spectateLabel.Text = OVERHEAD_TEXT
			setGiftTarget(nil)
		end
		local a = (os.clock() - started) * 0.08
		local ease = math.min(1, (os.clock() - started) / 1.2) -- swoop up into the overhead view
		cam.CameraType = Enum.CameraType.Scriptable
		local overhead = centre.Position + Vector3.new(math.cos(a) * 16, 62 + 8 * ease, math.sin(a) * 16)
		local swoop = centre.Position + Vector3.new(math.cos(a) * 40, 20, math.sin(a) * 40)
		cam.CFrame = CFrame.lookAt(swoop:Lerp(overhead, ease * ease * (3 - 2 * ease)), centre.Position)
	end)
end
player:GetAttributeChangedSignal("ArenaMode"):Connect(function()
	local mode = player:GetAttribute("ArenaMode")
	if mode == "LavaRush" then
		stopSpectate()
	elseif mode == "Lobby" and state.Phase == "Round" then
		task.delay(1.2, function()
			if player:GetAttribute("ArenaMode") == "Lobby" and state.Phase == "Round" then
				startSpectate()
			end
		end)
	end
end)
local LOOK_KEYS = {
	[Enum.KeyCode.W] = true,
	[Enum.KeyCode.A] = true,
	[Enum.KeyCode.S] = true,
	[Enum.KeyCode.D] = true,
	[Enum.KeyCode.Space] = true,
	[Enum.KeyCode.Thumbstick1] = true,
}
-- Winner cam: when a round ends, anyone who was watching from above swings round to the winner for a few seconds,
-- so the whole server sees who escaped. Winners and players who walked off keep their own camera. A move key or a
-- drag hands the camera back early; Reduce Motion cuts straight to a still shot instead of swooping and orbiting.
local WINNER_CAM_SECONDS = 3.2
local winnerCamUntil = 0
local function winnerCam(at: Vector3)
	stopSpectate()
	local cam = workspace.CurrentCamera
	local from = cam.CFrame
	local started = os.clock()
	local a0 = math.atan2(from.Position.Z - at.Z, from.Position.X - at.X)
	winnerCamUntil = started + WINNER_CAM_SECONDS
	Run:UnbindFromRenderStep("LavaWinnerCam")
	Run:BindToRenderStep("LavaWinnerCam", Enum.RenderPriority.Camera.Value + 2, function()
		local t = os.clock() - started
		if os.clock() >= winnerCamUntil then
			Run:UnbindFromRenderStep("LavaWinnerCam")
			cam.CameraType = Enum.CameraType.Custom
			return
		end
		cam.CameraType = Enum.CameraType.Scriptable
		local a = a0 + (if REDUCED_MOTION then 0 else t * 0.35)
		local goal = CFrame.lookAt(at + Vector3.new(math.cos(a) * 14, 6, math.sin(a) * 14), at + Vector3.new(0, 1.5, 0))
		local ease = if REDUCED_MOTION then 1 else math.min(1, t / 0.8)
		cam.CFrame = from:Lerp(goal, ease * ease * (3 - 2 * ease))
	end)
end
showWinnerCam = function(names: { any }, positions: { any })
	local watching = spectating or os.clock() - spectateAutoEnded < 2
	local at = positions[1]
	if not watching or typeof(at) ~= "Vector3" or table.find(names, player.DisplayName) then
		return
	end
	winnerCam(at)
end

UIS.InputBegan:Connect(function(input, processed)
	local look = LOOK_KEYS[input.KeyCode] or input.UserInputType == Enum.UserInputType.MouseButton2 or input.UserInputType == Enum.UserInputType.Touch
	if spectating and not processed and look then
		stopSpectate(true)
	end
	if winnerCamUntil > os.clock() and not processed and look then
		winnerCamUntil = 0
	end
end)

-- Away: after the server's LavaAwayAfter seconds with no input at all, ask to sit out the automatic rounds (so you
-- aren't dropped in to fall off while you're gone). The first input afterwards puts you back in the queue.
do
	local lastInput = os.clock()
	local askedBack = false
	local function active()
		lastInput = os.clock()
		if player:GetAttribute("LavaAway") and not askedBack then
			askedBack = true
			event:FireServer("LavaBack")
		end
	end
	player:GetAttributeChangedSignal("LavaAway"):Connect(function()
		askedBack = false
		lastInput = os.clock()
	end)
	UIS.InputBegan:Connect(active)
	UIS.InputChanged:Connect(active)
	task.spawn(function()
		while true do
			task.wait(10)
			local after = tonumber(workspace:GetAttribute("LavaAwayAfter"))
			if after and os.clock() - lastInput > after and not player:GetAttribute("LavaAway") and not player:GetAttribute("LavaOptOut") then
				event:FireServer("LavaAway")
			end
		end
	end)
end

-- Active volcano: ash drifts down from the rim, sparks float up through the crater, the lava falls on the walls
-- stream downward, and during a round the lava throws up glowing fountains every few seconds. All local and visual.
local volcanoAir: Model? = nil
local fallTextures: { Texture } = {}
local blobs: { { part: BasePart, vel: Vector3, floorY: number } } = {}
local nextFountain = 0

local function buildVolcanoAir(crater: Instance, cx: number, cz: number)
	local rimAttr = crater:GetAttribute("RimY")
	local rimY = if type(rimAttr) == "number" then rimAttr else 80
	local air = Instance.new("Model")
	air.Name = "VolcanoAir"
	local function emitterPart(name: string, size: Vector3, at: Vector3): BasePart
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Transparency = 1
		p.Size = size
		p.CFrame = CFrame.new(at)
		p.Parent = air
		return p
	end
	local ashPart = emitterPart("Ash", Vector3.new(190, 1, 190), Vector3.new(cx, rimY + 12, cz))
	local ash = Instance.new("ParticleEmitter")
	ash.Shape = Enum.ParticleEmitterShape.Box
	ash.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	ash.EmissionDirection = Enum.NormalId.Bottom
	ash.Rate = 45 * EFFECTS
	ash.Lifetime = NumberRange.new(10, 16)
	ash.Speed = NumberRange.new(3, 6)
	ash.SpreadAngle = Vector2.new(20, 20)
	ash.RotSpeed = NumberRange.new(-90, 90)
	ash.Rotation = NumberRange.new(0, 360)
	ash.Color = ColorSequence.new(Color3.fromRGB(150, 140, 140), Color3.fromRGB(90, 85, 90))
	ash.Size = NumberSequence.new(0.35)
	ash.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.1, 0.25), NumberSequenceKeypoint.new(1, 0.6) })
	ash.Parent = ashPart
	local sparkPart = emitterPart("Sparks", Vector3.new(170, 50, 170), Vector3.new(cx, 30, cz))
	local sparks = Instance.new("ParticleEmitter")
	sparks.Shape = Enum.ParticleEmitterShape.Box
	sparks.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	sparks.EmissionDirection = Enum.NormalId.Top
	sparks.Rate = 70 * EFFECTS
	sparks.Lifetime = NumberRange.new(3, 6)
	sparks.Speed = NumberRange.new(2, 5)
	sparks.SpreadAngle = Vector2.new(35, 35)
	sparks.LightEmission = 1
	sparks.Color = ColorSequence.new(Color3.fromRGB(255, 220, 110), Color3.fromRGB(255, 70, 15))
	sparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) })
	sparks.Parent = sparkPart
	local snow = Instance.new("ParticleEmitter")
	snow.Name = "Snow"
	snow.Shape = Enum.ParticleEmitterShape.Box
	snow.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	snow.EmissionDirection = Enum.NormalId.Bottom
	snow.Rate = 120
	snow.Lifetime = NumberRange.new(8, 12)
	snow.Speed = NumberRange.new(5, 9)
	snow.SpreadAngle = Vector2.new(25, 25)
	snow.Color = ColorSequence.new(Color3.new(1, 1, 1))
	snow.LightEmission = 0.4
	snow.Size = NumberSequence.new(0.3)
	snow.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.1, 0.1), NumberSequenceKeypoint.new(1, 0.4) })
	snow.Parent = ashPart
	local function snowing()
		local id = workspace:GetAttribute("LavaEvent")
		local on = false
		for _, e in Config.Events or {} do
			if e.Id == id and e.Snow then
				on = true
			end
		end
		snow.Enabled = on
	end
	workspace:GetAttributeChangedSignal("LavaEvent"):Connect(snowing)
	snowing()
	air.Parent = workspace.CurrentCamera
	volcanoAir = air
	table.clear(fallTextures)
	for _, d in crater:GetDescendants() do
		if d:IsA("BasePart") and d.Name == "LavaFall" then
			for layer = 1, 2 do
				local tex = Instance.new("Texture")
				tex.Face = Enum.NormalId.Front
				tex.Texture = "rbxasset://textures/particles/smoke_main.dds"
				tex.StudsPerTileU = if layer == 1 then 6 else 10
				tex.StudsPerTileV = if layer == 1 then 9 else 15
				tex.Color3 = if layer == 1 then Color3.fromRGB(255, 230, 130) else Color3.fromRGB(255, 160, 50)
				tex.Transparency = if layer == 1 then 0.3 else 0.45
				tex.Parent = d
				table.insert(fallTextures, tex)
			end
		end
	end
end

local function fountain(lava: BasePart, cx: number, cz: number)
	local top = lava.Position.Y + lava.Size.Y / 2
	local half = lava.Size.X / 2 - 2
	-- Somewhere in the open lava around the grid.
	local a = math.random() * math.pi * 2
	local r = math.random() * 6 + half - 6
	local at = Vector3.new(cx + math.cos(a) * r, top, cz + math.sin(a) * r)
	burst(at, FIRE, 40, 18)
	local me = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if me and me:IsA("BasePart") and (me.Position - at).Magnitude < 90 then
		play("Scorch", 0.55 + math.random() * 0.1)
	end
	for _ = 1, if LOW_END then 5 else 9 do
		local blob = Instance.new("Part")
		blob.Shape = Enum.PartType.Ball
		blob.Material = Enum.Material.Neon
		blob.Color = Color3.fromRGB(255, 120 + math.random(0, 80), 30)
		local s = 0.7 + math.random() * 1.1
		blob.Size = Vector3.new(s, s, s)
		blob.Anchored = true
		blob.CanCollide = false
		blob.CanQuery = false
		blob.CanTouch = false
		blob.CastShadow = false
		blob.CFrame = CFrame.new(at)
		local trail = Instance.new("ParticleEmitter")
		trail.Texture = "rbxasset://textures/particles/fire_main.dds"
		trail.Rate = 40
		trail.Lifetime = NumberRange.new(0.3, 0.6)
		trail.Speed = NumberRange.new(0.5, 1.5)
		trail.LightEmission = 1
		trail.Color = FIRE
		trail.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, s * 1.2), NumberSequenceKeypoint.new(1, 0) })
		trail.Parent = blob
		blob.Parent = workspace
		local spread = Vector3.new(math.random() - 0.5, 0, math.random() - 0.5) * 22
		table.insert(blobs, { part = blob, vel = spread + Vector3.new(0, 30 + math.random() * 22, 0), floorY = top })
	end
end

Run.RenderStepped:Connect(function(dt: number)
	local floors = workspace:FindFirstChild("SkySprout") and workspace.SkySprout:FindFirstChild("Floors")
	local arena = floors and floors:FindFirstChild("Floor_1") and floors.Floor_1:FindFirstChild("LavaRush")
	local crater = arena and arena:FindFirstChild("Crater", true)
	local tower = arena and arena:FindFirstChild("LavaRushTower")
	local cx = tower and tower:GetAttribute("CenterX")
	local cz = tower and tower:GetAttribute("CenterZ")
	if crater and type(cx) == "number" and type(cz) == "number" and not volcanoAir then
		buildVolcanoAir(crater, cx, cz)
	end
	for _, tex in fallTextures do
		tex.OffsetStudsV = (tex.OffsetStudsV - dt * (if tex.StudsPerTileV < 12 then 14 else 9)) % tex.StudsPerTileV
	end
	local lava = tower and tower:FindFirstChild("Lava")
	if lava and lava:IsA("BasePart") and type(cx) == "number" and type(cz) == "number" and state.Phase == "Round" and os.clock() >= nextFountain then
		nextFountain = os.clock() + (if LOW_END then 5 else 3) + math.random() * 3
		fountain(lava, cx, cz)
	end
	for i = #blobs, 1, -1 do
		local b = blobs[i]
		b.vel += Vector3.new(0, -70 * dt, 0)
		local pos = b.part.Position + b.vel * dt
		if pos.Y < b.floorY and b.vel.Y < 0 then
			burst(Vector3.new(pos.X, b.floorY, pos.Z), FIRE, 8, 8)
			b.part:Destroy()
			table.remove(blobs, i)
		else
			b.part.CFrame = CFrame.new(pos)
		end
	end
end)

-- Bots ride their tile like everything else on the grid: the server only says which tile, so each client places
-- them on the moving floor every frame, with a little hop arc between tiles and a tumble into the lava when out.
type BotView = { row: number?, col: number?, from: CFrame?, at: number, last: CFrame? }
local botViews: { [BasePart]: BotView } = {}
Run.RenderStepped:Connect(function()
	local floors = workspace:FindFirstChild("SkySprout") and workspace.SkySprout:FindFirstChild("Floors")
	local arena = floors and floors:FindFirstChild("Floor_1") and floors.Floor_1:FindFirstChild("LavaRush")
	local towerModel = arena and arena:FindFirstChild("LavaRushTower")
	if not towerModel then
		return
	end
	local t = workspace:GetServerTimeNow()
	for _, item in CollectionService:GetTagged("LavaBot") do
		if not item:IsA("BasePart") or not item:IsDescendantOf(towerModel) then
			continue
		end
		local row, col, stand, yaw = item:GetAttribute("BotRow"), item:GetAttribute("BotCol"), item:GetAttribute("BotStand"), item:GetAttribute("BotYaw")
		if type(row) ~= "number" or type(col) ~= "number" or type(stand) ~= "number" then
			continue
		end
		local view = botViews[item]
		if not view then
			view = { at = 0 }
			botViews[item] = view
		end
		local fallAt = item:GetAttribute("BotFalling")
		if type(fallAt) == "number" then
			local k = math.max(0, t - fallAt)
			local base = view.last or item.CFrame
			item.CFrame = (base - Vector3.new(0, 26 * k * k, 0)) * CFrame.Angles(k * 3, 0, k * 2)
			continue
		end
		local target = Grid.TileCFrame(towerModel, row, col, t) * CFrame.new(0, 0.6 + stand, 0) * CFrame.Angles(0, if type(yaw) == "number" then yaw else 0, 0)
		if view.row ~= row or view.col ~= col then
			view.from = view.last
			view.at = t
			view.row, view.col = row, col
		end
		local cf = target
		local from = view.from
		if from and t - view.at < 0.3 then
			local k = (t - view.at) / 0.3
			local pos = from.Position:Lerp(target.Position, k) + Vector3.new(0, math.sin(k * math.pi) * 3, 0)
			cf = CFrame.new(pos) * target.Rotation
		end
		item.CFrame = cf
		view.last = cf
	end
	for item in botViews do
		if not item.Parent then
			botViews[item] = nil
		end
	end
end)

-- Eruption: each time the floor rises the volcano rumbles: a short camera shake, and a few glowing rocks break off
-- the crater rim and plunge into the lava. Purely visual and local, so it never touches anyone.
local SHAKE_TIME = 0.7
local shakeUntil = 0
local shakeStrength = 0
local shakeLength = SHAKE_TIME
Run:BindToRenderStep("LavaRumble", Enum.RenderPriority.Camera.Value + 1, function()
	local left = shakeUntil - os.clock()
	if left <= 0 then
		return
	end
	local k = shakeStrength * (left / shakeLength)
	local t = os.clock() * 30
	local cam = workspace.CurrentCamera
	cam.CFrame *= CFrame.new(math.noise(t, 0.3) * k, math.noise(t, 1.7) * k, 0) * CFrame.Angles(0, 0, math.noise(t, 3.1) * k * 0.02)
end)

rumble = function(strength: number, length: number?)
	if REDUCED_MOTION then
		return
	end
	-- A weaker shake (a shove kick) never cuts a stronger one (an eruption) short.
	local left = shakeUntil - os.clock()
	if left > 0 and shakeStrength * (left / shakeLength) > strength then
		return
	end
	shakeStrength = strength
	shakeLength = length or SHAKE_TIME
	shakeUntil = os.clock() + shakeLength
end

local function fallingRock(tower: Instance, lavaY: number)
	local cx, cz = tower:GetAttribute("CenterX"), tower:GetAttribute("CenterZ")
	if type(cx) ~= "number" or type(cz) ~= "number" then
		return
	end
	local floors = workspace:FindFirstChild("SkySprout") and workspace.SkySprout:FindFirstChild("Floors")
	local crater = floors and floors:FindFirstChild("Crater", true)
	local rimAttr = crater and crater:GetAttribute("RimY")
	local rimY = if type(rimAttr) == "number" then rimAttr else 80
	local a = math.random() * math.pi * 2
	local from = Vector3.new(cx + math.cos(a) * 96, rimY - 4, cz + math.sin(a) * 96)
	local to = Vector3.new(cx + math.cos(a) * (48 + math.random() * 10), lavaY, cz + math.sin(a) * (48 + math.random() * 10))
	local rock = Instance.new("Part")
	rock.Name = "EruptionRock"
	rock.Anchored = true
	rock.CanCollide = false
	rock.CanQuery = false
	rock.CanTouch = false
	rock.CastShadow = false
	local size = 2.5 + math.random() * 3
	rock.Size = Vector3.new(size, size * 0.8, size * 0.9)
	rock.Material = Enum.Material.CrackedLava
	rock.Color = Color3.fromRGB(255, 110, 40)
	rock.CFrame = CFrame.new(from)
	local trail = Instance.new("ParticleEmitter")
	trail.Texture = "rbxasset://textures/particles/fire_main.dds"
	trail.Rate = 60
	trail.Lifetime = NumberRange.new(0.4, 0.8)
	trail.Speed = NumberRange.new(1, 3)
	trail.LightEmission = 1
	trail.Color = ColorSequence.new(Color3.fromRGB(255, 200, 80), Color3.fromRGB(255, 60, 10))
	trail.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size * 0.8), NumberSequenceKeypoint.new(1, 0) })
	trail.Parent = rock
	rock.Parent = workspace
	local fall = 1.1 + math.random() * 0.4
	local spin = CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6)
	task.spawn(function()
		local start = os.clock()
		while rock.Parent do
			local k = math.min(1, (os.clock() - start) / fall)
			-- Arc inward, then accelerate down like it's really falling.
			local flat = from:Lerp(to, k)
			local y = from.Y + (to.Y - from.Y) * k * k + math.sin(k * math.pi) * 6
			rock.CFrame = CFrame.new(flat.X, y, flat.Z) * spin:Lerp(CFrame.identity, 1 - k)
			if k >= 1 then
				break
			end
			Run.RenderStepped:Wait()
		end
		burst(to, FIRE, 30, 22)
		rock:Destroy()
	end)
end

local function erupt(tower: Instance)
	rumble(0.35)
	play("Shove", 0.45)
	for i = 1, 4 do
		task.delay(i * 0.18, fallingRock, tower, state.LavaY)
	end
end

-- Climb meter: a slim bar on the right edge. The floor marker climbs toward the crown at the top while the
-- lava fills up from below, so you can see at a glance how high you are and how close the lava is.

local meter: Frame = make("Frame", {
	Name = "ClimbMeter",
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -18, 0.43, 0),
	Size = UDim2.new(0, 22, 0.38, 0),
	BackgroundColor3 = Color3.fromRGB(35, 20, 30),
	BackgroundTransparency = 0.25,
	Visible = false,
}, gui)
make("UISizeConstraint", { MinSize = Vector2.new(22, 150), MaxSize = Vector2.new(22, 320) }, meter)
make("UICorner", { CornerRadius = UDim.new(1, 0) }, meter)
UI.glass(meter)
local meterLava: Frame = make("Frame", {
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.fromScale(0, 1),
	Size = UDim2.fromScale(1, 0),
	BackgroundColor3 = Color3.new(1, 1, 1),
	BorderSizePixel = 0,
}, meter)
make("UICorner", { CornerRadius = UDim.new(1, 0) }, meterLava)
make("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(255, 200, 60), Color3.fromRGB(230, 50, 20)) }, meterLava)
local meterCrown: TextLabel = make("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 0, -4),
	Size = UDim2.fromOffset(34, 30),
	BackgroundTransparency = 1,
	Font = FONT,
	TextScaled = true,
	Text = "👑",
}, meter)
local meterFloor: Frame = make("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 1),
	Size = UDim2.fromOffset(40, 12),
	BackgroundColor3 = Color3.new(1, 1, 1),
	ZIndex = 3,
}, meter)
make("UICorner", { CornerRadius = UDim.new(0, 4) }, meterFloor)
local meterFloorStroke: UIStroke = make("UIStroke", { Thickness = 2.5, Color = Color3.fromRGB(40, 20, 30) }, meterFloor)
local meterTicks: { Frame } = {}
-- Your personal best: a gold line with a medal beside the bar, so you can see the height to beat this round.
local meterBest: Frame = make("Frame", {
	Name = "BestMark",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0),
	Size = UDim2.new(1, 10, 0, 3),
	BackgroundColor3 = Color3.fromRGB(255, 215, 80),
	BorderSizePixel = 0,
	Visible = false,
	ZIndex = 2,
}, meter)
make("TextLabel", {
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(0, -4, 0.5, 0),
	Size = UDim2.fromOffset(22, 22),
	BackgroundTransparency = 1,
	Font = FONT,
	TextScaled = true,
	Text = "🏅",
	ZIndex = 2,
}, meterBest)
local bestCheered = false

local meterLavaY: number? = nil
local meterFloorFrac = 0
local riseY: number? = nil
local rising = false

Run.RenderStepped:Connect(function(dt: number)
	local floors = workspace:FindFirstChild("SkySprout") and workspace.SkySprout:FindFirstChild("Floors")
	local arena = floors and floors:FindFirstChild("Floor_1") and floors.Floor_1:FindFirstChild("LavaRush")
	local tower = arena and arena:FindFirstChild("LavaRushTower")
	local watching = me.Running or spectating
	local show = tower ~= nil and state.Phase == "Round" and watching and (player:GetAttribute("VisitFloor") or 1) == 1
	meter.Visible = show
	if not show or not tower then
		meterLavaY, riseY, rising = nil, nil, false
		bestCheered = false
		return
	end
	local t = workspace:GetServerTimeNow()
	local _, gridY = Grid.Pose(tower, t)
	local bottom, top = state.BaseY, state.CrownY
	local span = math.max(1, top - bottom)
	local function frac(y: number): number
		return math.clamp((y - bottom) / span, 0, 1)
	end

	-- One tick per rise, so the bar shows how many steps are left to the crown.
	local base, step, phases = tower:GetAttribute("BaseY"), tower:GetAttribute("RiseStep"), tower:GetAttribute("Phases")
	if type(base) == "number" and type(step) == "number" and type(phases) == "number" and #meterTicks ~= phases then
		for _, tick in meterTicks do
			tick:Destroy()
		end
		table.clear(meterTicks)
		for p = 1, phases do
			table.insert(meterTicks, make("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 1 - frac(base + step * p)),
				Size = UDim2.new(1, -8, 0, 2),
				BackgroundColor3 = Color3.new(1, 1, 1),
				BackgroundTransparency = 0.55,
				BorderSizePixel = 0,
				ZIndex = 2,
			}, meter))
		end
	end

	meterLavaY = if meterLavaY then meterLavaY + (state.LavaY - meterLavaY) * math.min(1, dt * 4) else state.LavaY
	local lavaFrac = frac(meterLavaY :: number)
	meterLava.Size = UDim2.fromScale(1, lavaFrac)
	meterFloorFrac += (frac(gridY) - meterFloorFrac) * math.min(1, dt * 10)
	meterFloor.Position = UDim2.fromScale(0.5, 1 - meterFloorFrac)
	local theme = LavaThemes.Get(workspace:GetAttribute("LavaTheme"))
	local danger = math.clamp(1 - (meterFloorFrac - lavaFrac) / 0.12, 0, 1)
	local blink = danger > 0.5 and (REDUCED_MOTION or math.floor(t * 6) % 2 == 0)
	meterFloor.BackgroundColor3 = if blink then Color3.fromRGB(255, 70, 40) else Color3.fromHSV(theme.TileHue or 0.05, 0.35, 1)
	meterFloorStroke.Color = if danger > 0.5 then Color3.fromRGB(120, 10, 0) else Color3.fromRGB(40, 20, 30)
	meterCrown.TextTransparency = if meterFloorFrac > 0.97 then 0 else 0.35

	-- Personal best marker. Heights are measured at your character, which stands about 3 studs above its tile.
	local best = tonumber(player:GetAttribute("BestHeight")) or 0
	local bestFrac = frac(bottom + best - 3)
	meterBest.Visible = best > 0 and bestFrac < 0.97
	meterBest.Position = UDim2.fromScale(0.5, 1 - bestFrac)
	local myRoot = rootPart()
	if me.Running and best > 0 and not bestCheered and myRoot and myRoot.Position.Y - bottom > best + 0.5 then
		bestCheered = true -- climbed past your old best: cheer once per round
		play("Crown", 1.5)
		floatText(myRoot.Position + Vector3.new(0, 3, 0), "🏅 NEW BEST!")
		burst(myRoot.Position, ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(255, 215, 80)), 50, 20)
		pop(meterBest)
	end

	-- Whoosh + a little pop on the marker each time the floor starts to rise.
	if riseY and gridY > riseY + 0.05 then
		if not rising then
			rising = true
			play("Rise", 0.95 + math.random() * 0.1)
			pop(meterFloor)
			erupt(tower)
		end
	elseif riseY and gridY <= riseY + 0.001 then
		rising = false
	end
	riseY = gridY
end)

-- Hot Potato: a quick beep each second for the last 3 seconds while you hold the bomb.
local lastBombText = ""
Run.Heartbeat:Connect(function()
	local character = player.Character
	local bombModel = character and character:FindFirstChild("LavaBomb")
	local label = bombModel and bombModel:FindFirstChild("TextLabel", true)
	local text = if label and label:IsA("TextLabel") then label.Text else ""
	if text ~= lastBombText then
		lastBombText = text
		local secs = tonumber(string.match(text, "%d+"))
		if secs and secs <= 3 and secs > 0 then
			play("Beep", 1.6 + (3 - secs) * 0.2)
			tint.BackgroundTransparency = 0.7
		end
	end
end)

-- Lobby gems: spin and bob the hidden lava gems, and hide the ones you've already found (the server lists them in
-- the "LavaGems" attribute). Gems stream in and out, so this works on whatever is loaded.
do
	local function foundSet(): { [string]: boolean }
		local set = {}
		for id in string.gmatch(tostring(player:GetAttribute("LavaGems") or ""), "[^,]+") do
			set[id] = true
		end
		return set
	end
	local found = foundSet()
	player:GetAttributeChangedSignal("LavaGems"):Connect(function()
		found = foundSet()
	end)
	local home: { [BasePart]: Vector3 } = setmetatable({}, { __mode = "k" }) :: any
	local TILT = CFrame.Angles(math.rad(45), 0, math.rad(45))
	Run.RenderStepped:Connect(function()
		local floors = workspace:FindFirstChild("SkySprout") and workspace.SkySprout:FindFirstChild("Floors")
		local floor1 = floors and floors:FindFirstChild("Floor_1")
		local folder = floor1 and floor1:FindFirstChild("LobbyGems")
		if not folder then
			return
		end
		local t = os.clock()
		for _, gem in folder:GetChildren() do
			if gem:IsA("BasePart") then
				local at = home[gem]
				if not at then
					at = gem.Position
					home[gem] = at
				end
				local hidden = found[gem.Name] == true
				gem.Transparency = if hidden then 1 else 0
				for _, fx in gem:GetChildren() do
					if fx:IsA("PointLight") or fx:IsA("ParticleEmitter") then
						fx.Enabled = not hidden
					end
				end
				if not hidden and not REDUCED_MOTION then
					gem.CFrame = CFrame.new(at + Vector3.new(0, math.sin(t * 2) * 0.25, 0)) * CFrame.Angles(0, t * 1.5, 0) * TILT
				end
			end
		end
	end)
end
