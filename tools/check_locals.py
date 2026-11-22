"""Warn when a script's main body gets close to Luau's 200-local limit.

Luau gives each function at most 200 registers. A script's top level is one function, so every top-level `local`
(and `local function`) stays alive to the end of the file, and the locals inside a top-level `do ... end` block are
alive on top of them while the block runs. Going over makes the whole script fail to compile ("Out of local
registers when trying to allocate X: exceeded limit 200"), which once stopped the whole lava client in Studio while
the other lint passed.

This counts, per file: the top-level locals declared so far plus the most locals declared directly inside any
top-level `do` block at that point (the peak). Temporaries, loop variables and multi-line declarations also use
registers that this doesn't count, so the real limit is hit well before 200. LIMIT is calibrated on the lava client:
it compiled at a count of 162 and failed ("exceeded limit 200") at 163. Fix by moving new code into its own
function (`task.defer(function() ... end)` or a `local function` called once) or grouping state in a table, instead
of adding top-level locals.

Usage: python tools/check_locals.py [folder]   (default: Assets/Scripts). Exits 1 if any file is at or over LIMIT.
"""

import pathlib
import re
import sys

LIMIT = 163  # see above: the lava client failed to compile at this count
TOP_LOCAL = re.compile(r"^local\s+(function\s+\w+|[\w\s,:?{}<>|]+?)(\s*=|\s*$|\s*--)")
BLOCK_LOCAL = re.compile(r"^\tlocal\s+(function\s+\w+|[\w\s,:?{}<>|]+?)(\s*=|\s*$|\s*--)")


def names(declared: str) -> int:
    if declared.startswith("function"):
        return 1
    return len([n for n in declared.split(",") if n.strip()])


def peak(path: pathlib.Path) -> tuple[int, int]:
    top = 0
    block = 0
    in_block = False
    best, best_line = 0, 0
    for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        if line == "do" or line.startswith("do --"):
            in_block, block = True, 0
            continue
        if in_block and (line == "end" or line.startswith("end --")):
            in_block, block = False, 0
            continue
        m = TOP_LOCAL.match(line)
        if m:
            top += names(m.group(1))
        elif in_block:
            b = BLOCK_LOCAL.match(line)
            if b:
                block += names(b.group(1))
        if top + block > best:
            best, best_line = top + block, number
    return best, best_line


def main() -> int:
    root = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "Assets/Scripts")
    bad = 0
    for path in sorted(root.rglob("*.luau")):
        count, line = peak(path)
        if count >= LIMIT:
            bad += 1
            print(f"{path}:{line}: about {count} locals counted in the main body (fails to compile from about {LIMIT})")
    print(f"{bad} file(s) near the 200-local limit")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
