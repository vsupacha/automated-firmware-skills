#!/usr/bin/env python3
"""Repository validator - run before every commit (and before listing the repo anywhere).

Usage:
  python tools/validate_skills.py [--quiet]

Checks
  skills    SKILL.md frontmatter (name = folder, description <= 1024 chars, no tags) and required
            sections; the standard stage scripts exist (incl. open_ide.sh + IDE_EXT/IDE_APP, stage 2d), have a shebang and LF endings; board-stage
            scripts are gated by M1; scripts/ and reference/ files named in SKILL.md exist; hello-world, blink and
            push-to-light templates with description.txt and valid tests/*.json; test specs of the
            same template agree across skills (warning)
  boards    every board has README.md and per-skill profiles (board.env + README.md) of existing
            skills; BOARD_EXTENDS targets exist; boards/index.json matches the folders, its
            evidence levels are consistent and dated in the profile log, aliases are unambiguous
  docs      relative Markdown links resolve; scripts named in docs/workflow.md exist unless the
            line says "planned"; README.md and the plugin manifest mention every skill
  manifests .claude-plugin/plugin.json + marketplace.json parse and agree
  leaks     no user paths, COM ports, probe/USB serials, private IPs or e-mail addresses in files
            git would commit (a line containing "leak-ok" is exempt)

Exit 0 "VALIDATE: PASS", 2 "VALIDATE: PASS with warnings", 1 "VALIDATE: FAIL".
"""
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
# <toolchain>-<framework>-<board>: at least three lowercase parts joined by "-"
SKILL_NAME_RE = re.compile(r"^[a-z0-9]+-[a-z0-9]+-[a-z0-9]+(-[a-z0-9]+)*$")
REQUIRED_SCRIPTS = ["env.sh", "help.sh", "check_tools.sh", "new_app.sh", "open_ide.sh", "build.sh",
                    "clean.sh"]
# stage 2d (IDE handoff): VS Code extension ids a skill may name in env.sh IDE_EXT, or a standalone
# IDE (IDE_APP=<id>, e.g. rt-thread-studio) that open_ide.sh starts itself
IDE_EXT_RE = re.compile(r"^IDE_EXT=([a-z0-9-]+\.[a-z0-9-]+)", re.M)
IDE_APP_RE = re.compile(r"^IDE_APP=([a-z0-9-]+)", re.M)
# M1 board-stage scripts (connect, flash, test): required, unless the skill's SKILL.md marks its
# "M1 bring-up (board)" row **planned** (skill with the build stages only)
BOARD_STAGE_SCRIPTS = ["discover.sh", "flash.sh", "serial_test.py"]
BOARD_GATED_SCRIPTS = ["discover.sh", "flash.sh", "backup.sh", "identity_check.sh"]
REQUIRED_SECTIONS = ["Milestones, stage numbers and developer actions", "Help menu", "Stage 1",
                     "Stage 2", "Stage 3", "Stage 4", "Stage 5", "Stage 6", "Stage 7",
                     "Reporting", "Safety rules"]
REQUIRED_TEMPLATES = ["hello-world", "blink", "push-to-light"]   # bring-up demos: UART, LED, button
LEVELS = ["unverified", "built", "flashed", "tested", "interactive", "observed"]

LEAKS = [
    ("user path", re.compile(r"(?i)\b[a-z]:[\\/]+users[\\/]+(?!<)[^\\/\s`'\"<>]+|/c/Users/(?!<)\w|"
                             r"(?<![\w.])/(?:home|Users)/(?!<)[a-z][\w.-]*/")),
    ("COM port", re.compile(r"\bCOM\d{1,3}\b")),
    ("serial number", re.compile(r"\b(?=[0-9A-F]*[A-F])(?=[0-9A-F]*\d)[0-9A-F]{16,}\b")),
    ("private IP", re.compile(r"\b(?:10\.\d{1,3}|192\.168|172\.(?:1[6-9]|2\d|3[01]))\.\d{1,3}\.\d{1,3}\b")),
    ("e-mail address", re.compile(r"\b[\w.+-]+@(?!anthropic\.com\b|github\.com\b)[\w-]+\.[\w.-]*[a-z]\b")),
]
LEAK_SKIP = {"tools/validate_skills.py"}

