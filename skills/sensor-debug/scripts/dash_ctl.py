#!/usr/bin/env python3
"""Talk to a running sensor_dash.py from another shell (the page keeps the stream).

  dash_ctl.py cmd "info" ["led?" ...] [--gap 1.0]     send console commands, one per --gap seconds
                                                       (a console that polls its UART loses bytes
                                                       when commands arrive back to back)
  dash_ctl.py mark SW1                                 write '# mark SW1' into the raw log
  dash_ctl.py log [--tail 20] [--grep REGEX]           print the newest raw log lines
Options: --http-port 8765, --app <app-dir> (where the raw log lives; default newest apps/*/logs).
"""
import argparse
import glob
import json
import os
import re
import sys
import time
import urllib.request


def post(port, path, obj):
    req = urllib.request.Request(f"http://127.0.0.1:{port}{path}", data=json.dumps(obj).encode(),
                                 headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=5) as r:
        return r.read().decode()


def newest_log(app):
    repo_apps = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", "apps")
    pats = ([os.path.join(app, "logs", "liveview-*.log")] if app else
            ["apps/*/logs/liveview-*.log", os.path.join(repo_apps, "*", "logs", "liveview-*.log"), "liveview-*.log"])
    files = [f for p in pats for f in glob.glob(p)]
    return max(files, key=os.path.getmtime) if files else None


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--http-port", type=int, default=8765)
    ap.add_argument("--app")
    sub = ap.add_subparsers(dest="action", required=True)
    c = sub.add_parser("cmd")
    c.add_argument("commands", nargs="+")
    c.add_argument("--gap", type=float, default=1.0, help="seconds between commands (default 1.0)")
    m = sub.add_parser("mark")
    m.add_argument("name")
    lg = sub.add_parser("log")
    lg.add_argument("--tail", type=int, default=20)
    lg.add_argument("--grep")
    a = ap.parse_args()
    if a.action == "cmd":
        for i, cmd in enumerate(a.commands):
            if i:
                time.sleep(a.gap)
            print(cmd, post(a.http_port, "/cmd", {"cmd": cmd}))
    elif a.action == "mark":
        print("mark", a.name, post(a.http_port, "/mark", {"name": a.name}))
    else:
        f = newest_log(a.app)
        if not f:
            sys.exit("DASH: no raw log found")
        lines = open(f, encoding="utf-8", errors="replace").read().splitlines()
        if a.grep:
            lines = [l for l in lines if re.search(a.grep, l)]
        print(f"# {f}")
        print("\n".join(lines[-a.tail:]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
