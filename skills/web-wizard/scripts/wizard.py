#!/usr/bin/env python3
"""Browser forms for questions that would otherwise be asked one by one in the console.

Opens a local page, waits until the user submits (or cancels / times out), prints the answers as
one JSON line and exits. Nothing is built, flashed or changed here - the agent acts on the answers
with the gated scripts of the chosen skill.

Modes:
  wizard.py project [--board <id>] [--skill <name>] [--app <name>] [--ws <apps-dir>]
        new-app wizard for the board skills of this repo: board (boards/index.json), skill (the
        board's profiles), template (the skill's templates/ with their verified level), app name,
        next step (generate + IDE | + build | + build + flash + test). "Check" runs the gates the
        scripts would run first: app name, existing app, board profile, template - and on request
        the skill's read-only check_tools.sh.
  wizard.py ask <questions.json>     generic form, AskUserQuestion-like spec:
        {"title": "...", "questions": [{"id": "q1", "header": "Scope", "question": "...",
          "multi": false, "other": true, "options": [{"label": "...", "description": "..."}]}]}

Output (stdout, last line): WIZARD: ANSWERS {json} | WIZARD: CANCELLED | WIZARD: TIMEOUT
Options: --http-port 8766  --timeout 900 (s)  --no-open  --out <file.json> (also save answers)
Binds 127.0.0.1 only. One page; the server exits after the answer.
"""
import argparse
import json
import re
import shutil
import subprocess
import sys
import threading
import time
import webbrowser
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

SKILL = Path(__file__).resolve().parent.parent
REPO = SKILL.parent.parent
APP_RE = re.compile(r"^[A-Za-z0-9_-]+$")


def text(p):
    return p.read_text(encoding="utf-8").strip() if p.is_file() else ""


def env_value(env_sh, key):
    m = re.search(rf'^{key}="?([^"\n]*)"?', text(env_sh), re.M)
    return m.group(1).strip() if m else ""


def catalog(board, skill, app, ws):
    """everything the project page needs, from the repo's live data"""
    index = json.loads(text(REPO / "boards" / "index.json") or "{}")
    skills = {}
    for sd in sorted((REPO / "skills").iterdir()):
        td = sd / "templates"
        if not td.is_dir():                         # tool skills (like this one) have no templates
            continue
        sc = sd / "scripts"
        skills[sd.name] = {
            "ide": env_value(sc / "env.sh", "IDE_NAME") or "the IDE",
            "board_stages": (sc / "flash.sh").is_file() and (sc / "discover.sh").is_file(),
            "templates": {t.name: {"description": text(t / "description.txt"),
                                   "tests": sorted(j.name for j in (t / "tests").glob("*.json"))}
                          for t in sorted(td.iterdir()) if t.is_dir() and not t.name.startswith("_")},
        }
    boards = {}
    for b in index.get("boards", []):
        profiles = {k: v for k, v in b.get("profiles", {}).items() if k in skills}
        if profiles:
            boards[b["id"]] = {"name": b.get("name", b["id"]), "mcu": b.get("mcu", ""),
                               "family": b.get("mcu_family", ""), "profiles": profiles}
    return {"boards": boards, "skills": skills, "default_board": board if board in boards else next(iter(boards), ""),
            "default_skill": skill or "", "default_app": app or "", "ws": str(ws), "levels": index.get("evidence_levels", {})}


