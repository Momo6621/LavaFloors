--!strict
-- Shared UI style: dark glass panels with glowing lava-gradient borders, light text and gold-to-lava titles.
-- Both HUD scripts style their frames, labels and buttons through these helpers so the whole game looks the same.
local U = {}

U.Font = Enum.Font.LuckiestGuy -- chunky cartoon caps (owner picked it from Media/font-options.jpg; was Fredoka One)
U.Glass = Color3.fromRGB(24, 15, 17)
U.GlassTransparency = 0.16
U.GlassLight = Color3.fromRGB(54, 33, 31)
U.Lava = Color3.fromRGB(255, 112, 36)
U.LavaHot = Color3.fromRGB(255, 196, 92)
U.LavaDeep = Color3.fromRGB(200, 45, 15)
U.Gold = Color3.fromRGB(255, 208, 90)
U.Text = Color3.fromRGB(255, 242, 228)
U.Muted = Color3.fromRGB(205, 180, 170)
U.Shadow = Color3.fromRGB(18, 6, 2)
-- Title text gradient (top, bottom). It follows the round's world theme (#106): LavaFloorsUI calls U.setTitleColors
-- from LavaThemes' TextTop/TextBottom whenever the theme changes. These are the Sunset colours.
U.TitleTop = Color3.fromRGB(255, 240, 170)
U.TitleBottom = Color3.fromRGB(255, 150, 50)
-- Border/button accent and panel glass. They follow the round's world theme too (#126): U.setThemeColors swaps them
-- from LavaThemes' UIAccent/UIGlass. Anything styled with the default lava accent follows; a named accent (gold,
-- green, red) keeps its colour.
U.Accent = U.Lava
U.GlassTint = U.Glass

local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)

local function clear(obj: Instance, classes: { string })
	for _, c in obj:GetChildren() do
		for _, name in classes do
			if c:IsA(name) then
				c:Destroy()
				break
			end
		end
	end
end

-- A border that glows from hot yellow at the top to deep lava at the bottom.
function U.lavaStroke(obj: GuiObject, thickness: number?, accent: Color3?): UIStroke
	clear(obj, { "UIStroke" })
	local themed = accent == nil or accent == U.Lava
	local a = if themed then U.Accent else accent :: Color3
	local s = Instance.new("UIStroke")
	s.Thickness = thickness or 2
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Color = WHITE
	local g = Instance.new("UIGradient")
	if themed then
		g.Name = "AccentStroke" -- recoloured by U.setThemeColors
	end
	g.Rotation = 90
	g.Color = ColorSequence.new(a:Lerp(WHITE, 0.4), a:Lerp(BLACK, 0.2))
	g.Parent = s
	s.Parent = obj
	return s
end

-- Dark see-through panel with a soft top-to-bottom shade and a glowing border.
function U.glass(obj: GuiObject, radius: number?, accent: Color3?)
	clear(obj, { "UIGradient", "UIStroke" })
	obj.BackgroundColor3 = U.GlassTint
	obj:SetAttribute("ThemeGlass", true) -- recoloured by U.setThemeColors
	obj.BackgroundTransparency = U.GlassTransparency
	obj.BorderSizePixel = 0
	local c = obj:FindFirstChildOfClass("UICorner") or Instance.new("UICorner")
	if radius then
		c.CornerRadius = UDim.new(0, radius)
	end
	c.Parent = obj
	local shade = Instance.new("UIGradient")
	shade.Rotation = 90
	shade.Color = ColorSequence.new(Color3.fromRGB(255, 225, 215), Color3.fromRGB(150, 140, 140))
	shade.Parent = obj
	U.lavaStroke(obj, 2, accent)
end

