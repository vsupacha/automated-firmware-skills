#!/usr/bin/env python3
"""Stage 9 (M2 layer check): check the layering rules of docs/board-api.md in app sources.

Usage:
  python check_layers.py <app-dir> [<dir> ...]

Several dirs are checked as one tree (e.g. a template plus templates/_common). Layers by folder:
  board/, shared/   board layer - the only place for vendor headers, vendor calls, BOARD_xxx #ifs
  func/             logic layer - C library (or <Arduino.h> in Arduino skills), its own headers,
                    board-layer headers (board.h)
  <root>/*.c|cpp|h  execution layer (main, app_main) in a folder that has board/ or func/ - may
                    also use func/ and its own headers
Everything else (generated mx/, BSPs, libs, build outputs, vendor projects) is not ours: skipped.

Rules: no vendor headers or vendor API calls in func/ or the execution layer; no upward includes
(board -> func/exec, func -> exec); no #if/#ifdef on BOARD_xxx in func/ (warning in the
execution layer - prefer a board.h capability function).

Exit 0 "LAYERS: PASS", 2 "LAYERS: PASS with warnings", 1 "LAYERS: FAIL", 10 milestone inactive.
"""
import os
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]

SKIP_DIRS = {"build", "libs", "mx", ".mx", ".pio", "mtb_shared", "bsps", "logs", ".git",
             "GeneratedSource", "deps", "backup", ".cache", ".bench", "tests"}
SRC_EXT = {".c", ".cc", ".cpp", ".h", ".hpp"}
BOARD_DIRS = {"board", "shared"}

STD_HEADERS = set("""
assert.h complex.h ctype.h errno.h fenv.h float.h inttypes.h iso646.h limits.h locale.h math.h
setjmp.h signal.h stdalign.h stdarg.h stdatomic.h stdbool.h stddef.h stdint.h stdio.h stdlib.h
stdnoreturn.h string.h tgmath.h threads.h time.h uchar.h wchar.h wctype.h
cassert cctype cerrno cfloat cinttypes climits cmath cstdarg cstdbool cstddef cstdint cstdio
cstdlib cstring ctime algorithm array atomic bitset functional limits memory new numeric
optional string string_view tuple type_traits utility vector
""".split())
# Platform APIs allowed in every layer: <Arduino.h> is the portable layer of Arduino skills (millis,
# Print/Stream, strings) the way the C library is for C skills. Pin I/O and the choice of the
# Serial port stay in board/ (VENDOR_CALL below).
STD_HEADERS |= {"Arduino.h"}

# vendor APIs that belong in board/ only (ModusToolbox PDL/HAL/BSP, STM32 HAL/LL + CubeMX2
# generated getters, arduino-pico / Arduino, pico-sdk GPIO)
VENDOR_CALL = re.compile(
    r"\b(?:Cy_\w+|cyhal_\w+|cybsp_\w+|HAL_\w+|LL_\w+|mx_\w+|"
    r"digitalWrite|digitalRead|pinMode|analogRead|analogWrite|"
    r"gpio_(?:init|put|get|set_dir|pull_up|pull_down)\w*)\s*\(|\bSerial\d?\s*\.")
INCLUDE = re.compile(r'^\s*#\s*include\s*([<"])([^>"]+)[>"]')
COND = re.compile(r"^\s*#\s*(?:if|ifdef|ifndef|elif)\b(.*)")
BOARD_MACRO = re.compile(r"\bBOARD_[A-Z0-9_]+")
COMMENT_OR_STRING = re.compile(r'//[^\n]*|/\*.*?\*/|"(?:\\.|[^"\\\n])*"|\'(?:\\.|[^\'\\\n])*\'', re.S)


def milestone_gate():
    active = os.environ.get("FW_ACTIVE_MILESTONES")
    if active is None:
        try:
            text = (REPO_ROOT / "milestones.env").read_text(encoding="utf-8")
        except OSError:
            text = ""
        m = re.search(r'^ACTIVE_MILESTONES="?([^"#\n]*)', text, re.M)
        active = m.group(1).strip() if m else ""
    if "M2" not in active.split():
        print(f"ACTION: SETUP check_layers.py (stage 9 layer check) belongs to milestone M2, which is not "
              f"active in this release (active: {active or 'none'}). Enabling it is the developer's decision: "
              f"add M2 to ACTIVE_MILESTONES in {REPO_ROOT / 'milestones.env'}, or export "
              f'FW_ACTIVE_MILESTONES="{(active + " ") if active else ""}M2" for one session')
        sys.exit(10)


