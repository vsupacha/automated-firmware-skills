"""Shared Stage 8 (test) engine: data-driven serial test runner for every skill.

Each skill has a thin scripts/serial_test.py that calls run(cfg) with its own port lookup:
  cfg = {skill_dir, env_prefix (PSE84|PICO|CUBE), serial_key (bench variable with the USB serial of
         the console), serial_env (env override suffix), vid_key, default_vid (hex), title}


Usage:
  python serial_test.py <port|auto> <spec.json> <log> [--board ID] [--sync | --wait-boot]
         [--boot-timeout S] [--wait-port S] [--interactive | --only-interactive]

Port "auto" (needs --board) = the COM port whose USB serial is the bench serial of this board
(bench file written by discover.sh, or <PREFIX>_<serial_env>). With --board, the INFO line must
report board=<ID>.

Modes (how the runner knows the app is up):
  --sync (default)  run AFTER flash.sh: send the sync command every second until the
                    expected reply arrives (boot-timeout). Works after a power cycle too.
  --wait-boot       start BEFORE flashing: passively wait for the boot marker (sees the banner).
  --wait-port S     first wait up to S seconds for the COM port to (re)appear (USB replug).

spec.json keys:
  baud                       default 115200
  boot   {expect, timeout}   boot marker for --wait-boot (e.g. "READY")
  sync   {send, expect}      for --sync (e.g. "info" -> "READY")
  steps  list of:
    name         label in the log
    send         line to send (CR appended)
    expect       list of substrings that must all appear (any order)
    expect_re    list of regexes that must all match some line
    timeout      seconds to wait for expectations (default 2)
    pause        seconds to wait after the step (default 0.3)
    interactive  true = needs a human; runs only with --interactive/--only-interactive
    prompt       text shown to the human; {btn1} {btn2} ... are replaced by the board's
                 BTN_LABELS (boards/<id>/<skill>/board.env), e.g. "SW2"
    requires_re  skip the step unless a line received so far (e.g. the INFO line) matches,
                 e.g. "leds=[2-9]" - use for board capabilities
--only REGEX runs just the steps whose name matches (e.g. --only "BTN1").
Exit 0 = all non-skipped steps PASS.
"""
import argparse
import atexit
import json
import os
import re
import shutil
import socket
import sys
import time
from pathlib import Path

import serial
from serial.tools import list_ports


def _pid_alive(pid):
    if os.name == "nt":             # os.kill(pid, 0) would TERMINATE the process on Windows
        import ctypes
        k32 = ctypes.WinDLL("kernel32", use_last_error=True)
        h = k32.OpenProcess(0x1000, False, pid)          # PROCESS_QUERY_LIMITED_INFORMATION
        if not h:
            return ctypes.get_last_error() == 5          # access denied = exists
        code = ctypes.c_ulong()
        k32.GetExitCodeProcess(h, ctypes.byref(code))
        k32.CloseHandle(h)
        return code.value == 259                         # STILL_ACTIVE
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        return False
    except PermissionError:
        return True
    return True


def bench_lock(bench_dir, board_id, tool):
    """Exclusive use of this PC's board - same protocol as bench_lock in lib/common.sh."""
    if os.environ.get("FW_BENCH_LOCK_HELD") == board_id:
        return
    d = Path(bench_dir) / f"{board_id}.lock"
    host = socket.gethostname()
    d.parent.mkdir(parents=True, exist_ok=True)
    try:
        d.mkdir()
    except FileExistsError:
        try:
            text = (d / "owner").read_text(encoding="utf-8")
        except OSError:
            text = ""
        owner = dict(line.split("=", 1) for line in text.splitlines() if "=" in line)
        pid = owner.get("pid", "")
        if owner.get("host", "").lower() == host.lower() and pid.isdigit() and _pid_alive(int(pid)):
            sys.exit(f"ERROR: board '{board_id}' is in use: {' '.join(text.split())}\n"
                     f"       Wait until that run ends and re-run. If no such run exists any more, delete {d}")
        print(f"NOTE: replacing a stale lock of board '{board_id}' ({' '.join(text.split())})")
        shutil.rmtree(d, ignore_errors=True)
        d.mkdir()
    (d / "owner").write_text(f"host={host}\npid={os.getpid()}\ntool={tool}\n"
                             f"since={time.strftime('%Y-%m-%d %H:%M:%S')}\n", encoding="utf-8", newline="\n")
    os.environ["FW_BENCH_LOCK_HELD"] = board_id

    def release():
        try:
            if f"pid={os.getpid()}\n" in (d / "owner").read_text(encoding="utf-8"):
                shutil.rmtree(d, ignore_errors=True)
        except OSError:
            pass
    atexit.register(release)



