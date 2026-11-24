# Improvement log

One entry per improvement-loop iteration: what the research said players and kids like, what was built, and how it
was checked. Newest first.

## 152. The live round screen shows the time left

**Why.** A round is won by surviving until time runs out, so "how long is left" is the thing watchers on the deck most
want to know. (Showing rises out of the total was tried first and dropped: the climb is only 3 rises, and "⬆ 3/3" read
like a win when you still have to survive to the end.)

**Built.** SkySproutLavaService, LiveRound board: the round's last line starts with the time left from `L.EndsAt`,
"⏱ 33s · 🤖 3 bots · 💣 Hot Potato" (or "⏱ 33s · 💣 Hot Potato" with no bots left).

**Verified.** Lints pass. The Studio copy matches the repo (232506 bytes, hash 300777450) and compiles. Solo playtest
reading the board each second: "⏱ 33s" counting down one a second to "⏱ 20s" with the bots and the Hot Potato twist.
Noticed, not changed: a player dropped back in during phase 1 shows "⬆ 3" right away. Their peak seems to count the
height they're dropped from (the result card and coins use the same `peak`), so it's worth a look.

## 151. The live round screen shows the twist during the round

**Why.** The countdown names the twist (#145), but once the round started the deck lost it, and twists like Drop
Party or Mega Shoves explain what the watchers see on the floor.

**Built.** SkySproutLavaService, LiveRound board: during a round the last line is "🤖 3 bots still in · 🎁 Drop Party"
(or "Twist: 🎁 Drop Party" with no bots left).

**Verified.** Lints pass. The Studio copy matches the repo (232331 bytes, hash 905400936) and compiles. Solo playtest
reading the board every 0.5 s: countdown "Twist: 🎁 Drop Party", then "🤖 3 bots still in · 🎁 Drop Party" through the
round, then "Round over! ... 👑 🤖 Taffy, 🤖 Gumdrop won!" and "Last round:".

## 150. The live round screen names the bots when they win

**Why.** In a round the bots win, the round-over screen (#145) only listed the players, all "💥 out", so the deck
couldn't tell who won.

**Built.** SkySproutLavaService, LiveRound board: in the Results phase, if no player was crowned, the last line says
which bots are still standing ("👑 🤖 Blizzard, 🤖 Glacier won!", at most two names). It replaces a fourth player's
line, the same way the bot count does during the round.

**Verified.** Lints pass. The Studio copy matches the repo (232165 bytes, hash 75069221) and compiles. Solo playtest:
after the player was knocked out the board showed "Round over! / (player)  💥 out / 👑 🤖 Blizzard, 🤖 Glacier won!",
then "Last round: ... Next round soon!".

## 149. An all-time Top Winners board on the hub deck (owner's request)

**Why.** After #147 the owner said yes to an all-time board. The hub's Top Climbers board only counts this week's
crowns; the player list only shows who is in this server.

**Built.** SkySproutLavaService:
- `allTime`, one table (the script is near its local limit), holds the OrderedDataStore `LavaAllTimeCrowns_v1`
  (not opened in Studio, where data store access is off).
- `allTime.Write` saves a player's total crowns, keyed by UserId, after every crown (in `crownPlayer`, next to the
  weekly count).
- Every 60 s a loop reads the top 5. Names come from `GetNameFromUserIdAsync`, cached with the weekly board's names.
  The same loop writes anyone here with crowns who isn't in the store yet this session, so wins from before the
  board count.
- The board "🏆 ALL-TIME WINNERS" uses `board()`'s raised mode from #144: 14 studs left of the live round screen,
  facing the plaza, over Top Supporters. It merges the stored top 5 with the players in the server now, like the
  weekly board, and shows "1. Name  🏆 12" rows, or "Win a round to get on the board!" when empty.
- One data store write per crown plus at most one per player per server, well inside the budget.

**Verified.** Lints pass. The Studio copy matches the repo (231804 bytes, hash 714686207) and compiles. Playtest:
- The board stands at y 214.5, 14 studs from the live screen, facing the plaza, and shows the empty-board line.
- With a temporary Studio-only edit giving the unsaved test profile 3 crowns, the board showed "1. (player)  🏆 3"
  and the player list "🏆 Wins=3", which also checks #147's Wins column. The edit was removed and the shop
  service re-hashed to the repo (9169, 710849118).

Not checked: the data store itself (Studio can't reach it here), and a screenshot.

## 148. New players see their day-1 reward card again

**Why.** While testing #146 a brand-new player never saw the daily calendar card. Two causes:
1. A race on joining. The server sent the "LavaDaily" message about 2.5 s after the save loaded, before
   SkySproutLavaClient had connected to the remote. A RemoteEvent hands queued messages to the first script that
   listens, which was another client script, so the lava HUD never got it.
2. No window to show it. New players go straight from round to round. The card waits for 3 s out of a round with
   the result card closed, and the result card (5.5-8 s) closes about 1.5 s before the next round starts.

**Built.**
- SkySproutShopService: the day's card goes out as a `LavaDailyCard` player attribute (JSON) instead of a message.
  An attribute stays put until it's read.
- SkySproutLavaClient: reads the attribute when it starts and whenever it changes. If your result card is up when a
  card is waiting, the calendar joins the end-of-round column under the result card (LayoutOrder 4; `fitEndStack`
  counts it). When it closes it goes back to its usual place. Still never over the floor during a climb.

**Verified.** Lints pass. The Studio copies match the repo (SkySproutShopService 9169 bytes, hash 710849118;
SkySproutLavaClient 127457, hash 541851556) and compile. Fresh Studio join, watched from the client:
- 2.7 s: the attribute arrived.
- 7.0 s: the card showed in the middle of the screen ("🔥 1 day in a row!").
- 9.0 s: hidden as the first round started.
- 28.3 s: the round ended; the card came back under the result card in the end-of-round column.
- 35.3 s: it closed itself, before the next round.

Before the fix, the same join never showed the card in 75 s.

## 147. Wins and rounds played on the player list leaderboard (owner's request)

**Why.** The owner asked for the number of battles played and games won, on a leaderboard. The game already saved
both (`Crowns` for rounds escaped, `RoundsPlayed` for rounds finished, #124), but the player list only showed
"👑 Crowns" and coins.

**Built.** SkySproutArenaService (party mode's leaderstats): the columns are now 🏆 Wins, 🎮 Played and 💰 Coins.
Wins come first, so Roblox's player list sorts everyone by them. `stats()` fills Wins from `Crowns` and Played from
`RoundsPlayed`; it already runs after every payout, so both update as soon as a round ends. Nothing new is saved.

**Verified.** Lints pass. The Studio copy matches the repo (24656 bytes, hash 67128363) and compiles. Solo
playtest reading the leaderstats every 0.5 s: "🏆 Wins=0, 🎮 Played=0, 💰 Coins=25" on joining, then Played 1 and 2
after the first two rounds (coins 70, then 90). Not checked: Wins going up (a solo test player can't reliably win a
round; it reads the same `Crowns` value the old 👑 Crowns column showed) and a screenshot of the player list.

## 146. Days in a row on the daily card (owner's request)

**Why.** The owner asked for a feature that shows how many days you've logged in in a row. The daily reward ladder
counts days collected but pauses on a missed day, so it never said "in a row".

**Built.**
- SkySproutShopService `daily()`: when the day's reward is collected, `LoginStreak` goes up by one if you last
  collected yesterday (UTC days), otherwise it starts again at 1; `BestLoginStreak` keeps the highest. Both go to the
  client in the "LavaDaily" message (`InRow`, `BestInRow`).
- SkySproutRules: the two new profile fields default to 0 and are cleaned like `DailyStreak` (whole numbers 0-100000).
- SkySproutLavaClient: the daily card is 28 px taller with a gold line under the hint: "🔥 1 day in a row!", or
  "🔥 5 days in a row · Best: 9" when your best is higher. The label is created without a new local and found by name
  (that script is at Luau's 200-local limit).
- Kid-fair: no coins or items depend on the count, so missing a day loses nothing (the reward ladder still never
  resets); it's a number to be proud of, with your best kept.

**Verified.** Lints pass. The Studio copies match the repo (SkySproutRules 11753 bytes, hash 185548886;
SkySproutShopService 9040, hash 825350797; SkySproutLavaClient 125873, hash 485575190) and compile. Studio
playtest (Studio saves nothing, so every play is a first day): the server sent `InRow = 1, BestInRow = 1` with the
"Day 1 daily reward" notice. A LavaDaily message fired from the test server with `InRow = 5, BestInRow = 9` showed the
card ("DAY 3 REWARD: +75", "🔥 5 days in a row · Best: 9") and it closed itself 7 s later. Not checked: two real days in
a row on a published server, and a screenshot (capture timed out with Studio in the background). Noticed: in Studio
the fresh player is dropped into back-to-back rounds, and the real day-1 card didn't come up within ~70 s; the card's
show-after-3-s-out-of-a-round logic is unchanged by this entry.

## 145. The live round screen counts down and remembers the last round

**Why.** Between rounds the new screen (#144) only said "waiting", which is most of what the deck sees. Kids want to
know when the next round starts, what the twist is, and how the last one went.

**Built.** SkySproutLavaService, LiveRound board fill:
- Countdown phase: "Next round in N..." (from `L.EndsAt`) and "Twist: " with the chosen twist's name.
- Results phase: "Round over!" over the same standings list; the list is kept.
- Idle (and any moment with no runners): "Last round:" with the top three of that list and "Next round soon!"; the
  first-ever wait still shows the look-down hint.

**Verified.** Lints pass. The Studio copy matches the repo (228773 bytes, hash 217450367) and compiles. Solo playtest
reading the board every 0.5 s for 85 s across three rounds: the waiting text, then each round's countdown 4-3-2-1
with its twist (Mega Shoves, Drop Party, Duos), the live lines during the round, "Round over!" with the player's
line, and "Last round: ... Next round soon!" until the next countdown.

## 144. A live round screen on the hub deck

**Why.** The owner's hub is meant to "onlook the game". From the deck you can see the island far below, but not who
is who or how high they've got. A stadium-style screen makes watching the round easy, especially for small kids.

**Built.** SkySproutLavaService: `board()` takes an optional `live` flag: the board floats 9 studs higher (no post,
bottom at about 210, well over head height), faces the plaza instead of the spawn, and refreshes every second. The
new "LiveRound" board sits over the walkway between Top Climbers and Top Supporters. During a round it lists up to
four players from `L.Runners`, crowned first, then those still in, then by rises (the same peak-to-rises formula as
the result card): "Name  ⬆ 3", "👑" or "💥 out"; the last line counts the bots still climbing. Between rounds it
says to look down through the force field. Real names only for real players, as on the other boards.

**Verified.** Lints pass. The Studio copy matches the repo (228067 bytes, hash 350964163) and compiles. Solo
playtest, reading the board's labels each second: the waiting text in the lobby; in the round the player's line went
"⬆ 0", then "💥 out" when they fell, then "⬆ 3" after the phase-1 drop back in, with "🤖 3 bots still climbing".
The board sits at y 214.5 and faces the plaza (look vector 0.80, -0.61). Not checked: a screenshot (capture timed
out with Studio in the background) and a crowned line.

## 143. The leaderboard posts stand on the deck again

**Why.** Found while placing the bounce pads: the Top Climbers and Top Supporters boards' posts were still built at
y 0.75, the old ground-level hub, so since the hub moved up to the floating deck (#138) the boards floated with no
post under them and two stray posts stood on the ground 200 studs below.

**Built.** SkySproutLavaService `board()`: the post's height is now `plazaPos.Y + 0.75`, so it stands on the deck
(or on the ground if the hub is ever moved back down).

**Verified.** Lints pass. The Studio copy matches the repo (226384 bytes, hash 734602873) and compiles. Playtest: both
posts span y 200.00-201.50 on the deck top (200.00) and meet their boards (bottoms at 201.25).

## 142. Bounce pads on the hub deck

**Why.** The hub is where kids wait between rounds (owner's hub idea). Besides the Warm-up Hop and the mirror there was
little to just play with; a trampoline is the simplest toy, and the empty side of the deck had room.

**Built.**
- SkySproutLavaService: `CFG.BouncePads` lists three pads (sideways and toward-island offsets, launch speed, colour).
  The deck block builds each as a basalt ring with a neon top (pink 75, teal 90, gold 105), on the side of the plaza
  away from the Warm-up Hop, clear of the boards, gems and mirror. The tops carry a `Bounce` attribute and the
  `LavaBounce` tag; all are NoTheme.
- LavaFloorsUI: each Heartbeat a short downward raycast (only against tagged pads) finds a pad under you while you're
  not rising; it sets your upward speed to the pad's `Bounce`, plays the built-in jump sound pitched by power, and
  flashes the pad white. Client-side because the client owns its character's physics. No coins or score.

**Verified.** Lints pass. The Studio copies match the repo (server 226371 bytes, hash 805725842; LavaFloorsUI 70730,
hash 398921717) and compile. Solo playtest on the deck: dropped onto each pad, the character kept bouncing (4-5
bounces in 3.5 s) and peaked 14.4, 20.6 and 28.0 studs above the pads, as planned; no console errors. Not checked:
a screenshot (Studio wasn't the front window, so the capture timed out). 2-player Studio test (2026-11-24): both
players bounced at the same time on different pads (teal 6 bounces, peak 20.7; gold 5 bounces, peak 28.1), no errors.

## 141. Names over climbers while spectating from above

**Why.** The top view (#132, owner's request) puts a big name over every climber. Knocked-out players watch the
same floor from the overhead spectate camera but couldn't tell who was who, which matters for the strawberry gift
and for cheering a friend on.

**Built.**
- SkySproutLavaClient sets a local `LavaSpectatingAbove` attribute: true when the overhead spectate view starts or
  ◀ ▶ comes back to it, false while following one player (also when joining to watch a friend) and when spectating
  ends.
- LavaFloorsUI: the top view's name layer now has its own switch (`updateNames`), on during top view or while
  `LavaSpectatingAbove` is set. Names are placed by their own render step after whichever camera ran that frame.
  Same names and look as #132; no new pop-up.

**Verified.** Lints pass. The Studio copies match the repo (LavaFloorsUI 68691 bytes, hash 538706371;
SkySproutLavaClient 125087, hash 863989976) and compile. 2-player Studio test: Player1 knocked out 17 s into a
round while Player2 was still in; 1.2 s later the overhead spectate began, `LavaSpectatingAbove` turned on and the
name layer showed "Player2", "🤖 Flare" and "🤖 Pumice", all on screen; at the next round it turned off and the
names cleared. Not tested: switching to a followed player with ◀ ▶, and no screenshot (the look is the same as #132).

## 140. A try-on mirror on the hub deck (owner's request, hub stage 3)

**Why.** The owner asked for a hub "to wait and look at costumes and stuff", and picked a try-on mirror.

**Built.**
- SkySproutLavaService: a glass stage behind the plaza (36 studs away from the island) and a 12x15 reflective mirror
  in a gold frame with a "✨ TRY-ON MIRROR ✨" sign. The server sets an `OnMirror` attribute on whoever stands on the
  stage (checked every 0.3 s, never during a round). A new `LavaTryOn` action (checked: on the stage, a known glove,
  hat or buddy id) puts that item on you for `CFG.TryOnSeconds` (30). Tried-on items live in a separate `tryOn`
  table, so the saved profile is never touched; stepping off or the timer puts your own look back.
- LavaFloorsUI: on the stage the shop opens with a "✨ TRY" button on every glove, hat and buddy card (Aurora too),
  and the camera looks out of the mirror at you. Stepping off hands the camera back. No hint pop-up.
- Kid-fair: trying is free and saves nothing; buying is still each card's own button.

**Verified.** Lints pass. The Studio copies match the repo (server 224840 bytes, hash 604177101; LavaFloorsUI 67890,
hash 945365401) and compile. Playtest (solo): on the stage OnMirror turns on, the shop opens with 27 TRY buttons,
a Watermelon Hat, Magma Gloves and a Pineapple Buddy go on, the profile keeps the saved Hat/Skin/Pet, and stepping
off restores the saved look about 2 s later. The 🪞 emoji draws as an empty box in Roblox, so the sign and buttons
use ✨. Owner approved the previews.
2-player Studio test (2026-11-24): both players on the stage at once each got the TRY buttons (27) and wore their
own try-on (Banana hat + Strawberry buddy, Pineapple hat), seen the same from the other player's client; when one
stepped off, only their try-on cleared (hat and buddy gone, TRY buttons hidden) and the other kept theirs. The mirror
camera itself only runs on a rendering window, so it wasn't checked in the background test windows.

## 139. A pillar of light while a round is on (owner's request, hub stage 2)

**Why.** Part of the owner's hub idea: "a pillar of light sprouting on the ground to indicate that a game is taking
place", theme-coloured (their pick).

**Built.** SkySproutLavaService:
- `buildArena` adds GamePillarCore (5-stud neon cylinder) and GamePillarGlow (14-stud) from the ground (y 2) to
  y 702, through the island's centre. They don't collide, query or touch, and are fully transparent by default.
  Lava-coloured, so the theme pass shifts them with the world like the lava.
- `setGamePillar(on)` tweens them over 1.5 s: core 0.15 and glow 0.8 when a round starts (`L.Phase = "Round"`),
  back to 1 when the results show.

**Verified.** Lints pass. The Studio copy matches the repo (219667 bytes, hash 147576653) and compiles. Playtest:
the core read 1 before the round, 0.15 during it, and 1.00 again once the vote opened. Screenshots from the deck:
the pillar rising from the island during a Sunset round, and none between rounds. The owner approved ("Ship").
Console clean of game errors (Studio printed its own Assistant plugin version notice).

## 138. The hub becomes a floating deck above the island (owner's request)

**Why.** Right after #137 (hub on the ground looking up), the owner asked: "is the hub higher than the island? you
should be able to onlook the game with a barrier blocking it". They chose: keep the island floating, hub on a deck
above it, with a glowing force field for the barrier.

**Built.** SkySproutLavaService:
- `CFG.Beacon` (the hub plaza) → (-110.9, 200, 193.9): 175 studs out, beside the island and above the floor's
  highest phase. `DeckRadius = 74` (everything around the plaza fits within ~63 studs).
- `buildArena` adds a "HubDeck" when the plaza is above y 20: a slate disc under the plaza, a 5-layer rocky
  underside, and a ring of 40 ForceField-material walls (12 studs tall, solid) with a neon rail. They're
  lava-coloured, so the theme pass recolours them.
- `buildGems`: on a deck the ground can't be reached, so the five gems move onto it (over the Warm-up Hop goal,
  behind the Top Climbers board, three along the force field). Same ids, and the pickup reads the same list. The
  notice now says "hidden around the hub".
- Players who drop more than 60 studs below the hub (not in a round) are brought back, like the old sea limit.
- At start the floor model's "Spawn"/"SpawnLookAt" attributes point at the deck. The old travel code
  (SkySproutTowerService) put every new character at the old plaza from them. Its MaxExploreHeight is raised to
  cover the deck (190 in the place → 280): it had been sending deck players "back to floor 1" every 0.35 s.
- The place's SpawnLocation was moved onto the deck in Studio.

**Verified.** Lints pass. The Studio copy matches the repo (218171 bytes, hash 498664406) and compiles. Playtests:
- Spawned on the deck (-124, 202, 204); a round put the player on the island (y ≈ 116); knocked out, they came back
  to the deck; a phase-1 drop-back put them on the island again.
- Walking outward stopped at 73.4 studs from the deck centre (the force field), still on the deck.
- Stepping on gems G3 and G1 gave "💎 Lava gem 1/5 … 2/5" and LavaGems=G1,G3.
- No "Returned to floor 1" notices after the height fix. The two spawn problems (old plaza spawn, the height check)
  were found and fixed in these runs.
- Screenshots: the deck from above, and the view from its edge down onto the island during a round. The owner locked
  it in from those.
- Console clean. Not tested: multiplayer, phones.

## 137. The arena floats above a hub (owner's request, stage 1 of the hub)

**Why.** The owner wants a hub area "onlooking the island from the bottom", with a light pillar while a game is on
and a place to try on costumes. They chose: lift the island into the sky, hub off to the side (not right
underneath), knocked-out climbers still teleported back. Stage 1 is the layout; the beam and the try-on mirror follow.

**Built.** SkySproutLavaService:
- `CFG.Center` y 0 → 100. Everything in the arena (floor, grid, lava, rims, spires, vents, lava strip, crown
  height) is built from it, so the whole arena floats.
- `buildArena` adds an "IslandUnderside" when the centre is above y 20: 8 stacked basalt discs narrowing over 90
  studs (100-stud top radius, past the spire ring), 16 hanging rocks around the edge and 12 neon lava cracks.
  Decoration only (no collide, query or touch). The theme pass recolours them like the rest of the arena. The cone
  starts just under the arena floor, so the rising lava never shows through it.
- `CFG.Beacon` (the hub plaza) moved from beside the arena (-200.7, 262.4) to 150 studs out (-130.7, 209.0) on flat
  ground (terrain y 2 checked along the way). The beacons, lanterns, leaderboards, Warm-up Hop and placeAtBeacon all
  follow it.
- The beach fruit decor (`islandMode`) stays on the ground.
- At start the server moves the SpawnLocation to the plaza. The place's own SpawnLocation was also moved there in
  Studio (-213, 272 → -143, 219), so the very first spawn is right too.

**Verified.** Lints pass. The Studio copy matches the repo (213611 bytes, hash 49678761) and compiles.
- Playtests: a player went from the hub up onto the island at round start (y ≈ 119 at 100, ≈ 157 at the first 140
  try) and came back to the new plaza (-143, 4, 219) when scorched. Phase-1 drop-backs put them on the island again.
- Screenshots from the old plaza (straight under: only the underside) led the owner to pick "off to the side". From
  the new plaza the island looms at an angle, spires and all. The owner locked the layout in from that view.
- Known limit, told to the owner: from the ground you can't see the climbers on top (the island's floor hides them).
- Console clean. Not tested: multiplayer, phones.

## 136. Tiles decay at random (owner's request)

**Why.** The owner: "tiles should be able to randomly decay making the game on your feet fun". Until now a tile only
wore out under someone standing still, so a kid could stand anywhere they kept stepping. Random decay means the
whole floor stays alive: you watch for cracks and hop away, all round.

**Built.** SkySproutLavaService `updateWear`:
- From `DecayGrace` (4 s) after the floor starts moving, every `DecayEvery` (3 s) it picks phase+1 random tiles
  (1, 2, then 3), keeping at most `DecayMax` (4) decaying at once. Eligible tiles are solid, not raised, not the
  pillar and not already down.
- A picked tile wears over `DecayWarn` (2.5 s) with the existing darken/crack/shake warning, then crumbles and comes
  back after `CampRespawn`, exactly like a camped tile. No new visuals, no client change.
- It also sets "DecayFall", so the knockout tip says "🪨 That tile crumbled on its own. Hop off when a tile starts
  cracking!" instead of the standing-still line.
- Same for every twist; Quick Crumble still speeds up only the standing-still wear.

**Verified.** Lints pass. The Studio copy matches the repo (210248 bytes, hash 235354655) and compiles. Solo
playtest over 5 rounds with a client watching DecayFall on every tile: in each round the first random fall came at
+6.0 to +6.7 s (grace plus warning), the next about 3 s later. In phase 2 two fell together (Tile24 at +11.9 s and
Tile1 at +12.7 s). Console clean. Not tested: the new knockout tip (a test player can't be placed on a decaying tile
reliably), and how it feels with real players (worth watching in TwistOutcome analytics, #129).

## 134. Top view fits phones (Device Simulator check)

**Why.** #132 was only checked in a desktop-sized window. Most Roblox kids play on phones, where the screen is short
and the HUD takes a bigger share of it.

**Found.** Studio's Device Simulator as an iPhone 17 Pro (750×381 viewport, landscape):
- The top bar fits, with 🎥 in the ⚙️ More dropdown as planned. Studio's mouse tool couldn't open that dropdown while
  the simulator scaled the viewport; it's the same icon and handlers as on desktop, so top view was switched on
  through the saved-choice attribute (#133) instead.
- In top view, the far part of the floor sat under the timer panel and phase pill.
- The fixed 170×30 px names covered much of the small screen and piled up.

**Fixed.** LavaFloorsUI top view:
- The camera aims 10 studs past the floor's centre (`AHEAD`), so the floor sits lower on every screen.
- On screens under 500 px tall it backs off 1.3× (camera about 114 studs up instead of 91).
- Names are sized from the viewport height: h = 4.5 % of the height, 18–30 px, width 5.7 h. That's 171×30 on desktop
  as before, and 102×18 on the phone.

**Verified.** Lints pass. The Studio copy matches the repo (LavaFloorsUI 65918 bytes, hash 390856313) and compiles.
iPhone 17 Pro playtest: the whole floor sits below the HUD with smaller names (before/after screenshots). During a
round the bots' own labels read Enabled=false, so the hiding works; faint doubles in one shot were caught just after
the bots spawned. Desktop playtest after stopping the simulator: same name size, camera 91 studs up, floor below the
HUD panels (screenshot). The owner approved from the screenshots. Console clean; Studio's viewport reset to default.

## 133. The 🎥 top view choice is saved

**Why.** Follow-up to #132: the top view reset every visit, so a kid who prefers it had to find the 🎥 button again
each time. The music button already remembers its setting; the camera should too.

**Built.**
- SkySproutLavaService: a "LavaTopView" message (boolean only) saves `d.TopView` and sets the player's "TopView"
  attribute. Both join paths set the attribute from the profile, next to "MusicOff".
- SkySproutRules: `TopView` is kept on load only when it's `true`.
- LavaFloorsUI: a click that changes the choice shows the notice and tells the server. When the "TopView" attribute
  arrives or changes, the 🎥 icon is selected or deselected to match, without a notice or a message (the handlers
  compare against the saved value).

**Verified.** Lints pass, including check_remotes (the new message has a handler). The Studio copies match the repo
(lava service 208463 bytes, hash 276584430; Rules 11415, 689801806; LavaFloorsUI 65366, 495550401) and compile.
`R.clean` keeps `TopView = true` and drops "x". A `replace_all` sync edit silently didn't apply in Studio; the hash
check caught it, and it was redone as two edits. Playtest:
- Clicking 🎥 made the server set TopView false → true.
- With the server setting the attribute as a join would, false then true, top view came back on in a round (names
  layer on, camera scriptable).
- Setting it false switched it off mid-round (camera back to Custom).
- No "Top view" notice appeared during those restores. Console clean.

Not tested: a real rejoin on a live server (Studio doesn't keep profiles between sessions).

## 132. 🎥 Top view camera with names (owner's request)

**Why.** The owner: "add a different camera mode where it shows the characters from above … but displays their
names". From behind your character you only see a slice of the floor. From above you see the whole grid, where the
holes are opening and who is near you, and names tell you who is who.

**Built.** LavaFloorsUI:
- A 🎥 TopbarPlus toggle ("TopView", right side; in the ☰ dropdown as "🎥 Top view" below 900 px).
- While it's on and you're in a round, a RenderStep binding after the default camera sets a scriptable camera 78
  studs above and 30 toward you from the floor's centre, using `LavaGrid.Pose` so it rises with the floor.
- Every 0.3 s it tracks the climbers' heads: players in the round, and bots that aren't falling. Each frame a
  TextLabel on the "TopViewNames" ScreenGui is placed over each head with `WorldToViewportPoint`: "⭐ YOU" in gold,
  other players' display names, "🤖 Name" for bots. The bots' own small labels are hidden while it runs, and only
  those are re-enabled after.
- Leaving the round unbinds, puts the camera back on Custom with your humanoid as subject, and places it behind you.

**Verified.** Lints pass. The Studio copy matches the repo (LavaFloorsUI 64684 bytes, hash 128139469) and compiles.
Playtest (the 🎥 button clicked with Studio's mouse input):
- In a round the camera went Scriptable, about 91 studs up, with the whole floor in view.
- Names: "⭐ YOU" plus "🤖 Glacier / Splash / Icicle", all on screen, no doubled bot labels (screenshots).
- After a Duos round the camera returned to Custom, 12 studs behind the player, and the name layer turned off.

Found along the way: a first version used BillboardGuis (in PlayerGui, then in the head), but they never showed in
the screenshots, even a plain red test tag. They were replaced by the screen layer, which does show. The owner approved
from the screenshots. Console clean. Not tested: phone-sized screens, and keeping the choice between visits (it
resets when you leave).

## 131. Pre-publish smoke test: every twist in one session (no change needed)

**Why.** #109–#130 hadn't been published, and each was tested on its own. Before the owner publishes them together,
they should run together. Studio had also been closed and reopened, so its scripts might not match the repo.

**Checked.**
- All 48 scripts in the reopened place were hashed by name against the repo: 48/48 identical (sizes and chunk
  hashes), so nothing synced earlier was lost.
- One Studio session ran all 17 twists back to back. A server helper set `StudioForceMutator` to the next twist after
  each round's payout. Classic, Low Gravity, Turbo Spin, Hole Party, Speed Rush, Shield Party, Drop Party, Hot Potato,
  Duos, Big Heads, Mega Shoves, Quick Crumble, Bouncy, Shove Frenzy, Slow-Mo, Fast-Forward and Magnet Hands each
  played and paid out, spread over all five worlds. The client saw each twist's countdown notice.

**Result.** No errors or warnings in the console over the 17 rounds (only the engine's analytics lines). No change
needed. The helper ran only in the play session; no force attribute is left in the place.

## 130. Top bar pills take the world's glass tint (owner's request, follows #126/#128)

**Why.** After #126 and #128 the TopbarPlus pills were the last UI still on the fixed lava-brown glass in every world.

**Built.** LavaFloorsUI theme hook: on every theme change, each TopbarPlus icon (`Icon.getIcons()`, which includes
the ones SkySproutLavaClient makes) gets `modifyTheme({ {"IconButton", "BackgroundColor3", UIGlass} }, "ThemeGlass")`.
The fixed modification id makes each theme replace the last one, and TopbarPlus keeps it through hover and
selection. Icons and their label colours are unchanged. Sunset keeps its glass. Icons created later in a round pick
the tint up at the next theme change.

**Verified.** Lints pass. The Studio copy matches the repo (LavaFloorsUI 59100 bytes, hash 484705108) and compiles.
Playtest: all 13 visible IconButtons read 12,20,38 in Blue Inferno and 58,22,48 in Candy Crater (screenshots of
both). The tint is dark and the pills see-through, so the change is subtle; the owner was shown that and chose to
ship it as is rather than add accent outlines. Console clean; the force attribute was cleared.

## 129. Measure how each twist goes (TwistOutcome analytics)

**Why.** Feature loop. There are now 16 twists plus a Surprise option, and several are new (Magnet Hands,
Fast-Forward, Bouncy). A twist that knocks most kids out in seconds stops being fun for a 7-year-old, but nothing
showed the owner which ones those are. Kid-fair balance needs numbers.

**Built.** SkySproutLavaService `payout`: one AnalyticsService custom event per climber per round, `TwistOutcome`,
with CustomField01 "Twist - <id>", CustomField02 "Outcome - Crowned/Survived/Scorched" and CustomField03
"World - <theme>". Values follow the Roblox analytics guide's "Key - Value" form. The combinations (17 × 3 × 5 = 255)
are far under the 8,000 cap, and it's one new event name. No gameplay change.

**Verified.** Lints pass. The Studio copy matches the repo (208070 bytes, hash 989052695) and compiles. Solo
playtest with a temporary Studio-only print beside the call: two rounds logged "Twist - FastForward, Outcome -
Scorched, World - BlueInferno" and "Twist - MegaShove, Outcome - Scorched, World - PurpleMoon", each followed by the
engine's "LogCustomEvent event fired". The print was removed and the copy re-hashed. Console clean.

## 128. The lobby shop and panels follow the world theme too (owner's request)

**Why.** Following #126 ("the UI color still doesnt match the theme"): the HUD matched the world, but the lobby
panels didn't. The glove/hat/buddy shop and the daily challenges kept a lava-orange ribbon, lava-brown glass,
lava-brown item cards and orange buttons, built with LavaFloorsUI's own colours rather than LavaUI's themed helpers.

**Built.**
- LavaUI: `U.accentFill(bar, mixTop, mixBottom)` for header ribbons: an accent-to-deep gradient that follows the
  theme. The lava accent keeps its own deep red-orange, so Sunset ribbons look as before.
- LavaUI: `U.GlassLightTint` for the lighter card glass. Sunset keeps its lava-brown; other themes mix 18 % of the
  accent into their glass. `U.setThemeColors` recolours `AccentFill` gradients, `ThemeBar` ribbons and
  `ThemeGlassLight` cards along with the #126 markers.
- LavaFloorsUI: `corner()` marks panel glass (`ThemeGlass`) and cards (`ThemeGlassLight`) and builds them in the
  current theme. `ORANGE` is now the lava accent (was 255,122,40, almost the same), so WEAR / CLAIM / emote buttons
  follow. The shop ribbon and lava-coloured panel bars (Daily Challenges) use `U.accentFill`. Panels with their own
  colour (Lava Pass purple, VIP gold) keep it.

**Verified.** Lints pass. The Studio copies match the repo (LavaUI 11750 bytes, hash 115087370; LavaFloorsUI 58704,
392910531) and compile. Studio screenshots of the glove shop in Blue Inferno (blue ribbon, navy glass and cards),
Candy Crater (pink and berry) and Sunset (unchanged lava look). A first Blue Inferno shot showed the cards still brown,
which is why the card glass got its own tint before the owner saw it. The owner approved from those screenshots.
Console clean; the force attribute was cleared.

## 127. Two-player check of Magnet Hands and knockout credit (one wording fix)

**Why.** #115 (Magnet Hands) and #119 (knockout credit) could only be tested against bots solo. A first 2-player
attempt failed: every Studio test player counts as new, so the first-round bubble shield (#83) blocked the shove.

**Checked.** A 2-player Studio test with Magnet Hands forced and a temporary Studio-only copy showing every
challenge. Player1's client waited until Player2's bubble was gone, stood 3.5 studs away facing them, and shoved.
Player2's client logged the shove it received, then dropped itself into the lava to test the credit.
- Pull: Player2 was launched straight toward Player1 (direction match 1.00, 66 studs/s), with "🧲 Player1 pulled you!".
- Credit: Player1's "Knock 2 climbers off the floor" went 0 → 1 when Player2 was scorched right after the pull.
- Found: Player2's "why you fell" tip said "💥 Player1 shoved you off" in a Magnet round.

**Fixed.** SkySproutLavaService `knockoutReason`: in a Magnet Hands round the shove reason reads "🧲 X pulled you off.
Keep away from the edges!". Re-run of the same 2-player test: the tip showed the new wording, and the credit went 0 → 1
again.

**Verified.** Lints pass. The Studio copy matches the repo (207452 bytes, hash 111693336) and compiles, with the
temporary copy restored and the force attribute cleared. Server console clean in both runs. Still untested: an escape
party with three real crowned players (#113).

## 126. The whole HUD follows the world theme, not just the titles (owner's request)

**Why.** The owner: "the UI color still doesnt match the theme". #106 only recoloured the title text. The panel
glass (dark lava-brown), the glowing borders and the default buttons (orange) stayed the same in every world. In Blue
Inferno that meant orange-on-brown panels over an icy blue crater (screenshot), and the same clash in Purple Moon,
Starry Night and Candy Crater.

**Built.**
- LavaThemes: `UIAccent` and `UIGlass` per theme. Blue Inferno blue on navy, Purple Moon violet on deep purple,
  Starry Night periwinkle on midnight, Candy Crater pink on berry; Sunset keeps the lava orange and brown.
- LavaUI: `U.Accent` / `U.GlassTint` replace the fixed lava colours in `lavaStroke`, `glass`, `tone` and `button`
  wherever the default lava accent is used, and mark what they style (`AccentStroke` gradients, `ThemeGlass` and
  `ThemeButton` attributes). The new `U.setThemeColors(accent, glass, root)` recolours everything marked and sets the
  colours for anything built later. A named accent (gold Raise, green, red buttons) keeps its colour.
- LavaFloorsUI: the #106 theme hook now calls `U.setThemeColors` along with `U.setTitleColors`.
- Not covered: the TopbarPlus pills and the lobby shop panels, which use their own fixed colours.

**Verified.** Lints pass. The Studio copies match the repo (LavaThemes 5835 bytes, hash 950909851; LavaUI 10193,
823329373; LavaFloorsUI 58329, 64136841) and compile. Studio playtest: before-and-after screenshots in Blue Inferno
(orange/brown → blue/navy) and an after screenshot in Candy Crater (pink/berry, notice pill themed too). The gold
Raise button stayed gold. The owner approved from those screenshots ("Yes, ship them"). Console clean; the force
attribute was cleared.

## 125. Fix: notices that arrive together all get shown

**Why.** Found while looking for this iteration's feature. A notice replaced the one on screen instantly, so notices
sent in the same moment collapsed to the last. That happens a lot: being knocked out sends "🔥 SCORCHED!" and the
"why you fell" tip together, and a round's end can bring a first crown, an escape party (#113), a new title
(#114/#123), a milestone gift (#124) and challenge completions (#116/#119/#120) at once. Kids were missing rewards
they'd earned, and the knockout tip hid the SCORCHED line.

**Built.** LavaFloorsUI `notify` (the toast players see) now queues. Each toast stays at least 1.8 s while others
wait, the last one stays the usual 3.6 s, and a flood keeps only the newest 5 (worst case about 9 s behind). The old
SkySproutClient `notice` (the SkySproutHUD line, not in the party-mode UI) got the same queue so the two behave alike.
No change to how a notice looks.

**Verified.** Lints pass. The Studio copies match the repo (SkySproutClient 15010 bytes, hash 523588432;
LavaFloorsUI 58125, 564540274) and compile. Playtest: the server sent three notices in one frame, and a client
watcher on the toast label recorded "QTEST 1 of 3" at 9.1 s, "2 of 3" at 10.9 s, "3 of 3" at 12.8 s and hidden at
16.5 s (before the fix only "3 of 3" would have shown). The party-mode PlayerGui has no SkySproutHUD, so that copy
can't be watched there. Console clean; the one "infinite yield" warning came from my own test script looking for
that HUD.

## 124. Round milestones: a thank-you at 10, 25, 50, 100… rounds

**Why.** Feature loop. Kids love round numbers and being noticed for sticking with a game. Every reward so far is
for doing something in a round (crowns, shoves, berries) or for the day (daily reward, challenges). Nothing
recognised a kid who has simply played a lot. A milestone gift is pure thanks: no timer, nothing to lose.

**Built.** SkySproutLavaService `payout`: every finished round adds 1 to the saved `RoundsPlayed`. At 10, 25, 50,
100, 250, 500 and 1000 rounds (`CFG.RoundMilestones`, 25 → 300 coins) it pays a flat gift, logged as
"RoundMilestone_N", with "🎉 That was your 50th round! Thanks for playing: +75 coins". SkySproutRules: `RoundsPlayed`
defaults to 0 and is cleaned on load (whole number, 0–10,000,000). Existing players start counting at the publish.

**Verified.** Lints pass. The Studio copies match the repo (lava service 207257 bytes, hash 798003889; Rules 11369,
929505463) and compile; `R.new()` gives 0, `R.clean` turns 42.7 into 42 and "x" into 0. Solo playtest with a
temporary Studio-only milestone at round 2: round 1 paid none; round 2 showed the notice, and Coins went
215 → 250 (round 10 + gift 25). The copy was restored and re-hashed. Console clean.

## 123. 🌍 World Traveler title

**Why.** Feature loop. Collect-them-all goals are a favourite with kids, and the five worlds are the game's most
visible variety. #120 rewards three worlds in a day; this is the lifetime version: play in all five, ever, and wear
it over your head.

**Built.** SkySproutLavaService: title 🌍 World Traveler (teal), `Need = "Worlds"`, unlocked when `WorldsSeen`
holds every theme in `LavaThemes.List`. `payout` adds the round's world to the saved `WorldsSeen` and, when the
last new one fills the set, unlocks the title with the usual "🏷️ New title" notice. SkySproutRules: `WorldsSeen`
defaults to `{}` and is cleaned on load (string keys, `true` values, at most 20). Existing players start with an
empty set; nothing is backfilled.

**Verified.** Lints pass. The Studio copies match the repo (lava service 206527 bytes, hash 220546736; Rules 11204,
153935382) and compile; `R.clean` kept `{Candy, Sunset}` and dropped a bad entry, and `R.new()` has the table. Solo
playtest with no temporary code. A first helper that advanced `StudioForceTheme` whenever the theme changed raced
ahead: in Studio that attribute re-themes on the spot, so it jumped through all five at once and the rounds stayed
Candy. A second helper set the next world only after each round's payout. After a Purple Moon round, the Blue
Inferno round ended with "🏷️ New title: 🌍 World Traveler!" and `LavaTitles` listed it. Picking it gave the head tag
"🌍 World Traveler". The screenshot missed the player, so the emoji render on the tag isn't confirmed. The first
helper muddled which worlds were already seen, so this shows the unlock firing once at a round end, not the exact
fifth-world moment. Console clean; no force attribute left in the place.

## 122. Duos teams get names

**Why.** Feature loop. In Duos you could only tell your team by its outline colour, and the win line read "Team Ann &
Bob wins!". Kids love belonging to a named team, and a name tied to the colour ("I'm Team Froggy, the green one!")
makes it easier to spot your teammate.

**Built.** SkySproutLavaService: `TEAM_NAMES`, one per outline colour (💧 Team Splash blue, 🌸 Team Blossom pink,
🐸 Team Froggy green, ⚡ Team Zap yellow, 🔮 Team Wizard purple, 🦊 Team Fox orange). The pairing notice now says
"👥 DUOS! You're 💧 Team Splash with X. Last team standing wins!" (or "…, solo this round. Good luck!"). The win
notice says "👥 🐸 Team Froggy wins! (Ann & Bob)". Text only; the outlines are unchanged.

**Verified.** Lints pass. The Studio copy matches the repo (205699 bytes, hash 860972176) and compiles. Solo
playtest with Duos forced: "👥 DUOS! You're 💧 Team Splash with 🤖 Fudge. Last team standing wins!", then with 🤖
Gloom the next round. The screenshot shows the notice on one line with 💧 rendered, and the player's blue outline
matching. Console clean; the force attribute was cleared. Not tested: the win notice (with one real player, a
knockout ends the round before a team can win), a plain string change.

## 121. Daily challenges give Lava Pass XP too

**Why.** Feature loop. The daily challenges and the Lava Pass were two separate tracks, so finishing a challenge only
paid coins. Kids love seeing a progress bar move, and the free track (hats at tiers 3, 9 and 16) is the main
long-term goal for players who never buy anything. Now the daily goals push it along too.

**Built.** SkySproutConfig `LavaPass.XP.Challenge = 10` (about one round's worth). SkySproutLavaService `challenge`:
on completion it adds that XP through `A.Season.AddXP`, the same call rounds use (it announces any tier unlock), and
the notice now ends "· +10 pass XP". Everyone gets the same XP; the premium pass only changes which rewards you can
claim, as before.

**Verified.** Lints pass. The Studio copies match the repo (lava service 205298 bytes, hash 650364571; Config 6642,
950957537) and compile. Solo playtest in a temporary Studio-only copy that showed every challenge: "📋 Challenge
complete: Play in 3 different worlds! +40 coins · +10 pass XP" and the same for "Vote for the next twist 3 times".
PassXP ended at 62 = 3 scorched rounds × 14 + 2 challenges × 10. (Reading it right at each notice showed no change,
because the attribute replicates before the notice arrives.) The copy was restored and re-hashed. Console clean.

## 120. Daily challenge: play in 3 different worlds

**Why.** Feature loop. The five world themes are the biggest visual treat in the game (and four of them are bonus
rounds with extra fruit and a lost buddy), yet no goal pointed kids at them. The world is picked at random and never
repeats twice in a row, so this is an easy, relaxed challenge: keep playing and you'll see three.

**Built.** SkySproutLavaService `payout`: each player's first round in a world today counts toward "Play in 3
different worlds" (40 coins). The worlds played are kept in the saved daily state (`Daily.W`), which resets with
the day like the rest. SkySproutRules cleans `Daily.W` on load (string keys, `true` values, at most 20). Pool: 15
challenges.

**Verified.** Lints pass. The Studio copies match the repo (lava service 204959 bytes, hash 910693150; Rules 11012,
104316958) and compile. `R.clean` kept `W = {Candy, Sunset}` and dropped a bad entry. Solo playtest in a temporary
Studio-only copy that showed every challenge: rounds in Purple Moon, Candy and Starry Night took Worlds 1/3 → 2/3 →
3/3 with "📋 Challenge complete: Play in 3 different worlds! +40 coins". The copy was restored and re-hashed. Console
clean. Not tested: a repeated world not counting twice (worlds never repeat back-to-back, so it needs 4+ rounds).

## 119. Daily challenge: knock 2 climbers off the floor

**Why.** Feature loop. "Land 6 shoves" counts every bump, but the moment kids actually cheer for is sending someone
into the lava. Bots count, so a kid can finish it without ever knocking out a friend.

**Built.** SkySproutLavaService: the challenge "Knock 2 climbers off the floor" (50 coins). A bot shoved or pulled
straight into the lava (`shoveBot`) counts for the shover. For players, `shove` now also remembers who shoved you
(`shovedByPlayer`), and `scorch` credits them when you go out within `ReasonWindow` of the shove: the same window
that makes the "why you fell" line say "X shoved you off". Pool: 14 challenges.

**Verified.** Lints pass. The Studio copy matches the repo (204584 bytes, hash 510709179) and compiles. Solo
playtest with Mega Shoves forced, in a temporary Studio-only copy that showed every challenge: a client script
shoved the nearest bot repeatedly. "🤖 Ember got shoved into the lava" took Knockouts to 1/2; "🤖 Comet got shoved
into the lava" took it to 2/2 with "📋 Challenge complete: Knock 2 climbers off the floor! +50 coins". The copy was
restored and re-hashed; the force attribute was cleared. Console clean. Not tested: the player-vs-player credit, which
needs two players. Multiplayer windows were skipped again because the Riot Client was running.

## 118. Bots named for the world they're in

**Why.** Feature loop. The five worlds look completely different (mint tiles over pink lava in Candy Crater, icy blue
in Blue Inferno), but the bots were always called Ember, Magma and Basalt. Matching names make each world feel like
its own place, and kids get a laugh out of "🤖 Sprinkles got pulled into the lava!". (Planned first: a 2-player
Magnet Hands check. The Riot Client was running, so no multiplayer test windows this time.)

**Built.** SkySproutLavaService: `CFG.BotNamesByTheme` gives six names each for Blue Inferno (Frosty, Blizzard,
Glacier…), Purple Moon (Luna, Gloom, Shadow…), Starry Night (Comet, Nova, Twinkle…) and Candy Crater (Gumdrop,
Sprinkles, Taffy…). `spawnBotsOnly` draws from the round's theme list and falls back to `BotNames` for Sunset. Names
only: labels, notices and models all use the name as before.

**Verified.** Lints pass. The Studio copy matches the repo (204039 bytes, hash 653612839) and compiles. Solo
playtest with `StudioForceTheme = "Candy"`: the bots were Bot_Taffy, Bot_Jellybean and Bot_Gumdrop, labelled
"🤖 Taffy" etc. (screenshot). Forcing Sunset next: the first check read the old tower (the theme switches at the
countdown, before the new tower is built); the freshly built Sunset tower had Bot_Obsidian, Bot_Ash and Bot_Basalt.
Console clean; force attributes cleared.

## 117. 👋 Welcome back gift

**Why.** Feature loop. Kids drift away from games for a week or two (school, holidays) and come back. The daily
streak already pauses instead of resetting, so being away costs nothing; a warm welcome on top makes coming back
feel good. It's the opposite of fake urgency: nothing is lost by leaving, there's just a small gift for returning.

**Built.** SkySproutShopService `daily`: if your last daily was 7 or more days ago (`WELCOME_BACK_DAYS`), the day's
reward comes with a flat 100 coins (`WELCOME_BACK_COINS`, no VIP multiplier), logged as the economy event
"WelcomeBack", plus the notice "👋 Welcome back! We missed you: +100 coins" right after the daily reward notice.
Brand-new players (`LastDaily` 0) don't get it.

**Verified.** Lints pass. The Studio copy matches the repo (8548 bytes, hash 456575836) and compiles. Tested in a
temporary Studio-only copy that skipped the "already collected today" check and set the last daily to 8 days ago.
On joining, "🎁 Day 1 daily reward: +25 coins!" then "👋 Welcome back! We missed you: +100 coins"; coins came to 125
(Studio starts each session at 0, as the #113 test's 25 shows). The copy was restored and re-hashed. Console clean.
Not tested: a real 7-day gap on a live server (a plain day subtraction on the saved `LastDaily`).

## 116. Two twist challenges: survive twist rounds, vote for twists

**Why.** Feature loop. The game now has 16 twists and a Surprise option, but the daily challenges never mention
them. Kids who try new twists, and kids who join the vote, should get some credit for it. The pool grows from 11 to
13, so the same three come round less often.

**Built.** SkySproutLavaService `CFG.Challenges`: "Survive 2 twist rounds" (60 coins, any twist except Classic,
credited in `payout` next to "Survive") and "Vote for the next twist 3 times" (20 coins, credited on your first vote
on each ballot, so changing your mind doesn't count twice). Adding to the pool reshuffles which three come up each
day, as #109 did. Progress is kept by challenge Id, so nothing already earned is lost.

**Verified.** Lints pass. The Studio copy matches the repo (203539 bytes, hash 810844217) and compiles. Solo playtest
with the twist forced to Bouncy, in a temporary Studio-only copy that showed every challenge and counted every finish
as survived (a solo player can't survive a round): TwistSurvive went 0 → 1 → 2/2 with "📋 Challenge complete: Survive 2
twist rounds! +60 coins". On each of 3 ballots the client voted, then changed its vote; Vote went 1 → 2 → 3/3 (one per
ballot) with its completion notice. The copy was restored and re-hashed; the force attribute was cleared. Console
clean. Not tested: that a Classic round doesn't count (a plain Id check).

## 115. 🧲 Magnet Hands twist

**Why.** Feature loop. Every shove twist so far changed how far or how often you push. Kids love magnets and
"yoink!" moments, and pulling flips the usual strategy: instead of staying away from the strongest shover, you stay
away from anyone standing across a hole from you. It's a vote option, so nobody gets it without the server choosing it.

**Built.** SkySproutLavaService: new twist `Magnet` ("🧲 Magnet Hands", weight 2). In `shove`, the push direction
is reversed, so the target is launched toward the shover with the usual speed and lift (often flying right past
them), and the victim's notice reads "🧲 X pulled you!". In `shoveBot` the bot slides 1.6 tiles toward the shover;
if that lands off the floor it falls ("got pulled into the lava by X!"). Mega Shoves and showdown power are
unchanged. No client change: the client applies whatever velocity the server sends.

**Verified.** Lints pass. The Studio copy matches the repo (203091 bytes, hash 387547182) and compiles. Solo playtest
with `StudioForceMutator = "Magnet"`: the countdown said "Twist: 🧲 Magnet Hands!". A client script faced the
nearest bot, shoved, and compared the hit bot's grid tile with mine. Three clean results: me (2,5), bot (3,5) →
(1,5); me (5,4), bot (4,4) → (6,4) (both yanked past me), and a bot pulled into the lava with the new notice. An
earlier position-based attempt was muddied by bots hopping on their own and the floor spinning. Console clean; the
force attribute was cleared. Not tested: a pull between two real players (the same reversed vector the client
already applies for shoves).

## 114. 🤝 Team Player title

**Why.** Feature loop. Titles are the game's collectibles, and kids show them off over their heads. Every title so
far rewarded solo feats (crowns, gems, chests, twists) except 🍓 Kind Climber. The new escape party (#113) gives a
natural second title for playing together.

**Built.** SkySproutLavaService: the title 🤝 Team Player (light blue) unlocks after CFG.TitleParties (3) escape
parties. Each escape party adds 1 to the saved `EscapeParties` counter, and the third unlocks the title with the
usual "🏷️ New title" notice. SkySproutRules: `EscapeParties` defaults to 0 and is cleaned on load like `GiftsSent`.
No client change: the title list is built by the server.

**Verified.** Lints pass. The Studio copies match the repo (lava service 202576 bytes, hash 89202579; Rules 10816,
893950994) and compile; `R.new()` gives `EscapeParties = 0`. As in #113, the round was tested in a temporary
Studio-only copy (every runner counts, threshold 1, title after 1 party). One solo round gave the escape party notice,
then "🏷️ New title: 🤝 Team Player!", and `LavaTitles` listed it. Picking it with the LavaTitle remote showed
"🤝 Team Player" over the climber's head, emoji rendered (screenshot). The copy was then restored and re-hashed.
Console clean.

## 113. 🤝 Escape party bonus

**Why.** Feature loop. Shoving is the core of the game, but in a server full of kids the best rounds are the ones
where a group of friends makes it out together. Nothing rewarded that. A small shared bonus nudges players toward
helping each other survive without taking anything from anyone.

**Built.** SkySproutLavaService `payout`: counts the players crowned this round (bots don't count). If it's
CFG.EscapePartyMin (3) or more, each crowned player gets CFG.EscapePartyCoins (15) on top, flat and after the
multipliers like the first-crown bonus, logged as the "EscapeParty" economy event, with the notice "🤝 Escape party!
N climbers escaped together: +15 coins". No client change.

**Verified.** Lints pass. The Studio copy matches the repo (202017 bytes, hash 518200290) and compiles. A test
player can't reliably survive a full round, and three crowned players would need a multiplayer test that can't win
either, so the payout was tested in a temporary Studio-only copy that counted every runner with a threshold of 1. A
solo round gave the notice and the Coins attribute went 25 → 75 (round 35 + bonus 15). The copy was then restored
and re-hashed. Not tested: the real 3-crown count in a live server (a simple count over the round's runners).

## 112. 🎲 Surprise! in the twist vote

**Why.** Feature loop. Kids love a mystery box. The vote always showed three named twists, so the twists nobody
picks (Shield Party, Quick Crumble) rarely came up, and there was no thrill of the unknown. A surprise option adds
that thrill at no cost to fairness: everyone gets the same twist, and it's revealed before the round starts.

**Built.** SkySproutLavaService: with CFG.SurpriseChance (0.5) the last of the three vote slots becomes "🎲 Surprise!".
If it wins, the next twist is drawn from the twists that weren't on the ballot, never Classic or the twist just
played. The "Next twist" notice says "🎲 Surprise!", and the countdown reveals it ("🎲 Surprise twist: 🕳️ Hole
Party!"). If nobody is ready and the round waits, the surprise wording carries over. No client change: the vote
card already draws whatever options the server sends, and TwistVote analytics log "Surprise" like any twist.

**Verified.** Lints pass. The Studio copy matches the repo (201343 bytes, hash 629341067) and compiles. Solo
playtest: the first 4 ballots had no Surprise (about 1 in 16 at 0.5), then 2 of the next 3 did. Voting it gave
"🗳️ Next twist: 🎲 Surprise! (1 vote)" and then "🌅 Sunset · 🎲 Surprise twist: 🕳️ Hole Party!" and "🍭 Candy
Crater · 🐾 Bonus round · 🎲 Surprise twist: 🕳️ Hole Party!", both twists off the ballot. The screenshot shows the
die emoji rendering on the vote button. Console clean. Side note: the test player was opted out by the existing away
check after idle rounds; I cleared it by hand (not a bug).

## 111. Store icon and thumbnail that pop (owner's request)

**Why.** The owner asked for an icon and thumbnail a kid would pick on sight, with dynamic poses. Kids' game
thumbnails that do well on Roblox share a look: big, close characters in action, a thick outlined title, bright
saturated colour and one clear focal point.

**Built.**
- `tools/compose_pop_art.py`: chroma-keys green-screen Studio captures, adds white sticker outlines and drop
  shadows, a light burst, sparkles and a lava glow, and sets "LAVA FLOORS" in Luckiest Guy with a white and brown
  outline and a yellow-to-orange fill.
- Thumbnail: the crowned winner in the middle, a shoved climber on the left, a leaper on the right, two fruit
  buddies in the corners, over the Sunset crater. Icon: the winner, a buddy and "LAVA".
- Uploaded as Open Use images (icon 73026836484929, thumbnail 73147668402610), both approved by moderation, and set
  as the place icon and first thumbnail through the Assets API. The previous banner stays as the second thumbnail.

**Verified.** The owner approved both images from previews. Reading the place back with
`readMask=previews,icon` shows the new icon and the new thumbnail first. The place revision didn't change (the
update only touched metadata). Not checked: how the store page looks on a phone.

## 110. Jump styles and four more celebrations (owner's request)

**Why.** The owner asked for "different jump animations" and "different celebration animations", taken from sources
that allow it. Roblox only plays an animation in a game its owner has given access to, so animations ripped from
other games wouldn't load anyway. Roblox's own animations (its default emotes and its free animation packs) work in
every game. Every ID was checked with `MarketplaceService:GetProductInfo` (creator Roblox, Animation type) before use.

**Built.**
- LavaFloorsUI, jump styles: on every landing the client sets the default Animate script's `JumpAnim` to one of 12
  Roblox pack jumps at random (Cartoony, Ninja, Superhero, Stylish, Toy, Bubbly, Astronaut, Levitation, Rthro, Robot,
  Mage, Knight); all 12 are preloaded. Just a look: no change to jump height or timing.
- LavaFloorsUI, emotes: Shuffle (R15 dance 3), Clap (EmoteClap), Happy (emote_happy) and Bop ("Keeping Time") join
  the panel, which is now 4 rows tall. SkySproutLavaService `WinEmotes` accepts them as victory emotes. Five catalog
  emotes (Salute, Shrug, Hello, Stadium, Tilt) turned out to hold only face animations, so they weren't used.

**Verified.** Lints pass. The Studio copies match the repo (LavaFloorsUI 57500 bytes, hash 521041655; lava service
200120, 809650616) and compile. Studio playtest: 6 jumps played 6 different pack jumps (Bubbly, Stylish, Mage,
Stylish, Robot, Cartoony); all four new emotes loaded and played (lengths 1.9, 3.0, 5.4 and 3.4 s). The emote panel
showed all 10 buttons; the owner approved it from that screenshot. The Shuffle icon was changed from 🪩 (not
rendered by Roblox's font) to 🎉. Consoles clean. A 30 s gameplay video was recorded for the owner.

## 109. Three new daily challenges: cheer, gift, shield orbs

**Why.** Feature loop. The daily pool had 8 challenges, so the same three came round often, and none rewarded
the kind, social things knocked-out kids can do. Cheering and gifting give them something to do on the sidelines.

**Built.** SkySproutLavaService `Challenges`: "Cheer %d times from the sidelines" (3, 30 coins), "Send %d strawberry
gift" (1, 40) and "Grab %d shield orbs" (2, 50). They're counted where cheers are sent (after the cheer cooldown),
where a gift goes through, and where a shield orb is picked up. The pool is now 11; three a day as before.

**Verified.** Lints pass. The Studio copy matches the repo (200085 bytes, hash 725752901) and compiles. 2-player
Studio test with all 11 challenges active (`ChallengesPerDay` 11 in the Studio copy only) and Shield Party forced:
Player1 grabbed two shield orbs ("Challenge complete: Grab 2 shield orbs! +50"), sat out the next round, cheered three
times ("Cheer 3 times … +30") and sent Player2 a strawberry ("Send 1 strawberry gift! +40"; "🍓 Sent to Player2!").
Server console clean; test ended; test value restored and re-hashed.

## 106. Title colours follow the world theme (owner's request)

**Why.** The owner asked for "the font color [to] match the themes". The HUD titles were always gold-to-orange, so in
Blue Inferno or Candy Crater they clashed with the world.

**Built.**
- LavaThemes: each theme has `TextTop` and `TextBottom` colours. Sunset keeps gold-to-orange; Blue Inferno ice to
  blue; Purple Moon lavender to purple; Starry Night cream to periwinkle; Candy Crater mint to pink.
- LavaUI: titles take the current `U.TitleTop`/`U.TitleBottom`, and the new `U.setTitleColors(top, bottom, root)`
  repaints every `TitleGradient` under root.
- LavaFloorsUI: when `workspace.LavaTheme` changes (each countdown), it repaints the whole PlayerGui. Body text stays
  light for readability.

**Verified.** The owner approved the look from a Studio preview (one title per theme) before this was committed.
Lints pass. The Studio copies match the repo (LavaThemes 5247 bytes, hash 279652373; LavaUI 8780, 968646449;
LavaFloorsUI 55491, 713103016) and compile. Studio playtest: with Blue Inferno forced, all 7 HUD titles were
(215,240,255)->(80,160,255); after switching to Candy Crater during play, all 7 were (225,255,240)->(255,125,200).
Consoles clean; force attribute cleared.

## 108. The store is live: 5 passes and 8 products created and wired in (owner's request)

**Why.** The owner asked what's needed to earn money. Every pass and product ID in the game was 0, so the store was
hidden. The owner asked me to create them ("you got that") once Studio's upload folder allowed the icons.

**Built.**
- Created over Open Cloud, at the prices the owner approved earlier, each with its icon from Media/store:
  VIP 299 (2094204889), Lava Pass Premium 199 (2093742988), 2x Lava Coins 149 (2096444986), Aurora Gloves 99
  (2092939013), Flame Trail 79 (2093340957); coins 100/500/2,000/6,000 at 19/79/249/599 (3735086616, …644, …666,
  …685); tips 25/100/500/1,000 (3735086772, …785, …798, …811).
- Passes and coin packs have Price Optimization (managed pricing) on. Tips don't, so each tip costs exactly what it
  says. Descriptions are honest: coins "can also be earned by playing", the cosmetics are "just a look", and a tip
  "doesn't give anything in the game".
- SkySproutConfig: the 13 IDs are filled in (`PassId`, `DoubleLavaPassId`, `LavaPassPremiumId`, `VipPassId`,
  `TrailPassId`, `ProductIds`).

**Verified.** `MarketplaceService:GetProductInfo` returned the right name and price for all 13, and every pass is for
sale. The Studio copy of the config matches the repo (6550 bytes, hash 691564689) and compiles. In a Studio playtest
the shop showed the Aurora Gloves, Flame Trail and 2x cards, the four coin packs (R$ 19/79/249/599), the four tips
and the VIP panel, with no errors on client or server. The owner's account counts as owning its own passes, so the
VIP panel read "YOU'RE VIP". Not tested: an actual purchase (no test purchases were made).

## 107. ⏩ Fast-Forward twist

**Why.** Feature loop. Slow-Mo (#103) gives younger kids an easier round; skilled kids get a matching challenge. It's
the same for everyone and rarer (weight 1), so it spices things up without making the game harder overall.

**Built.** SkySproutLavaService: a new twist `{ Id = "FastForward", Name = "⏩ Fast-Forward", Weight = 1 }`.
`buildTower` sets the tower's `PhaseTime` to `FastForwardPhaseTime` (8 s), using the same mechanism as Slow-Mo, so
the grid, round end and lava all run 1.25x faster (a 24 s round). (#106, theme-coloured titles, is waiting for the
owner's yes on the look.)

**Verified.** Lints pass. The Studio copy matches the repo (199734 bytes, hash 996108217) and compiles. Solo Studio
playtest: a forced Fast-Forward round had `PhaseTime` 8 and a 24 s schedule; the next round, forced Classic, had 10
and 30 s. Server console clean; force attribute cleared.

## 105. 🌀 Twist Tamer title

**Why.** Feature loop. With 16 twists, there's now a reason to try them all. A collect-them-all title (like Gem
Hunter and Buddy Collector) rewards variety without coins and without favouring anyone.

**Built.**
- SkySproutLavaService: a new title, 🌀 Twist Tamer (`Need = "Twists"`), unlocked once you've been crowned in
  `TitleTwists` (5) different twists. Each crown adds that round's twist to the profile's `TwistWins`; the fifth
  different one runs `applyTitle` and says "🏷️ New title: 🌀 Twist Tamer! …", as Chest Cracker does.
- SkySproutRules: `TwistWins` in new profiles, and `clean` keeps it (string keys, at most 60).

**Verified.** Lints pass. The Studio copies match the repo (lava service 199417 bytes, hash 151265757; rules 10645,
510712026) and compile. A test player can't win in Studio, so in the Studio copy only every payout counted as a crown
and `TitleTwists` was 2. After a forced Bouncy round and a forced Slow-Mo round, `LavaTitles` listed "🌀 Twist
Tamer". Server console clean; test values restored and re-hashed.

## 104. A cue when your bubble ends

**Why.** Feature loop. Bubbles now matter a lot (first-round, underdog and pickup shields, #83, #87, #91), but the
only sign one has ended is the bubble disappearing around your own character, which is easy to miss mid-climb. Key
cues should come through more than one sense (the same reasoning as the tile crack in #20). No visual change.

**Built.** SkySproutLavaClient, in a `task.defer` block (no new top-level locals): when the `LavaBubble` ForceField
leaves your character during a round and no new one replaced it (a pickup refresh swaps it straight away), it plays
the "bubble on" chime lower (`Crown`, pitch 1.1) and a light `UIClick` HapticEffect on phones and controllers.

**Verified.** Lints pass. The Studio copy matches the repo (124718 bytes, hash 349026693) and compiles. Solo Studio
playtest with the bubble shortened to 2 s and the underdog bubble given after one loss (Studio copy only, so it ends
while the test player is still climbing): in two rounds the cue (`LavaBubbleEndHaptic`) came 1.9 and 2.0 s after the
bubble appeared, at the moment it went. In an earlier run with a 4 s bubble, the player was knocked out first and no
cue came, which is right. Consoles clean; test values restored and re-hashed.

## 103. 🐢 Slow-Mo twist (a gentler round)

**Why.** Feature loop. The recent twists (#99, #102) make rounds wilder; younger kids also need rounds they can
actually win. Slow-Mo slows the whole floor for everyone, so it's fair, and it gives new players room to learn the
moves.

**Built.** SkySproutLavaService: a new twist `{ Id = "SlowMo", Name = "🐢 Slow-Mo", Weight = 2 }`. `buildTower` sets
the tower's `PhaseTime` attribute to `SlowMoPhaseTime` (13 s) instead of `PhaseTime` (10 s). The grid schedule, the
round's end time and the lava height all follow that attribute, on the server and on every client, so the whole
round runs 1.3x slower (39 s instead of 30). `lateOpen` (the phase-1 "dropping you back in" window) now reads the
tower's phase time too, instead of the fixed setting.

**Verified.** Lints pass. The Studio copy matches the repo (198548 bytes, hash 851915652) and compiles. Solo Studio
playtest: a forced Slow-Mo round had `PhaseTime` 13 and a 39 s schedule; the next round, forced Classic, had 10 and
30 s. Consoles clean; force attribute cleared. Not separately tested: a phase-1 drop-back between 10 and 13 s into a
Slow-Mo round.

## 102. 🎯 Shove Frenzy twist

**Why.** Feature loop. Shoving is the game's core interaction (#39) and the party-game charts are led by shove games
(#83). A twist where everyone can shove twice as often makes for chaotic, readable rounds. It's fair because the rule
is the same for every climber, and bubbles and the late-join grace still protect as usual.

**Built.** SkySproutLavaService: a new twist `{ Id = "ShoveFrenzy", Name = "🎯 Shove Frenzy", Weight = 2 }`. `shove`
uses `FrenzyShoveCooldown` (0.4 s) in that twist and `ShoveCooldown` (0.8 s) otherwise. Server only; the client has no
cooldown of its own.

**Verified.** Lints pass. The Studio copy matches the repo (198033 bytes, hash 396690927) and compiles. Solo Studio
playtest, counting the "Swing" replies (sent only for accepted presses, #93) to 8 presses 0.5 s apart: in a confirmed
Shove Frenzy round all 8 were accepted, and in a Classic round 4 of 8. Consoles clean; force attribute cleared.

## 101. 👑 First crown of the day bonus

**Why.** Feature loop. A small daily goal gives kids a reason to come back, and a crown is the game's real
achievement. It stays kid-fair: there's no timer, nothing is lost if you skip a day, and it isn't bought; the daily
reward ladder already pauses rather than resetting (#45).

**Built.**
- SkySproutLavaService payout: when a climber is crowned and their saved `FirstCrownDay` isn't today (UTC), they get
  `FirstCrownCoins` (50) on top, added after the round multipliers so VIP and 2x don't change it, with the notice
  "👑 First crown today! +50 coins" and an economy event `FirstCrownToday`.
- SkySproutRules: `FirstCrownDay` in new profiles and kept by `clean`, so rejoining can't claim it twice.

**Verified.** Lints pass. The Studio copies match the repo (lava service 197745 bytes, hash 174225143; rules 10457,
404400078) and compile. A test player can't win a round in Studio, so for the playtest the condition was temporarily
`(r.crowned or true)` in the Studio copy only. The bonus notice came with the first round's payout and not with the
second or third (once a day). Consoles clean. The temporary change was removed and re-hashed.

## 100. "🐾 Bonus round" in the countdown

**Why.** Feature loop. The themed worlds now have extra fruit drops (#96) and a lost buddy to find (#97), but nothing
told kids that. Without a cue, a buddy on the outer ring looks like a random object, and kids don't know to go for it.
The owner wants fewer pop-ups (#80), so this goes into the existing countdown notice rather than a new one.

**Built.** SkySproutLavaService: in every theme except Sunset, the countdown notice reads, for example,
"🌙 Purple Moon · 🐾 Bonus round · Twist: 💥 Mega Shoves!". Sunset rounds read exactly as before.

**Verified.** Lints pass. The Studio copy matches the repo (197236 bytes, hash 694770723) and compiles. Solo Studio
playtest: with Purple Moon forced, the countdowns read "🌙 Purple Moon · 🐾 Bonus round · Twist: 🎁 Drop Party!" and
"… · Twist: 💥 Mega Shoves!". With Sunset and Classic forced, the countdown read "🌅 Sunset · Lava Rush in 4s!".
Server and client consoles clean; force attributes cleared.

## 99. 🦘 Bouncy twist

**Why.** Feature loop, second feature. Twists are the game's main source of round-to-round variety, and the twist
vote works best with plenty to choose from. Big bouncy jumps are an easy, readable thrill for kids, with no new art
and no unfairness: everyone gets the same jump.

**Built.** SkySproutLavaService: a new twist `{ Id = "Bouncy", Name = "🦘 Bouncy", Weight = 2 }`. A new
`baseJumpPower()` returns `BouncyJumpPower` (58, about 8.6 studs) in Bouncy rounds and `RoundJumpPower` (48, about 5.9)
otherwise. `enter` and the end of a super-jump boost use it, and the boost itself is now
`max(JumpBoostPower, baseJumpPower() + 12)`, so a super-jump pickup still lifts you higher in a Bouncy round (70).

**Verified.** Lints pass. The Studio copy matches the repo (196990 bytes, hash 377645468) and compiles. Solo Studio
playtest with Bouncy forced: across 7 round entries (including phase-1 drop-backs) the climber's JumpPower was 58,
and it was back to the lobby's 40 after each knockout. Server and client consoles clean; no test attributes left.
Not tested: the super-jump pickup in a Bouncy round (the 70 comes from the one-line max above).

## 98. 🐾 Buddy Collector title and a "lost buddy" daily challenge

**Why.** First feature of the owner's "loop and add a bunch of features" run. The theme buddies (#97) are a set of
four, and collect-them-all goals with something to show for it keep kids coming back (titles already work that way
for gems, chests and gifts, see #38).

**Built.** SkySproutLavaService:
- A new title, 🐾 Buddy Collector (`Need = "Buddies"`): unlocked when a player owns every theme buddy. `applyTitle`
  runs after each find, so it shows up in the title picker the moment the last one is found.
- A new daily challenge, "Grab 1 lost buddy" (60 coins). Any lost-buddy grab counts, including one you already own.
- Note: today's three challenges are a seeded shuffle of the whole pool, so adding one changes which three come up
  once this is published. Progress is kept per challenge, so nobody loses anything they've earned.

**Verified.** Lints pass. The Studio copy matches the repo (196589 bytes, hash 774401393) and compiles. Solo Studio
playtest, forcing each theme in turn while a test helper kept the player alive and grabbed the lost buddy once its
tile grew in: "You found the Moon Banana / Candy Dragon / Inferno Berry / Star Buddy", and after the fourth the
`LavaTitles` list gained "🐾 Buddy Collector". Today's challenges didn't include the new one, so its progress
couldn't be watched; the call ran on all four grabs without errors. Server console clean (the only client errors
came from an early version of my test helper, which kept a stale tower reference). No test attributes left.

## 97. Theme buddies to find in the bonus rounds (owner's request)

**Why.** Second half of the owner's request in #96: the themed worlds should also drop collectibles, "like a pet that
follows you around". Collecting pets is one of the main draws of party games (see #51), and a buddy you can only find
in one world gives each theme its own reason to cheer when it comes up.

**Built.**
- SkySproutConfig `Pets`: four buddies with `FindIn` (the theme), `Model` (the fruit they're made from), `Where` and
  `Aura`: Inferno Berry (blueberry, blue flames), Moon Banana (banana, purple glow), Star Buddy (star fruit,
  sparkles) and Candy Dragon (dragon fruit, pink sparkles). `Cost = 0`, and they're never sold.
- SkySproutRules `pet`: an unowned theme buddy can't be bought; it answers "Find the Inferno Berry in 💙 Blue Inferno
  rounds!".
- SkySproutLavaService: in every theme except Sunset, `buildTower` puts that theme's lost buddy in a bubble on an
  outer-ring tile that isn't a strawberry's (it grows in during phase 1, like the strawberries, so you go and get
  it). The first climber to grab it gets it in `OwnedPets`, it becomes their buddy and follows them, with the notice
  "🐾 You found the Inferno Berry! It follows you now." and an analytics custom event `BuddyFound`. A buddy they
  already own pays `BuddyFindCoins` (40) instead. `applyPet` builds theme buddies from their `Model` fruit and adds
  the aura (a light, plus Fire or Sparkles).
- LavaFloorsUI shop: theme buddy cards show the right fruit and "Find in 💙 Blue Inferno" until found, then BRING /
  ✓ WITH YOU like the others.

**Verified.** Lints pass. The owner approved the look from a Studio preview (bubbles and buddies with googly eyes;
flames and sparkles only show in play). Solo Studio playtest with Blue Inferno forced: the lost buddy spawned in its
bubble with Fire and a PointLight. Grabbing it set `OwnsPetInfernoBerry` and `PetStyle = InfernoBerry`, and the
buddy followed the player with its fire; a second one the next round paid "🐾 Another Inferno Berry! +40 coins".
Studio matched the repo for the config, rules and UI scripts. Console clean.

**Outer ring, verified after reconnecting.** That first test placed the buddy on a start tile, where a player could
spawn on it, so it was moved to the outer ring. After Studio reconnected, all 48 scripts matched the repo (lava
service 196061 bytes, hash 967030495). In a forced Blue Inferno round the lost buddy sat on tile 7,8, ring 3 (start
tiles are rings 0-2). Once its tile grew in, grabbing it gave "🐾 You found the Inferno Berry! It follows you now.",
and the buddy followed with its fire and light. Server and client consoles clean; no test attributes left.

## 96. Bonus rounds: more, and more varied, fruit drops in the themed worlds (owner's request)

**Why.** The owner asked for the coloured worlds to drop more items and collectibles: "every theme except Sunset
drops pickups in variety", with fruit drops and a collectible buddy (the buddy is the next part, #97). Until now every
theme dropped the same: a fruit supply drop every 20 s, about two a round.

**Built.** SkySproutLavaService:
- `ThemeDropEvery = 12`: in Blue Inferno, Purple Moon, Starry Night and Candy Crater, supply drops come every 12 s
  (about 3-4 a round). Sunset keeps 20 s, and Drop Party keeps its own 6 s.
- Variety: `pickBoost` never picks the same fruit as the previous drop (in every round). Drops still vanish after 8 s,
  so there is never more than one on the floor.

**Verified.** Lints pass. The Studio copy matches the repo (192534 bytes, hash 357133158) and compiles. Solo Studio
playtest with the timings shortened in the Studio copy only (theme 3 s, normal 5 s, first drop at 1 s, lifetime
1.5 s) so a short round shows several drops: forced Blue Inferno rounds dropped every 3.0 s, a forced Sunset round
every 5.0 s, and in 39 drops no fruit came twice in a row. Console clean. Timings restored and re-hashed; no test
attributes left.

## 95. Name sweep: settings and attributes (no change needed)

**Why.** The message check in #93/#94 found a real gap, so I ran the same kind of name check on the other things
looked up by string.

**Checked.**
- SkySproutLavaService `CFG`: 144 keys defined, 144 used. None is read without being defined, and none is unused.
- SkySproutConfig (shared): every key the lava service, both lava clients, the shop and the pass service read
  exists.
- Attributes read but never set by any script: 41, almost all from the old SkySprout RPG systems (portals, tower,
  wilds), set in the place itself or Studio-only test switches (`StudioForce*`, `StudioGrant*`). The only lava ones
  are `FallFrom` / `FallStart` / `FallSpeed` in `LavaGrid.FallLift`, left from the parachute crates removed in
  ff4ff20 ("flash spawns"). It now always returns 0, costs next to nothing and was left in place.

**Verified.** Read-only scans of Assets/Scripts; no code changed.

## 94. Lint: messages nobody handles (tools/check_remotes.py)

**Why.** The "Swing" gap fixed in #93 went unnoticed from the first version until now: the server sent an effect on
every shove press and no client handled it. The game talks over one RemoteEvent with string names, so a typo or a
forgotten handler fails silently. Per the project rule, a mistake gets one fix, and here that's a lint. It's a
separate change from #93, so the check didn't land in the same commit as the code it judges.

**Built.** `tools/check_remotes.py` checks three things by name:
- actions clients send with `FireServer("Name")` that no server script compares against,
- message kinds the server sends with `FireClient(p, "Name")` / `FireAllClients("Name")` that no client checks,
- effect kinds the server puts in a message (`Kind = "Name"`) that no client checks.

`QuestReward` (the old SkySprout tower quests, not used in party mode) is listed as known and doesn't fail. The
script exits 1 on anything else. The README's Building section now lists it with the other two lints.

**Verified.** On the repo: "0 unhandled message name(s)", exit 0, with QuestReward reported as known. On a scratch
copy with the #93 fix undone and a made-up `FireServer("LavaNope")` added, it reported both ("server effect
"Swing" is sent but no client checks for it" and "client action "LavaNope" is sent but no server script handles
it") and exited 1. No game scripts changed.

## 93. A missed shove still answers the button

**Why.** In the #92 two-player test most shove presses didn't land (the 0.8 s cooldown and a nearer bot took some),
and a press that misses gave the shover nothing at all: no sound, no flash. Game-feel guides (see #39) say every
input should get a response. A check of every effect kind the server sends against the client handlers found the
reason: the server has sent a "Swing" effect on each accepted shove press since the first version, but no client
ever handled it.

**Built.** SkySproutLavaClient: "Swing" now plays the existing shove sound high and light (pitch 1.9), so every
accepted press makes a whoosh. A hit adds its usual thud on top. It reuses the message the server already sends, so
there's no new network traffic, and presses during the cooldown stay silent, as before. No visual change.

**Verified.** Lint and the local-limit check pass. The Studio copy matches the repo (123530 bytes, hash 4610860)
and compiles. Solo Studio playtest: three shove presses 1 s apart in a round with nobody in reach each got a "Swing"
on the client (the shove sound is loaded) and no errors; console clean. Not checked by ear: how the whoosh sounds.
The other way round, the client also handles four kinds no server sends (Avatar, Contract, Explore, Story); they
belong to the old SkySprout RPG screens and were left alone.

## 92. Two-player check: the shove buzz and the ready gate (no change needed)

**Why.** Two of this session's changes had only been checked with one player: the shove buzz (#86 said "not
tested: the shove buzz in a real two-player shove") and the ready gate (#88) with more than one client joining. I
also checked whether the catch-up bubbles are fair in 💣 Hot Potato.

**Checked.**
- 2-player Studio test. Both players had `LavaReady` set on joining and both went through a round normally.
- Player1 moved next to Player2 in a round and shoved. Player2's client got the shove (speed 68) and the
  "💥 Player1 shoved you!" notice, and created `LavaShoveHaptic` (GameplayCollision) at the same moment. After the
  knockout, the "shoved you off" reason followed, and a crack buzz (`LavaCrackHaptic`) fired later in the round. All
  haptic effects were cleaned up within 2 s.
- Hot Potato, read from the code: a shielded kid can still be passed the bomb, but their bubble soaks the blast
  ("Your bubble shield soaked the blast!"), so the bubbles stay fair in that twist.

**Verified.** As above; server and Player2 consoles had no errors (only Studio's DataStore notice); test ended with
`EndTest`; no test attributes left in the place. No code changed. Still untested: the feel on a real phone.

## 91. Fix: the bubble vanished after a reset in phase 1

**Why.** Found while checking the edge cases around #87. A kid who resets (or otherwise loses their character) in
phase 1 respawns 3 s later and is dropped back into the round on a new character. The runner's `shieldUntil` is
carried over, so a running first-round or underdog bubble still protected them. But the visible bubble (a
ForceField) belonged to the old character, and nothing put it back: the grant only happens when no shield is
running. A test reset 2 s into the first-round bubble confirmed the respawn and drop-back timing. The missing
bubble itself comes from reading the code; I didn't sample it before the fix.

**Built.** SkySproutLavaService: the visible bubble is now its own `showBubble` helper. `enter` shows it again, for
the time that's left and with no notice, when a dropped-back climber still has a shield running but no bubble. A
pickup that doesn't extend the shield (#87) also puts the bubble back if it's missing.

**Verified.** Lint and the local-limit check pass. The Studio copy matches the repo (192126 bytes, hash 179621785)
and compiles. Solo Studio playtest: first-round bubble on, then the character was killed 2 s later. The new
character spawned at +5.4 s and was dropped back in at +7.3 s. The bubble was on it at +9 s, +12 s and +14 s, and
gone by +16 s (the 15 s bubble had ended). Console clean; no test attributes left.

## 90. Leak check after this session's changes (no change needed)

**Why.** Since the last leak check (#22) a lot of per-round code has changed: haptic effects created per shove and
per crack (#86), shield bubbles that now persist through orb pickups (#87), the ready gate (#88) and two new
analytics events (#85, #89). Now that the game is live, rounds run for hours per server, so anything left behind
each round would add up.

**Checked.**
- 8 solo Studio rounds (about 3.5 minutes), sampling after each round once the player was settled in the lobby.
- Server: workspace stayed between 3471 and 3536 instances and the whole game between 6139 and 6204, with no
  upward trend (the spread is bots and pickups). No HapticEffect or ForceField was left after any round.
- Client: workspace stayed between 3973 and 4029 and PlayerGui at 1994–1996, also with no HapticEffect left.
- Studio's total memory stayed between 2096 and 2110 MB (shared by the server and client in one process), with no
  trend.
- Leaderboard DataStore calls are within budget: the weekly board and the supporters board each read once a
  minute, and writes happen only on a crown or a tip.
- No deprecated APIs (legacy wait/delay/spawn, Body movers, Humanoid:LoadAnimation) anywhere in the scripts.

**Verified.** As above; consoles clean apart from Studio's usual DataStore notice. No code changed.

## 89. Measure real load times (LoadTime analytics)

**Why.** #88 left the real-world wait unmeasured: Studio loads instantly, so nobody knows how long phones take or
whether the 20 s `ReadyWait` fallback is too short or too long. Analytics answers that from live play, the same way
#63 and #85 did for strawberries and catch-up bubbles.

**Built.** SkySproutLavaService: a new `markReady` marks a player ready once, from the client's "LavaReady" or the
fallback. For players who joined after the service started, it logs the custom event `LoadTime`: the value is the
seconds from joining to ready (data load plus client load), and field 1 is "Under 5s", "5-10s", "10s+" or
"Fallback". Players already in the server at start are skipped, because their join time is unknown.

**Verified.** Lint and the local-limit check pass. The Studio copy matches the repo (191585 bytes, hash 304660356)
and compiles. Solo Studio playtests with a temporary print (Studio copy only): a normal join logged once ("Client",
1.8 s, "Under 5s") and the fallback 20 s later stayed silent. With the client's send temporarily disabled, it logged
"Fallback" at 20 s. "LogCustomEvent event fired" both times; console clean. Test edits removed and both scripts
re-hashed (LavaFloorsUI still 54583 / 75811917); no test attributes left.

## 88. Loaded first: no round until the game has loaded for you

**Why.** The game is live now, and most kids play on phones, where loading can take many seconds. The server
auto-queued a player as soon as their save loaded, and with one player a round starts after a 4 s countdown. So a
kid on a slow phone could be placed in their first round while still on Roblox's loading screen. They'd lose it to
the crumbling tiles before seeing anything, use up the first-round bubble (#83) and start a loss streak. There was no
loading gate anywhere (no ReplicatedFirst screen, no ready signal).

**Built.**
- LavaFloorsUI: once `game:IsLoaded()`, the client sends "LavaReady", resending every 2 s (up to 30 times) until the
  server confirms by setting the player's `LavaReady` attribute. A message sent before the save loads is ignored by
  the arena's handler, hence the resend.
- SkySproutLavaService: `autoQueue` needs `LavaReady`. A fallback sets it `ReadyWait` (20 s) after joining, also for
  players already in the server when the service starts, so nobody can get stuck out. Joining by hand is unchanged.

**Verified.** Lints pass. The Studio copies match the repo (lava service 190621 bytes, hash 242487548; LavaFloorsUI
54583 bytes, hash 75811917) and compile. Solo Studio playtests:
- Normal: `LavaReady` was set 0.1 s into the check and the player entered a round 4.3 s later.
- Gate: with `LavaReady` cleared on the server, the player sat out the next 20 s (no round started); once it was set
  again they were in a round 5.0 s later.
- Fallback: with the client's send temporarily disabled (Studio copy only), `LavaReady` came from the fallback
  17.6 s after the check began (about 20 s after joining) and the round followed at 22.5 s.
Console clean. Test edits removed and re-hashed; no test attributes left.

**Not tested:** a real slow phone. Studio loads instantly, so the real-world wait is unmeasured.

## 87. Fix: a shield orb cut the underdog bubble short

**Why.** Found in a Studio playtest while trying to check the open "not verified" items from #12 and #14. In a
🛡️ Shield Party round, a kid in the 15 s underdog bubble picked up a shield orb and got a second notice ("Bubble
shield! ... 7s") at the same moment. Worse, the orb replaced the bubble: `grantShield` always set the shield to end
7 s from the pickup, so the catch-up bubble (underdog or first-round) ended about 8 s early. Blueberry supply drops
did the same.

**Built.** SkySproutLavaService `grantShield`: if the new shield would end no later than the one already running,
the pickup only plays its effect. The longer bubble stays and there's no notice. A pickup that does extend the
shield works and reads exactly as before.

**Verified.** Lint and the local-limit check pass. The Studio copy matches the repo (189812 bytes, hash 311102475)
and compiles. Solo Studio playtest with `UnderdogAfter` temporarily set to 1 (Studio copy only) and Shield Party
forced: the player got the underdog bubble and moved onto a shield orb. The pickup 1.3 s later showed the effect
with no notice. The bubble was still on at +9 s and +12 s (the old code ended it at about +8.3 s) and gone by
+16 s. Console clean. Test edits removed and re-hashed; no test attributes left.

**Still not verified (#12, #14).** That surviving resets the underdog count and that a real player's win makes bots
sharper again. Three tries at a client-side survival driver kept the test player alive through phase 1 but not
phase 2 (they slipped off an edge as the floor rose), so I stopped there. The same run did confirm the bots' ease
rises 0.06 per bot win and stops at the 0.30 cap.

## 86. Phones feel shoves and cracking tiles too (HapticEffect)

**Why.** The two buzzes in the game (being shoved, #39, and your own tile about to break, #20) used
HapticService's motors, which only reach gamepads. Most kids play on phones, so they felt nothing. Roblox's newer
`HapticEffect` (https://create.roblox.com/docs/reference/engine/classes/HapticEffect) covers Android and iOS phones
with haptics as well as PlayStation, Xbox and Quest controllers.

**Built.** SkySproutLavaClient: a shove now plays a `GameplayCollision` HapticEffect, and the tile-about-to-break cue
plays a custom 180 ms buzz at 0.6 strength (the same as the old gamepad motor). Each effect is cleaned up after
2 s. The top-level `HapticService` local is gone (one fewer local in the client).

**Verified.** Lint and the local-limit check pass. The Studio copy matches the repo (123330 bytes, hash 22971980)
and compiles. Solo Studio playtest: standing still in a round made the tile crack, and `LavaCrackHaptic` (Custom)
appeared and was cleaned up; client console clean. Both effect types also played on the Studio client without
errors. Not tested: the shove buzz in a real two-player shove (same code, checked on its own), and how either
feels on a real phone (this PC has no vibration). Worth a feel on a phone after the next publish.

## 85. Measure the catch-up bubbles (CatchUpBubble analytics)

**Why.** The two-player test in #82 found that, with bots winning most rounds, a struggling kid had the underdog
shield nearly every round, so they were unshoveable for half of it. The note said to watch real play data before
changing anything. With the game now live, this event collects that data; it starts with the next publish after
version 130.

**Built.** SkySproutLavaService: `enter` records which bubble a climber started the round in ("FirstRound" or
"Underdog"). At payout every climber logs one `CatchUpBubble` custom event, with field 1 set to the bubble ("None" if
there wasn't one) and how the round ended, for example "Underdog - Survived". No player-facing change.

**Verified.** Lint and the local-limit check pass. The Studio copy matches the repo (189508 bytes, hash 214978859)
and compiles. Solo Studio playtest with `UnderdogAfter` temporarily set to 2 and a temporary print, both in the
Studio copy only: three rounds logged "FirstRound - Scorched", "None - Scorched" and "Underdog - Scorched", each with
"LogCustomEvent event fired" and no errors. The test edits were then removed and the hash re-checked; no test
attributes are left in the place.

## 84. Fewer "bubble shield blocked your shove" notices

**Why.** With first-round and underdog bubbles common, shoving a shielded kid repeatedly sent the shover the same
notice every time, against the owner's "less chatter" direction (#80).

**Built.** SkySproutLavaService `shove`: the blue "Blocked" flash still shows every time, but the words come at most
once every `BlockedNoticeGap` (6 s) per shover and target.

**Verified.** Lint and the local-limit check pass; the Studio copy matches the repo (188852 bytes, hash 960709853)
and compiles; server console clean. The first 2-player test was inconclusive (the target had no bubble when the
punches landed). Retest: Player2 got the first-round bubble for a fresh round; Player1 shoved them 9 times in 9 s:
8 blue "Blocked" flashes, and the notice only at 1.1 s and 7.3 s (6 s apart). Server console clean.

## 83. First-round bubble for new players

**Why.** Party charts are led by shove games right now (e.g. "Knockout!" on Rotrends' Party & Casual list,
https://rotrends.com/games/TopPartyAndCasual), and the onboarding research in #71 says new players leave when the
first moments feel unfair. With the tutorial tips gone (#80, owner's call), the worst first moment left is a
brand-new kid being shoved out by a veteran in the first seconds. This teaches by play, not by text.

**Built.** SkySproutLavaService `enter`: a player whose `Tutorial` attribute is true (their first round hasn't
finished) starts the round in the same 15 s bubble as the underdog shield, with "🫧 First-round bubble! Shoves can't
move you for 15s." It also covers a phase-1 drop-back in that round. From the second round on, only the underdog rule
applies.

**Verified.** Solo Studio playtest: first round (`Tutorial` true), the bubble was on 1 s after the round started,
with the notice; once the round finished, `Tutorial` was false and the next round had no bubble. The Studio copy
matches the repo (188226 bytes, hash 297689131); console clean.

## 82. Two-player smoke test of the shove twists (no change needed)

**Why.** This session changed a lot around shoves and rounds (late-join grace, the shove speed cap, Mega Shoves,
Quick Crumble, the client's new scopes, new music, tips removed), so a regression run before moving on. The owner
also chose to keep strawberries scarce, so no Berry Rain twist (see #81).

**Checked.** A 2-player Studio test with the server forcing six twists in turn, two rounds each (Mega Shoves, Quick
Crumble, Hot Potato, Duos, Shield Party, Big Heads), while both players repeatedly moved next to each other and
shoved:
- Every twist was announced and ran. Hot Potato passed the bomb back and forth; a blast arrived as a 70 push with
  the right knockout tip.
- Shoves arrived at 66 (normal) and 89 (showdown 1.35x); Duos teammates couldn't shove each other; shields (Shield
  Party and the underdog shield) blocked shoves with the usual message; a bot was shoved into the lava.
- No unprompted tips appeared; the only tips were knockout reasons.

**Note for later.** With bots winning most rounds, both test players had the underdog shield nearly every round
(3 losses in a row, 15 s). That's working as designed, but it means a struggling kid is often unshoveable for half a
round. Worth watching in real play data before changing.

**Verified.** As above; server console clean across 12 rounds. Forced twist and away attributes are cleared in the
Edit copy. No code changed.

## 81. ⚡ Quick Crumble twist

**Why.** Variety through rare modes: Grow a Garden's "Sheckle Rain" shows kids love a rare surprise round
(https://www.sportskeeda.com/roblox-news/grow-garden-sheckle-rain-guide). A "Berry Rain" twist was the first idea
but would undo the owner's call to keep strawberries scarce, so it's parked for the owner. Quick Crumble is
server-only and touches no economy.

**Built.** SkySproutLavaService: an eleventh twist, `QuickCrumble` ("⚡ Quick Crumble", weight 1, so rarer). While
it runs, `updateWear` uses `CampTime` x `QuickCrumble` (0.6): a tile you stand on cracks after about 2.4 s instead
of 4, and empty tiles recover at the same faster rate. The crack, shake and warning plates are unchanged.

**Verified.** Solo Studio playtest, standing still on a start-ring tile right after the floor moved: with the twist
forced it cracked 2.76 s after landing; with Classic forced, 4.24 s (both include the landing and the 0.25 s wear
tick). Studio copy matches the repo (187838 bytes, hash 533737701); console clean; forced twist attribute cleared.

## 80. Tips only when you lose (owner's request)

**Why.** The owner asked for fewer tips, shown only when a player loses.

**Removed.**
- First-round coach cards ("NEW HERE? TIP 1 / 6", one every 5 s through a new player's first round).
- The rotating tips on the lobby countdown line (shove, spin, bubbles, red tiles, raise, crates, hot potato). The
  line now reads just the world and "N climbers ready".
- "⏳ Shoves start when the floor moves!" (#71). Early shoves are still blocked, just silently.
- The lava gems hint 25 s after joining (`GemHintAfter`).

**Kept.** The "why you fell" line on every knockout (it already says how to avoid it next time), and direct replies
to something you did (e.g. "Stand on a solid tile to raise it"). The `Tutorial` attribute still marks a player's
first round, for the onboarding funnel.

**Verified.** Solo Studio playtest, every notice logged for 75 s across three rounds: the countdown line showed no
tips, a punch 2.9 s before the floor moved gave no notice, no gem hint, and each knockout gave one tip ("Your tile
crumbled from standing still. Keep moving!"). Studio copies match the repo (client 123216 / 175067866, service
187584 / 622346687); console clean.

## 79. Music that fits the volcano (owner's request)

**Why.** The owner asked for free, licensed, public music that fits the theme. The old track, APM's "Take Me Higher
(c)", was licensed but generic.

**Built.** Two tracks from the music Roblox licenses for experiences (APM Music in the Creator Store, free to use):
- Lobby: "Hawaiian Parkour (b)" (asset 1837792555, 71.8 s), an island tune for the volcano island. (The full
  "Hawaiian Parkour" is only 31 s, so it would loop too often.)
- Rounds: "Natural Disaster", the climax version (9045720005, 76.8 s, APM's description: driving cinematic
  percussion with an accelerating, anxious back end). It starts from the top when a round starts, keeps the old
  build-up (5% faster each phase, louder in the last), and crossfades back to the lobby tune when the round ends.
- Both sit in one SoundGroup, so 🔇 (saved as `MusicOff`) mutes both. The drums are ~1.8x as loud as the island
  tune (PlaybackLoudness 222 vs 123 at the same volume), so they play at 0.14 (0.19 in the last phase) against the
  lobby's 0.22.

**Verified.** Solo Studio playtest: lobby track plays at 0.22 with the round track silent; once the floor moves, the
lobby fades to 0 and the drums play from the top; phase 1 speeds them up (x1.04); after the round, back to the
lobby at 0.22. Mute through the saved setting: group volume 0 with `MusicOff` true, then back to 1. The Studio copy
matches the repo (54127 bytes, hash 321511382); console clean. Not checked by ear: how the tracks sound together.
Listen: https://create.roblox.com/store/asset/1837792555 and https://create.roblox.com/store/asset/9045720005

## 78. 💥 Mega Shoves twist

**Why.** Same research as #77 (variety through modifiers). Shoving is the part kids play with most, so a twist that
makes it bigger is cheap chaos. Unlike Slippery Floor it is server-only, with no new look and no movement code.

**Built.** SkySproutLavaService: a tenth twist, `MegaShove` ("💥 Mega Shoves", weight 2), in the vote pool like the
others. Player shoves are 1.6x as strong (`MegaShove`), and a shoved bot slides 2.6 tiles instead of 1.6. Shields
still block it. **Bug caught before testing:** the client drops any shove over 120 studs/s as a bad value, and Mega
Shoves in the showdown (1.35x) would have sent 143, so those shoves would have silently done nothing. Shove speed is
now capped at `ShoveMax` (110).

**Verified.** 2-player Studio test with the twist forced: Player2 received a shove of 105.6 horizontal (66 x 1.6)
and 18 lift, with "Player1 shoved you off"; Player1's other shove knocked a bot into the lava. The underdog shield
kept blocking shoves in the first runs, so for one run the Studio copy's `UnderdogAfter` was raised and then put
back (the Studio copy matches the repo again: 188255 bytes, hash 906128646). Server console clean; the forced twist
attribute is cleared.

## 77. 🧊 Slippery Floor twist: tried, not shipped (owner's call needed)

**Why.** DevForum minigame feedback asks for variety through modifiers
(https://devforum.roblox.com/t/suggestions-for-elimination-based-minigames/737856), and icy floors are a kid
favourite in obbies. A physics-only twist would need no new look.

**Tried (four approaches, none kept).** Tests used real W key presses in Studio, measuring speed after release.
1. Low tile friction (0.03, weight 100): Roblox's Humanoid ignores floor friction (same stop as normal ground).
2. Blending the root's velocity each Heartbeat: the humanoid resets velocity every physics step (18.5 to 0.3 in
   0.1 s).
3. Smoothing `Humanoid:Move` from `MoveDirection`: reads back its own output, so on ice you couldn't walk at all.
4. Smoothing `Humanoid:Move` from the controls' `MoveAction` (this place runs the Input Action System
   PlayerModule under StarterPlayer) in PreSimulation: the default controls' own Move still wins. A test hook
   connected later did win, so it depends on connection order, which isn't reliable.

Per the 3-attempts rule this stops here for the owner. Untried: switching the default controls off while on ice
(`ControlModule.Enabled`) and moving and jumping from `MoveAction` / `JumpAction` directly. Repo and Studio are back
to the last commit (hashes checked); the attempt is saved outside the repo.

**Verified.** None shipped. Repo and Studio match the previous commit (lava service 187656 / 118038813, client
126349 / 347076022), and the forced twist attribute is cleared.

## 76. Two-player check: the late-join shove grace (no change needed)

**Why.** #71's 2 s `JoinGrace` (nobody can shove a climber who just landed) was only untested because it needs two
real players, and multiplayer tests were off while VALORANT was running. It's off now.

**Checked.** 2-player Studio test. Player2 sat out, then joined 0.5 s after the floor started (a late drop-in).
Player1 stood 3 studs beside Player2, facing them, and punched twice from the same spot. Player2 happened to have
the underdog shield, which made the test clearer: a shove that targets a shielded player prints "bubble shield
blocked your shove".
- Punch 0.47 s after the join: only the swing, no shield message, so Player2 was not a target.
- Punch 2.68 s after the join: "Player2's bubble shield blocked your shove!", so Player2 was a target again.

**Verified.** As above; server console clean. No code changed.

## 75. Headroom under the 200-local limit in the lava client

**Why.** After #74 the lava client counted 162 with the limit at 163, so any new top-level local would stop the
whole lava HUD from compiling again.

**Built.** Three self-contained sections of SkySproutLavaClient now sit in their own `do ... end` scope: climb
parallax (12 locals), the active volcano (6) and the climb meter (12). Their locals are only used inside them, so
nothing else changes; ignoring indentation the diff is six lines. The count is now 146, so there are 17 spare
slots.

**Mistake caught.** My first pick also wrapped the daily reward calendar. The scan I used to find unused locals
missed every `local function` (its pattern needed `=` or `:` after the name), and `showDaily` is called later, so the
playtest console showed "attempt to call a nil value" at the LavaDaily handler. With the scan fixed, the daily
section was left alone. The scan was a scratch script, not a repo check: the guard that matters here is reading the
console after every play start (already in the testing notes).

**Verified.** Studio copy rebuilt by the same transform and matches the repo (126349 bytes, hash 347076022); it
compiles (`loadstring`). Solo playtest over several rounds: the climb meter shows in rounds and moves (lava line
0.84 to 0.58, best mark 1.00 to 0.57), the volcano air model exists, and the console has no errors.
`check_locals.py` and `check_luau.py` pass.

## 74. Lint: the 200-local limit (tools/check_locals.py)

**Why.** The one fix for the mistake in #73: Luau gives a script's main body at most 200 registers, and going over
makes the whole script fail to compile, which `check_luau.py` can't see.

**Built.** `python -I tools/check_locals.py` counts the top-level locals (plus the biggest top-level `do` block)
alive at each point of every script and fails at 163. It undercounts real registers (temporaries, loop variables),
so the limit is calibrated on the lava client: it compiled at 162 and failed at 163. Run it with `check_luau.py`
before every sync.

**Verified.** Passes on the repo (0 files). On a copy of the lava client rebuilt the way it broke in #73 it reports
167 and exits 1. The lava client is at 162, one local from breaking: freeing headroom there is a separate change.

## 73. Forgiving jumps (coyote time and a jump buffer)

**Why.** Floor-is-lava listings and DevForum/itch.io feedback on similar games keep coming back to movement: players
like the idea but say the movement needs work
(https://devforum.roblox.com/t/woah-is-the-floor-disappearing-looking-for-feedback-on-spleef-battles/324273). In
LAVA Floors tiles shatter under you and kids hop tile to tile and up the pillar ledges, so a press a moment too late
or too early just fails. Platformers forgive both; Roblox only forgives ~0.115 s late (until the humanoid notices the
fall) and not at all early.

**Built.** SkySproutLavaClient, client only (your own character's movement is yours anyway):
- Coyote time: a jump pressed in free fall up to `COYOTE` (0.2 s) after the feet left a floor still jumps.
- Jump buffer: a jump pressed up to `BUFFER` (0.12 s) before landing jumps on touchdown (`ChangeState(Jumping)`;
  `Humanoid.Jump` is ignored in the Landed state).
- One jump per landing, so no double jumps; skipped for 0.6 s after a shove or hot potato blast (the shove handler
  stamps `LavaShovedAt` on the humanoid) so shoves still send you flying.

**Mistake caught.** The first version added one top-level `local` and the script went over Luau's 200-local limit
("Out of local registers when trying to allocate TILT"), so the whole lava client failed to compile in Studio. Lint
passed; the Studio console showed it. Fixed by keeping the new code inside its own `task.defer` function and using a
humanoid attribute instead of a new top-level local. Nothing broken was committed. A lint rule for this comes next,
in its own change.

**Verified.** Solo Studio playtest with a test platform 60 studs up removed by a key, real key presses, and the
humanoid's states logged: press 0.13 s after the drop (already Freefall) jumped; press 0.3 s after did not; press
0.09 s before landing jumped on touchdown; press 0.29 s before did not; a second press right after a jump did not
double-jump; with `LavaShovedAt` just set, a press 0.13 s after the drop did not jump. The script compiles
(`loadstring`), repo and Studio match (125669 bytes, hash 395013665), console clean. Not tested on touch or a
controller (both go through JumpRequest).

## 72. Monetization table lists every pass (docs only)

**Why.** Comparing the README with the code: commit 2700f5b added a one-time VIP game pass (`VipPassId`, preferred
over a subscription for a kids' game) and a Flame Trail pass (`TrailPassId`), but the README's monetization table
and "Before publishing" checklist still listed VIP as a subscription only and left out the trail. The owner creates
passes from that checklist, so a missing row means a pass that never goes on sale.

**Built.** The table now shows VIP as a one-time pass or subscription (`VipPassId` / `VipSubscriptionId`) and adds
🔥 Flame Trail (just a look). The checklist names all five passes.

**Verified.** None (docs only). Checked against SkySproutPassService (the trail only adds a Trail between two
attachments, no speed or jump change) and the VIP panel in LavaFloorsUI (it prompts `VipPassId` when set, else the
subscription).

## 71. Fair starts: no shoves before the floor moves

**Why.** Roblox's onboarding guide and DevForum retention threads
(https://create.roblox.com/docs/production/game-design/onboarding,
https://devforum.roblox.com/t/improving-new-user-engagement-on-my-game/2947546) say new players leave when the first
moments feel unfair or confusing. In LAVA Floors anyone could shove during the 3 s get-ready before the floor starts,
so a kid could be out before their round even began, and a late joiner could be shoved the instant they landed.

**Built.** `shove` (SkySproutLavaService) does nothing until the tower's `Start` time and tells the shover once per
round "⏳ Shoves start when the floor moves!". Climbers who landed on the grid under `JoinGrace` (2 s) ago (late join
or coconut rescue) can't be picked as a shove target. Bots and the hot potato are unchanged.

**Verified.** Solo playtest in Studio, driven from the client over ArenaEvent: two punches 2.9 s and 1.7 s before the
start gave one notice and no swing; a punch 0.2 s after the start gave the swing. Repo and Studio match (187656 bytes,
hash 118038813). Console: no errors from the game. Not tested: the 2 s late-join grace needs two real players
(VALORANT was running, so no multiplayer test).

## 70. README brought up to date (docs only)

**Why.** Entries #57–#69 changed the look (font, icons, phone menu, coin counter and ping, plain fruit pickups), but
the README still described emoji labels that are no longer in the game.

**Built.** The server goal, streak and near-miss lines now match the current UI, and a new "Look and feel" section
covers the font, Flibpook icons, phone ☰ menu, compact result card, coin counter and ping, and pickup visuals.

**Verified.** None (docs only). The wording was checked against the client scripts.

## 69. A coin ping with each gain

**Why.** It completes #68: kids' Roblox games pair the count-up and bounce with a sound, so a gain registers even
when you aren't looking at the corner of the screen.

**Built.** A short, quiet ping plays once with each coin gain (not when spending). It's Roblox's own
`rbxasset://sounds/electronicpingshort.wav` (0.7 s), so nothing is uploaded, at volume 0.3 and pitch 1.3. It plays
whether or not Reduce Motion is on, since that setting is about movement. Client only.

**Verified.** Studio solo playtest (VALORANT open, so no extra windows): the sound loaded, and when the +14 payout
arrived (25 → 39) its Played event fired exactly once. The console was clean, and repo and Studio hashes matched (52,907
bytes). The loudness hasn't been heard by a person yet; it's `Volume = 0.3` in LavaFloorsUI if it needs a nudge.

## 68. Juicy coin counter

**Why.** Continuing the owner's "make it pop for kids". Simulator-style Roblox games celebrate every coin gain
(count-up numbers, bouncing icons, floating "+N"), and kids notice it. LAVA Floors' coins panel just swapped the
number.

**Built.** When coins go up (round payout, daily reward, chest, challenge or gift):
- the number on the coins panel counts up over 0.6 s;
- the coin picture bounces (1.35 → 1, Back easing);
- a gold "+N" with the dark outline appears beside the panel, then drifts up and fades over 1 s.

Spending coins, or Roblox's Reduce Motion setting, just sets the number. A newer gain takes over from a count-up
that's still running. Client only.

**Verified.** Studio solo playtest (VALORANT open, so no extra windows), sampling the coins label every frame around a
+14 round payout. The label went 25 → 26 → … → 38 → 39, the coin's UIScale peaked at 1.35, and a "+14" float was
created and had faded to transparent by the end. The console was clean, and repo and Studio hashes matched (52,591 bytes).

## 67. Coin icon on the daily reward card and the Lava Pass

**Why.** These were the last two panels with 💰 emoji. A preview (Media/daily-pass-coin-preview.jpg) got "Yes, both".

**Built.**
- **LavaFloorsUI.** The coin placement from #66 is now a shared `coinBeside(label)` helper, used by shop prices and by
  Lava Pass coin rewards (free and premium tracks). `rewardText` returns just the number for coin rewards. Hat
  rewards are unchanged.
- **Daily card (SkySproutLavaClient).** Each day tile shows "Day N" (or ✅) over a coin-and-amount row. The title reads
  "DAY N REWARD: +X" with the coin placed right after it, and the hint now says "Next time you play: 50 coins."

**Verified.** Studio solo playtest (3D rendering, VALORANT closed):
- On join the daily card read "DAY 1 REWARD: +25", followed by the coin, over seven coin tiles (25 to 300) and the
  "50 coins" hint.
- A real tap on the Pass button opened the Lava Pass, with coin rewards (50, 60, 80, 100, 120, 150…) beside the coin.
  The strawberry hat tier was unchanged.
- The console was clean, and repo and Studio hashes matched for both scripts.

## 66. Coin icon on shop prices, the Raise button and challenge rewards

**Why.** The last 💰 emoji next to the new coins panel. A preview (Media/coin-icon-preview.jpg) of shop price buttons,
the Raise button and a challenge reward, with emoji and with the Flibpook coin, got "Yes, use the coin icon".

**Built.** In LavaFloorsUI:
- **Shop prices.** A `setPrice(button, amount, colour)` helper shows the number with the coin just left of it (placed
  from the text width, re-placed when the text or size changes). `setButton` hides the coin again when a card switches
  to WEAR, ✓ WORN or BRING. Gloves, hats and buddies all use it.
- **Challenge rewards.** They read "+50" with the coin after it.
- **Raise button.** It's now a "⬆️ RAISE" line over a coin and 40 row.
- **Left alone.** The Lava Pass reward labels, the event pill and the Invite label weren't part of the approved preview.

**Verified.** Studio solo playtest (VALORANT open, so no extra windows):
- A real tap on the Gloves button opened the shop. The price buttons showed the coin and 160, 320 and 600, while
  ✓ WORN showed no coin.
- In a round the Raise button showed "⬆️ RAISE" over the coin and 40.
- Studio rendered 3D again this time, and the round line showed the 3D strawberry after the berry count, which closes
  the check left open in #60.
- The console was clean, and repo and Studio hashes matched (50,240 bytes).

## 65. Pre-launch hygiene sweep (no change needed)

**Why.** After 64 iterations of syncing, temporary preview boards, Studio-only test hooks and test attributes, check that
nothing from testing could ship with a publish.

**Checked.**
- **Studio place.** The workspace has only the server-set `LavaTheme` attribute; no `LavaAwayAfter` or `Studio*` test
  attributes are left. StarterGui is empty (no TEMP preview boards). ServerStorage holds only the game's asset
  folders and a plugin's saves (the IconPreview copy of the icon pack is gone). No instance or script source contains
  "TEMP".
- **Repo scripts.** The only `print` calls are the start-up line and two traces, `[friends]` and `[fun]`, which are
  both gated by `Run:IsStudio()`. The one `warn` is the round-crash handler.
- **Sync.** All 48 repo scripts (Server, Client, Shared) match Studio by size and chunk hash. Studio has no scripts that
  aren't in the repo, apart from the TopbarPlus package.

**Result.** Clean; nothing to fix. (VALORANT was open, so all checks were read-only in the Edit datamodel.)

## 64. Result card readable on phones again (after the font change)

**Why.** Checked the #60/#61 changes on a small phone (Device Simulator, iPhone 7, 666 × 374). Everything fit, but
the result card stayed 380 design px wide while the end-of-round area is scaled to about 0.53. In the wider Luckiest Guy
font the lines came out only 14–17 px. Also checked: bots never pick up strawberries (only real climbers are tested
against pickups), so the 2 edge strawberries are always there for kids.

**Built.**
- **Wider on phones.** On compact screens the result card may grow to 560 design px wide (380 elsewhere); the
  end-of-round stack has room for it.
- **Taller rows.** When the card has fewer than four lines, each row gets up to 44 design px (was a fixed 33). That's
  enough to read bigger, but still short enough that one line beats wrapping onto two.

**Verified.** Studio solo playtests (VALORANT open, so no extra windows):

| Screen | Card width | Lines |
|---|---|---|
| iPhone 7, before | 201 px | 14–17 px |
| iPhone 7, wider card only | 298 px | 17 px |
| iPhone 7, wider card + taller rows | 298 px | 23 px each, one line |
| Desktop 1130 × 753 | 344 px | 24 and 30 px, one line each |

The console was clean, and repo and Studio hashes matched. Studio was reset to the default viewport.

## 63. Measure the edge-strawberry gamble (EdgeBerries analytics)

**Why.** #58 and #62 made strawberries a risk: 2 a round on the outer ring that drops away in phase 2. #58 left open
whether kids find that window fair. Playtests by one tester can't answer that, but the live game's analytics can.

**Built.** Each edge strawberry is now marked as such. Climbers count the ones they grab (`r.edgePicked`, kept across a
phase-1 re-drop like the other counters). At the end of each round every climber logs a custom event `EdgeBerries`,
with the value set to the number grabbed and CustomField01 set to how the round ended (Crowned, Survived or
Scorched). In the Creator Dashboard (Analytics → Custom events) the owner can see:
- how often kids go for the edge strawberries;
- whether the ones who do still survive.

If most grabbers end up scorched, the strawberries can move one ring in. If nobody tries, they can be worth more. It's
server-only, so players see nothing new.

**Verified.** Studio solo playtest (VALORANT open, so no extra windows), with a temporary Studio-only print added to the
Studio copy. That print was removed afterwards and the hash rechecked. The event fired once per round with the right
outcome: 0 Scorched, 0 Crowned, 0 Crowned and 0 Scorched in rounds where the strawberry wasn't reached. A driver that
walked onto an edge strawberry while its tile was Still then logged "1 Crowned" (the result card showed 1 berry
banked). The console was clean, and repo and Studio hashes matched. Studio doesn't send analytics, so the dashboard view
itself only fills in once the game is live.

## 62. Edge strawberries: 2 a round (owner's call); twist emoji stay

**Why.** Follow-up to #58. Asked whether to keep 4 edge strawberries or make them scarcer, the owner picked "Make it 2".
In the same check-in, a preview of the vote card and round title without the twist emoji (Media/twist-names-preview.jpg)
got "Keep the emoji", so those stay as they are. A scan of the live UI found everything on screen already in
Luckiest Guy (including the top bar labels), apart from TopbarPlus hover captions and its tiny notice counter.

**Built.** `Berries = 2` (was 4) in SkySproutLavaService CFG. Each one is still 4 coins. README updated.

**Verified.** Studio solo playtest (VALORANT open, so no extra windows): the server counted 3 strawberries in the round,
2 on ring 4 (the edge that drops away) plus the pillar top (ring 0). The console was clean, and repo and Studio hashes
matched.

## 61. Luckiest Guy font with thick outlines ("make it pop for kids")

**Why.** After #60 the owner asked for a different font style, not just a bigger size: "make it pop for kids". A preview
board (Media/font-options.jpg) showed four styles: today's Fredoka One, Luckiest Guy with a thick outline and gold shine,
a beefed-up Fredoka, and Bangers. The owner picked **B: Luckiest Guy**.

**Built.**
- **Font.** `U.Font`, both HUD scripts' `FONT` and SkySproutHUD's `BOLD` are now `Enum.Font.LuckiestGuy` (was
  Fredoka One).
- **Outlines.** `U.text` outlines are fully opaque and thicker: titles 3.5 (was 2.5), body 2.5 (was 1.5).
- **Result card rows.** Rows are a fixed 33 design px, centred, with full-height pictures, so the wide caps stay on one
  line. In tall two-line rows the text had wrapped.
- **Wording.** "First best: N. Beat it next round!" became "First best: N!".

**Verified.** Studio solo playtest at 1130 × 753:
- The round panel, tip card, coins chip, Raise button, vote card and winner banner all render in Luckiest Guy with
  the thick outline.
- The result card shows the crown and "ESCAPED!", then "+60 coins • height 81" (25 px) and "First best: 81!" (29 px),
  each on one line (Media/font-luckiest.jpg).
- Repo and Studio hashes matched, and lint was clean.

Not changed: TopbarPlus labels (they use TopbarPlus's own font) and the older shop and daily panels in
SkySproutClient.

**Privacy.** The winner banner shows the tester's Roblox username, so the name is now blurred in
Media/font-luckiest.jpg, Media/result-card-icons.jpg and Media/phone-result-card.jpg. The last two had been committed
unblurred, so, with the owner's OK, git history was rewritten (filter-branch over the six affected commits, so every
version is the blurred one) and force-pushed. The final files are identical, and the commit hashes from "Result card
readable on phones" onward changed.

## 60. HUD and result card icons, bigger text (icon refresh, part 3)

**Why.** The owner approved the preview (Media/hud-preview.jpg): "Yes, switch". They also asked to "change the font size
too".

**Built.**
- **Coins panel.** The Flibpook coin and crown pictures replace 💰 and 👑. Numbers are 30 px (was 26) and 28 px (was 22).
- **Round info line.** It reads "Phase 1/3 • 4 left • 2", followed by the game's own 3D strawberry (ViewportFrame,
  placed from the text width). The line is 29 px tall (was 24).
- **Result card.** The card is now 236 tall (was 210).
  - The title gets a crown (ESCAPED!) or checkmark (SURVIVED!) image; the emoji came out of all titles.
  - The single body text box became up to four picture rows: coin for coins and height, 3D strawberry for berries,
    trophy for best, lightning for streaks. The rows share 132 px, with text up to 30 px.
  - The chest bar has a gold gem instead of 🎁, which sometimes drew as a broken box.
  - "1 berry" is now singular.
- **Icon module.** `Coin` and `GemYellow` were added to LavaIcons.

**Verified.** Studio solo playtest at 1130 × 753:
- The coins panel showed the coin and crown with the larger numbers.
- The round line read "Phase 1/3 • 4 left • 0" with the strawberry box placed after it (29 × 32 px at x = 698).
- A crowned result card showed the crown, "ESCAPED!", "+58 coins • height 81", "1 berries banked (x2!)" (since fixed to
  singular), "2 rounds in a row!" with lightning, and the gem on the chest bar (Media/result-card-icons.jpg).
- Each line measured 29–30 px.
- Repo and Studio hashes matched, and lint was clean.

Not seen: the 3D strawberry pictures themselves. This Studio session drew no 3D at all, so the arena was blank too,
though ViewportFrames rendered fine in earlier sessions (shop, buddy board).

## 59. Top bar icons: Flibpook images instead of emoji (icon refresh, part 2)

**Why.** The owner called the emoji icons ugly. A side-by-side preview of today's top bar and the free Flibpook pack
(Media/topbar-preview.jpg) got a "Yes, switch".

**Built.**
- **Icon module.** New `Shared/LavaIcons.luau` (ReplicatedStorage.LavaIcons) holds the pack's image IDs and a `Scale`
  of 0.75. TopbarPlus draws images at 0.5 (17 px in a 44 px button), which looked tiny.
- **Swaps.**

| Button | Icon |
|---|---|
| Gloves | shop stall |
| Pass | purple gem |
| VIP | crown |
| Challenges | checkmark |
| Server goal | trophy (and "3/40") |
| Invite | heart (and "+150") |
| Lava Rush | lightning bolt ("Lava Rush" / "Jump in!") |
| Lava Rush, queued | checkmark ("Queued") |
| Music | speaker on / red speaker off |
| ☰ phone menu | gear |

- **Labels.** The labels lost their emoji. The ⚙ dropdown items say "Lava Pass", "VIP", "Invite +150💰" and
  "Music on/off".
- **No match in the pack.** Emotes (😀), 👀 Watch and the event pill keep their emoji.
- **Credit.** The pack is credited in the README.

**Verified.** Studio solo playtest at 1130 × 753:
- Every left/right button showed its Flibpook image at 26 × 26 px.
- Lava Rush cycled lightning "Lava Rush" → checkmark "Queued" → lightning "Jump in!".
- The screenshot is Media/topbar-desktop.jpg.

Device Simulator, iPhone 7:
- No overflow menus.
- A real tap on ⚙ opened the dropdown with gem, crown, heart and speaker next to their names
  (Media/topbar-phone.jpg).

The console was clean, and repo and Studio hashes matched for LavaIcons, LavaFloorsUI and SkySproutLavaClient. Studio was
reset to the default viewport, and the temporary copy of the pack (ServerStorage.IconPreview) was removed, since the
game uses the image IDs directly. VALORANT was open, so no multiplayer windows were opened.

## 58. Strawberries become a risk: fewer, on the edge, worth more (and the word pills are gone)

**Why.** Owner feedback on #57: the word pills over the pickups were ugly. Asked what should go there instead, the owner
said to make the fruit scarce and expand the area so there's a risk/reward. Before this change, 6 strawberries sat on
the starting 5 × 5 tiles every round, worth 2 coins each, so picking them up was a free side errand.

**Built.**
- **Pills removed.** `pickupTag()` and the boost `Tag` field are gone, so pickups are just the 3D fruit, glow and
  light beam again (no emoji either).
- **Strawberries.** There are now `Berries = 4` a round, placed only on tiles outside `StartRings`. Those are the outer
  ring of the 9 × 9 grid, which grows in during phase 1 and drops away in phase 2. The pillar-top strawberry stays.
  They're placed on distinct tiles. A grid that never grows falls back to the inner tiles.
- **Value.** `EmberCoins` goes from 2 to 4 per banked strawberry. The maximum is about the same as before (16 vs 12, doubled
  when crowned), but it now has to be earned.
- **Drops.** Supply drops come every 20 s instead of 14, about two a round instead of three.

**Verified.** Studio solo playtest (VALORANT open, so no extra windows), with the survival driver kept on the inner
tiles. The server log, reading each strawberry's tile through LavaGrid, showed 4 strawberries on rings 3 and 4 plus
the pillar top:
- Hidden at the start.
- Growing in at about 6 s.
- Still from 8 s to 18 s.
- Warning at 18 s.
- Left (dropped away) at 20 s.

That gives roughly a 10–12 s window at the edge. There were 0 PickupTag billboards left, the console was clean, and
repo and Studio hashes matched. Not yet tested: grabbing an edge strawberry by hand, and whether kids find the window
fair. That's a quick thing to watch in a real playtest.

## 57. Clean word tags over the shield and fruit pickups (icon refresh, part 1)

**Why.** Owner feedback (2026-11-22): the shield and fruit look ugly, and so do the icons in general. The shield orbs and
supply drops are already the game's own 3D fruit (a blueberry inside the shield bubble; banana, pineapple, blueberry,
coconut or watermelon in a drop). What looked bad was the emoji floating over them (🛡️ ⚡ 🦘 🪂 🔥): small, flat and
muddy against the arena's neon. A comparison board (Media/icon-options.jpg) put today's emoji next to a free icon pack
(Flibpook, by Digital Gaming Studio: free to use, credit appreciated, no reselling) and the game's 3D fruit. The owner
said to go ahead with it.

**Built.** `pickupTag()` in SkySproutLavaService: a bold Fredoka word in a rounded pill of the pickup's colour, with a white
rim and a dark text outline. The shield orb says SHIELD and drops say SPEED, JUMP, SHIELD, RESCUE or BERRIES (new `Tag`
field on each boost). The fruit underneath stays the picture. The emoji billboards are gone.

Also during this step: a second free pack from the Creator Store ("Simulator Icon Pack") hid a script inside a
UIStroke (`PoseTexture` / `TextureConfiguration`), a common Toolbox backdoor pattern. It was only ever inserted
sandboxed into ServerStorage, where scripts don't run. It was deleted at once and nothing of it is left in the place.

**Verified.** Studio solo playtest (VALORANT open, so no extra windows): during a Shield Party round the server found
the PickupTag billboards (SHIELD on orbs, JUMP on a drop). The screenshot (Media/pickup-tags.jpg) shows crisp blue
SHIELD pills over the 3D blueberries. The console was clean, and repo and Studio hashes matched.

**Next.** Part 2 is the top bar (Flibpook images: shop, crown, checkmark, heart, sound on/off, gear). Part 3 is the
HUD, result card and floating texts.

## 56. Result card readable on phones

**Why.** #50 left one check open: a four-line result card (height, berries, best, streak) shrinks its TextScaled text.
DevForum guidance warns that UI that scales down with the screen can get unreadably small on phones ("Specific details
about UI scaling best practices"; "All about text best practices"). Measured in Device Simulator on an iPhone 7
(666 × 374), where the card is scaled to about 0.53 (201 × 111 px): the four body lines came out at about **10 px** each.
The card also said "embers banked", while the HUD and the floor show 🍓 strawberries.

**Built.**
- The title goes from 60 to 48 design px and the body grows from 80 to 100, so the body gets 25% more height. The chest
  bar stays where it was.
- When a streak line shows and there's no new best, the plain "Your best: N" line is dropped. The 🏅 marker on the climb
  meter already shows your best. Most cards now have at most three lines.
- "N embers banked" now reads "🍓 N berries banked", and "Your streak: N in a row. Start a new one!" is now the shorter
  "🔥 Streak ended at N. Go again!".

**Verified.** Device Simulator on iPhone 7, solo play with the survival driver (VALORANT was open, so no multiplayer
windows), reading each card's live TextBounds:

| Card | Before | After |
|---|---|---|
| 2 lines ("SO CLOSE", first best) | — | 25.5 px/line |
| 3 lines (crowned, berries, best) | ≈12 | 17 px/line |
| 4 lines (crowned, berries, new best, streak) | 10 | 13 px/line |

The screenshot (Media/phone-result-card.jpg) shows all four lines legible. The console was clean, repo and Studio
hashes matched, and Studio was reset to the default viewport. The 4-line worst case is still small: a phone-only layout
for the end-of-round cards (bigger card, less scaling) is the next step if it's worth it.

## 55. Phones: a ☰ menu instead of two overflow menus

**Why.** The follow-up to #54. Device Simulator on an iPhone 7 (666 × 374) showed both halves of the top bar folded
into TopbarPlus overflow menus: Gloves, Pass, VIP, Challenges and the server goal on the left, and Music, Emotes,
Invite and 👀 Watch on the right. Kids on hand-me-down phones had to hunt through two "…" menus for the Lava Rush and
Watch buttons. Roblox's own buttons take the first 216 px, which leaves room for about 8 of our icons, but up to 10 can
show at once.

**Built.** Below 900 px wide, a grey ☰ button joins the left of the bar with a TopbarPlus dropdown holding the extras:
🎟️ Lava Pass, ⭐ VIP, the event pill (only during an event), 👥 Invite +150💰 and 🎵 Music on/off. The dropdown has room,
so its items get full words. Gloves, Challenges, the server goal, Lava Rush, 👀 Watch and Emotes stay on the bar.
Wider screens are unchanged.

**Verified.** Studio Device Simulator, solo play only (VALORANT was open on the main screen, so no multiplayer test
windows were opened):
- **iPhone 7:** 370 samples over 100 s and several rounds, with no overflow menu on either side. The busiest moment
  (🔥 Go!, 👀 and 😀 on the right) left an 11 px gap.
- **Dropdown:** a real tap on ☰ opened it with "🎟️ Lava Pass, ⭐ VIP, 👥 Invite +150💰, 🎵 Music on"
  (Media/phone-more-menu.jpg). A real tap on Music inside it paused the music, saved `MusicOff=true` and changed the
  label to "🔇 Music off".
- **Fire HD 10 (959 × 599), no menu:** 369 samples with no overflow, and at least 140 px spare.
- **Wrap-up:** consoles clean, repo and Studio hashes matched, and Studio was reset to the default viewport.
- **Not tested:** the event pill inside the dropdown (no event was running), and portrait (the game is
  landscape-only).

## 54. Top bar fits on mid-size screens (no more overflow menus)

**Why.** Iteration 53 showed that at 1130 px wide, the right-hand top bar folded into TopbarPlus's overflow menu
whenever Lava Rush was showing in the lobby. That hid the main "🔥 Jump in!" button behind an extra tap, and the
👀 Watch button from #52 made it worse. In the multiplayer test window (774 px), both sides overflowed. DevForum
feedback on the Roblox top bar keeps coming back to how little room there is, and to managing that room being the
developer's job ("New In-Game Topbar", "The new CoreGui is a downgrade").

**Built.** A `UI.tight(full, short)` helper in LavaUI that switches to the short label below 1300 px. Gloves, Pass, VIP,
Challenges, Emotes, Invite and the seasonal event pill use it, so the play buttons (Lava Rush, 👀 Watch) keep their words.
`NARROW_WIDTH` (where even those go short) went from 900 to 960, because the worst-case bar needs about 955 px. On
narrow screens, Invite shows just 👥 instead of "👥 +150".

**Verified.** Studio solo playtest at 1130 × 753, sampling the top bar every 0.25 s for 2 minutes over several rounds.
The left group ended at 515 px (578 after the first pass, 706 before). The worst-case right group (👥 +150, 😀, 🎵,
"🔥 Jump in!" or "🔥 Lava Rush", and 👀 Watch / 🚶 Back) was 373 px, and neither overflow menu showed up once. The
console was clean, and repo and Studio hashes matched. Not tested: below 960 px. At 774 px, measured widths of 46 px
per short icon and 8 px gaps put the whole bar at about 790 px with Watch showing, so a 774 px window would still fold one
icon away, while phones in landscape (about 800 to 930 px) should fit. A Device Simulator pass is the next check. I
didn't run a second multiplayer test because the user is gaming on the main screen (see tools/move-studio-test-windows.ps1).

## 53. 🔇 Music stays off when you rejoin

**Why.** Roblox players complain when audio choices don't stick between joins: DevForum threads report output-device
settings resetting on every rejoin ("Roblox changes Audio Inputs/Outputs when rejoining") and argue that a mute should
never switch itself back on ("Mute should never deactivate automatically"). I found no thread about this exact case. In
LAVA Floors, the 🎵 button forgot your choice every time, so a kid (or a parent next to them) who muted the music had to
do it again every visit. Researched "what kids praise" again too: the players-left counter, final showdown and music
build-up the Hex-A-Gone write-ups praise are already in the game.

**Built.** The 🎵 / 🔇 button now sends `LavaMusic` (a boolean) to the server, which saves `MusicOff` in the profile
(cleaned: only a real `true` counts) and mirrors it in the `MusicOff` player attribute at join. The client applies the
saved choice as soon as the attribute arrives, and the icon label follows.

**Verified.** Rules: `new()` gives false; `clean` keeps `true` but drops "yes" and missing values. Studio solo
playtest: at join, `MusicOff` was false and the music played. A real tap on 🎵 paused the music, showed 🔇 and the
server echoed `MusicOff=true`. Setting the attribute from the server (what a rejoin with a saved choice does) turned the
music on with false and off with true. The console was clean. Repo and Studio hashes matched for all three scripts. Not
testable in Studio: an actual save and rejoin (Studio doesn't reach DataStores here).

**Noticed.** At 1130 px wide, the right-hand top bar folds into an overflow menu whenever the Lava Rush button is
shown in the lobby (Lava Rush, Music, Emotes and Invite are ~385 px). This happened before #52 too. The 👀 Watch button
adds to it on mid-size screens. It's worth a pass: shorter labels at this width, or a smaller Invite label.

## 52. 👀 Watch the round from the lobby

**Why.** DevForum threads on round-based games keep coming back to the wait in the lobby. Players with nothing to do
while a round runs leave, eliminated players stuck walking around a small lobby get bored, and one asks directly for
lobby players to be able to see the round ("How can I make this round-based game less boring?"; "Feedback on my first
round-based game"; "How can I keep players in my game for longer?"). In LAVA Floors, spectating only started right after
a knockout or when joining a friend. Anyone who moved (which hands the camera back), sat out, or joined mid-round alone
had no way to watch.

**Built.** A blue 👀 Watch top bar button (just 👀 on phones) that is shown only while a round is on and you're in the
lobby on floor 1. Tapping it starts the existing overhead spectate (◀ ▶ follow, 🍓 gift, controller L1/R1/X). The button
then reads 🚶 Back, and tapping again or any move key returns your camera. It hides when the round ends. Client only:
no server changes.

**Verified.** Studio 2-player test: Player1 climbing with the survival driver, Player2 opted out in the lobby. The icon
showed during the round. Synthetic clicks don't reach TopbarPlus icons inside the overflow menu in the small test
window: the right-hand icons all overflow at 774 px wide, which isn't new. So for the test only, I bound the same
handler to an attribute in Studio's copy, removed it afterwards and re-checked the hash. First tap: Scriptable camera
80 studs up with "👀 Spectating from above", and the icon became 🚶. Second tap: Custom camera, label gone, 👀 again.
Third tap: watching again. At the round's end the icon hid and the spectate label went away, while the existing winner
cam was still running. The server and client consoles were clean. Repo and Studio hashes matched. Not tested: a real
tap at desktop width.

## 51. 🐾 Fruit buddies (pets bought with earned coins)

**Why.** Guides to Epic Minigames, one of Roblox's best-known party games, list collecting pets, titles and effects
with coins won in rounds among its main draws (the game's own page; VideoGamer; Sportskeeda's Epic Minigames guide).
LAVA Floors had gloves, hats and titles, but no pets.

**Built.** Five fruit buddies in the shop (Strawberry 600, Blueberry 1000, Pineapple 1500, Watermelon 2200, Coconut
3000 coins). They are made from the game's existing fruit models plus two googly eyes, so there's no new art. The
buddy floats by your right shoulder on a Weld to the root and scales with the character. Each client bobs and sways it
gently, and Reduce Motion keeps it still. It is cosmetic only: no collision, touch or queries, and no gameplay effect.
Buying and equipping follow the hat pattern: a `Pet` action in SkySproutArenaService, `Rules.pet` (tap again to send it
to rest), `Pet`/`OwnedPets` in the profile (cleaned), `PetStyle`/`OwnsPet*` attributes, and a `Pet_*` economy sink
event. There is no Robux path.

**Verified.** Studio solo playtest. The owner-only coin grant doesn't work for the test account, so I temporarily set
the Strawberry price to 20 in Studio, then restored it and rechecked the hash. Asking for the 3000-coin Coconut with 25
coins was refused ("3000 coins needed."). Buying Strawberry took 20 coins, set `PetStyle` and `OwnsPetStrawberry`, and
put a 14-part buddy 1.24 studs to the side of the root, bobbing (height 0.86 → 0.99). The shop cards read
"✓ WITH YOU", "💰 1000" and so on. Tapping again took it off. Tapping once more brought it back without charging again,
and it was still there after a respawn. A screenshot (Media/fruit-buddy.jpg) shows the strawberry with googly eyes
beside the player. The console was clean. Repo and Studio hashes matched for all five scripts.

## 50. 🔥 Survival streak on the result card

**Why.** Write-ups of Roblox's floor-is-lava games say that you're back in the lobby within seconds, so you can play
20 or 30 rounds in one sitting. They credit survival counters, leaderboards and "see who made it the farthest" with
the replay value (earnaldo.com, The Floor Is Lava vs Natural Disaster Survival, 2026; Sportskeeda beginner's guide).
LAVA Floors tracks your best height and crowns, but nothing rewards stringing good rounds together.

**Built.** The server counts rounds you survived or escaped in a row (`L.Streak`, this visit only) and sends `Streak` and
`StreakWas` with `LavaResult`. From 2 in a row, the result card adds "🔥 N rounds in a row!". When a streak of 2+
ends, it says "Your streak: N in a row. Start a new one!", an encouraging line rather than a loss. It's just for show:
no coins and nothing saved, so it adds no pressure to keep playing.

**Verified.** Studio solo playtest with the survival driver: round 1 crowned (streak 1, no line), round 2 crowned
("🔥 2 rounds in a row!"), then the driver stopped, and round 3 scorched ("Your streak: 2 in a row. Start a new one!").
I read the card text from the live ResultCard. The console was clean apart from Studio's usual DataStore notice. Repo
and Studio hashes matched for both scripts. Not checked by eye: a card with four lines (height, embers, best, streak) shrinks its
TextScaled text a little.

## 49. Music that builds with the round

**Why.** Fans single out how Fall Guys' final-round music shifts into a more intense section as the pressure mounts
(TV Tropes, Fall Guys YMMV page), and reviewers point to the "delicious tension" of the finals (PC Gamer review). A
Kotaku piece says the peppy music is what keeps the writer coming back. LAVA Floors played one track at the same pace
in the lobby and in every phase.

**Built.** In LavaFloorsUI, a small loop reads the round phase from the tower (`LavaGrid.Phase`) every half second.
The music eases (1.5 s tween) to 5% faster per lava phase (1.00, 1.05, 1.10) and from volume 0.22 to 0.30 in the
final phase. It eases back to normal when the round is over. Because the tower stays up after an early ending
(everyone out, or a winner before the last phase), it also listens to `LavaState` and treats any phase other than
"Round" as over. No new sounds or assets. The 🎵 mute button still pauses it.

**Verified.** Studio solo playtest over three rounds, sampling the music every 0.25 s with the survival driver on.
Rounds 1 and 2 ended early in phase 1: the music went 1.00 → 1.05 and then eased back to 1.00 / 0.22 within a
second of the round ending. In round 3 the player was crowned: the music went 1.00 → 1.05 → 1.10, with volume rising
to 0.30 in the final phase, and eased back to 1.00 / 0.22 after the crown. The console was clean apart from Studio's
usual DataStore notice. Repo and Studio script hashes matched (43,022 bytes).

## 48. Pick your victory emote

**Why.** In party games, players love choosing how they celebrate a win (Fall Guys celebrations, Stumble Guys
emotes), and it costs nothing to make that choice free. LAVA Floors always played the same Cheer when you were crowned.

**Built.** A gold 🏆 "When I win: 🙌 Cheer" button at the bottom of the 😀 Emotes panel. Each tap moves to the next of
the six free emotes and plays a quick preview. The server checks the name against `CFG.WinEmotes`, saves it as
`WinEmote` in the profile (cleaned in SkySproutRules) and mirrors it in the `WinEmote` player attribute. When you're
crowned, your pick plays (looped dances keep going until you move). The panel is now named `EmotePanel`.

**Verified.** Studio solo playtest: the attribute started at Cheer; three instance-path taps on the button cycled it
to Dance (Laugh → Point → Dance) and the label followed. The survival driver kept the player alive until crowned (22 s),
and the playing Action track was the looped Dance (507771019). The server ignored "Hacker" and a number, then took
"Wave". The console was clean, apart from Studio's usual DataStore notice. Repo and Studio script hashes matched.

## 47. Smoke test: every twist for a full round (no change needed)

**Why.** Before launch, every round twist should run cleanly at least once with the current code. Several only get
exercised when they come up at random, and the code around them has changed many times since they were written
(shove feel, gifts, gems, titles, daily card, fun check).

**Checked.** One solo Studio session, with the survival driver keeping the player alive through every phase. The
server forced each twist for the next round with `StudioForceMutator`, then waited for that round to start and end:

| Twist | Round length |
|---|---|
| Low Gravity | 36 s |
| Turbo Spin | 34 s |
| Hole Party | 36 s |
| Speed Rush | 26 s |
| Shield Party | 23 s |
| Drop Party | 35 s |
| Hot Potato | 19 s |
| Duos | 20 s |
| Big Heads | 20 s |
| Classic | 26 s |

Every round started and ended. The console showed no errors across all ten, only analytics lines and the expected
Studio DataStore notice. A follow-up round confirmed the forcing itself: the round was announced as
"🌅 Sunset · Twist: 🛡️ Shield Party!". No code changed, and the forced-twist attribute was cleared.

## 46. 🍭 Candy Crater, a bright daytime world

**Why.** Editorial lists name variety as the main draw of party games (entry 31's sources), and entry 44's
"Having fun?" check now records which rounds kids enjoy. All four world themes were fiery or night-time, and kids'
favourite worlds lean bright and colourful.

**Change.** A fifth theme in LavaThemes (weight 2):
- mint tiles (hue 0.44) over lava shifted to strawberry pink (`Hue` 0.92);
- pinkish crater rock and a sunny midday sky (`Sky` "Day", clock 13.5) with a soft pink haze.

It's data only, picked like the other themes. Mint keeps the red warning tiles easy to tell apart. The first try used
hue 0.52, which read as ice, so it moved to mint.

**Verified.** Studio play test with `StudioForceTheme = "Candy"`:
- The theme was "Candy" and the clock 13.5.
- Screenshots from a climber's view and overhead mid-round (saved as `Media/candy-crater.jpg`): the gaps and lava
  glow pink, worn tiles darken visibly, and strawberries stand out.
- The console was clean. Studio matches the repo by chunk hash; the forced theme was cleared, and the place was
  saved as version 81.

## 45. Daily reward: a gentle streak and a calendar you can see

**Why.** Roblox's discovery now weights day-1 retention
([Roblox newsroom](https://about.roblox.com/newsroom/2026/06/optimizing-discovery-great-games-reach-millions-players-roblox)).
LAVA Floors already paid a daily login reward climbing 25 → 300 over 7 days, but kids only saw a one-line notice, so
the ladder was invisible. Missing a single day also reset it to Day 1, which punishes kids whose parents limit screen
time and goes against the README's "no fake urgency" rule.

**Change.**
- Gentle streak (SkySproutShopService): the ladder counts days you've collected, up to the top reward. Missing a day
  only pauses it.
- When the coins are granted, the server sends `LavaDaily`. The client shows a 7-day calendar card: collected days
  ✅, today in gold, and the next reward with "Missing a day won't reset it!". Tap or 7 s closes it.
- The card never covers the floor. It waits until you've been out of a round for 3 s and the result card has closed.
  If a round starts while it's showing, it goes back in the queue, up to 3 times.

**Debugging the re-show.** The first three attempts all seemed to "fail to re-show" after a round cut the card short.
Temporary trace attributes showed why: the re-show did fire, but into the 2-second lobby gap of a phase-1 knockout
drop-back, and was cut short again. The fix was about when to show it (3 s settled), plus 3 re-shows instead of 1. A
second fix: the card tracks whether it's on screen itself instead of trusting `Visible`. The traces were removed
before committing.

**Verified.** Solo Studio play tests:
- Day 1 card screenshot.
- A Day 3 card sent mid-round waited, then showed 1 s after the result card closed.
- A 60 s timeline in a fresh session: the card skipped the 2 s drop-back gap, showed at 17.9 s, went back in the
  queue when a round started at 24.2 s, and showed again at 45.2 s. It was on screen for 11.5 s in total, with 0
  frames during a round.
- The console was clean. Studio matches the repo by chunk hash for the shop service and client; place saved as
  version 80.
- Not testable in Studio: a real multi-day streak (DataStores are off, so every session is Day 1).

## 44. "Having fun?" check

**Why.** Every iteration so far has been steered by outside research. Once the game is live, players' own answers
should steer it. Roblox analytics custom events are server-only and record nothing in Studio
(Studio's `rbx-instrument-analytics` skill); custom fields are preferred over new event names, which are capped at 100.

**Change.**
- Once a session, on the player's 3rd finished round (`FunAskAfter`), the result message carries `AskFun`.
- The client shows a small "Having fun? 😀 😐 😞" strip under the result card. There's no typing, and the card
  stays up 8 s.
- The server accepts one answer (1–3), only after it asked, and logs `FunRating` with CustomField01 "Twist - <id>",
  so the dashboard can show which twists kids enjoy. The player gets a 💛 thank-you notice.

**Verified.** Solo Studio play tests:
- The strip appeared on the 3rd result (screenshot), under the result card with no overlap.
- In a fresh session, a real click on 😀 turned the strip into "💛 Thanks!". The server printed "[fun] … rated 3 after
  a Duos round", and a `LogCustomEvent` fired just before it.
- A second answer sent straight to the server was ignored (no new line).
- Studio matches the repo by chunk hash; place saved as version 74.
- The first test's click arrived after the 8 s card had closed; the test was redone with an immediate click. Real
  dashboard data only appears once the game is published.

## 43. 📸 Share your escape

**Research.** Roblox's Captures API lets a game take a screenshot and open the device's share sheet with it, plus an
invite link to the experience where supported. Players who aren't eligible get a download prompt instead
([CaptureService docs](https://create.roblox.com/docs/en-us/reference/engine/classes/CaptureService),
[DevForum announcement](https://devforum.roblox.com/t/captures-apis-are-now-available/2838188)). Sharing a win with
friends is the natural growth moment for a party game, and it fits next to the existing 👥 Invite.

**Change.**
- After you escape or survive, a "📸 Share" pill sits on the result card's top-right corner.
- Tapping it hides the pill, takes a screenshot (`CaptureScreenshot`), restores the pill, and opens
  `PromptShareCapture` with the capture and launch data "lava-escape". It tries the newer `Content` form first, then
  the plain id, all inside `pcall`.
- The pill is hidden when `PolicyService` says content sharing isn't allowed for that player.
- With the pill showing, the result card stays up 8 s instead of 5.5 s. The first test showed the card was gone
  before there was time to tap.
- The result card is now named "ResultCard" so tests can reach it by path.

**Verified.** Solo Studio play test, with the survival driver until the bots fell:
- The result card read "👑 ESCAPED!" with the Share pill.
- A real click hid the pill and brought it back 0.42 s later, when the capture callback ran.
- The console showed no errors. Studio matches the repo by chunk hash; place saved as version 73.
- Not testable in Studio: the share sheet itself, and the invite link it carries. Both need a real device.

## 42. Joined mid-round? Watch your friend climb

**Why.** Entry 34's research named waiting after joining mid-round as a top onboarding problem
([DevForum](https://devforum.roblox.com/t/allow-developers-to-mark-servers-as-unpreferred-for-new-player-joins/3680997)).
Entry 41 told a newcomer whose friend was climbing that they'd be in the next round together, but left them standing
in the lobby. The spectate camera only started when a player's mode changed to Lobby during a round, which a fresh
joiner never triggers.

**Change.**
- In that case the server names the friend in a player attribute, `LavaWatchFriend`.
- The client starts spectating and follows the friend. The bar reads "👀 Watching your friend …", and the 🍓 gift is
  ready to send.
- It retries for a few seconds if the round state hasn't arrived yet, and does nothing if the friend has already
  left the round.
- A move key hands the camera back, as for any spectator, so nobody exploring the lobby is trapped.

**Verified.** 2-player Studio test with `StudioFakeFriends`:
- Player1 was kept climbing with the driver, and Player2 was opted out in the lobby. The server set
  `LavaWatchFriend` on Player2 mid-round (the same call the join path makes).
- Player2's bar showed "👀 Watching your friend Player1" with the gift button, and the camera was scripted.
- At round end the winner cam swung to "THEY ESCAPED!" (screenshot).
- The client console was clean. Studio matches the repo by chunk hash for the service and client; the attribute was
  cleared, and the place was saved as version 72.
- Not seen: the real join path setting the attribute (both test players join while the lobby is open).

## 41. Spawn with friends

**Research.** Roblox ships an official "Spawn With Friends" module because, in its docs' words, it can be challenging
to locate friends in-game ([Creator docs](https://create.roblox.com/docs/resources/modules/spawn-with-friends)).
A [DevForum thread](https://devforum.roblox.com/t/allow-developers-to-modify-the-default-spawn-system/2017252/3) lists
spawning near friends as a top reason games customise spawning. The module's docs warn that it can drop players into
restricted areas; here that would be the round arena. LAVA Floors already noticed friends (+25% coins) but spawned
everyone on the lobby pad.

**Change.**
- When someone joins and a friend is in the lobby, they're placed `FriendSpawnGap` (5) studs beside the friend,
  facing them. Both get a 👋 notice.
- The four candidate spots are raycast, and only ground that isn't lava counts. Non-solid parts such as the spawn pad
  are ignored.
- If the friend is climbing, the newcomer stays put and gets "👀 Your friend … is climbing right now. You'll be in
  the next round together!"
- Players who arrive while the server is still starting go through the same step: everyone after the first joiner
  goes to an earlier friend.
- Studio only: `StudioFakeFriends` makes test players friends, and `[friends]` lines in the server console show
  which way it went.

**What went wrong on the way.**
- A line starting with `(p.Character :: Model):PivotTo(...)` right after another statement is ambiguous Luau. It
  stopped the whole lava service from loading in the first test. Fixed with a local; a checker for this follows in
  the next commit.
- The ground check required `CanCollide`, but the friend stood on the spawn pad, which has `CanCollide` off, so every
  spot was rejected. The `[friends]` trace showed it (four hits on "SpawnLocation"). Fixed with
  `RespectCanCollide`.

**Verified.** 2-player Studio test with `StudioFakeFriends`: the server printed "Player2 placed 5.0 studs from
Player1", with no errors. Studio matches the repo by chunk hash; the attribute was cleared, and the place was saved
as version 70. Not seen in a test: the "friend is climbing" notice (both players joined while the lobby was open).

## 40. Shove and hot potato knockout reasons checked (no change needed)

**Why.** Entry 24 added a one-line "why you fell" reason to every knockout. The 💥 shove and 💣 hot potato reasons were
never seen in a test: lining up two players took more than three attempts, so it was stopped and logged as
untested. Entry 39's method (pin one player beside the other every frame, then shove) made the test possible.

**Checked.** 2-player Studio test. Both players ran the survival driver so they didn't lose tiles to the camp
crumble, and each was set to drop into the lava 0.3 s after a shove or blast:
- Classic round: Player1 pinned beside Player2 and shoved. Player2 got "💥 Player1 shoved you!", then after the fall
  "💥 Player1 shoved you off. Keep away from the edges!"
- Hot Potato round (forced on the server): Player2 got the bomb, then "💥 BOOM! The bomb went off in your hands!",
  then after the fall "💣 The hot potato blew up on you. Pass it on quickly!"
- An earlier try where the players stood still showed "🪨 Your tile crumbled from standing still", which is the
  right reason for that case.

No code changed. The forced-twist attribute was cleared afterwards.

## 39. Shoves you can feel (and see from the sidelines)

**Research.** Game-feel guides list knockback, a short camera nudge (about 0.1–0.3 s), sound and particles at the
impact point as the layers that make a hit satisfying, and warn that juice must not hide cause and effect
([itch.io juice guide](https://itch.io/blog/1059831/making-a-game-feel-juicy-with-simple-effects),
[Mega Cat juice guide](https://megacatstudios.com/blogs/game-development/mega-cat-developer-juice-guide-v1-0-08-23-17),
[Game Developer](https://gamedeveloper.com/design/6-mistakes-that-ll-drain-the-juice-out-of-your-game)). Shoving is
LAVA Floors' core interaction. Before this change, only the shover heard a sound and saw a small burst, and the
victim got a red tint. Bystanders and spectators saw someone fly off with no visible cause.

**Change.**
- Shover: a 💥 floats over the target, plus a short camera kick (0.15 strength, 0.2 s).
- Victim: a firmer camera jolt (0.4, 0.35 s), and a 0.15 s buzz on a controller.
- Everyone else within 160 studs gets a lighter puff and a 💥 where the shove landed. The server's new
  `shoveImpact` sends it for player and bot shoves.
- `rumble()` gained a length parameter, and a weaker shake no longer cuts a stronger eruption shake short.
- Reduce Motion still turns all camera shake off.

**Verified.** 2-player Studio test with listeners on both clients:
- Player1 shoving Player2 sent Hit to Player1 and the knockback to Player2, and no ShoveSeen to the victim.
- Player1 shoving Bot_Ash sent Hit to Player1 and ShoveSeen to Player2.
- Both client consoles were empty.
- Studio matches the repo by chunk hash for the service and client; place saved as version 64.
- Not verified: the look of the shake and buzz (screen capture can't time a shove) and a real controller buzz.

## 38. Pick your title, and three new ones to earn

**Research.** Parent guides say kids love customising how they look and that playing Roblox is mostly about friends
([Qustodio](https://www.qustodio.com/blog/is-roblox-safe-for-kids-app-safety-guide-for-parents/),
[Screenwise](https://screenwiseapp.com/guides/understanding-roblox-s-social-features)). LAVA Floors' overhead title
was picked automatically from total crowns, so a new player had no title and no say. Other achievements (gems,
chests, kindness) weren't shown anywhere.

**Change.**
- Three new titles:
  - 🔶 Gem Hunter: every lava gem found.
  - 🎁 Chest Cracker: 5 Lava Chests opened.
  - 🍓 Kind Climber: 5 strawberry gifts sent (a new saved counter, `GiftsSent`).
- Each one announces itself when unlocked.
- A 🏷️ button in the Challenges panel footer cycles through Auto (the best crown title, as before), every unlocked
  title, and No title.
- The server only accepts unlocked picks, saves the choice as `Title`, and shows it over your head.
- The panel, its body and the button got unique names so tests can click them by path.

**Verified.** In a Studio play test:
- Before any unlocks the list was just Auto and No title, and picking Gem Hunter while locked was refused.
- Collecting the five gems added 🔶 Gem Hunter.
- Three real clicks on the 🏷️ button went Gem Hunter (shown over the head) → No title (tag removed) → Auto. A
  fourth click went back to Gem Hunter.
- `SkySproutRules.clean` kept `Title` and `GiftsSent`, dropped a 40-character title and a non-number, and gave an
  old profile the defaults.
- The console was clean. Repo and Studio match by chunk hash for the service, rules and UI; place saved as version
  63.
- Not tested in play: the Chest Cracker and Kind Climber unlocks (they need 5 chests or 5 gifts).

## 37. Controller shortcuts for spectators and the twist vote

**Research.** Roblox runs on Xbox and PlayStation. On a gamepad, on-screen buttons need Roblox's UI selection mode
(press Select, then steer a highlight), which DevForum developers call hard to get right and players rarely find
([DevForum](https://devforum.roblox.com/t/is-it-me-or-is-making-guis-gamepad-compatible-incredibly-frustrating/117420)).
The recommended fix is to bind actions directly or set `GuiService.SelectedObject` for the player
([new selection APIs](https://devforum.roblox.com/t/new-gamepad-ui-selection-apis/1791278),
[setting the starting selection](https://devforum.roblox.com/t/is-there-a-way-to-set-the-selected-button-for-controller-navigation/89328)).
LAVA Floors mapped shove (R2) and raise (Y), but everything a spectator does needed selection mode.

**Change.**
- While spectating, L1 / R1 switch who you follow, and X sends the 🍓 gift when it's available. The binding exists
  only while spectating.
- With a gamepad in use, small L1 / R1 labels appear under the ◀ ▶ arrows and the gift reads "🍓 Gift (X)". They
  switch with the last input type. The gift button grew to 104 px to fit.
- When the twist vote opens for a controller player, the selection starts on the first option. It's cleared when
  the vote closes, so the controller goes back to the character.

**Verified.** 2-player Studio test; Player1 was kept alive with the survival driver:
- The action was not bound while Player2 was climbing and was bound once they were spectating. A keyboard player
  saw no pad hints and the plain "🍓 Gift" label.
- Real R1 presses (sent with Studio's input tool) changed the bar to "👀 Watching Player1" and showed the gift
  button.
- A real X press ran the gift send: the button hid. The round ended at that moment, so no gift bubble came back. The
  server side of gifting was verified with clicks in entry 33.
- The consoles were clean. Studio matches the repo by chunk hash; place saved as version 61.
- Not testable here: Studio's input tool reports gamepad buttons as keyboard input, so the pad hints and the vote
  auto-select (both need a real gamepad as the last input type) still need a real controller.

## 36. Honour Roblox's Text Size setting

**Research.** Roblox's [accessibility guide](https://create.roblox.com/docs/en-us/production/publishing/accessibility)
says players may find small text hard to read, and lets them pick Large, Larger or Largest text
(`GuiService.PreferredTextSize`). It also says text with `TextScaled` "will not be scaled by the PreferredTextSize
value". Nearly every label in LAVA Floors is TextScaled, so the setting did nothing in the game. Young readers are
the players who need it most.

**Change.**
- `LavaUI.fitScreen` already scales both HUD ScreenGuis to the screen height (0.7–1).
- It now also reads the setting: Large, Larger and Largest grow the UI to 1.15×, 1.3× and 1.45×.
- It only grows as far as the screen leaves room: the UI never gets smaller than its 560 px tall / 960 px wide
  design space.
- It updates live when the setting changes.
- Medium (the default) and phones are exactly as before.

**Verified.** In a Studio play test:
- At Medium the scale was 1.000, the same as before.
- `PreferredTextSize` is read-only, so I loaded a fresh LavaUI copy with `textScale` returning 1.45 (Largest) and
  re-applied it to the live HUD. The scale became 1.177, limited by the 1130 px window width.
- Screenshots mid-round and at round end show everything larger with no overlaps: the round banner, coin pill, coach
  tip, Raise button, why-you-fell line, winner banner, result card and twist vote.
- That play test also showed entry 34's 25 s gem hint, which entry 34 had left unverified.
- The console was clean. Studio matches the repo by chunk hash; place saved as version 60.
- Not tested: a real device with the setting changed. TopbarPlus top bar buttons keep their own size.

## 35. Performance check for low-end phones: half the particles

**Research.** DevForum developers note that games with younger audiences tend to have more players on lower-end
devices ([DevForum](https://devforum.roblox.com/t/how-many-people-are-playing-on-low-end-devices/3358138)), and
that crashes and frame drops make players leave at once
([DevForum](https://devforum.roblox.com/t/every-time-i-publish-an-update-with-the-slightest-change-my-average-playtime-drops-to-nearly-half/4551961)).
Entry 22 checked for leaks; nothing had measured rendering cost.

**Measured** with `SceneAnalysisService`:

| | Draw calls | Triangles |
|---|---|---|
| Lobby, toward the grid | 222 | 253k |
| Lobby, toward the island | 269 | 213k |
| Mid-round | 158 | 145k |

All are well under the roughly 600 draw calls / 800k triangles where most devices hold 60 fps. There are about 6,000
instances and 50 lights, of which only 4 stage lights cast shadows.

Particles were the outlier: about 6,300 live particles (rate × lifetime) across the workspace. Two background
volcano cones from the Creator Store each ran a 500/s fire emitter with 2 s lifetimes, plus two large smoke
emitters, which is about 1,900 particles per cone. Both cones sit 560 studs out, hidden behind the crater wall from
the lobby and mostly hidden from the island.

**Change.** When backdrop models are placed, each emitter is capped at `BackdropParticleCap` (120) live particles by
lowering its rate. Nothing else changes.

**Verified.**
- Live particles went from 6,303 to 3,149 (backdrop: 1,280).
- In island screenshots before and after, the only visible difference is a faint smoke trail behind the peaks. The
  main background volcano still throws embers from the lobby.
- The console was clean. Studio matches the repo by chunk hash; place saved as version 59.
- Not measured: frame rate on a real phone.

## 34. 💎 Lava gems hidden around the lobby

**Research.**
- A DevForum request on round-based games names players who join mid-round and wait as a top onboarding problem
  ([DevForum](https://devforum.roblox.com/t/allow-developers-to-mark-servers-as-unpreferred-for-new-player-joins/3680997)).
- Replies on lobby design suggest giving waiting players places to walk and a few secrets to find.
- Roblox's June 2026 discovery update weights day-1 retention more heavily
  ([Roblox newsroom](https://about.roblox.com/newsroom/2026/06/optimizing-discovery-great-games-reach-millions-players-roblox)),
  and Roblox's [strategy docs](https://create.roblox.com/docs/get-started/strategies) recommend short-term goals.
- LAVA Floors already had the Warm-up Hop, but nothing to discover.

**Change.**
- 5 glowing lava gems (a neon crystal with a light and sparkles, built from parts; no generated content):
  - over the Warm-up Hop goal (a reward for finishing it);
  - tucked behind the Top Climbers board;
  - under a palm on the island's south side;
  - at the foot of a palm further out on the island;
  - by a palm on the east beach.
- A server loop checks distance every 0.25 s. Each gem pays 25 coins once per account; the fifth pays 100 more, so
  225 in total.
- Finds save in the profile (`Gems`, added to `SkySproutRules.new` and `clean`). The player attribute `LavaGems`
  tells the client which gems to hide; the rest spin and bob (they stay still with Reduce Motion).
- One hint about 25 s after joining, unless every gem is already found.
- First positions tried: one behind the far beacon across the crater sat beside the round's lava, so it moved to an
  island palm. Island gems were raised to clear the tall grass, and the beach gem was nudged off a palm trunk.

**Verified.**
- Screenshots at every spot.
- Pickup test, teleporting onto each gem:
  - coins 39 → 64 → 89 → 114 → 139 → 264 (the fifth paid 125);
  - `LavaGems` went from "" to "G1,G2,G3,G4,G5";
  - found gems went invisible for the player;
  - going back to a found gem paid nothing.
- `SkySproutRules.clean` kept G1 and G3, dropped bad entries, and gave an old profile an empty `Gems`.
- The console was clean. Repo and Studio match by chunk hash for the service, client and rules; place saved as
  version 58.
- Not verified: the 25 s hint message, and saving across sessions (Studio can't reach DataStores).

## 33. 🍓 Strawberry gift from the sidelines

**Research.** The developer of Spleef Battles, a disappearing-floor elimination game, planned a "Sabotage Machine"
that lets players who are out of a round affect the climbers
([DevForum](https://devforum.roblox.com/t/woah-is-the-floor-disappearing-looking-for-feedback-on-spleef-battles/324273)).
Floor-is-lava listings lean on playing with friends and on social play. Knocked-out players in LAVA Floors could
already watch, follow a climber, cheer and predict the winner, but nothing they did reached the round. Sabotage isn't
kid-fair, so this is the friendly version.

**Change.**
- While you follow a real player who's still climbing, a 🍓 Gift button joins the end of the cheer bar.
- Once a round it sends that player one strawberry (`GiftBerries`). It counts like one picked off the floor: banked
  only if they survive, and it doesn't count toward the Berry Picker award.
- The receiver gets the pickup effect and a notice. Everyone sees a "🍓 Giver → Receiver" bubble.
- The server checks everything: the round is running, the giver is out, the gift is unused this round, and the target
  is a different real player who is still climbing. No new remote; it goes through ArenaEvent's rate limit.
- The button hides after sending, when you go back to the overhead view, or when the climber leaves the round. It
  resets when the round ends.
- With the gift button the cheer bar is 400 px wide, which fits a 705 px phone screen.

**Verified.** 2-player Studio test; Player1 was kept alive with the survival driver:
- When Player2 fell in phase 2, the spectate bar showed and the gift button was hidden.
- A real click on ▶ changed the bar to "👀 Watching Player1". A real click on 🍓 Gift then floated
  "🍓 Player2 → Player1" and hid the button.
- A second `LavaGift` sent straight to the server was refused (no bubble).
- Player1's HUD showed 🍓 1, and their result card said "2 embers banked". The driver can also pick up berries, so
  this doesn't isolate the gift's share.
- The server console was clean. Studio matches the repo by chunk hash for the service and client; place saved as
  version 57.

## 32. Fix: bots finally wear their eyes and fruit hats

**Why.** Testing entry 31 showed that every bot's glowing ember eyes and fruit hat were about 380 studs away from the
bot, in every round. Bots have been plain rock figures since the golem look was added. The bots are kids' first
rivals in a quiet server, and the look exists so they're easy to tell apart from players.

**Research.** A WeldConstraint is inactive while its parts are outside the Workspace
([WeldConstraint docs](https://create.roblox.com/docs/en-us/reference/engine/classes/WeldConstraint.md)). DevForum
threads on welds placed before spawning give the same fix: parent first, then move
([PivotTo before spawning](https://devforum.roblox.com/t/using-pivotto-to-move-the-model-before-spawning-it-causes-the-weld-positions-to-become-incorrect/4188036),
[welds made outside Workspace](https://devforum.roblox.com/t/weld-constraint-sets-part-cframe-to-the-rootparts-of-a-assembly-when-created-outside-workspace/835450)).

**Change.** In `makeBot`:
- The bot is parented into the tower before its eyes and hat are welded on.
- The whole model is then moved with `PivotTo`, instead of setting only `rootPart.CFrame`.
- In Big Heads rounds the bot is built with `HumanoidDescription.HeadScale`. Raising `HeadScale` on the finished rig
  regrew the head a frame later, which brought back the default face and reset the basalt material.

**Verified.** In Studio play tests:
- Big Heads round: 3 bots with 1.28-stud heads, basalt, no face decal. Eyes stayed on the front of the head (same
  offset after 5 s of hopping), and hats sat on the head.
- Classic round: 0.73-stud heads, eyes on the face, hat bottoms at the head top.
- Screenshots show the golems with fruit hats and ember eyes. The console was clean.
- Studio matches the repo by chunk hash; place saved as version 55.

## 31. 🎈 Big Heads twist

**Research.** Lists of 2026 party picks name variety as the main draw of games like Epic Minigames, along with quick
rounds, simple rules and cosmetics ([Bloxodes party list](https://bloxodes.com/lists/top-trending-roblox-party-casual-games),
[Bloxodes group games](https://bloxodes.com/articles/roblox-games-for-groups), [Beebom](https://beebom.com/best-roblox-games/amp/)).
LAVA Floors had 9 twists, all of which change the rules or the floor. None was just for laughs.

**Change.** A new twist, Big Heads (weight 2, also in the end-of-round twist vote):
- Every climber's head grows by `BigHeadScale` (1.75×) for the round, bots included.
- The head grows through the Humanoid's `HeadScale`, so hair and face scale with it; fruit hats and the crown are
  rebuilt to sit on the bigger head.
- Bodies, speed, jumps and shoves are unchanged.
- The original size is stored on the Humanoid (`LavaBaseHead`) and put back on knockout (`scorch`) and at round end
  (`release`).
- 2× hid too much of the floor ahead behind your own head in the third-person camera, so it's 1.75×.

**Verified.** In Studio play tests with `StudioForceMutator = "BigHeads"`:
- The banner read "🎈 Big Heads". The player's head went from 0.743 to 1.300 at 1.75× (1.485 at 2×), and bot heads
  doubled at 2×.
- Walk speed stayed 24 and jump 48.
- After the knockout the head was back to 0.743, the attribute was cleared and walk speed was 18.
- Screenshots were taken in the round, and the console was clean.
- Studio matches the repo by chunk hash; place saved as version 53.

**Found, not fixed here.** Bot eyes and fruit hats have been ~380 studs away from their bots in every round, Classic
included. `makeBot` sets `rootPart.CFrame` while the model is still outside the workspace, so the welded eyes and hat
stay at the build spot. Fixed in entry 32.

## 30. Lava Pass XP rebalanced for 3-phase rounds

**Why.** The owner asked to match entry 18: the pass paid the same XP per round while rounds got about 30% shorter,
so it filled about 1.4× faster per minute.

**Change.** Per-round pass XP is scaled to 0.7×:
- Played: 20 → 14.
- Survived: 30 → 21.
- Crowned: 50 → 35.
- Per banked strawberry: 5 → 4 (3.5 rounded up).

`XPPerTier` stays 100, so XP players already have keeps its meaning.

**Verified.** In a Studio play test, a knocked-out round raised `PassXP` from 0 to 14. Studio matches the repo by
chunk hash for the config, service and client.

## 29. Warm-up Hop checked with real jump physics (no change needed)

**Why.** The redesigned hop (entry 16) had only been checked by teleporting. After entry 28 everyone in the lobby
has walk 18 and jump power 40, which reaches only about 4.1 studs.

**Checked.** The same physics-driven method as the pillar (entry 23): stand on each piece, `MoveTo` the next, jump,
and check the landing. The route is start pad → round pillar → fork-1 solid stone → beam → step → fork-2 solid
stone → gold pad. Three full runs landed 18 of 18 hops. No change needed.

## 28. Fix: knocked-out players kept round movement in the lobby

**Found** during the hands-on checks. A player whose round ended normally went back to lobby movement (walk 18,
jump power 40), but a player knocked out mid-round kept the round's walk 24 and jump power 48 in the lobby. Only
`release()` at round end restored them. So the lobby, including the Warm-up Hop, felt different depending on how
your last round ended.

**Fix.**
- `scorch` restores lobby walk speed and jump when it sends the player to the lobby. A phase-1 drop-back sets the
  round values again on re-entry.
- The hot-potato cleanup now only resets speed for a holder who is still climbing.

**Verified.** In a Studio play test, the lobby at start read walk 18 / jump 40, in the round 24 / 48, and after a
knockout past phase 1 18 / 40 again. Studio matches the repo by chunk hash.

## 27. Teach the pillar climb

**Why.** King of the Pillar (entries 19 and 23) only pays off if players know it's there. The first-round coach
taught climbing, red tiles, shoving and fruit, but not the pillar. Onboarding guidance (entry 10's research) favours
teaching through play with short, timely prompts.

**Change.** A sixth first-round tip, shown before the last one: "🗿 Climb the pillar's ledges to grab the strawberry
on top!". Tips are 5 s each, so all six fit in a 33 s round.

**Verified.** In a Studio play test of a first round, with the player kept alive, tips 1–6 appeared in order and tip
5 was the pillar tip. Studio matches the repo by chunk hash.

## 26. Roomier HUD on phones

**Found** by repeating the end-of-round check on the Galaxy A06 (705×338 viewport) after entry 25:
- The first-round coach tip ("NEW HERE? TIP 5 / 5") stayed up after the round ended, over the winner banner and
  result card. A tip lasts 5 s even if the round ends during it.
- The notice toast (now carrying the "why you fell" line) touched the top of the winner banner.

**Fix.**
- When winners are announced, any coach tip is hidden along with the showdown card.
- The end-of-round column starts 18 px below the notice toast instead of 10 (`NOTICE_GAP`).

**Verified.** Galaxy A06 screenshots before and after. After: no coach card at round end, a clear gap between the
toast and the banner, and the banner and result card as separate cards. Studio matches the repo by chunk hash, and
the simulator was reset to the default viewport.

## 25. Follow a climber, and a roomier HUD

**Follow a climber.** Knocked-out players only had the high overhead orbit, so they couldn't keep an eye on a friend.
Earlier research (entries 1 and 6) found that watching keeps knocked-out players around.
- ◀ ▶ buttons (46 px, touch-friendly) beside the spectate bar cycle between the overhead view and following any
  climber still in the round, players or bots.
- The chase camera sits just outside and above them, looking back across the floor, and eases in. With Reduce
  Motion it cuts instead.
- The bar reads "👀 Watching *Name*". If that climber falls, the view returns to overhead.

**Roomier HUD.** The owner asked to space out the UI. Screenshots across these tests found:
- The end-of-round cards (winner banner, result card, twist vote) sat about 10 px apart, and the column didn't
  allow for the vote card. The cards are now 20 px apart (`END_GAP`), and the column keeps clear of the vote card
  (104 px plus the 70 px under it plus an 18 px gap) while it shows, shrinking to fit if needed.
- The "FINAL SHOWDOWN" card could still be up when the round ended, on top of the winner banner. It now hides when
  winners are announced, and sits lower (42% instead of 36%) so it clears the notice toast.
- The cheer bar sat 8 px above the spectate bar. Now it's 22 px.
- A 774 px-wide window overflowed the top bar ("Chall…" under Invite). `UI.short` now also picks the short labels
  below 900 px wide.

**Verified.** In 2- and 3-player Studio multiplayer tests, with real mouse clicks in the spectator's window:
- ▶ switched the bar to "👀 Watching Player1" and the camera to a close chase view of Player1 on their tile.
- The end-of-round screenshot shows the banner, result card and vote separated, with no showdown card on top.
- The spectate screenshot shows the cheer bar clear of the spectate bar, and a top bar that fits.
- The console showed no errors, and Studio matches the repo by chunk hash.

## 24. Why you fell

**Research.** Writing on failure in game design agrees that a loss should be attributable and explained, with a
lesson the player can use on the very next try. An unclear death frustrates, especially when the game's systems
are abstract ([Game Developer](https://www.gamedeveloper.com/design/figuring-out-failure-in-game-design),
[My Game Design](https://mygamedesign-frontend.pages.dev/how-can-failure-states-teach-without-frustrating)).
In LAVA Floors every knockout just said "🔥 SCORCHED!", whether you'd camped, missed a hole warning, been shoved or
stepped off the edge.

**Built.** The server records what last happened to each climber: who shoved them and when, a hot-potato blast,
and the last tile they stood on. On a knockout it sends a one-line reason with a tip, checking the most specific
cause first. Each counts if it happened within `CFG.ReasonWindow` (3 s) of the fall.
- 💣 The hot potato blew up on you. Pass it on quickly!
- 💥 *Name* shoved you off. Keep away from the edges!
- 🪨 Your tile crumbled from standing still. Keep moving!
- 🕳️ That tile dropped away. Step off red tiles in time!
- 🧱 The edge was left behind. Move inward when the floor shrinks!
- 🌋 You slipped into the lava. Watch your step near the edges! (the fallback)

**Verified.** In Studio play tests:
- Standing still: 🪨.
- Stepping onto a planned drop tile 4 s into the phase: 🕳️. (The first try, from the phase start, crumbled from
  camping first, and the message correctly said 🪨.)
- Stepping off a safe tile into the lava: 🌋.
- In the 2-player test, an idle player on the outer ring when it was left behind got 🧱.
- The console showed no errors, and Studio matches the repo by chunk hash.

Not verified: the 💥 shove message. Three tries at lining up two scripted clients for a shove at the edge didn't put
the target in range; the one hit landed on a bot. The reason is recorded on the same line that sends the shove.
💣 is untested as well (needs the Hot Potato twist).

## 23. Pillar climb tuned with real jump physics

**Why.** Entry 19 placed the pillar ledges by teleporting a player onto them; nobody had jumped up them. The store
thumbnail promises a climber on top.

**Tested.** A physics-driven climb between rounds, with the round's jump power 48, walk speed 24 and character scale
0.62. For each hop: stand on a ledge, `MoveTo` the next, jump, and check where the character lands.
- **Original (3 ledges, 4.5 studs apart, 2.6 wide, 4.6 from the axis):** 3 of 9 hops landed. The physics agree: a
  4.5-stud rise clears the next ledge's edge by only about 0.3 studs while moving, and from the top ledge the cap
  rim is reached before the character has risen 3.3 studs.
- **Wider and further out (3.4 wide, 5.0 from the axis):** still 3 of 9.
- **Final (4 ledges, 3.65 studs apart):** tops at 3.65, 7.3, 10.95 and 14.6, with the cap 2.2 above the last.
  10 of 12 hops landed, including a clean bottom-to-cap climb. That's with a script that has no timing skill, so
  real players should do at least as well.

**Verified.** The climb results above, and a screenshot of the test character standing on the cap with the ledges
spiralling up. Studio matches the repo by chunk hash.

## 22. Leak check over many rounds (no change needed)

**Why.** DevForum threads on round-based games describe memory that climbs every round from leftover connections or
instances, and phones hit their memory limit first
([1](https://devforum.roblox.com/t/i-disconnect-all-connections-and-even-that-is-not-helping-eliminate-lag-buildup-in-my-game/1601284),
[2](https://devforum.roblox.com/t/server-untrackedmemory-goes-up-and-never-comes-down-again/134529),
[3](https://devforum.roblox.com/t/why-is-my-memory-building-up-this-is-incredibly-annoying/2025341)).
LAVA Floors rebuilds its tower every round, and this session added several per-round systems (pillar, ledges,
awards, goal, away and underdog tracking).

**Checked.** In a solo Studio play test of 7 rounds, the client stepped into the lava after phase 1 each round.
After each round I logged instance counts and memory on both sides:
- Server workspace: about 3,500 instances every time. The dips to about 2,600 are rounds caught between tower builds.
- Tile riders: 267–323. Strawberries: 6–7.
- Client workspace: 3,100–4,000. PlayerGui: 1,565–1,590. Camera children: 125.
- Studio's total memory (one process shared by server and client, so only a rough signal): about 2.2 GB early,
  falling to about 1.4 GB.
- No upward trend in any count, and no console errors.

Nothing to fix. Worth repeating with real devices and a longer session before launch, using the Developer Console's
memory tags.

## 21. Phone and tablet layout pass

**Research.** About 80% of Roblox sessions are on mobile
([Search Engine Land](https://searchengineland.com/guide/roblox-users),
[HostingAdvice](https://www.hostingadvice.com/studies/roblox-statistics/)). Most of this session's checks had been
in a desktop-sized Studio window.

**Checked** with Studio's Device Simulator, in play mode, in the lobby countdown and mid-round:
- Samsung Galaxy A06 (800×360, the smallest phone listed; 705×338 viewport with touch controls).
- iPad 10th gen (1180×820).

**Found and fixed on the phone:**
- **Top bar overflow in the lobby.** The Lava Rush toggle's "✅ Queued" label pushed the right-hand group over the
  "🌋 0/40" goal pill. On phones the toggle now shows "✅", "🔥 Go!" or "🔥" (via `UI.short`); the full words stay on
  bigger screens.
- **Coach card under the RAISE button.** The first-round tip card (90% wide at 70% height) ran under RAISE and
  reached toward the thumbstick. On phones it now sits in the clear band between them: 45% wide, centred at
  42.5% across.

**Fine as built:** the round HUD on the phone (title card, phase label, climb meter, RAISE, SHOVE, jump), and the
whole tablet layout (full top bar labels with room to spare; the coach card clears RAISE).

**Verified.** Screenshots before and after on the Galaxy A06 and on the iPad:
- The phone's coach card measures x 141–458 of 705. The thumbstick ends at about 130 and RAISE starts at about 472.
- The console showed no errors, and Studio matches the repo by chunk hash.
- The Device Simulator was reset to the default viewport afterwards.

## 20. Your own tile cracks out loud

**Research.**
- Xbox Accessibility Guideline 103 asks for key cues through more than one sense, with rumble as a supplement, so
  players who miss the visual still get the warning
  ([XAG 103](https://devdocs.xbox.com/gaming/accessibility/xbox-accessibility-guidelines/103),
  [Game Accessibility Guidelines](https://gameaccessibilityguidelines.com/?p=21)).
- In LAVA Floors the tile under you wearing out (darkening, cracking, shaking) was visual only. Your own character
  usually hides that tile from the third-person camera, and there was no sound until it shattered.

**Built.** On the client:
- A low crack plays when the tile you're standing on is half worn.
- A lower crack and a short gamepad buzz come when it's 85% worn, just before it breaks.
- Each stage plays once per tile and resets if the tile recovers.
- It covers camping wear and planned holes alike (`Grid.Crumble`). It reuses the existing Shove sound at lower
  pitches, so no new audio.
- The buzz uses `HapticService`, only where vibration is supported.

**Verified.** In a Studio play test, a player was pinned to one tile during a round:
- Crack at 2.2 s, when wear was 0.5.
- Second crack at 3.6 s, at wear 0.85.
- The existing shatter sound at 4.4 s, when the tile broke.
- The console showed no errors, and Studio matches the repo by chunk hash.

Not verified: the gamepad buzz, because no controller was connected.

## 19. King of the Pillar

**Research.** King-of-the-hill design writing says one contested high spot is simple to read and generates tension,
and a payoff you only keep if you hold out raises the stakes
([game design patterns](https://www.math.vu.nl/~eliens/multimedia/media/pattern-kingofthehill.html),
[Halopedia](https://www.halopedia.org/King_of_the_Hill)). The new store thumbnail shows a crowned climber on the
centre pillar, but players couldn't actually get up there.

**Built.**
- Three light stone ledges spiral up the pillar, 60° apart and 4.5 studs apart in height (`PillarLedges`,
  `PillarLedgeStep`; a round jump reaches about 5.8). The 60° spacing means each hop clears the column instead of
  passing through it.
- A strawberry waits on the cap each round. Like every strawberry, it's only banked if you survive.
- Camping isn't possible: standing up there wears the centre tile, and when it shatters the pillar drops with it.
- **Two fixes so the top is actually playable:**
  - `LavaGrid.TileAt` treated anything over 14 studs above the floor as off-grid, which would have scorched climbers
    on the top ledge as "hovering". Around the pillar's tile and its 8 neighbours the limit is now the pillar top
    plus 8 (tower attribute `PillarTop`). Everywhere else keeps 14.
  - The client only carried players on `Tile<n>` parts found by an overlap query, which skips the pillar (it's left
    out of queries so the camera ignores it). The client now checks the pillar and ledges by shape during a climb
    and carries the player with the centre tile. The tower lookup is cached.

**Verified.** In Studio play tests:
- On the cap for 3.5 s: still climbing (not scorched), centred on the cap the whole time, and the strawberry collected.
- On the lowest ledge while the floor spun 179°: stayed dead centre on the ledge, at a steady height.
- Ledge tops measured at 4.5, 9 and 13.5 studs above the tile.
- Screenshots in the Sunset and Blue Inferno themes show the ledges, the lighter ledge colour, and the strawberry on the cap.
- The console showed no errors, and Studio matches the repo by chunk hash for the service, client and `LavaGrid`.

Not verified: a real player jumping up the ledges. The positions were teleported; the heights and gaps are within
a round jump on paper.

## 18. Rebalance coins and chest for 3-phase rounds

**Why.** After the switch to 3 phases (entry 16), a round paid the same as before but took about 44 s instead of about
63 s (countdown 4 s + start 3 s + phases + results and vote 7 s). So coins and Lava Chests came about 1.4–1.5× faster
per minute against unchanged shop prices. The owner asked to bring them back to the old pace.

**Change.** Round rewards are scaled to 0.7× (44 / 63):
- `CoinsPerStud`: 0.15 → 0.105.
- `SurviveCoins`: 20 → 14.
- `CrownCoins`: 60 → 42.
- `EmberCoins`: 3 → 2.
- `ChestGoal`: 150 → 215, with the same fill per round, so a chest still comes about every 4.5 minutes for an average player.

Unchanged: the personal-best bonus, Pick the winner, the server goal, challenge rewards and Lava Pass XP (still per round).

**Verified.** In a Studio play test, a knockout at height 40 paid 14 coins: 4 for height plus the 10-coin first-best
bonus. Chest fill was 27 of 215. By the same maths a crowned round pays about 50 before strawberries, against 72
before (0.69×). Studio matches the repo by chunk hash.

## 17. Fix: the hop's cracked-stone ⚠

**Found** while checking the cracked stones by hand.
- **The mark didn't hide.** It stayed visible while its stone dropped. The server set `SurfaceGui.Enabled = false`,
  but the client's `SkySproutPerception` resets `Enabled` on every floor-1 SurfaceGui to its original value every
  0.25 s, so the change never showed.
- **The mark was too small.** With the default canvas it read as a tiny yellow dot.

**Fix.**
- The drop now fades the ⚠ label's `TextTransparency`, which the perception module doesn't touch.
- The mark now copies the round's warning tiles: a square 200×200 canvas, dark text and a 6 px white outline.

**Verified.** In a Studio play test, on the client:
- Before landing: stone 0, ⚠ 0. At 1.1 s: stone 0.8 and not solid, ⚠ 1, and the player had fallen and was back
  on the start pad. At 4.3 s: stone 0 and solid, ⚠ 0.
- A screenshot shows a clear outlined ⚠ on the cracked stone.
- Studio matches the repo by chunk hash.

## 16. Hands-on pass: 3-phase rounds, centre pillar, puzzle hop, top bar fixes

Done with Studio in front, following the owner's notes while watching.

**Owner's notes and changes.**
- "Too many squares on the hop; puzzle-like jumps would work better." The Warm-up Hop is now:
  - a round pillar;
  - a fork where one stone is cracked: lighter, with a ⚠, and it drops 0.6 s after you land, then comes back after
    3 s (`HopCrackDelay`, `HopCrackBack`). It practises reading cracked tiles before a real round;
  - a narrow beam and a step up;
  - a second cracked-or-solid fork before the gold pad.
- "Make it 3 phases instead of 7." A round is now 3 phases of 10 s.
  - Rises are 23 studs (`GridRise`), so the crown is at 81, still just over the crater rim at 80: winners still escape
    the volcano.
  - The floor grows 5x5 → 9x9 in phase 1, then shrinks to 5x5 and to a 3x3 finale.
  - The showdown can start from phase 2.
  - The "Reach phase 5" daily challenge is now "Reach phase 3".
  - The round funnel logs Phase2 and FinalPhase, instead of a "Phase3" step that now fell on the final phase.
- "Counting the lava height isn't as important." The "Lava N below" count is gone from the round HUD. The red tint
  still warns you when the lava is close.
- "The grid doesn't look good; maybe a pillar in the middle blocking the view?" A 16-stud basalt pillar with a glowing
  cap now stands on the centre tile.
  - It rides the tile, so it rises and spins with the floor.
  - It fills most of the tile and blocks the view across the grid.
  - It's ignored by camera checks, so the camera doesn't jump in front of it.
  - `LavaGrid.IsPillar` keeps the centre tile out of the random drops, `Safe`, bot moves, bot and player spawns, and
    strawberries.

**Found by looking.**
- **Top bar overflow.** At about 1130 px wide the new "🌋 Server goal 0/40" pill pushed the title pill under the
  right-hand group. Fixes: the goal pill always uses the short "🌋 12/40" with a hover caption, and the title pill now
  also needs a screen at least 1280 px wide.
- **Long award names.** A long display name wrapped an award across lines on the winner banner. Names are now cut to
  12 characters.
- **Fine as built:** the Warm-up Hop look, the award banner layout and the goal pill.

**Verified.** In Studio play tests:
- A survival-driven player climbed y 15.5 → 38.5 → 61.3 → 84.4 over the 3 phases and was crowned.
- Screenshots at eye level show the pillar blocking the far side, in three themes.
- The HUD reads "Phase 1/3 • 4 left • 🍓 2".
- The hop built every piece (2 cracked, 5 solid).
- The console showed no errors, and Studio matches the repo by chunk hash for the service, client, `LavaFloorsUI` and
  `LavaGrid`.

Not verified:
- A clean screenshot of the hop's ⚠ marks, and a cracked stone actually dropping under a player.
- Real jumps through the hop: my scripted runner wasn't reliable enough to judge.
- Coin pace: a round still pays by height, but rounds are now about 33 s instead of about 52 s, so coins and chests
  come roughly 1.5x faster per minute.

## 15. Server goal

**Research.**
- Shared progress bars that everyone fills together are a common way to make players care about each other's play,
  as in Call of Duty: Mobile clan bars and match-3 community challenges
  ([GameRefinery](https://www.gamerefinery.com/keep-players-engaged-with-communal-mechanics/)).
- The best versions pair personal play with the shared bar, and only reward players who took part. Plants vs. Zombies
  locked its community chests until you'd contributed.
- LAVA Floors already had personal goals (Lava Chest, challenges, best height) but nothing the whole server worked on together.

**Built.** Every rise a real player reaches in a round adds to one bar for the whole server: 40 rises (`CFG.GoalRises`).
- When it fills, everyone who climbed since the last goal gets 30 coins (`CFG.GoalCoins`), the same for all, with the
  coin burst and "🌋 Server goal!".
- The whole server is told, and a new bar starts.
- Bots don't count. Neither do idle players: they never reach a rise, and they're benched anyway (entry 11).
- A top bar pill shows "🌋 Server goal 12/40" ("🌋 12/40" on narrow screens), fed by the workspace attributes
  `LavaGoal` and `LavaGoalSize`.
- Pacing: a solo player reaching 2–3 rises a round fills it in about 15 rounds; a busy server does it every few rounds.

**Verified.** In a solo Studio play test, with the Studio copy temporarily set to a goal of 3:
- After rounds 1–3 the goal read 0, 1, then paid out "🌋 Server goal! +30" and reset to 0.
- The pill read 🌋 0/3 → 1/3 → 0/3.
- The console showed no errors.
- Studio was set back to 40 afterwards and matches the repo by chunk hash, for the service and for `LavaFloorsUI`.

Not verified: the pill's look, since Studio was in the background.

## 14. Adaptive bots

**Research.**
- Dynamic difficulty adjustment exists to keep players out of boredom and frustration, and recent work reports it helps
  keep players engaged and feels fairer
  ([preprint](https://www.preprints.org/manuscript/202511.2251)).
- Work on young children notes they have fewer strategies for handling frustration
  ([arXiv 2406.04794](https://arxiv.org/pdf/2406.04794)).
- The same research says adapting can backfire if players sense it's unfair, so the change should be small and bounded.
- In LAVA Floors, bots fill small rounds with a fixed 12% mistake chance. In a server of young players, bots can win
  round after round.

**Built.** Each round the bots win in a row adds 0.06 to their mistake chance, up to +0.30 (`CFG.BotEase`, `CFG.BotEaseMax`).
- A mistake is a random hop to a neighbouring tile instead of the safest one.
- A real player winning takes off 0.12. A round the lava wins changes nothing.
- It's per server and invisible in play. The value is published as the workspace attribute `LavaBotEase` for testing.
- The bots never get better than the original 12%, so strong players face the same bots as before.

**Verified.** In a solo Studio play test, the player stepped into the lava after phase 1 for 4 rounds. The bots won
each time, and `LavaBotEase` went 0.06 → 0.12 → 0.18 → 0.24. The console showed no errors, and Studio matches the repo by chunk hash.

Not verified: the drop after a real player wins. A test player can't win while Studio is in the background. That's a
one-line `math.max(0, …)` next to the tested increase.

## 13. Fix: Berry Picker missed knocked-out players

**Found** while building the underdog shield. The Berry Picker award (entry 9) counted `r.embers`, but a scorch
empties `r.embers` (you drop the strawberries you were carrying). So a player who picked several strawberries and
then fell never won Berry Picker, even though they did the most picking.

**Fix.** A separate per-round `picked` counter goes up with each strawberry. A scorch doesn't clear it, and it carries
over a phase-1 drop-back like shoves and drops. The award uses `picked`. Coins are unchanged: scorched players still
lose the strawberries they carried.

**Verified.** In a 2-player Studio multiplayer test, Player1 picked 6 strawberries, then stepped into the lava after
phase 1. The awards were "🧗 Top Climber: Player2 | 🍓 Berry Picker: Player1". With the old code no one could have
got Berry Picker that round, because Player2 picked none and Player1's count was reset to 0. The server console
showed no errors, and Studio matches the repo by chunk hash.

## 12. Underdog shield

**Research.**
- Catch-up ("rubber band") mechanics keep players who are behind engaged, and work best in casual and party games
  ([Game Developer](https://gamedeveloper.com/design/the-value-of-rubber-banding-an-engagement-driver-),
  [feedback loops](https://computerscience.chemeketa.edu/cis125greader/MechanicsDynamics/FeedbackLoops.html)).
- The same writing warns that too much catch-up makes good play pointless, and that the blue shell punishes the
  leader. The gentle kind is a small, fixed help for whoever is behind, like Catan's free resource.
- LAVA Floors had nothing for a kid who keeps falling first.

**Built.** Knocked out 3 rounds in a row in this server (`CFG.UnderdogAfter`), you start the next round inside the
bubble shield for 15 s (`CFG.UnderdogShield`, vs 7 s for the blueberry pickup). The message is "🫧 Underdog shield! Tough few
rounds, so shoves can't move you for 15s."
- It only stops shoves. The lava, cracking tiles and the climb are unchanged, so it can't win a round for you.
- Surviving or winning resets the count.
- It's free and automatic, nothing to buy, and isn't saved between servers.
- `grantShield` now takes an optional duration and message. The blueberry pickup is unchanged.

**Verified.** In a solo Studio play test, the client stepped into the lava after phase 1 each round:
- Round entries 1–3 had no bubble. Entry 4 had the bubble and the underdog message.
- The bubble was gone about 12–16 s later.
- The console showed no errors, and Studio matches the repo by chunk hash.

Not verified: the reset after surviving. A test player can't survive a round while Studio is in the background.

## 11. Away players sit out

**Research.** DevForum threads on round-based games say idle players who get pulled into rounds "ruin the experience
for others". The advice is to keep them out of the playing pool until they come back, and to count only active players
when starting a round
([1](https://devforum.roblox.com/t/make-1-player-afk-in-a-round-based-game-with-a-script-not-a-local-script/857220),
[2](https://devforum.roblox.com/t/how-would-i-make-an-afk-system/3435486),
[3](https://devforum.roblox.com/t/simple-afk-system/825577)).

In party mode LAVA Floors queues everyone automatically. So a kid who walked away was dropped into every round and
fell off. That took a slot a bot would have filled, and it changed the last-one-standing rule for everyone else.

**Built.**
- After 2 minutes with no input at all (`CFG.AwayAfter`, sent to clients as the workspace attribute `LavaAwayAfter`),
  the client asks to sit out.
- The server agrees only between climbs, and only if the player hadn't already chosen to sit out. It takes them out of
  the queue and says "💤 You've been away, so you're sitting out. Move to jump back in!"
- Any input afterwards (a key, a click, a touch or moving the mouse) sends them back: "🔥 Welcome back! You're in the next round."
- Tapping Join also clears it. A player who opted out by hand is never put back automatically.
- Benching is logged as an analytics custom event (`Away`).

**Verified.** In a Studio play test, by firing the remotes from the client:
- Benching mid-climb was refused.
- In the lobby, benching set away and opt-out, and the player was not put into the next round (35 s watched).
- Coming back cleared both, and the player was in the following round.
- With the limit lowered to 5 s and no input, the client benched itself after 8 s.
- Join cleared it.
- After a manual opt-out, both "away" and "back" were ignored.
- The console showed no errors, and Studio matches the repo by chunk hash.

Not verified: real input bringing a player back. Studio was in the background, so no input events fired; the test
sent "LavaBack" directly.

## 10. Winner cam

**Research.**
- Roblox pitches emotes as the way to "celebrate a hard-earned win"
  ([Roblox newsroom](https://corp.roblox.com/newsroom/2019/08/expanding-emotes-more-animations-more-fun)).
- Party games such as Violent Party end each match on a winner screen that puts the top player front and centre
  ([guide](https://allthings.how/how-to-play-violent-party-on-roblox-full-minigame-guide/)).
- LAVA Floors already plays a cheer for the winner and fires a gold pillar and fireworks. But the players watching
  from the overhead spectate camera saw it from about 70 studs up, so the winning moment was tiny on their screens.

**Built.** When a round ends with a real winner, anyone who was watching from the spectate camera swings round to
the winner and slowly orbits them for 3.2 s. Then the normal camera comes back, just as the results move everyone
back to the lobby.
- Winners keep their own view. So do players who had walked off on their own, so nobody's camera is grabbed mid-jump
  on the Warm-up Hop.
- Any move key, a right-drag or a touch hands the camera back at once.
- With Roblox's Reduce Motion setting on, it cuts to a still shot instead of swooping and orbiting.

**Verified.** In a Studio play test with the player in the lobby, not watching:
- A server-sent winner banner showed, and the camera stayed `Custom`.
- A malformed position was ignored.
- The console showed no errors, and Studio matches the repo by chunk hash.

Not verified: the swing and orbit themselves. They run in RenderStep, which doesn't fire while Studio is in the
background. That needs a hands-on look: get knocked out, watch from above, and let someone else win.

## 9. Round awards on the winner banner

**Research.**
- Game-design writing on keeping losing players engaged says people enjoy a game they didn't win when they were
  good at something in it, and party hosts spread recognition with named awards beyond first place
  ([League of Game Makers, "Hey, loser"](https://www.leagueofgamemakers.com/hey-loser-keeping-players-engaged/)).
- The same idea is the "bonus stars" at the end of a party-board game.
- LAVA Floors only named the winners. Everyone else saw "THE BOTS WIN!" or "Nobody survived".

**Built.** With two or more real players in a round, the winner banner adds up to four shout-outs:
- 🧗 Top Climber: the highest climber who wasn't crowned.
- 💪 Shove Champ: the most shoves landed, on players or bots.
- 🍓 Berry Picker: the most strawberries.
- 🍍 Fruit Grabber: the most supply drops.

Rules:
- One award per player, so more kids get named.
- An award only goes to someone who actually did the thing. A tie goes to the lower UserId.
- No coins, so there's nothing to farm.
- Shown two per line, so the text stays readable. The banner grows from 120 to 158 or 190 and the end stack refits.
- Shoves and drops carry over if a phase-1 knockout drops you back in.

**Verified.** In a 2-player Studio multiplayer test:
- Real round 1: "🧗 Top Climber: Player1". Player2 did nothing and got nothing. The banner was 158 tall with the line showing.
- Real round 2: "🧗 Top Climber: Player2".
- A 4-award payload from the server showed both lines, and the banner grew to 190 with the text fitting. A malformed
  award entry was dropped.
- The console showed no errors, and Studio matches the repo by chunk hash for both scripts.

Not verified: a real Shove Champ, Berry Picker or Fruit Grabber. Both test rounds ended in under 25 s, before the bots
came within shoving range. The counters are one line each, next to the existing shove challenge counter and the drop pickup.

## 8. Warm-up Hop in the lobby

**Research.**
- DevForum threads on round-based games keep coming back to dead time in the lobby: new players who join mid-round,
  or who get knocked out early, have nothing to do and leave. The suggested fix is something small to play in the
  lobby (a mini obby, a secret, a mini-game) while you wait
  ([1](https://devforum.roblox.com/t/how-can-i-make-this-round-based-game-less-boring/312762),
  [2](https://devforum.roblox.com/t/what-should-i-do-with-the-time-players-have-in-between-games/1124487),
  [3](https://devforum.roblox.com/t/people-leaving-game-really-early-on/2158215?page=3)).
- LAVA Floors already covers the people watching (spectating, Pick the winner, Cheers), but the lobby itself had only
  boards and the join beacons.

**Built.** A short stepping-stone run beside the lobby plaza: a green start pad, six basalt stones rising over a pool
of practice lava, and a gold finish pad.
- Falling in is safe: you go straight back to the green pad.
- The clock runs from leaving the green pad to touching the gold one. The finish shows "⏱ 4.2s", "NEW BEST!" or
  "🏆 SERVER RECORD!", and the sign over the finish shows the server's fastest run.
- No coins, so there's nothing to farm. Runs faster than 2.5 s (`CFG.HopMinTime`) are ignored.
- Players in a round can't use it. Knocked-out players can, between cheers.
- The volcano rock spires now keep clear of the course: one had landed on the finish pad.

**Verified.** In a Studio play test:
- Run: green pad → stones → gold pad gave "⏱ 3.0s 🏆 SERVER RECORD!". The finish sign switched to the record.
- Fall: dropped between the first two stones, I was back on the green pad within 0.5 s, with full health.
- After the spire fix, nothing overlaps the course except the ground and the plaza edge, and all 16 spires are still placed.
- The console showed no errors, and Studio matches the repo by chunk hash.

Not verified:
- Real jumping. The test teleported between stones; the gaps (about 3 studs, rising 1 stud a stone) are meant for the
  default lobby jump.
- How it looks, because Studio was in the background.
- The edit-mode preview copy, which wasn't refreshed. `BuildPreview` fails from the plugin because
  `SkySproutProfiles` calls `BindToClose`, which only works on a running server. The game builds a fresh map at start.

## 7. "One more round": Lava Chest and near misses

**Why.** Asked for directly: a mechanic that makes players say "one more run". The two classic drivers are a progress
bar that is almost full when the round ends, and a near miss that makes the next try feel winnable. Both had to be
kid-fair: fixed rewards, nothing random, nothing to buy, and no timer or streak that punishes taking a break.

**Built.**
- **Lava Chest.** Every round fills a bar on the result card:
  - 12 for playing;
  - up to 30 for how high you climbed;
  - +15 for surviving, +30 for the crown.
- At 150 the chest opens for 100 coins (every 5th chest: 300), and the leftover carries over. The card animates the
  fill, celebrates an open chest, then says how close the next one is: "🎁 69% · one more round to the chest!" or
  "about 3 rounds to the BIG chest". Chest coins are flat (no VIP or pass multiplier), so it's the same for everyone.
- **Near miss.** Knocked out one or two rises from the crown, the title reads "😱 SO CLOSE! 2 rises left" instead of
  "💀 SCORCHED".

**Balance.** The first test with a goal of 100 opened 2 chests in 4 rounds, roughly doubling an average player's
coins against shop prices of 160–4,000. The goal is now 150: about one chest every 4 rounds for an average player and
every 2–3 for a good one.

**Verified.** Studio play tests with real rounds:
- Crowned → chest 0 → 69 (+69), "69% · one more round to the chest!".
- Next round +42 → chest opened, +100 coins, 11 carried over; then 11 → 53.
- Stepping off at phase 5 (height 66) → "😱 SO CLOSE! 2 rises left", RisesLeft = 2.
- After the goal change: 0 → 22 of 150, fill bar landed at 0.15, "14% · about 6 rounds to the chest".
- The console showed no errors, and Studio matches the repo by chunk hash.

Not verified: the fill animation itself. Tweens don't run while Studio is in the background, so the code now also sets
the final width directly.

## 6. Cheers from the sidelines

**Research.**
- DevForum threads on round-based games keep repeating that waiting with nothing to do is the boring part
  ([DevForum](https://devforum.roblox.com/t/how-can-i-make-this-round-based-game-less-boring/312762),
  [DevForum](https://devforum.roblox.com/t/what-do-you-guys-think-is-better-for-when-players-are-waiting/1996143)).
- Party-game design treats a long sit-out for knocked-out players as a poor fit, and says the game should be fun to
  watch ([Wikipedia: party game](https://en.wikipedia.org/wiki/Party_game)).
- Jackbox keeps knocked-out players in the game and lets the audience react with emoji
  ([Jackbox audience play-along](https://www.jackboxgames.com/how-audience-play-along-differs-in-each-jackbox-game)).

**Gap.** A knocked-out player sits out the rest of the round (up to about 50 s). They could pick a winner (entry 1),
watch from above or explore, but couldn't interact with anyone.

**Built.**
- Anyone not climbing gets a glass bar of six preset emoji above the spectate label: 🔥 👏 😂 😱 💪 🎉. That includes
  knocked-out players and players sitting the round out.
- A tap floats the emoji up the right side of everyone's screen with the sender's name, then it fades. With Reduce
  Motion on it fades in place.
- There's no typing, so it's kid-safe. The server only accepts cheers during a round, from players who aren't
  climbing, for one of the six emoji, at most one every 1.2 s.

**Verified.** Two-player Studio test, with Player1 climbing and Player2 opted out and watching (cheer bar shown):
- Player2 sent #2, #3 right away, #6 1.4 s later, #9, 1.5, and #4 1.4 s after that.
- Player1 received exactly 👏, 🎉, 😱, each as a floating bubble that cleaned itself up.
- The too-soon cheer, the out-of-range index and the fraction were dropped.
- Earlier runs showed cheers from a player still climbing are rejected. This includes the phase-1 re-drop, where a
  player knocked out in phase 1 is put back in, which first looked like a bug.
- Server and client consoles showed no errors. Studio matches the repo byte for byte.

## 5. Accessibility: ⚠ on warning tiles, and Reduce Motion

**Research.** A DevForum accessibility guide written by a disabled developer, and the replies to it, warn against
showing status by colour alone. Adding a symbol next to the colour helps colour-blind players without extra settings
([DevForum guide](https://devforum.roblox.com/t/making-accessible-games-for-the-disability-aware-era-a-not-fully-comprehensive-guide-by-an-actual-disabled-developer/1375919/2),
[colour-blind threads](https://devforum.roblox.com/t/how-can-i-make-a-red-green-colourblind-mode-for-my-ui/1001221)).
Roblox added a Reduce Motion setting that games read through `GuiService.ReducedMotionEnabled`
([Roblox accessibility guidelines](https://create.roblox.com/docs/production/publishing/accessibility),
[announcement](https://devforum.roblox.com/t/introducing-accessibility-settings/2723187)).

**Gap.** The tiles about to be left behind were marked by a blinking **red** plate on orange and brown tiles, the
hardest pairing for red-green colour blindness, and the core skill of the game is reading those tiles. The game also
had a lot of motion (camera shake, FOV kick, speed streaks, tile wobble, blinking) and ignored Reduce Motion.

**Built.**
- Every warning plate shows a dark ⚠ with a white outline while it warns, so the cue is a shape as well as a colour.
- With Reduce Motion on: no eruption camera shake, no FOV kick, no speed streaks and no wobble on crumbling tiles (the
  cracks still show). Warning plates and the meter's danger state stay steady instead of blinking.

**Verified.** Studio play test:
- `ReducedMotionEnabled` reads fine on the client (off by default).
- All 81 plates got a mark, and up to 30 lit up when a ring was about to be left behind.
- Over about 6,200 samples, each mark was on exactly when its plate showed (0 mismatches).
- The console showed no errors, and Studio matches the repo byte for byte.

Not verified: the Reduce Motion "on" path, because the setting is the player's own Roblox menu toggle and can't be
set from a script. It needs a hands-on check: turn on Reduce Motion in the Roblox menu during a play test.

## 4. Personal best height

**Research.** Kids like floor-is-lava games because they're easy to pick up and the lava keeps rising, pushing you
higher ([Pabau](https://mgmt.pabau.com/news/the-floor-is-lava-on-roblox)). Retention advice for Roblox says new
players need quick proof that the game is worth continuing, and that drop-off often follows a run of losses
([Opper roundtable](https://opper.ai/ai-roundtable/questions/how-can-i-improve-my-roblox-gamess-play-through-and-deep-029bbec3)).
Visible progress keeps coming up as a top draw (see entry 1). In an elimination game most rounds end in a loss, so the
progress has to show even when you lose.

**Gap.** The result card showed "Height N" each round, but nothing remembered it, so a kid who got higher than ever
before got the same "💀 SCORCHED" as a bad round.

**Built.** Your best height is saved (BestHeight). Beating it:
- adds a line to the result card: "🏅 NEW BEST! 82 (was 46)", or "🏅 First best: 46. Beat it next round!";
- pays +10 coins (CFG.BestCoins);
- plays a chime.

Other rounds show "Your best: N". During a round, a gold 🏅 line on the climb meter marks the height to beat, and
climbing past it pops a "🏅 NEW BEST!" over your character. Best heights are capped at the crown, so the bonus can't be
farmed.

**Verified.** Studio play test with two real rounds driven by a test script:
- round 1 → "SCORCHED h=46 best=46 new=true prev=0", 16 coins including the bonus;
- round 2 → "h=82 best=82 new=true prev=46", 22 coins.

The BestHeight attribute updated to 82, the PersonalBest analytics event fired twice, and the console showed no
errors. Script contents in Studio match the repo byte for byte (chunk hashes). The size check caught a patch bug: real
line breaks inside three repo strings. Studio was correct and the repo was fixed. Not verified: the meter marker and
the mid-round cheer, because Studio was in the background and the client rendered no frames. These need a hands-on
look.

## 3. Weekly Top Climbers board

**Research.** Leaderboards in the lobby are one of the most common retention tools in Roblox games: seeing who is
ahead makes players want to catch up, and a top spot is a badge of honour
([creation.dev](https://www.creation.dev/glossary/leaderboard),
[RoLearn](https://rolearn.dev/guidance/player-engagement-retention),
[RoWatcher](https://rowatcher.com/news/how-top-roblox-games-keep-players-coming-back-retention-mechanics-that-work)).
The common warning is that all-time boards get taken over by early players and whoever plays the most, which puts new
players off. In round-based party games like Violent Party, the standings between rounds are part of the fun
([allthings.how](https://allthings.how/how-to-play-violent-party-on-roblox-full-minigame-guide/)).

**Gap.** The lobby's "Top Climbers" board only ranked the players in the current server by all-time crowns. Kids
never saw a wider ranking, and the board was never a goal that a new player could reach.

**Built.** The board is now "🏆 Weekly Top Climbers": crowns won this week across all servers, saved to an
OrderedDataStore with one scope per week. It merges in the climbers in the current server, so a new crown shows up
within seconds. It also shows "⏳ New week in Xd Yh" and resets every Monday 00:00 UTC, so every kid gets a fresh shot.
When the data store is down (or in Studio) it falls back to the server's own climbers. Nothing is paid; only crowns
count.

**Verified.** Studio play test: the empty board showed "Win a round to get on the board!" and the right countdown to
Monday. A test driver kept the test player on safe tiles through a full real round, and the server crowned them. The
board then showed the player at #1 with 👑 1. The console showed no errors. Script sizes in Studio matched the repo
(Rules 8595, LavaService 140159). The cross-server data store part only runs in a live server, so it still needs
checking after publishing.

## 2. Emotes (wave, cheer, laugh, point, two dances)

**Research.** Kids use emotes to celebrate a win, greet friends and joke around without typing, and victory
animations are one of the things Roblox itself teaches as a "feel good" moment
([GeekChamp](https://geekchamp.com/?p=239646),
[Roblox build-it-play-it: victory animation](https://developer.roblox.com/resources/build-it-play-it/2020summer/tier-2/overview)).
On phones and tablets typing `/e dance` is awkward, so most young players never find emotes at all.

**Gap.** LAVA Floors had no emote button, and winning the crown had no character reaction.

**Built.** A "😀 Emotes" top bar pill opens a panel with six free emotes (Roblox's own default animations): Wave,
Cheer, Laugh, Point, Dance and Groove. The two dances loop until you move. Winning the crown plays a cheer
automatically. Nothing is sold; all six are free for everyone.

**Verified.** Studio play test: the panel has all six buttons. After a server-sent Crown event for the player, the
cheer track (rbxassetid://507770677) was playing on the character. The console showed no errors. The script size in
Studio matched the repo (37545 bytes).

## 1. Pick the winner (knocked-out players stay in the game)

**Research.** Parent guides and player-behaviour articles keep coming back to the same draws: playing with friends,
quick "one more round" games, visible progress (coins, badges, unlockables), self-expression, and constant novelty
(updates, codes) ([Romper](https://www.romper.com/parenting/why-kids-like-roblox-problem-solving-creativity),
[Playgama](https://playgama.com/blog/2025/07/10/why-do-children-enjoy-playing-roblox-so-much/),
[Screenwise](https://screenwiseapp.com/guides/popular-roblox-games)). Round-based retention write-ups suggest giving
eliminated players something to do, such as letting spectators predict who survives, and point to "zero incentive" and
"not feeling rewarded" as reasons players leave
([RoWatcher](https://rowatcher.com/news/how-top-roblox-games-keep-players-coming-back-retention-mechanics-that-work),
[DevForum](https://devforum.roblox.com/t/feedback-on-my-first-round-based-game/1200079)).

**Gap.** LAVA Floors already covers friends (invite deal, Duos), short rounds, progression (coins, titles, challenges,
pass) and novelty (twist vote, events, codes). In an elimination game most players spend most of a round knocked out,
and they had nothing to do but watch.

**Built.** While knocked out, a glass "🔮 Who will win?" card lists the climbers still standing (players and bots).
One free pick per round; if that climber wins, +15 coins (CFG.PredictCoins). No stake, so it's not gambling. The server
only accepts picks from players who are out, for someone still in, once per round.

**Verified.** 3-player Studio test: Player1 was knocked out, picked Player2 from the card's contenders, got the pick
notice, and when Player2 won got "You called it! +15 coins". A solo test showed your own name could appear for a moment
after a knock-out (the server rejected it); the client now filters it out.