def walk(top):
    for dirpath, dirnames, filenames in os.walk(top):
        dirnames[:] = sorted(d for d in dirnames if d not in SKIP_DIRS)
        for f in sorted(filenames):
            p = Path(dirpath) / f
            if p.suffix in SRC_EXT:
                yield p


def main(argv):
    if not argv or argv[0] in ("-h", "--help"):
        print(__doc__.strip())
        return 0 if argv else 1
    milestone_gate()
    tops = [Path(a).resolve() for a in argv]
    for t in tops:
        if not t.is_dir():
            print(f"ERROR: no folder {t}", file=sys.stderr)
            return 1

    # roots = folders (relative to their top) holding a board/ or func/ folder
    files = []          # (path, top, rel)
    roots = set()
    for t in tops:
        for p in walk(t):
            rel = p.relative_to(t)
            if t.name in BOARD_DIRS | {"func"}:      # checking a func/ or board/ folder itself
                rel = Path(t.name) / rel
            files.append((p, t, rel))
            parts = rel.parts[:-1]
            for i, part in enumerate(parts):
                if part in BOARD_DIRS | {"func"}:
                    roots.add(Path(*parts[:i]) if i else Path("."))

    def layer(rel):
        dirs = rel.parts[:-1]
        if "func" in dirs:
            return "func"
        if BOARD_DIRS & set(dirs):
            return "board"
        if rel.parent in roots:
            return "exec"
        return None

    by_suffix = {}
    for p, _, rel in files:
        by_suffix.setdefault(p.name, []).append(p)
    layer_of = {p: layer(rel) for p, _, rel in files}

    def resolve(src, name):
        cand = (src.parent / name).resolve()
        if cand in layer_of:
            return cand
        norm = "/" + name.replace("\\", "/").lstrip("./")
        for p in by_suffix.get(Path(name).name, []):
            if p.as_posix().endswith(norm):
                return p
        return None

    allowed = {"func": {"func", "board"}, "exec": {"exec", "func", "board"}, "board": {"board"}}
    fails, warns, counts = [], [], {"board": 0, "func": 0, "exec": 0}

    for p, t, rel in files:
        lay = layer_of[p]
        if lay is None:
            continue
        counts[lay] += 1
        where = f"{t.name}/{rel.as_posix()}"
        text = p.read_text(encoding="utf-8", errors="replace")
        for n, line in enumerate(text.splitlines(), 1):
            m = INCLUDE.match(line)
            if m:
                kind, name = m.groups()
                base = name.replace("\\", "/").split("/")[-1]
                if kind == "<" and lay != "board":
                    if base not in STD_HEADERS and name not in STD_HEADERS:
                        fails.append(f"{where}:{n}: {lay} includes <{name}> - vendor/system header, only board/ may use it")
                elif kind == '"':
                    target = resolve(p, name)
                    tlay = "board" if base == "board.h" and target is None else (layer_of.get(target) if target else None)
                    if tlay is None:
                        if lay != "board":
                            fails.append(f'{where}:{n}: {lay} includes "{name}" - not part of the app layers '
                                         f"(vendor/generated header), only board/ may use it")
                    elif tlay not in allowed[lay]:
                        fails.append(f'{where}:{n}: {lay} includes "{name}" from the {tlay} layer - '
                                     f"dependencies point downward only (exec > func > board)")
                continue
            m = COND.match(line)
            if m and lay != "board":
                macros = sorted(set(BOARD_MACRO.findall(m.group(1))))
                if macros:
                    msg = f"{where}:{n}: {lay} has #if on {', '.join(macros)} - board differences go in board/"
                    (fails if lay == "func" else warns).append(msg)
        if lay != "board":
            code = COMMENT_OR_STRING.sub(lambda mm: re.sub(r"[^\n]", " ", mm.group(0)), text)
            for n, line in enumerate(code.splitlines(), 1):
                for m in VENDOR_CALL.finditer(line):
                    fails.append(f"{where}:{n}: {lay} calls {m.group(0).rstrip('(').strip()} - vendor API, wrap it in board/")

    summary = f"{counts['board']} board, {counts['func']} func, {counts['exec']} exec files"
    for f in fails:
        print(f"FAIL {f}")
    for w in warns:
        print(f"WARN {w}")
    if counts["func"] + counts["exec"] == 0:
        print(f"LAYERS: FAIL (no func/ or execution-layer sources found under {', '.join(map(str, tops))})")
        return 1
    if fails:
        print(f"LAYERS: FAIL ({len(fails)} violations, {len(warns)} warnings; {summary})")
        return 1
    if warns:
        print(f"LAYERS: PASS with warnings ({len(warns)}; {summary})")
        return 2
    print(f"LAYERS: PASS ({summary})")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
