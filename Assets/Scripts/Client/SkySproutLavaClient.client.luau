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

type State = { Phase: string, EndsAt: number, Mutator: string?, Theme: string?, Queued: number, Running: number, LavaY: number, BaseY: number, CrownY: number, GridPhase: number?, GridPhases: number?, Alive: number? }
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
local function fieryPill(color: Color3): { any }
	return {
		{ "IconButton", "BackgroundColor3", color },
		{ "IconButton", "BackgroundTransparency", 0 },
		{ "IconLabel", "TextColor3", Color3.new(1, 1, 1) },
		{ "IconLabel", "FontFace", Font.fromEnum(Enum.Font.FredokaOne) },
	}
end
Icon.new():setName("LavaFloorsTitle"):setLabel("🔥 " .. Config.GameTitle):align("Left"):lock():modifyTheme(fieryPill(Color3.fromRGB(255, 120, 40)))

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

-- End-of-round cards stack in one column (winner banner on top, your result under it) that starts just below the
-- notice strip, so the notice, banner and result never cover each other. The column shrinks to fit short screens.
local NOTICE_BOTTOM = 156 -- the notice toast in LavaFloorsUI sits at 116..156 below the top bar
local endStack: Frame = make("Frame", {
	Name = "EndStack",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, NOTICE_BOTTOM + 10),
	Size = UDim2.new(1, -24, 0, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1,
}, gui)
make("UIListLayout", { FillDirection = Enum.FillDirection.Vertical, HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 10) }, endStack)
local endScale: UIScale = make("UIScale", {}, endStack)

