# Improvement log

One entry per improvement-loop iteration: what the research said players and kids like, what was built, and how it
was checked. Newest first.

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