errors, warnings = [], []
checks = 0


def err(msg):
    errors.append(msg)


def warn(msg):
    warnings.append(msg)


def ok(cond, msg, level=err):
    global checks
    checks += 1
    if not cond:
        level(msg)
    return cond


def rel(p):
    return p.relative_to(ROOT).as_posix()


def read(p):
    return p.read_text(encoding="utf-8", errors="replace")


def frontmatter(text):
    m = re.match(r"^---\r?\n(.*?)\r?\n---\r?\n", text, re.S)
    if not m:
        return None
    fm = {}
    for line in m.group(1).splitlines():
        k, sep, v = line.partition(":")
        if sep and not line.startswith((" ", "\t")):
            fm[k.strip()] = v.strip()
    return fm


def tracked_files():
    try:
        out = subprocess.run(["git", "ls-files", "--cached", "--others", "--exclude-standard", "-z"],
                             cwd=ROOT, capture_output=True, check=True).stdout
        return sorted({ROOT / f for f in out.decode("utf-8").split("\0") if f and (ROOT / f).is_file()})
    except (OSError, subprocess.CalledProcessError):
        return sorted(p for p in ROOT.rglob("*") if p.is_file()
                      and not {".git", "apps"} & set(p.relative_to(ROOT).parts))


# ------------------------------------------------------------------------------------- skills
def check_skills():
    skills = sorted(d for d in (ROOT / "skills").iterdir() if d.is_dir())
    specs = {}                                   # (template, spec file) -> {skill: json}
    for sd in skills:
        name = sd.name
        ok(SKILL_NAME_RE.match(name), f"skills/{name}: folder name must be <toolchain>-<framework>-<board> (lowercase, '-' between parts)")
        md = sd / "SKILL.md"
        if not ok(md.is_file(), f"skills/{name}: no SKILL.md"):
            continue
        text = read(md)
        fm = frontmatter(text)
        if ok(fm is not None, f"skills/{name}/SKILL.md: no YAML frontmatter"):
            ok(fm.get("name") == name, f"skills/{name}/SKILL.md: frontmatter name '{fm.get('name')}' != folder name")
            desc = fm.get("description", "")
            ok(desc, f"skills/{name}/SKILL.md: empty description")
            ok(len(desc) <= 1024, f"skills/{name}/SKILL.md: description is {len(desc)} characters (limit 1024)")
            ok(not re.search(r"<[A-Za-z/]", desc), f"skills/{name}/SKILL.md: description contains a tag")
        heads = re.findall(r"^#{2,3} +(.+)$", text, re.M)
        for sec in REQUIRED_SECTIONS:
            ok(any(sec in h for h in heads), f"skills/{name}/SKILL.md: missing section '{sec} ...'")
        for ref in sorted(set(re.findall(r"\b((?:scripts|reference)/[\w.-]+\.(?:sh|py|md))\b", text))):
            if Path(ref).stem == "x":                   # "$SKILL/scripts/x.sh" placeholder
                continue
            ok((sd / ref).is_file(), f"skills/{name}/SKILL.md names {ref}, which does not exist")

        sc = sd / "scripts"
        for s in REQUIRED_SCRIPTS:
            ok((sc / s).is_file(), f"skills/{name}/scripts/{s} missing (standard stage script)")
        env = sc / "env.sh"
        if env.is_file():
            ok(IDE_EXT_RE.search(read(env)) is not None or IDE_APP_RE.search(read(env)) is not None,
               f"skills/{name}/scripts/env.sh: no IDE_EXT=<publisher.extension> or IDE_APP=<id> (stage 2d IDE handoff)")
            ok("IDE_NAME=" in read(env), f"skills/{name}/scripts/env.sh: no IDE_NAME (stage 2d IDE handoff)")
        if (sc / "new_app.sh").is_file():
            ok("fw_new_app_ide" in read(sc / "new_app.sh"),
               f"skills/{name}/scripts/new_app.sh does not end with stage 2d (fw_new_app_ide)")
        board_row = next((l for l in text.splitlines() if l.startswith("| M1 bring-up (board)")), None)
        ok(board_row is not None, f"skills/{name}/SKILL.md: milestone table has no '| M1 bring-up (board) |' row")
        board_planned = "**planned**" in (board_row or "")
        for s in BOARD_STAGE_SCRIPTS:
            ok((sc / s).is_file(), f"skills/{name}/scripts/{s} missing (M1 board-stage script"
               + (", planned in SKILL.md)" if board_planned else ")"), warn if board_planned else err)
        for f in sorted(sc.glob("*")):
            if f.suffix not in (".sh", ".py"):
                continue
            data = f.read_bytes()
            ok(b"\r\n" not in data, f"{rel(f)}: CRLF line endings (keep scripts LF)")
            if (f.suffix == ".sh" and f.name != "env.sh") or f.name == "serial_test.py":
                ok(data.startswith(b"#!"), f"{rel(f)}: no shebang line")
            if f.suffix == ".sh" and f.name != "env.sh":
                ok(b'. "$(dirname "$0")/env.sh"' in data, f"{rel(f)}: does not source env.sh", warn)
        for s in BOARD_GATED_SCRIPTS:
            f = sc / s
            if f.is_file():
                ok("require_milestone M1" in read(f), f"{rel(f)}: board-stage script without 'require_milestone M1'")
        st = sc / "serial_test.py"
        if st.is_file():
            ok("fwtest.run(" in read(st), f"{rel(st)}: not a wrapper of lib/fwtest.py (milestone gate lives there)")

        td = sd / "templates"
        ok((td / "_common").is_dir(), f"skills/{name}/templates/_common missing (board layer)")
        for t in REQUIRED_TEMPLATES:
            ok((td / t).is_dir(), f"skills/{name}/templates/{t} missing (shared test contract)")
        for t in sorted(d for d in td.iterdir() if d.is_dir() and d.name != "_common"):
            ok((t / "description.txt").is_file(), f"{rel(t)}: no description.txt")
            jsons = sorted((t / "tests").glob("*.json"))
            ok(jsons, f"{rel(t)}: no tests/*.json")
            for j in jsons:
                try:
                    spec = json.loads(read(j))
                except ValueError as e:
                    err(f"{rel(j)}: invalid JSON ({e})")
                    continue
                steps = spec.get("steps")
                if ok(isinstance(steps, list) and steps, f"{rel(j)}: no 'steps' list"):
                    ok(all(isinstance(s, dict) and s.get("name") for s in steps), f"{rel(j)}: a step has no name")
                specs.setdefault((t.name, j.name), {})[name] = spec

    for (tname, jname), by_skill in sorted(specs.items()):
        if len(by_skill) < 2:
            continue
        base_skill, base = next(iter(by_skill.items()))
        base_steps = {s.get("name"): s for s in base.get("steps", [])}
        for sk, spec in by_skill.items():
            if sk == base_skill:
                continue
            steps = {s.get("name"): s for s in spec.get("steps", [])}
            missing = [n for n in base_steps if n not in steps]
            extra = [n for n in steps if n not in base_steps]
            changed = [n for n in base_steps if n in steps and base_steps[n] != steps[n]]
            ok(not (missing or extra or changed),
               f"tests drift: {tname}/tests/{jname} in {sk} vs {base_skill}:"
               + (f" missing {missing}" if missing else "") + (f" extra {extra}" if extra else "")
               + (f" changed {changed}" if changed else ""), warn)
    return [s.name for s in skills]


