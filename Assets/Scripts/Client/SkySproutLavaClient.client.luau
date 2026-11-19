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

local result: Frame = make("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.4),
	Size = UDim2.new(1, -24, 0, 170),
	BackgroundColor3 = Color3.new(1, 1, 1),
	Visible = false,
}, gui)
make("UISizeConstraint", { MaxSize = Vector2.new(380, 170) }, result)
make("UICorner", { CornerRadius = UDim.new(0, 20) }, result)
make("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(255, 150, 40), Color3.fromRGB(235, 60, 25)) }, result)
make("UIStroke", { Thickness = 5, Color = Color3.fromRGB(110, 25, 5), ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, result)
local resultTitle: TextLabel = make("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(10, 10), Size = UDim2.new(1, -20, 0, 60), Font = FONT, TextScaled = true, TextColor3 = TITLE, Text = "" }, result)
stroked(resultTitle, 3)
local resultBody: TextLabel = make("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(10, 76), Size = UDim2.new(1, -20, 0, 80), Font = FONT, TextScaled = true, TextColor3 = Color3.new(1, 1, 1), Text = "" }, result)
stroked(resultBody)

local banner: Frame = make("Frame", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 150),
	Size = UDim2.new(1, -24, 0, 120),
	BackgroundColor3 = Color3.new(1, 1, 1),
	Visible = false,
}, gui)
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
	Text = "👀 Spectating · move to look around",
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
				burst(v.Position, ColorSequence.new(Color3.new(1, 1, 1), c), 50, 20)
				floatText(v.Position + Vector3.new(0, 2, 0), tostring(v.Text or "BOOST!"))
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
		bannerTitle.Text = if #names == 0 then "🌋 THE LAVA WINS!" elseif #names == 1 then "👑 WINNER!" else "👑 WINNERS!"
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
		resultTitle.Text = if v.Outcome == "CROWNED" then "👑 CROWNED!" elseif v.Outcome == "SURVIVED" then "🔥 SURVIVED!" else "💀 SCORCHED"
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
			local tips = { shoveTip,"🌀 The floor spins, grows, then rises — stay on!", "🛡️ Blue bubbles block shoves", "🔴 Red tiles fall or get left behind — move!", "🍉 Stay on one tile too long and it cracks!", "⬆️ Press E or tap RAISE to pop your tile up (40 coins)", "🏆 Get to the middle and survive every phase!", "🎁 Grab falling crates for boosts!" }
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
		local light = lava:FindFirstChildOfClass("SurfaceLight")
		if light then
			light.Brightness = 3 + math.noise(t * 2.3, 0.5) * 1.6
		end
		local point = lava:FindFirstChild("LavaGlowPoint")
		local rising = point and point:FindFirstChild("LavaGlow")
		if rising and rising:IsA("PointLight") then
			rising.Brightness = 2.2 + math.noise(t * 1.1, 3.7) * 0.9
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
		local moved = Grid.Delta(towerModel, tile, t) * rest
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
		local a = (os.clock() - started) * 0.15
		local cam = workspace.CurrentCamera
		cam.CameraType = Enum.CameraType.Scriptable
		cam.CFrame = CFrame.lookAt(centre.Position + Vector3.new(math.cos(a) * 70, 38, math.sin(a) * 70), centre.Position)
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
