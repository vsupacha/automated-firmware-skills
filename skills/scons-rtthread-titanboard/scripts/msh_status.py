#!/usr/bin/env python3
"""Stage 7 (status, no debug probe): ask the running RT-Thread image about itself over the msh console.

Usage:
  python msh_status.py <port|auto> --board ID [--json FILE] [--log FILE] [--sync-timeout S]

"auto" = the COM port whose USB serial is this PC's bench PROBE_SERIAL (discover.sh writes it).
Runs only read-only built-in commands - `version`, `help`, `ps`, `free`, `list device` - and prints
the image's RT-Thread version, every exported msh command with its description (the app's own
MSH_CMD_EXPORT commands included), threads with their stack use, heap and devices.
Nothing is written to the board; the board keeps running (no halt, no reset).
Gate: "MSH: PASS" (exit 0) | "MSH: WARNINGS n" (exit 2: a thread used >= 90 % of its stack, or a
command did not finish) | "MSH: FAIL" (exit 1: no shell answered on the port).
Parsers and formats: <repo>/lib/msh.py.
"""
import argparse
import json
import os
import re
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve()
SKILL_DIR = HERE.parent.parent
REPO_ROOT = SKILL_DIR.parent.parent
sys.path.insert(0, str(REPO_ROOT / "lib"))
import fwpaths  # noqa: E402
import fwtest  # noqa: E402
import msh  # noqa: E402
import serial  # noqa: E402
from serial.tools import list_ports  # noqa: E402

PREFIX = "RTT"
STACK_WARN_PCT = 90


def read_env(path):
    vals = {}
    if path and Path(path).is_file():
        for line in Path(path).read_text(encoding="utf-8").splitlines():
            m = re.match(r'\s*([A-Z_][A-Z0-9_]*)=("([^"]*)"|[^#\s]*)', line)
            if m:
                vals[m.group(1)] = m.group(3) if m.group(3) is not None else m.group(2)
    return vals


def board_settings(board_id):
    """profile (project boards first, then the repo's) + this PC's bench file, as fwtest does"""
    boards = Path(os.environ.get(f"{PREFIX}_BOARDS_DIR") or REPO_ROOT / "boards")
    prof = None
    for d in (fwpaths.project_root() / "boards", boards):
        f = d / board_id / SKILL_DIR.name / "board.env"
        if f.is_file():
            prof = f
            break
    if prof is None:
        sys.exit(f"ERROR: unknown board '{board_id}' (no {SKILL_DIR.name}/board.env)")
    vals = read_env(prof)
    bench = fwpaths.bench_dir(PREFIX) / f"{board_id}.env"
    vals.update(read_env(bench))
    if os.environ.get(f"{PREFIX}_PROBE_SERIAL"):
        vals["PROBE_SERIAL"] = os.environ[f"{PREFIX}_PROBE_SERIAL"]
    return vals, bench.parent