# ------------------------------------------------------------------------------------- boards
def board_env(path):
    m = re.search(r"^BOARD_EXTENDS=([A-Za-z0-9_-]*)", read(path), re.M) if path.is_file() else None
    return m.group(1) if m else ""


def norm(s):
    return re.sub(r"[\s_-]+", "", s.lower())


def check_boards(skill_names):
    bd = ROOT / "boards"
    boards = sorted(d for d in bd.iterdir() if d.is_dir() and not d.name.startswith("_"))
    profiles = {}
    for b in boards:
        ok((b / "README.md").is_file(), f"boards/{b.name}: no README.md (hardware sheet)")
        profiles[b.name] = {}
        for p in sorted(d for d in b.iterdir() if d.is_dir()):
            if not ok(p.name in skill_names, f"boards/{b.name}/{p.name}: not a skill name"):
                continue
            ok((p / "board.env").is_file(), f"boards/{b.name}/{p.name}: no board.env")
            ok((p / "README.md").is_file(), f"boards/{b.name}/{p.name}: no README.md (verification log)")
            ok(b"\r\n" not in (p / "board.env").read_bytes() if (p / "board.env").is_file() else True,
               f"boards/{b.name}/{p.name}/board.env: CRLF line endings")
            parent = board_env(p / "board.env")
            if parent:
                ok((bd / parent / p.name / "board.env").is_file(),
                   f"boards/{b.name}/{p.name}/board.env: BOARD_EXTENDS={parent} has no {p.name} profile")
            profiles[b.name][p.name] = parent

    idx_path = bd / "index.json"
    if not ok(idx_path.is_file(), "boards/index.json missing"):
        return
    try:
        idx = json.loads(read(idx_path))
    except ValueError as e:
        err(f"boards/index.json: invalid JSON ({e})")
        return
    entries = {e.get("id"): e for e in idx.get("boards", [])}
    ok(len(entries) == len(idx.get("boards", [])), "boards/index.json: duplicate ids")
    for b in profiles:
        ok(b in entries, f"boards/index.json: board '{b}' (folder) is not listed")
    names = {}
    for bid, e in entries.items():
        if not ok(bid in profiles, f"boards/index.json: '{bid}' has no boards/{bid}/ folder"):
            continue
        for key in ("name", "mcu", "aliases", "profiles"):
            ok(e.get(key), f"boards/index.json: '{bid}' has no {key}")
        for a in [bid] + list(e.get("aliases", [])):
            names.setdefault(norm(a), set()).add(bid)
        ok(set(e.get("profiles", {})) == set(profiles[bid]),
           f"boards/index.json: '{bid}' profiles {sorted(e.get('profiles', {}))} != folders {sorted(profiles[bid])}")
        parents = {v for v in profiles[bid].values() if v}
        ok(e.get("extends", "") == (next(iter(parents)) if parents else ""),
           f"boards/index.json: '{bid}' extends '{e.get('extends', '')}' but board.env says {sorted(parents) or 'nothing'}")
        for sk, pr in e.get("profiles", {}).items():
            level, tmpl = pr.get("level"), pr.get("templates", {})
            ok(level in LEVELS, f"boards/index.json: {bid}/{sk} level '{level}' not one of {LEVELS}")
            for t, tl in tmpl.items():
                ok((ROOT / "skills" / sk / "templates" / t).is_dir(),
                   f"boards/index.json: {bid}/{sk} template '{t}' does not exist in skills/{sk}/templates")
                ok(tl in LEVELS, f"boards/index.json: {bid}/{sk}/{t} level '{tl}' not one of {LEVELS}")
            if level in LEVELS and tmpl and all(t in LEVELS for t in tmpl.values()):
                top = max(tmpl.values(), key=LEVELS.index)
                ok(level == top, f"boards/index.json: {bid}/{sk} level '{level}' but best template is '{top}'")
            log = ROOT / pr.get("log", "")
            if ok(pr.get("log") and log.is_file(), f"boards/index.json: {bid}/{sk} log '{pr.get('log')}' missing"):
                if level != "unverified":
                    ok(pr.get("date") and f"- {pr['date']}" in read(log),
                       f"boards/index.json: {bid}/{sk} date '{pr.get('date')}' has no dated line in {pr.get('log')}")
    for n, ids in sorted(names.items()):
        ok(len(ids) == 1, f"boards/index.json: name '{n}' matches several boards {sorted(ids)}")