-- Text styles: "title" is gold-to-lava, "body" is light, "muted" is soft. All get a dark outline for contrast.
function U.text(label: TextLabel | TextButton, kind: string?)
	label.Font = U.Font
	if label.BackgroundTransparency < 1 then
		-- It has its own glass background and border stroke, so outline the text the classic way.
		label.TextStrokeColor3 = U.Shadow
		label.TextStrokeTransparency = 0
		clear(label, { "UIGradient" })
	else
		label.TextStrokeTransparency = 1
		clear(label, { "UIStroke", "UIGradient" })
		local outline = Instance.new("UIStroke")
		outline.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
		outline.Color = U.Shadow
		outline.Thickness = if kind == "title" then 3.5 else 2.5 -- thick dark outline so the text pops (was 2.5 / 1.5)
		outline.Transparency = 0
		outline.Parent = label
	end
	if kind == "title" then
		label.TextColor3 = WHITE
		local g = Instance.new("UIGradient")
		g.Name = "TitleGradient"
		g.Rotation = 90
		g.Color = ColorSequence.new(U.TitleTop, U.TitleBottom)
		g.Parent = label
	elseif kind == "muted" then
		label.TextColor3 = U.Muted
	else
		label.TextColor3 = U.Text
	end
end

-- Recolour every title (UIGradient named TitleGradient) under root, and use these colours for new titles too.
function U.setTitleColors(top: Color3, bottom: Color3, root: Instance?)
	U.TitleTop, U.TitleBottom = top, bottom
	if root then
		for _, d in root:GetDescendants() do
			if d:IsA("UIGradient") and d.Name == "TitleGradient" then
				d.Color = ColorSequence.new(top, bottom)
			end
		end
	end
end

-- Background and border colours for a button in an accent colour.
function U.tone(color: Color3): (Color3, Color3)
	return color:Lerp(U.GlassTint, 0.45), color:Lerp(WHITE, 0.2)
end

-- A dark button tinted by its accent, with a glowing accent border and light text.
function U.button(b: GuiButton, accent: Color3)
	clear(b, { "UIGradient", "UIStroke" })
	local themed = accent == U.Lava
	local bg = U.tone(if themed then U.Accent else accent)
	b:SetAttribute("ThemeButton", if themed then true else nil) -- recoloured by U.setThemeColors
	b.BackgroundColor3 = bg
	b.BackgroundTransparency = 0.05
	b.BorderSizePixel = 0
	local shade = Instance.new("UIGradient")
	shade.Rotation = 90
	shade.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(175, 165, 165))
	shade.Parent = b
	U.lavaStroke(b, 2.5, accent)
	if b:IsA("TextButton") then
		b.TextColor3 = U.Text
		b.TextStrokeColor3 = U.Shadow
		b.TextStrokeTransparency = 0.3
	end
end

-- Switch the accent and glass to a theme's colours (#126): every lava-accent border, glass panel and lava button
-- under root is recoloured, and new ones use these colours too.
function U.setThemeColors(accent: Color3, glass: Color3, root: Instance?)
	U.Accent, U.GlassTint = accent, glass
	if root then
		for _, d in root:GetDescendants() do
			if d:IsA("UIGradient") and d.Name == "AccentStroke" then
				d.Color = ColorSequence.new(accent:Lerp(WHITE, 0.4), accent:Lerp(BLACK, 0.2))
			elseif d:IsA("GuiObject") then
				if d:GetAttribute("ThemeButton") then
					d.BackgroundColor3 = U.tone(accent)
				elseif d:GetAttribute("ThemeGlass") then
					d.BackgroundColor3 = glass
				end
			end
		end
	end
end

-- TopbarPlus theme for a dark glass pill whose label glows in the accent colour.
function U.pill(color: Color3): { any }
	return {
		{ "IconButton", "BackgroundColor3", U.Glass },
		{ "IconButton", "BackgroundTransparency", 0.12 },
		{ "IconLabel", "TextColor3", color:Lerp(WHITE, 0.4) },
		{ "IconLabel", "FontFace", Font.fromEnum(U.Font) },
	}
end

