#!/usr/bin/env python3
"""Bring-up demo levels in the READMEs, generated from boards/index.json (the single source).

Writes / checks two places:
  boards/README.md        the "Board | Skill | hello-world | blink | push-to-light" table, between
                          <!-- board-status:begin --> and <!-- board-status:end --> markers
  boards/<id>/README.md   the level cells of the "| Demo | Uses | `<skill>` |" table (the "Uses"
                          column stays hand-written)
A template missing from a profile's "templates" shows as "not built yet"; a template listed in the
profile's "renamed" map (verified under an earlier template name) gets a " *" footnote mark.

Usage: python tools/board_status.py            check only: "STATUS: IN SYNC" (exit 0) or the
                                                differences + "STATUS: OUT OF SYNC" (exit 1)
       python tools/board_status.py --write    rewrite the tables, then "STATUS: WRITTEN n file(s)"
tools/validate_skills.py runs the check. Update the levels in boards/index.json (from the dated
verification log lines), then --write.
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BOARDS = ROOT / "boards"
DEMOS = ["hello-world", "blink", "push-to-light"]
BEGIN, END = "<!-- board-status:begin -->", "<!-- board-status:end -->"


def cell(profile, demo):
    level = profile.get("templates", {}).get(demo, "not built yet")
    return level + (" *" if demo in profile.get("renamed", {}) else "")


def overview(index):
    rows = ["| Board | Skill | " + " | ".join(DEMOS) + " |", "| --- | --- | " + " | ".join("---" for _ in DEMOS) + " |"]
    for b in index["boards"]:
        for skill, p in b["profiles"].items():
            rows.append(f"| [{b['name']}]({b['id']}/README.md) | `{skill}` | " + " | ".join(cell(p, d) for d in DEMOS) + " |")
    return "\n".join(rows)


def fix_overview(text, index):
    """text with the generated table between the markers (None if the markers are missing)"""
    m = re.search(re.escape(BEGIN) + r"\n(.*?)\n" + re.escape(END), text, re.S)
    if not m:
        return None
    return text[:m.start(1)] + overview(index) + text[m.end(1):]


def fix_board(text, board):
    """text with the level cells of the board README's demo table set from the index"""
    lines = text.split("\n")
    for i, ln in enumerate(lines):
        if ln.startswith("| Demo | Uses |"):
            skills = re.findall(r"`([^`]+)`", ln)
            for j in range(i + 2, len(lines)):
                parts = lines[j].split("|")
                if len(parts) < 4 or not lines[j].startswith("|"):
                    break
                demo = parts[1].strip()
                if demo not in DEMOS:
                    continue
                for k, skill in enumerate(skills):
                    p = board["profiles"].get(skill)
                    if p is not None and 3 + k < len(parts) - 1:
                        parts[3 + k] = f" {cell(p, demo)} "
                lines[j] = "|".join(parts)
            break
    return "\n".join(lines)


def plan():
    """[(path, current text, wanted text)] for every file the tables live in"""
    index = json.loads((BOARDS / "index.json").read_text(encoding="utf-8"))
    out = []
    f = BOARDS / "README.md"
    cur = f.read_text(encoding="utf-8")
    want = fix_overview(cur, index)
    out.append((f, cur, want))
    for b in index["boards"]:
        f = BOARDS / b["id"] / "README.md"
        if f.is_file():
            cur = f.read_text(encoding="utf-8")
            out.append((f, cur, fix_board(cur, b)))
    return out


def problems():
    """human-readable differences between the READMEs and boards/index.json (for the validator)"""
    msgs = []
    for f, cur, want in plan():
        rel = f.relative_to(ROOT).as_posix()
        if want is None:
            msgs.append(f"{rel}: no {BEGIN} ... {END} markers around the status table")
        elif cur != want:
            diff = [w for c, w in zip(cur.split("\n"), want.split("\n")) if c != w]
            msgs.append(f"{rel}: demo levels differ from boards/index.json ({len(diff)} line(s), e.g. {diff[:1]}) - run python tools/board_status.py --write")
    return msgs


def main():
    if "--write" in sys.argv[1:]:
        n = 0
        for f, cur, want in plan():
            if want is None:
                sys.exit(f"STATUS: FAIL {f.relative_to(ROOT).as_posix()} has no {BEGIN} / {END} markers")
            if cur != want:
                f.write_text(want, encoding="utf-8", newline="\n")
                print(f"wrote {f.relative_to(ROOT).as_posix()}")
                n += 1
        print(f"STATUS: WRITTEN {n} file(s)")
        return
    msgs = problems()
    for m in msgs:
        print(m)
    print("STATUS: OUT OF SYNC" if msgs else "STATUS: IN SYNC")
    sys.exit(1 if msgs else 0)


if __name__ == "__main__":
    main()
