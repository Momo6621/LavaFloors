# Improvement log

One entry per improvement-loop iteration: what the research said players and kids like, what was built, and how it
was checked. Newest first.

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