-- Small screens (phones in landscape) get the whole UI scaled down and short top bar labels.
local COMPACT_HEIGHT = 500 -- viewport heights below this count as a phone
local DESIGN_HEIGHT = 560 -- the height the UI was laid out for

function U.isCompact(): boolean
	-- Right after joining the camera can still report a tiny placeholder size; wait briefly for the real one.
	local camera = workspace.CurrentCamera
	local started = os.clock()
	while camera.ViewportSize.Y < 100 and os.clock() - started < 3 do
		task.wait()
	end
	return camera.ViewportSize.Y < COMPACT_HEIGHT
end

-- The player's Roblox text size setting. The engine doesn't enlarge TextScaled text for it, and nearly all of this UI
-- is TextScaled, so fitScreen grows the whole GUI by this much instead, as far as the screen has room.
local GuiService = game:GetService("GuiService")
local TEXT_SIZE_SCALE: { [Enum.PreferredTextSize]: number } = {
	[Enum.PreferredTextSize.Medium] = 1,
	[Enum.PreferredTextSize.Large] = 1.15,
	[Enum.PreferredTextSize.Larger] = 1.3,
	[Enum.PreferredTextSize.Largest] = 1.45,
}
local DESIGN_WIDTH = 960 -- narrowest width the UI still fits at scale 1 (only limits growing for the text setting)

function U.textScale(): number
	local ok, size = pcall(function()
		return GuiService.PreferredTextSize
	end)
	return if ok then TEXT_SIZE_SCALE[size] or 1 else 1
end

-- Scale a whole ScreenGui (sizes and positions) to the screen height, between 0.7 and 1, then up to U.textScale()
-- for players who picked a larger text size, as far as the screen's height and width leave room.
function U.fitScreen(gui: ScreenGui)
	local scale = gui:FindFirstChild("ScreenFit") or Instance.new("UIScale")
	scale.Name = "ScreenFit"
	scale.Parent = gui
	local function fit()
		local camera = workspace.CurrentCamera
		local height = camera and camera.ViewportSize.Y or 0
		if height >= 100 then -- ignore placeholder sizes while the window is loading or hidden
			local s = math.clamp(height / DESIGN_HEIGHT, 0.7, 1)
			local wanted = U.textScale()
			if wanted > 1 then
				s = math.max(s, math.min(wanted, height / DESIGN_HEIGHT, camera.ViewportSize.X / DESIGN_WIDTH))
			end
			scale.Scale = s
		end
	end
	GuiService:GetPropertyChangedSignal("PreferredTextSize"):Connect(fit)
	-- Follow the current camera: Roblox can swap the camera object, and its size changes with the window.
	local watching: RBXScriptConnection? = nil
	local function watch()
		if watching then
			watching:Disconnect()
		end
		local camera = workspace.CurrentCamera
		watching = if camera then camera:GetPropertyChangedSignal("ViewportSize"):Connect(fit) else nil
		fit()
	end
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watch)
	watch()
end

-- Top bar label: the full text on big screens, the short one on phones and on windows too narrow for the full
-- labels side by side (a ~770 px wide window overflowed the top bar).
local NARROW_WIDTH = 960 -- below this even Lava Rush / 👀 Watch go short; the worst-case top bar needs ~955 px
function U.short(full: string, compact: string): string
	return if U.isCompact() or workspace.CurrentCamera.ViewportSize.X < NARROW_WIDTH then compact else full
end

-- For the less important top bar buttons: short a bit earlier (below TIGHT_WIDTH), so on mid-size screens the right
-- group (Lava Rush, 👀 Watch, Music, Emotes, Invite) fits without folding into TopbarPlus's overflow menu.
local TIGHT_WIDTH = 1300
function U.tight(full: string, compact: string): string
	return if workspace.CurrentCamera.ViewportSize.X < TIGHT_WIDTH then compact else U.short(full, compact)
end

return U
