"""Flag messages between server and clients that the other side never handles.

The game talks over one RemoteEvent (ReplicatedStorage.ArenaEvent) using string names, so a typo or a forgotten
handler fails silently: the message is sent and nothing happens. That hid a bug for a long time: the server sent a
"Swing" effect on every shove press from the first version on, but no client handled it, so a missed shove gave no
feedback at all (IMPROVEMENT_LOG #93).

This checks three things, by name:
- actions a client sends with FireServer("Name") that no server script compares against (`action == "Name"`),
- message kinds the server sends with FireClient(p, "Name") or FireAllClients("Name") that no client compares
  against (`kind == "Name"`),
- effect kinds the server sends inside a message (`Kind = "Name"`) that no client compares against
  (`Kind == "Name"`).

Names in KNOWN are messages of the old SkySprout RPG systems that party mode doesn't use; they're reported once as
known and don't fail the check. Names built at runtime (not string literals) aren't seen.

Usage: python tools/check_remotes.py [folder]   (default: Assets/Scripts). Exits 1 if anything unknown is unhandled.
"""

import pathlib
import re
import sys

KNOWN = {"QuestReward"}  # SkySproutTowerService quest rewards; the tower RPG isn't part of party mode

SENT_ACTION = re.compile(r'FireServer\(\s*"(\w+)"')
HANDLED_ACTION = re.compile(r'action\s*[=~]=\s*"(\w+)"')
SENT_KIND = re.compile(r'FireClient\([^,()]+,\s*"(\w+)"|FireAllClients\(\s*"(\w+)"')
HANDLED_KIND = re.compile(r'\b(?:kind|k)\s*[=~]=\s*"(\w+)"')
SENT_EFFECT = re.compile(r'\bKind\s*=\s*"(\w+)"')
HANDLED_EFFECT = re.compile(r'\bKind\s*[=~]=\s*"(\w+)"')


def found(pattern: re.Pattern[str], texts: dict[pathlib.Path, str]) -> dict[str, pathlib.Path]:
    out: dict[str, pathlib.Path] = {}
    for path, text in texts.items():
        for match in pattern.finditer(text):
            name = next(g for g in match.groups() if g)
            out.setdefault(name, path)
    return out


def main() -> int:
    root = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "Assets/Scripts")
    server = {p: p.read_text(encoding="utf-8") for p in sorted((root / "Server").rglob("*.luau"))}
    client = {p: p.read_text(encoding="utf-8") for p in sorted(root.rglob("*.luau")) if "Server" not in p.parts}
    checks = [
        ("client action", found(SENT_ACTION, client), found(HANDLED_ACTION, server), "no server script handles it"),
        ("server message", found(SENT_KIND, server), found(HANDLED_KIND, client), "no client checks for it"),
        ("server effect", found(SENT_EFFECT, server), found(HANDLED_EFFECT, client), "no client checks for it"),
    ]
    bad = 0
    for what, sent, handled, why in checks:
        for name, path in sorted(sent.items()):
            if name in handled:
                continue
            if name in KNOWN:
                print(f"known: {what} \"{name}\" ({path}) is unhandled (old RPG system)")
                continue
            bad += 1
            print(f"{path}: {what} \"{name}\" is sent but {why}")
    print(f"{bad} unhandled message name(s)")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
