--!strict
-- World themes picked per round (lighting, lava hue, moon).
export type Theme = {
	Id: string,
	Name: string,
	Weight: number,
	Hue: number?,
	Rock: Color3?,
	RockMix: number,
	Moon: Color3?,
	MoonHalo: Color3?,
	Sky: string,
	Stars: number,
	Clock: number,
	Brightness: number,
	Exposure: number,
	Ambient: Color3,
	Outdoor: Color3,
	AirColor: Color3,
	AirDecay: Color3,
	AirDensity: number,
	Haze: number,
	Tint: Color3,
	Water: Color3,
	TileHue: number, -- the floor tiles are shades of this one hue
	TextTop: Color3?, -- title text gradient, top (HUD titles follow the round's theme, #106)
	TextBottom: Color3?, -- title text gradient, bottom
	UIAccent: Color3?, -- HUD borders and default buttons (#126); nil keeps the lava orange
	UIGlass: Color3?, -- HUD panel glass tint (#126); nil keeps the dark lava-brown
	Bloom: number,
	BloomThreshold: number,
	Saturation: number,
	Contrast: number,
}

local T = {}

T.List = {
	{
		Id = "Sunset",
		Name = "🌅 Sunset",
		Weight = 3,
		Hue = nil,
		Rock = nil,
		RockMix = 0,
		Moon = nil,
		MoonHalo = nil,
		Sky = "Dusk",
		Stars = 400,
		Clock = 17.7,
		Brightness = 2,
		Exposure = 0,
		Ambient = Color3.fromRGB(120, 95, 110),
		Outdoor = Color3.fromRGB(140, 110, 120),
		AirColor = Color3.fromRGB(255, 170, 130),
		AirDecay = Color3.fromRGB(120, 60, 90),
		AirDensity = 0.34,
		Haze = 1.8,
		Tint = Color3.fromRGB(255, 240, 232),
		Water = Color3.fromRGB(38, 96, 112),
		TileHue = 0.035,
		TextTop = Color3.fromRGB(255, 240, 170),
		TextBottom = Color3.fromRGB(255, 150, 50),
		UIAccent = Color3.fromRGB(255, 112, 36),
		UIGlass = Color3.fromRGB(24, 15, 17),
		Bloom = 0.16,
		BloomThreshold = 2,
		Saturation = 0.035,
		Contrast = 0.025,
	},
	{
		Id = "BlueInferno",
		Name = "💙 Blue Inferno",
		Weight = 2,
		Hue = 0.56,
		Rock = Color3.fromRGB(34, 44, 78),
		RockMix = 0.55,
		Moon = Color3.fromRGB(205, 230, 255),
		MoonHalo = Color3.fromRGB(90, 160, 255),
		Sky = "Night",
		Stars = 2500,
		Clock = 20.3,
		Brightness = 1.6,
		Exposure = 0.2,
		Ambient = Color3.fromRGB(115, 135, 185),
		Outdoor = Color3.fromRGB(125, 150, 200),
		AirColor = Color3.fromRGB(70, 110, 210),
		AirDecay = Color3.fromRGB(18, 30, 90),
		AirDensity = 0.3,
		Haze = 1.2,
		Tint = Color3.fromRGB(228, 238, 255),
		Water = Color3.fromRGB(18, 56, 120),
		TileHue = 0.57,
		TextTop = Color3.fromRGB(215, 240, 255),
		TextBottom = Color3.fromRGB(80, 160, 255),
		UIAccent = Color3.fromRGB(70, 160, 255),
		UIGlass = Color3.fromRGB(12, 20, 38),
		Bloom = 0.45,
		BloomThreshold = 1.4,
		Saturation = 0.12,
		Contrast = 0.08,
	},
	{
		Id = "PurpleMoon",
		Name = "🌙 Purple Moon",
		Weight = 2,
		Hue = 0.765,
		Rock = Color3.fromRGB(52, 32, 72),
		RockMix = 0.55,
		Moon = Color3.fromRGB(215, 150, 255),
		MoonHalo = Color3.fromRGB(170, 80, 255),
		Sky = "Night",
		Stars = 3000,
		Clock = 0,
		Brightness = 1.6,
		Exposure = 0.25,
		Ambient = Color3.fromRGB(150, 120, 190),
		Outdoor = Color3.fromRGB(160, 130, 200),
		AirColor = Color3.fromRGB(140, 85, 210),
		AirDecay = Color3.fromRGB(45, 20, 85),
		AirDensity = 0.28,
		Haze = 1.1,
		Tint = Color3.fromRGB(242, 228, 255),
		Water = Color3.fromRGB(46, 28, 92),
		TileHue = 0.77,
		TextTop = Color3.fromRGB(245, 225, 255),
		TextBottom = Color3.fromRGB(180, 120, 255),
		UIAccent = Color3.fromRGB(175, 105, 255),
		UIGlass = Color3.fromRGB(25, 14, 38),
		Bloom = 0.45,
		BloomThreshold = 1.4,
		Saturation = 0.14,
		Contrast = 0.08,
	},
	{
		Id = "StarryNight",
		Name = "✨ Starry Night",
		Weight = 2,
		Hue = nil,
		Rock = Color3.fromRGB(36, 36, 58),
		RockMix = 0.4,
		Moon = Color3.fromRGB(255, 246, 220),
		MoonHalo = Color3.fromRGB(150, 175, 255),
		Sky = "Night",
		Stars = 3000,
		Clock = 0,
		Brightness = 1.6,
		Exposure = 0.25,
		Ambient = Color3.fromRGB(125, 130, 175),
		Outdoor = Color3.fromRGB(135, 140, 190),
		AirColor = Color3.fromRGB(45, 65, 140),
		AirDecay = Color3.fromRGB(14, 20, 60),
		AirDensity = 0.26,
		Haze = 0.9,
		Tint = Color3.fromRGB(232, 236, 255),
		Water = Color3.fromRGB(14, 32, 72),
		TileHue = 0.66,
		TextTop = Color3.fromRGB(255, 250, 215),
		TextBottom = Color3.fromRGB(140, 160, 255),
		UIAccent = Color3.fromRGB(130, 150, 255),
		UIGlass = Color3.fromRGB(13, 15, 34),
		Bloom = 0.4,
		BloomThreshold = 1.5,
		Saturation = 0.1,
		Contrast = 0.07,
	},
	{
		-- The one bright daytime world: mint tiles over strawberry-pink "syrup" lava under a sunny sky. Mint keeps the
		-- red warning tiles easy to tell apart.
		Id = "Candy",
		Name = "🍭 Candy Crater",
		Weight = 2,
		Hue = 0.92,
		Rock = Color3.fromRGB(150, 98, 140),
		RockMix = 0.45,
		Moon = nil,
		MoonHalo = nil,
		Sky = "Day",
		Stars = 0,
		Clock = 13.5,
		Brightness = 2.4,
		Exposure = 0,
		Ambient = Color3.fromRGB(170, 150, 178),
		Outdoor = Color3.fromRGB(185, 165, 195),
		AirColor = Color3.fromRGB(255, 196, 226),
		AirDecay = Color3.fromRGB(150, 100, 175),
		AirDensity = 0.24,
		Haze = 1.1,
		Tint = Color3.fromRGB(255, 242, 250),
		Water = Color3.fromRGB(110, 190, 230),
		TileHue = 0.44,
		TextTop = Color3.fromRGB(225, 255, 240),
		TextBottom = Color3.fromRGB(255, 125, 200),
		UIAccent = Color3.fromRGB(255, 110, 190),
		UIGlass = Color3.fromRGB(58, 22, 48),
		Bloom = 0.22,
		BloomThreshold = 1.8,
		Saturation = 0.15,
		Contrast = 0.05,
	},
	{
		-- 🌿 Jade Jungle (#157): glowing green "slime" lava under a warm jungle dusk, with golden tiles so the red warning
		-- tiles still stand out, and mossy rocks.
		Id = "JadeJungle",
		Name = "🌿 Jade Jungle",
		Weight = 2,
		Hue = 0.33,
		Rock = Color3.fromRGB(46, 70, 50),
		RockMix = 0.5,
		Moon = nil,
		MoonHalo = nil,
		Sky = "Dusk",
		Stars = 600,
		Clock = 18.1,
		Brightness = 1.9,
		Exposure = 0.05,
		Ambient = Color3.fromRGB(105, 130, 100),
		Outdoor = Color3.fromRGB(120, 145, 110),
		AirColor = Color3.fromRGB(170, 235, 150),
		AirDecay = Color3.fromRGB(60, 110, 70),
		AirDensity = 0.3,
		Haze = 1.4,
		Tint = Color3.fromRGB(240, 255, 236),
		Water = Color3.fromRGB(30, 100, 80),
		TileHue = 0.13,
		TextTop = Color3.fromRGB(240, 255, 200),
		TextBottom = Color3.fromRGB(90, 230, 110),
		UIAccent = Color3.fromRGB(80, 220, 110),
		UIGlass = Color3.fromRGB(14, 32, 20),
		Bloom = 0.3,
		BloomThreshold = 1.6,
		Saturation = 0.12,
		Contrast = 0.06,
	},
} :: { Theme }

T.ById = {} :: { [string]: Theme }
for _, theme in T.List do
	T.ById[theme.Id] = theme
end

function T.Get(id: unknown): Theme
	return (type(id) == "string" and T.ById[id]) or T.List[1]
end

function T.Pick(previousId: string?): Theme
	local total = 0
	for _, theme in T.List do
		if theme.Id ~= previousId then
			total += theme.Weight
		end
	end
	local roll = math.random() * total
	for _, theme in T.List do
		if theme.Id ~= previousId then
			roll -= theme.Weight
			if roll <= 0 then
				return theme
			end
		end
	end
	return T.List[1]
end

return T
