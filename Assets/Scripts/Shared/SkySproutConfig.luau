return {
 Version=8,GameTitle="LAVA Floors",SaveName="SkyboundArena_Player_v1",PassId=2092939013, -- Aurora Gloves (created 2026-11-23)
 DoubleLavaPassId=2096444986, -- 2x Lava Coins
 LavaPassPremiumId=2093742988, -- Lava Pass Premium
 VipPassId=2094204889, -- one-time VIP game pass (preferred over the subscription for a kids' game)
 TrailPassId=2093340957, -- Flame Trail cosmetic
 VipSubscriptionId="",
 ProductIds={Coins100=3735086616,Coins500=3735086644,Coins2000=3735086666,Coins6000=3735086685,Tip25=3735086772,Tip100=3735086785,Tip500=3735086798,Tip1000=3735086811},
 Tips={Tip25=25,Tip100=100,Tip500=500,Tip1000=1000},
 Vip={CoinBonus=0.25,DailyMultiplier=2,Hat="GoldenApple"},
 -- Friend deal: when someone joins from your invite you both get coins (once per friend; the welcome gift once per
 -- account). Playing with a friend, or someone you invited, gives +Bonus coins every round.
 FriendDeal={InviteCoins=150,WelcomeCoins=150,DailyCap=5,MinAccountAgeDays=3,Bonus=0.25},
 -- Seasonal events: yearly date ranges (UTC, month/day, may wrap into the new year). While one runs, round coins get
 -- CoinBonus, its Theme comes up more often, a top bar pill shows it, and Snow makes snow fall in the crater.
 Events={
  {Id="Spooky",Name="🎃 Spooky Eruption",Short="🎃 Spooky",From={10,20},To={11,3},CoinBonus=0.5,Theme="PurpleMoon"},
  {Id="Frostfire",Name="❄️ Frostfire Festival",Short="❄️ Frostfire",From={12,18},To={1,4},CoinBonus=0.5,Theme="BlueInferno",Snow=true},
 },
 BadgeIds={FirstRound=0,FirstCrown=0,TenCrowns=0,PlayWithFriend=0},
 PartyMode=true,
 SkipTowerApproach=true,
 MaxFloor=20,FloorHeight=256,BaseHeight=0,FloorNames={"Gateward Kingdom","Harvest Hollow","Neon Circuit","Corsair Coast","Maple Suburbia","Frostbound Reach","Dustwind Frontier","Sporelight Grove","Jade Shrine","Emberforge","Sunken Sanctum","Cloud Carnival","Clockwork Foundry","Hollowmoon Manor","Prism Skyline","Stormbreak Harbor","Silverpine Alps","Roseglass Gardens","Starfall Observatory","Celestial Crown"},
 PointsPerFloor=100,WinPoints=50,LossPoints=25,WinCoins=75,LossCoins=15,
 RoundSeconds=90,Countdown=4,RoundBreak=3,Health=100,Stamina=100,WalkSpeed=18,BlockSpeed=8,
 Punch={Damage=10,FinisherDamage=14,Cost=6,Range=7.5,Windup=.1,Cooldown=.4},
 Heavy={Damage=22,Cost=25,Range=8.5,Windup=.55,Cooldown=1.25},
 Dash={Cost=22,Cooldown=1.4,Invulnerability=.26,Speed=60,Duration=.15},
 Skins={
 {Id="Mint",Name="Mint Gloves",Cost=0,Color=Color3.fromRGB(122,244,183)},
 {Id="Peach",Name="Sunset Gloves",Cost=160,Color=Color3.fromRGB(255,169,133)},
 {Id="Lilac",Name="Royal Gloves",Cost=320,Color=Color3.fromRGB(189,159,255)},
 {Id="Magma",Name="Magma Gloves",Cost=600,Color=Color3.fromRGB(255,96,30),Material="CrackedLava"},
 {Id="Ocean",Name="Ocean Gloves",Cost=900,Color=Color3.fromRGB(45,150,255),Material="Glass"},
 {Id="Jade",Name="Jade Gloves",Cost=1200,Color=Color3.fromRGB(60,200,110),Material="Marble"}, -- #158
 {Id="Galaxy",Name="Galaxy Gloves",Cost=1500,Color=Color3.fromRGB(130,70,255),Material="Neon"},
 {Id="Frost",Name="Frost Gloves",Cost=2000,Color=Color3.fromRGB(190,235,255),Material="Ice"}, -- #158
 {Id="Gold",Name="Golden Gloves",Cost=2500,Color=Color3.fromRGB(255,200,60),Material="Foil"},
 {Id="Diamond",Name="Diamond Gloves",Cost=4000,Color=Color3.fromRGB(205,240,255),Material="Glass",Sparkle=true},
 {Id="Obsidian",Name="Obsidian Gloves",Cost=6000,Color=Color3.fromRGB(45,32,60),Material="Glass",Sparkle=true}, -- #158: a long-term goal
 {Id="Aurora",Name="Aurora Gloves",Premium=true,Cost=0,Color=Color3.fromRGB(105,224,255),Material="Neon",Sparkle=true},
 },
 -- Fruit buddies: little fruit pets with eyes that float by your shoulder. Cosmetic only, all bought with coins.
 Pets={
 {Id="Strawberry",Name="Strawberry Buddy",Cost=600,Color=Color3.fromRGB(235,70,80)},
 {Id="Blueberry",Name="Blueberry Buddy",Cost=1000,Color=Color3.fromRGB(120,110,255)},
 {Id="Pineapple",Name="Pineapple Buddy",Cost=1500,Color=Color3.fromRGB(255,170,60)},
 {Id="Watermelon",Name="Watermelon Buddy",Cost=2200,Color=Color3.fromRGB(255,110,140)},
 {Id="Coconut",Name="Coconut Buddy",Cost=3000,Color=Color3.fromRGB(150,95,60)},
 -- Remixed buddies (#163): an existing fruit (Model) remade in a new Material and Color, like the remixed hats.
 {Id="FrostBerryBuddy",Name="Frost Berry Buddy",Model="Blueberry",Material="Ice",Cost=3500,Color=Color3.fromRGB(185,230,255)},
 {Id="MoltenMelonBuddy",Name="Molten Melon Buddy",Model="Watermelon",Material="CrackedLava",Cost=4200,Color=Color3.fromRGB(255,110,40)},
 {Id="ShadowBananaBuddy",Name="Shadow Banana Buddy",Model="Banana",Material="Slate",Cost=2600,Color=Color3.fromRGB(60,50,80)}, -- #172
 {Id="EmeraldStrawberryBuddy",Name="Emerald Strawberry Buddy",Model="Strawberry",Material="Glass",Cost=3800,Color=Color3.fromRGB(60,210,120)}, -- #172
 {Id="GoldenPineappleBuddy",Name="Golden Pineapple Buddy",Model="Pineapple",Material="Foil",Cost=5500,Color=Color3.fromRGB(255,200,60)},
 -- Theme buddies: never sold. One "lost buddy" waits on the floor in each round of its world theme; the first climber
 -- to grab it keeps it (Model = the fruit it's made from, FindIn = the theme Id, Aura = its glow).
 {Id="InfernoBerry",Name="Inferno Berry",Model="Blueberry",FindIn="BlueInferno",Where="💙 Blue Inferno",Aura="Fire",Cost=0,Color=Color3.fromRGB(70,150,255)},
 {Id="MoonBanana",Name="Moon Banana",Model="Banana",FindIn="PurpleMoon",Where="🌙 Purple Moon",Aura="Glow",Cost=0,Color=Color3.fromRGB(175,115,255)},
 {Id="StarBuddy",Name="Star Buddy",Model="StarFruit",FindIn="StarryNight",Where="✨ Starry Night",Aura="Sparkles",Cost=0,Color=Color3.fromRGB(255,240,160)},
 {Id="TideCoconut",Name="Tide Coconut",Model="Coconut",FindIn="TidalLagoon",Where="🌊 Tidal Lagoon",Aura="Glow",Cost=0,Color=Color3.fromRGB(70,210,200)}, -- #173
 {Id="JadePineapple",Name="Jade Pineapple",Model="Pineapple",FindIn="JadeJungle",Where="🌿 Jade Jungle",Aura="Glow",Cost=0,Color=Color3.fromRGB(90,220,110)}, -- #157
 {Id="CandyDragon",Name="Candy Dragon",Model="DragonFruit",FindIn="Candy",Where="🍭 Candy Crater",Aura="Sparkles",Cost=0,Color=Color3.fromRGB(255,120,200)},
 },
 Hats={
 {Id="Strawberry",Name="Strawberry Hat",Cost=250,Color=Color3.fromRGB(235,70,80)},
 {Id="Banana",Name="Banana Hat",Cost=400,Color=Color3.fromRGB(255,220,80)},
 {Id="Pineapple",Name="Pineapple Hat",Cost=700,Color=Color3.fromRGB(255,170,60)},
 {Id="Watermelon",Name="Watermelon Hat",Cost=1000,Color=Color3.fromRGB(255,110,140)},
 {Id="Coconut",Name="Coconut Hat",Cost=1500,Color=Color3.fromRGB(150,95,60)},
 {Id="Blueberry",Name="Blueberry Hat",Cost=2200,Color=Color3.fromRGB(120,110,255)},
 -- Remixed hats (#160): an existing fruit (Model) remade in a new Material and Color.
 {Id="ShadowBanana",Name="Shadow Banana Hat",Model="Banana",Material="Slate",Cost=1800,Color=Color3.fromRGB(60,50,80)}, -- #171
 {Id="FrostBerry",Name="Frost Berry Hat",Model="Blueberry",Material="Ice",Cost=2600,Color=Color3.fromRGB(185,230,255)},
 {Id="EmeraldStrawberry",Name="Emerald Strawberry Hat",Model="Strawberry",Material="Glass",Cost=2800,Color=Color3.fromRGB(60,210,120)}, -- #171
 {Id="MoltenMelon",Name="Molten Melon Hat",Model="Watermelon",Material="CrackedLava",Cost=3200,Color=Color3.fromRGB(255,110,40)},
 {Id="CrystalCoconut",Name="Crystal Coconut Hat",Model="Coconut",Material="Glass",Cost=4500,Color=Color3.fromRGB(200,235,255)},
 {Id="DragonFruit",Name="Dragon Fruit Hat",Cost=0,PassOnly=true,Color=Color3.fromRGB(255,80,170)},
 {Id="StarFruit",Name="Star Fruit Hat",Cost=0,PassOnly=true,Color=Color3.fromRGB(255,215,60)},
 {Id="GoldenApple",Name="Golden Apple Hat",Cost=0,VipOnly=true,Color=Color3.fromRGB(255,200,40)},
 },
 LavaPass={
 Season=1,XPPerTier=100,
 -- Per-round XP, scaled 0.7x for 3-phase rounds (~44 s instead of ~63 s) so the pass fills at the old pace per minute (was 20/30/50/5).
 -- Challenge: each completed daily challenge (#121), about one round's worth.
 XP={Played=14,Survived=21,Crowned=35,Berry=4,Challenge=10},
 Tiers={
 {Free={Coins=50},Premium={Coins=100}},
 {Free={Coins=60},Premium={Coins=120}},
 {Free={Hat="Strawberry"},Premium={Coins=150}},
 {Free={Coins=80},Premium={Coins=150}},
 {Free={Coins=90},Premium={Coins=200}},
 {Free={Coins=100},Premium={Hat="Banana"}},
 {Free={Coins=110},Premium={Coins=200}},
 {Free={Coins=120},Premium={Coins=250}},
 {Free={Hat="Pineapple"},Premium={Coins=250}},
 {Free={Coins=140},Premium={Hat="DragonFruit"}},
 {Free={Coins=150},Premium={Coins=300}},
 {Free={Coins=160},Premium={Coins=300}},
 {Free={Coins=170},Premium={Hat="Watermelon"}},
 {Free={Coins=180},Premium={Coins=350}},
 {Free={Coins=200},Premium={Coins=350}},
 {Free={Hat="Coconut"},Premium={Coins=400}},
 {Free={Coins=220},Premium={Coins=400}},
 {Free={Coins=240},Premium={Hat="Blueberry"}},
 {Free={Coins=260},Premium={Coins=500}},
 {Free={Coins=300},Premium={Hat="StarFruit"}},
 },
 },
}