# --------------------------------------------------------------------------------------- docs
def check_docs(files, skill_names):
    for md in [f for f in files if f.suffix == ".md"]:
        text = read(md)
        text = re.sub(r"```.*?```", "", text, flags=re.S)
        for target in re.findall(r"\[[^\]]*\]\(([^)\s]+)\)", text):
            if re.match(r"^(https?:|mailto:|#)", target):
                continue
            path = target.split("#")[0]
            ok((md.parent / path).exists(), f"{rel(md)}: broken link '{target}'")

    wf = ROOT / "docs" / "workflow.md"
    if wf.is_file():
        everything = {p.name for p in ROOT.rglob("*") if p.is_file() and ".git" not in p.parts}
        for n, line in enumerate(read(wf).splitlines(), 1):
            for script in re.findall(r"`([\w-]+\.(?:sh|py))\b", line):
                ok(script in everything or "planned" in line,
                   f"docs/workflow.md:{n}: names {script}, which does not exist and is not marked planned")
            for script in re.findall(r"`([\w-]+\.(?:sh|py))[^`]*`\s*\*\(planned\)\*", line):
                ok(script not in everything,
                   f"docs/workflow.md:{n}: {script} exists now - drop '(planned)'", warn)

    readme = read(ROOT / "README.md") if (ROOT / "README.md").is_file() else ""
    for s in skill_names:
        ok(f"skills/{s}/SKILL.md" in readme, f"README.md: skill {s} not in the skills table", warn)
        ok(f"skills/{s}/SKILL.md" in read(wf) if wf.is_file() else False,
           f"docs/workflow.md: skill {s} not in the reference table", warn)