local result: Frame = make("Frame", {
	LayoutOrder = 2,
	Size = UDim2.new(1, 0, 0, 170),
	BackgroundColor3 = Color3.new(1, 1, 1),
	Visible = false,
}, endStack)
make("UISizeConstraint", { MaxSize = Vector2.new(380, 170) }, result)
make("UICorner", { CornerRadius = UDim.new(0, 20) }, result)
make("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(255, 150, 40), Color3.fromRGB(235, 60, 25)) }, result)
make("UIStroke", { Thickness = 5, Color = Color3.fromRGB(110, 25, 5), ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, result)
local resultTitle: TextLabel = make("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(10, 10), Size = UDim2.new(1, -20, 0, 60), Font = FONT, TextScaled = true, TextColor3 = TITLE, Text = "" }, result)
stroked(resultTitle, 3)
local resultBody: TextLabel = make("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(10, 76), Size = UDim2.new(1, -20, 0, 80), Font = FONT, TextScaled = true, TextColor3 = Color3.new(1, 1, 1), Text = "" }, result)
stroked(resultBody)

local banner: Frame = make("Frame", {
	LayoutOrder = 1,
	Size = UDim2.new(1, 0, 0, 120),
	BackgroundColor3 = Color3.new(1, 1, 1),
	Visible = false,
}, endStack)

local function fitEndStack()
	local top = GuiService:GetGuiInset().Y + NOTICE_BOTTOM + 10
	endStack.Position = UDim2.new(0.5, 0, 0, top)
	local need = (if banner.Visible then 120 else 0) + (if result.Visible then 170 else 0) + (if banner.Visible and result.Visible then 10 else 0)
	local room = workspace.CurrentCamera.ViewportSize.Y - top - 12
	endScale.Scale = if need > 0 then math.clamp(room / need, 0.45, 1) else 1
end
banner:GetPropertyChangedSignal("Visible"):Connect(fitEndStack)
result:GetPropertyChangedSignal("Visible"):Connect(fitEndStack)
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fitEndStack)
make("UISizeConstraint", { MaxSize = Vector2.new(520, 120) }, banner)
make("UICorner", { CornerRadius = UDim.new(0, 22) }, banner)
make("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(255, 225, 80), Color3.fromRGB(255, 150, 30)) }, banner)
make("UIStroke", { Thickness = 5, Color = Color3.fromRGB(120, 60, 0), ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, banner)
local bannerTitle: TextLabel = make("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(10, 8), Size = UDim2.new(1, -20, 0, 54), Font = FONT, TextScaled = true, TextColor3 = Color3.new(1, 1, 1), Text = "" }, banner)
stroked(bannerTitle, 3)
local bannerNames: TextLabel = make("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(10, 64), Size = UDim2.new(1, -20, 0, 44), Font = FONT, TextScaled = true, TextColor3 = Color3.new(1, 1, 1), Text = "" }, banner)
stroked(bannerNames)

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

local function pop(target: GuiObject)
	local scale = target:FindFirstChildOfClass("UIScale") or make("UIScale", {}, target)
	scale.Scale = 1.2
	TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Scale = 1 }):Play()
end

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
		if state.Phase == "Round" and wasPhase ~= "Round" and (me.Queued or me.Running) then
			play("Beep", 1.5)
		end
	elseif kind == "LavaMe" then
		local wasRunning = me.Running
		me = v
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
			play("Shove", 1.2)
			if v.Position then
				burst(v.Position, FIRE, 12, 18)
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
			play("Crown")
			if v.Position then
				burst(v.Position + Vector3.new(0, 3, 0), PARTY, 160, 40)
			end
		end
	elseif kind == "LavaWinners" then
		local names = if type(v.Names) == "table" then v.Names else {}
		bannerTitle.Text = if #names == 0 then "🌋 THE LAVA WINS!" elseif #names == 1 then "🌋 ESCAPED THE VOLCANO!" else "🌋 THEY ESCAPED!"
		bannerNames.Text = if #names == 0 then "Nobody survived this time" else table.concat(names, "  •  ")
		banner.Visible = true
		pop(banner)
		play("Crown", 1.1)
		if type(v.Positions) == "table" then
			for _, at in v.Positions do
				if typeof(at) == "Vector3" then
					burst(at + Vector3.new(0, 4, 0), PARTY, 120, 36)
				end
			end
		end
		task.delay(5, function()
			banner.Visible = false
		end)
	elseif kind == "LavaResult" then
		resultTitle.Text = if v.Outcome == "CROWNED" then "👑 ESCAPED!" elseif v.Outcome == "SURVIVED" then "🔥 SURVIVED!" else "💀 SCORCHED"
		resultTitle.TextColor3 = if v.Outcome == "SCORCHED" then Color3.new(1, 1, 1) else TITLE
		local emberLine = if v.Embers > 0 then string.format("\n%d embers banked%s", v.Embers, if v.Doubled then " (x2!)" else "") else ""
		resultBody.Text = string.format("Height %d  •  +%d coins%s%s%s", v.Height, v.Coins, if v.Boosted then " (2x)" else "", if v.Friends then " 👥+25%" else "", emberLine)
		result.Visible = true
		pop(result)
		task.delay(4.5, function()
			result.Visible = false
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
	local label = if me.Queued then "✅ Queued" elseif joinable then "🔥 Jump in!" else "🔥 Lava Rush"
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
				info.Text = string.format("%s  •  👥 %d left  •  🍓 %d  •  Lava %d below", stage, state.Alive or 0, me.Embers, gap)
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
		if w > 0.66 then
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
	return nil
end

Run.PreSimulation:Connect(function()
	local t = workspace:GetServerTimeNow()
	local blink = math.floor(t * 8) % 2 == 0
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
			item.Transparency = if state == "Warning" and crumble == nil then (if blink then 0.05 else 0.6) else 1
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
end)

-- Climb parallax: local-only rocks, clouds and light streaks drift down past the grid in three depth layers,
-- faster up close and slower far away, so the floor feels like it is climbing. They rush while the grid rises.

type Layer = { Count: number, Radius: NumberRange, Span: number, Drift: number, Rush: number }
type Floater = { part: BasePart, layer: Layer, angle: number, radius: number, y: number, spin: number }

local LAYERS: { [string]: Layer } = {
	Streak = { Count = 70, Radius = NumberRange.new(54, 95), Span = 70, Drift = 18, Rush = 13 },
	Rock = { Count = 28, Radius = NumberRange.new(66, 94), Span = 110, Drift = 8, Rush = 5.5 },
	Cloud = { Count = 18, Radius = NumberRange.new(150, 230), Span = 160, Drift = 3, Rush = 2.2 },
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
	local kick = math.clamp(rush / 5, 0, 1) * FOV_KICK
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
local function stopSpectate()
	if not spectating then
		return
	end
	spectating = false
	spectateLabel.Visible = false
	Run:UnbindFromRenderStep("LavaSpectate")
	workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
end
local function startSpectate()
	if spectating then
		return
	end
	spectating = true
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
		local a = (os.clock() - started) * 0.08
		local ease = math.min(1, (os.clock() - started) / 1.2) -- swoop up into the overhead view
		local cam = workspace.CurrentCamera
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
UIS.InputBegan:Connect(function(input, processed)
	if spectating and not processed and (LOOK_KEYS[input.KeyCode] or input.UserInputType == Enum.UserInputType.MouseButton2 or input.UserInputType == Enum.UserInputType.Touch) then
		stopSpectate()
	end
end)

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
	ash.Rate = 45
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
	sparks.Rate = 70
	sparks.Lifetime = NumberRange.new(3, 6)
	sparks.Speed = NumberRange.new(2, 5)
	sparks.SpreadAngle = Vector2.new(35, 35)
	sparks.LightEmission = 1
	sparks.Color = ColorSequence.new(Color3.fromRGB(255, 220, 110), Color3.fromRGB(255, 70, 15))
	sparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) })
	sparks.Parent = sparkPart
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
	for _ = 1, 9 do
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
		nextFountain = os.clock() + 3 + math.random() * 3
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

-- Eruption: each time the floor rises the volcano rumbles: a short camera shake, and a few glowing rocks break off
-- the crater rim and plunge into the lava. Purely visual and local, so it never touches anyone.
local SHAKE_TIME = 0.7
local shakeUntil = 0
local shakeStrength = 0
Run:BindToRenderStep("LavaRumble", Enum.RenderPriority.Camera.Value + 1, function()
	local left = shakeUntil - os.clock()
	if left <= 0 then
		return
	end
	local k = shakeStrength * (left / SHAKE_TIME)
	local t = os.clock() * 30
	local cam = workspace.CurrentCamera
	cam.CFrame *= CFrame.new(math.noise(t, 0.3) * k, math.noise(t, 1.7) * k, 0) * CFrame.Angles(0, 0, math.noise(t, 3.1) * k * 0.02)
end)

local function rumble(strength: number)
	shakeStrength = strength
	shakeUntil = os.clock() + SHAKE_TIME
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
make("UIStroke", { Thickness = 3, Color = Color3.fromRGB(110, 25, 5) }, meter)
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
	local blink = danger > 0.5 and math.floor(t * 6) % 2 == 0
	meterFloor.BackgroundColor3 = if blink then Color3.fromRGB(255, 70, 40) else Color3.fromHSV(theme.TileHue or 0.05, 0.35, 1)
	meterFloorStroke.Color = if danger > 0.5 then Color3.fromRGB(120, 10, 0) else Color3.fromRGB(40, 20, 30)
	meterCrown.TextTransparency = if meterFloorFrac > 0.97 then 0 else 0.35

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
