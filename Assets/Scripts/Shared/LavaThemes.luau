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
		Brightness = 1.3,
		Exposure = 0.15,
		Ambient = Color3.fromRGB(80, 100, 150),
		Outdoor = Color3.fromRGB(90, 115, 170),
		AirColor = Color3.fromRGB(70, 110, 210),
		AirDecay = Color3.fromRGB(18, 30, 90),
		AirDensity = 0.3,
		Haze = 1.2,
		Tint = Color3.fromRGB(228, 238, 255),
		Water = Color3.fromRGB(18, 56, 120),
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
		Brightness = 1.2,
		Exposure = 0.2,
		Ambient = Color3.fromRGB(110, 85, 150),
		Outdoor = Color3.fromRGB(120, 95, 165),
		AirColor = Color3.fromRGB(140, 85, 210),
		AirDecay = Color3.fromRGB(45, 20, 85),
		AirDensity = 0.28,
		Haze = 1.1,
		Tint = Color3.fromRGB(242, 228, 255),
		Water = Color3.fromRGB(46, 28, 92),
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
		Brightness = 1.2,
		Exposure = 0.2,
		Ambient = Color3.fromRGB(85, 90, 135),
		Outdoor = Color3.fromRGB(95, 100, 150),
		AirColor = Color3.fromRGB(45, 65, 140),
		AirDecay = Color3.fromRGB(14, 20, 60),
		AirDensity = 0.26,
		Haze = 0.9,
		Tint = Color3.fromRGB(232, 236, 255),
		Water = Color3.fromRGB(14, 32, 72),
		Bloom = 0.4,
		BloomThreshold = 1.5,
		Saturation = 0.1,
		Contrast = 0.07,
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