def run(cfg):
    SKILL_DIR = Path(cfg["skill_dir"]).resolve()
    REPO_ROOT = SKILL_DIR.parent.parent
    P = cfg["env_prefix"]
    BOARDS_DIR = Path(os.environ.get(f"{P}_BOARDS_DIR") or REPO_ROOT / "boards")

    ap = argparse.ArgumentParser(description=cfg["title"])
    ap.add_argument("port")
    ap.add_argument("spec")
    ap.add_argument("log")
    ap.add_argument("--board")
    mode = ap.add_mutually_exclusive_group()
    mode.add_argument("--sync", action="store_true")
    mode.add_argument("--wait-boot", action="store_true")
    mode.add_argument("--no-wait-boot", action="store_true", help=argparse.SUPPRESS)  # old name of --sync
    ap.add_argument("--boot-timeout", type=float)
    ap.add_argument("--wait-port", type=float, default=0)
    inter = ap.add_mutually_exclusive_group()
    inter.add_argument("--interactive", action="store_true")
    inter.add_argument("--only-interactive", action="store_true")
    ap.add_argument("--only", metavar="REGEX", help="run only steps whose name matches REGEX")
    args = ap.parse_args()
    # release scope: stage 8 (test) is milestone M3 (<repo>/milestones.env, FW_ACTIVE_MILESTONES)
    active = os.environ.get("FW_ACTIVE_MILESTONES")
    if active is None:
        conf = REPO_ROOT / "milestones.env"
        text = conf.read_text(encoding="utf-8") if conf.is_file() else ""
        m = re.search(r'^ACTIVE_MILESTONES="?([^"#\n]*)', text, re.M)
        active = m.group(1).strip() if m else ""
    if "M3" not in active.split():
        print(f"ACTION: SETUP serial_test.py (stage 8 test) belongs to milestone M3, which is not active in this "
              f"release (active: {active or 'none'}). Enabling it is the developer's decision: add M3 to "
              f"ACTIVE_MILESTONES in {REPO_ROOT / 'milestones.env'}, or export FW_ACTIVE_MILESTONES for one session")
        sys.exit(10)
    interactive = args.interactive or args.only_interactive
    spec = json.load(open(args.spec, encoding="utf-8"))
    boot = spec.get("boot", {})


    def read_env(path):
        vals = {}
        if path and Path(path).is_file():
            for line in Path(path).read_text(encoding="utf-8").splitlines():
                m = re.match(r'\s*([A-Z_][A-Z0-9_]*)=("([^"]*)"|[^#\s]*)', line)
                if m:
                    vals[m.group(1)] = m.group(3) if m.group(3) is not None else m.group(2)
        return vals


    board = {}
    if args.board:
        # same rules as env.sh: workspace = <repo>/apps inside the repo checkout, else ./apps;
        # board profiles from <project>/boards first, then the repo's boards
        cwd = Path.cwd().resolve()
        root = REPO_ROOT if cwd == REPO_ROOT or REPO_ROOT in cwd.parents else cwd
        ws = Path(os.environ.get(f"{P}_WS") or root / "apps")

        def profile(board_id):
            for d in (ws.parent / "boards", BOARDS_DIR):
                f = d / board_id / SKILL_DIR.name / "board.env"
                if f.is_file():
                    return f
            return None

        own = read_env(profile(args.board))
        if own.get("BOARD_EXTENDS"):   # parent profile first, this board overrides it
            board = read_env(profile(own["BOARD_EXTENDS"]))
        board.update(own)
        bench = Path(os.environ.get(f"{P}_BENCH_DIR") or ws / ".bench") / f"{args.board}.env"
        board.update(read_env(bench))
        bench_lock(bench.parent, args.board, "serial_test.py")
        if os.environ.get(f"{P}_{cfg['serial_env']}"):
            board[cfg["serial_key"]] = os.environ[f"{P}_{cfg['serial_env']}"]
    labels = [s.strip() for s in board.get("BTN_LABELS", "").split(",") if s.strip()]

    t0 = time.monotonic()
    log = open(args.log, "w", encoding="utf-8", newline="")


    def note(msg, echo=True):
        line = f"[{time.monotonic() - t0:8.3f}] {msg}"
        log.write(line + "\n")
        log.flush()
        if echo:
            print(line, flush=True)


    def resolve_port():
        if args.port.lower() != "auto":
            return args.port
        serial_no = board.get(cfg["serial_key"], "").upper()
        if not serial_no:
            sys.exit(f"port auto: no {cfg['serial_key']} for this board - run discover.sh or pass --board")
        vid = int(board.get(cfg["vid_key"], cfg["default_vid"]), 16)
        for p in list_ports.comports():
            if p.vid == vid and (p.serial_number or "").upper() == serial_no:
                return p.device
        return None


    def finish(results, extra=""):
        ran = [r for r in results if r[1] is not None]
        passed = sum(1 for r in ran if r[1])
        verdict = "PASS" if ran and passed == len(ran) else "FAIL"
        note(f"RESULT: {verdict} ({passed}/{len(ran)} passed, {len(results) - len(ran)} skipped){extra}")
        sys.exit(0 if verdict == "PASS" else 1)


    class Reader:
        def __init__(self, s):
            self.s, self.buf, self.seen = s, b"", []

        def lines(self, timeout):
            end = time.monotonic() + timeout
            while time.monotonic() < end:
                self.buf += self.s.read(256)
                while b"\n" in self.buf:
                    raw, self.buf = self.buf.split(b"\n", 1)
                    text = raw.decode("utf-8", "replace").replace("\r", "").rstrip()
                    note("RX " + text, echo=False)
                    self.seen.append(text)
                    yield text

        def wait_for(self, plain=(), regex=(), timeout=2.0, ignore=None):
            """Wait until every fragment/regex has been seen; lines equal to `ignore` (echo) skipped."""
            todo_p, todo_r = list(plain), [re.compile(r) for r in regex]
            for text in self.lines(timeout):
                if ignore is not None and text.strip() == ignore:
                    continue
                todo_p = [p for p in todo_p if p not in text]
                todo_r = [r for r in todo_r if not r.search(text)]
                if not todo_p and not todo_r:
                    return True, []
            return False, todo_p + [r.pattern for r in todo_r]


    results = []
    # 0. port (optionally wait for it to come back after a USB replug)
    port = resolve_port()
    deadline = time.monotonic() + args.wait_port
    while args.wait_port and time.monotonic() < deadline:
        port = resolve_port()
        if port and port in [p.device for p in list_ports.comports()]:
            break
        time.sleep(0.5)
    if not port:
        note("FAIL: console port not found (board connected? discover.sh run?)")
        finish([("port", False)])

    try:
        with serial.Serial(port, int(spec.get("baud", 115200)), timeout=0.05) as s:
            rd = Reader(s)
            note(f"open {port} spec={args.spec} board={args.board or '-'} interactive={interactive}")
            if args.wait_boot:
                tmo = args.boot_timeout or float(boot.get("timeout", 120))
                note(f"waiting up to {tmo:.0f}s for boot marker {boot.get('expect')!r} (flash now)")
                ok, _ = rd.wait_for([boot["expect"]], timeout=tmo)
            else:
                sync = spec.get("sync", {"send": "info", "expect": boot.get("expect", "READY")})
                tmo = args.boot_timeout or 60.0
                note(f"sync: sending {sync['send']!r} every 1s until {sync['expect']!r} (up to {tmo:.0f}s)")
                ok, end = False, time.monotonic() + tmo
                while not ok and time.monotonic() < end:
                    s.write((sync["send"] + "\r").encode())
                    ok, _ = rd.wait_for([sync["expect"]], timeout=1.0)
            note(("PASS" if ok else "FAIL") + " boot/sync")
            results.append(("boot", ok))
            if ok and args.board:
                same = any(re.search(rf"\bboard={re.escape(args.board)}\b", t) for t in rd.seen)
                if not same:   # INFO may have scrolled before sync; ask once more
                    s.write(b"info\r")
                    same, _ = rd.wait_for(regex=[rf"\bboard={re.escape(args.board)}\b"], timeout=2)
                note(("PASS" if same else "FAIL") + f" running image reports board={args.board}")
                results.append(("board identity", same))
                ok = ok and same
            if ok:
                time.sleep(0.2)
                for st in spec["steps"]:
                    name = st.get("name", st.get("send", "?"))
                    if args.only_interactive and not st.get("interactive"):
                        continue
                    if args.only and not re.search(args.only, name):
                        continue
                    req = st.get("requires_re")
                    if req and not any(re.search(req, t) for t in rd.seen):
                        note(f"SKIP {name} (board lacks: {req})")
                        results.append((name, None))
                        continue
                    if st.get("interactive") and not interactive:
                        note(f"SKIP {name} (interactive)")
                        results.append((name, None))
                        continue
                    s.reset_input_buffer()
                    rd.buf = b""
                    if st.get("prompt"):
                        prompt = st["prompt"]
                        for i in range(1, 9):
                            lab = labels[i - 1] if i <= len(labels) else f"BTN{i}"
                            prompt = prompt.replace(f"{{btn{i}}}", lab)
                        note(f"ACTION >>> {prompt} (within {st.get('timeout', 2)}s)")
                    if "send" in st:
                        note(f"TX {st['send']!r}")
                        s.write((st["send"] + "\r").encode())
                    ok, missing = rd.wait_for(st.get("expect", []), st.get("expect_re", []),
                                              float(st.get("timeout", 2)), ignore=st.get("send"))
                    note(("PASS " if ok else "FAIL ") + name + ("" if ok else f"  missing={missing}"))
                    results.append((name, ok))
                    time.sleep(float(st.get("pause", 0.3)))
    except serial.SerialException as e:
        note(f"FAIL: serial port error: {e} (port lost during USB replug, or opened by another program?)")
        results.append(("serial port", False))

    finish(results)