# ---------------------------------------------------------------------------------- manifests
def check_manifests(skill_names):
    d = ROOT / ".claude-plugin"
    try:
        plugin = json.loads(read(d / "plugin.json"))
        market = json.loads(read(d / "marketplace.json"))
    except (OSError, ValueError) as e:
        err(f".claude-plugin: cannot read manifests ({e})")
        return
    ok(plugin.get("name"), ".claude-plugin/plugin.json: no name")
    entries = market.get("plugins", [])
    ok(any(p.get("name") == plugin.get("name") for p in entries),
       f".claude-plugin/marketplace.json: no plugin named '{plugin.get('name')}'")
    for p in entries:
        ok((d.parent / p.get("source", "")).resolve().is_dir(),
           f".claude-plugin/marketplace.json: source '{p.get('source')}' is not a folder")
    for s in skill_names:
        ok(s in plugin.get("description", ""), f".claude-plugin/plugin.json: description does not mention {s}", warn)


# -------------------------------------------------------------------------------------- leaks
def check_leaks(files):
    global checks
    for f in files:
        r = rel(f)
        if r in LEAK_SKIP:
            continue
        try:
            text = f.read_bytes().decode("utf-8")
        except (UnicodeDecodeError, OSError):
            continue                                        # binary
        checks += 1
        for n, line in enumerate(text.splitlines(), 1):
            if "leak-ok" in line:
                continue
            for what, rx in LEAKS:
                m = rx.search(line)
                if m:
                    err(f"{r}:{n}: looks like a {what} ({m.group(0)}) - never commit per-PC data; "
                        f"mark a deliberate example with 'leak-ok'")


def main(argv):
    quiet = "--quiet" in argv
    files = tracked_files()
    skill_names = check_skills()
    check_boards(skill_names)
    check_docs(files, skill_names)
    check_manifests(skill_names)
    check_leaks(files)
    for e in errors:
        print(f"ERROR {e}")
    if not quiet:
        for w in warnings:
            print(f"WARN  {w}")
    summary = f"{checks} checks, {len(skill_names)} skills, {len(files)} files"
    if errors:
        print(f"VALIDATE: FAIL ({len(errors)} errors, {len(warnings)} warnings; {summary})")
        return 1
    if warnings:
        print(f"VALIDATE: PASS with warnings ({len(warnings)}; {summary})")
        return 2
    print(f"VALIDATE: PASS ({summary})")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
