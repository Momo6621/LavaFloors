# Improvement log

One entry per improvement-loop iteration: what the research said players and kids like, what was built, and how it
was checked. Newest first.

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
