# Improvement log

One entry per improvement-loop iteration: what the research said players and kids like, what was built, and how it
was checked. Newest first.

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