def run_check(ws, b):
    """the gates new_app.sh checks first (read-only); check_tools.sh only when asked"""
    board, skill, app, tpl = (str(b.get(k, "")) for k in ("board", "skill", "app", "template"))
    lines, rc = [], 0

    def gate(ok, good, bad):
        nonlocal rc
        lines.append(("PASS " + good) if ok else ("BLOCKED " + bad))
        rc = rc or (0 if ok else 1)
    sd = REPO / "skills" / skill
    gate(APP_RE.match(app) is not None, f"app name '{app}'", f"app name '{app}': use letters, digits, - and _")
    target = (Path(ws) / app).as_posix()
    gate(not Path(target).exists() if app else False, f"{target} does not exist yet",
         f"{target} already exists - pick another name")
    gate((REPO / "boards" / board / skill / "board.env").is_file(), f"board profile boards/{board}/{skill}",
         f"no board profile boards/{board}/{skill}/board.env")
    gate((sd / "templates" / tpl).is_dir(), f"template {tpl}", f"skill {skill} has no template {tpl}")
    if b.get("tools") and rc == 0:
        bash = shutil.which("bash")
        if not bash:
            lines.append("ACTION: SETUP bash (Git Bash) not found - run check_tools.sh in a Git Bash terminal")
            rc = 10
        else:
            r = subprocess.run([bash, str(sd / "scripts" / "check_tools.sh"), board], cwd=REPO,
                               capture_output=True, text=True, encoding="utf-8", errors="replace")
            out = [l for l in (r.stdout + r.stderr).splitlines() if l.strip()]
            lines += [l for l in out if l.startswith(("BAD", "WARN", "missing/bad", "ACTION"))] or out[-3:]
            rc = rc or r.returncode
    return {"rc": rc, "lines": lines}


class Handler(BaseHTTPRequestHandler):
    state = None

    def log_message(self, fmt, *args):
        pass

    def _send(self, code, body, ctype="application/json"):
        data = body if isinstance(body, bytes) else json.dumps(body).encode()
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(data)

    def _body(self):
        n = int(self.headers.get("Content-Length") or 0)
        return json.loads(self.rfile.read(n) or b"{}")

    def do_GET(self):
        st = self.state
        if self.path in ("/", "/index.html"):
            return self._send(200, (SKILL / "web" / f"{st['mode']}.html").read_bytes(), "text/html; charset=utf-8")
        if self.path == "/data.json":
            return self._send(200, st["data"])
        return self._send(404, {"error": "not found"})

    def do_POST(self):
        st = self.state
        try:
            b = self._body()
        except json.JSONDecodeError as e:
            return self._send(400, {"error": str(e)})
        if self.path == "/check" and st["mode"] == "project":
            return self._send(200, run_check(st["data"]["ws"], b))
        if self.path in ("/submit", "/cancel"):
            st["result"] = ("ANSWERS", b) if self.path == "/submit" else ("CANCELLED", None)
            self._send(200, {"ok": True})
            st["done"].set()
            return None
        return self._send(404, {"error": "not found"})


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("mode", choices=["project", "ask"])
    ap.add_argument("spec", nargs="?", help="questions.json (mode ask)")
    ap.add_argument("--board")
    ap.add_argument("--skill")
    ap.add_argument("--app")
    ap.add_argument("--ws", help="apps workspace (default: <repo>/apps)")
    ap.add_argument("--http-port", type=int, default=8766)
    ap.add_argument("--timeout", type=float, default=900)
    ap.add_argument("--no-open", action="store_true")
    ap.add_argument("--out", help="also write the answers JSON to this file")
    a = ap.parse_args()
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    except AttributeError:
        pass
    if a.mode == "ask":
        if not a.spec:
            sys.exit("WIZARD: ERROR mode ask needs a questions.json")
        data = json.loads(Path(a.spec).read_text(encoding="utf-8"))
    else:
        data = catalog(a.board, a.skill, a.app, Path(a.ws).resolve() if a.ws else REPO / "apps")
    state = {"mode": a.mode, "data": data, "done": threading.Event(), "result": ("TIMEOUT", None)}
    Handler.state = state
    srv = ThreadingHTTPServer(("127.0.0.1", a.http_port), Handler)
    srv.daemon_threads = True
    threading.Thread(target=srv.serve_forever, daemon=True).start()
    url = f"http://127.0.0.1:{a.http_port}/"
    print(f"WIZARD: waiting for the answer at {url} (timeout {a.timeout:.0f} s)", flush=True)
    if not a.no_open:
        webbrowser.open(url)
    state["done"].wait(a.timeout)
    time.sleep(0.3)                       # let the page receive its reply
    srv.shutdown()
    kind, ans = state["result"]
    if kind == "ANSWERS":
        if a.out:
            Path(a.out).write_text(json.dumps(ans, indent=2, ensure_ascii=False), encoding="utf-8")
        print("WIZARD: ANSWERS " + json.dumps(ans, ensure_ascii=False), flush=True)
        return 0
    print(f"WIZARD: {kind}", flush=True)
    return 1


if __name__ == "__main__":
    sys.exit(main())
