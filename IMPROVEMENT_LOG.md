# Improvement log

One entry per improvement-loop iteration: what the research said players and kids like, what was built, and how it
was checked. Newest first.

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
