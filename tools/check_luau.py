"""Flag Luau lines that start with "(" right after a line ending in something callable.

Luau reads
    local at = f()
    (p.Character :: Model):PivotTo(at)
as "f()(p.Character ...)" and refuses to load the script ("Ambiguous syntax"), which once stopped the whole lava
service. Fix by putting the cast in a local first. Lines after "then", "do", "else", "end" and similar are fine.

Usage: python tools/check_luau.py [folder]   (default: Assets/Scripts). Exits 1 if anything is found.
"""

import pathlib
import re
import sys

SAFE_ENDINGS = ("then", "do", "else", "end", "repeat", "return", "break", "continue")
CALLABLE_END = re.compile(r"[A-Za-z0-9_)\]}\"']$")
NUMBER_END = re.compile(r"(^|[^A-Za-z0-9_.])\d+(\.\d+)?$")  # a number literal can't be called
FUNCTION_HEADER_END = re.compile(r"function\s*[\w.:]*\s*\([^()]*\)(\s*:\s*[\w?<>{}, ]+)?$")  # body starts next


def code_part(line: str) -> str:
    """The line without a trailing -- comment (good enough for this check; ignores -- inside strings)."""
    in_string = None
    for i, ch in enumerate(line):
        if in_string:
            if ch == in_string and line[i - 1] != "\\":
                in_string = None
        elif ch in "\"'":
            in_string = ch
        elif line.startswith("--", i):
            return line[:i]
    return line


def check(path: pathlib.Path) -> list[str]:
    problems = []
    previous = ""
    for number, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        code = code_part(raw).rstrip()
        stripped = code.strip()
        if not stripped:
            continue
        if stripped.startswith("(") and previous and CALLABLE_END.search(previous):
            last_word = re.findall(r"[A-Za-z_]+$", previous)
            safe = (last_word and last_word[0] in SAFE_ENDINGS) or NUMBER_END.search(previous) or FUNCTION_HEADER_END.search(previous)
            if not safe:
                problems.append(f"{path}:{number}: line starts with '(' after a line ending in '{previous[-12:]}'")
        previous = stripped
    return problems


def main() -> int:
    root = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "Assets/Scripts")
    problems = []
    for path in sorted(root.rglob("*.luau")):
        problems += check(path)
    for p in problems:
        print(p)
    print(f"{len(problems)} ambiguous line(s)")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