def main():
    ap = argparse.ArgumentParser(description="RT-Thread msh status (version, commands, threads, heap, devices)")
    ap.add_argument("port")
    ap.add_argument("--board", required=True)
    ap.add_argument("--json", metavar="FILE", help="also write the result as JSON")
    ap.add_argument("--log", metavar="FILE", help="raw console log (default: none)")
    ap.add_argument("--sync-timeout", type=float, default=10.0)
    args = ap.parse_args()
    # release scope: board stages are milestone M1 (<repo>/milestones.env, FW_ACTIVE_MILESTONES)
    active = os.environ.get("FW_ACTIVE_MILESTONES")
    if active is None:
        conf = REPO_ROOT / "milestones.env"
        m = re.search(r'^ACTIVE_MILESTONES="?([^"#\n]*)', conf.read_text(encoding="utf-8") if conf.is_file() else "", re.M)
        active = m.group(1).strip() if m else ""
    if "M1" not in active.split():
        print(f"ACTION: SETUP msh_status.py (stage 7 status) belongs to milestone M1, which is not active "
              f"(active: {active or 'none'}) - enabling it is the developer's decision ({REPO_ROOT / 'milestones.env'})")
        sys.exit(10)

    board, bench_dir = board_settings(args.board)
    port = args.port
    if port.lower() == "auto":
        sn = board.get("PROBE_SERIAL", "").upper()
        if not sn:
            sys.exit("port auto: no PROBE_SERIAL for this board on this PC - run discover.sh first")
        vid = int(board.get("PROBE_VID", "045B"), 16)
        port = next((p.device for p in list_ports.comports()
                     if p.vid == vid and (p.serial_number or "").upper() == sn), None)
        if not port:
            print("MSH: FAIL (console port not found - board connected? discover.sh run on this PC?)")
            sys.exit(1)
    fwtest.bench_lock(bench_dir, args.board, "msh_status.py")

    log = open(args.log, "w", encoding="utf-8", newline="") if args.log else None
    t0 = time.monotonic()

    def note(msg):
        if log:
            log.write(f"[{time.monotonic() - t0:8.3f}] {msg}\n")

    warnings = []
    try:
        with serial.Serial(port, int(board.get("CONSOLE_BAUD", 115200)), timeout=0.05) as s:
            con = msh.Console(s, note)
            if not con.sync(args.sync_timeout):
                print(f"MSH: FAIL (no msh prompt on {port} within {args.sync_timeout:.0f}s - image running? baud?)")
                sys.exit(1)
            out = {}
            for key, cmd in (("version", "version"), ("help", "help"), ("ps", "ps"),
                             ("free", "free"), ("devices", "list device")):
                lines, done = con.run(cmd, timeout=3.0)
                if not done:
                    warnings.append(f"'{cmd}' did not return to the prompt within 3 s")
                out[key] = lines
    except serial.SerialException as e:
        print(f"MSH: FAIL (serial port error: {e})")
        sys.exit(1)
    finally:
        if log:
            log.close()

    result = {
        "port": port, "board": args.board,
        "version": msh.parse_version(out["version"]),
        "commands": msh.parse_help(out["help"]),
        "threads": msh.parse_ps(out["ps"]),
        "memory": msh.parse_free(out["free"]),
        "devices": msh.parse_devices(out["devices"]),
    }
    if not result["commands"]:
        warnings.append("`help` listed no commands (FINSH_USING_DESCRIPTION off, or output not recognised)")
    for th in result["threads"]:
        if th["max_used_pct"] >= STACK_WARN_PCT:
            warnings.append(f"thread {th['name']} used {th['max_used_pct']}% of its {th['stack']} B stack")

    print(f"RT-Thread {result['version'] or '(version not recognised)'} on {port}  (board {args.board})")
    print(f"commands ({len(result['commands'])}):")
    for name, desc in result["commands"].items():
        print(f"  {name:<16} {desc}")
    print(f"threads ({len(result['threads'])}):  name         pri status   stack  max used  error")
    for th in result["threads"]:
        print(f"  {th['name']:<12} {th['pri']:>3} {th['status']:<8} {th['stack']:>6} {th['max_used_pct']:>5}%    {th['error']}")
    m = result["memory"]
    if m:
        print(f"heap: total {m.get('total')} used {m.get('used')} maximum {m.get('maximum')} available {m.get('available')}")
        for p in m.get("pools", []):
            print(f"  memheap {p['name']:<12} size {p['size']} max used {p['max_used']} available {p['available']}")
    else:
        warnings.append("`free` output not recognised")
    print("devices: " + (", ".join(f"{d['name']} ({d['type']})" for d in result["devices"]) or "-"))
    if args.json:
        Path(args.json).write_text(json.dumps(result, indent=2), encoding="utf-8", newline="\n")
        print(f"json: {args.json}")
    for w in warnings:
        print(f"WARN {w}")
    if warnings:
        print(f"MSH: WARNINGS {len(warnings)}")
        sys.exit(2)
    print("MSH: PASS")


if __name__ == "__main__":
    main()
