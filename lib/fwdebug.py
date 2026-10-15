#!/usr/bin/env python3
"""Shared debug engine for the board skills (stage 7 debug) - Cortex-M, any GDB server.

Two jobs, both driven by a skill's debug.sh (which knows the probe tools of its board):

  fwdebug.py decode --cpuid X --dhcsr X [--cfsr X --hfsr X --mmfar X --bfar X]
      Decode core state and fault registers read WITHOUT halting (e.g. STM32CubeProgrammer hot
      plug, pyOCD attach). Prints CORE / FAULT lines and the gate line
      "DEBUG: STATUS <running|halted|sleeping|lockup> fault=<none|...>"; exit 0 no fault, 1 fault.

  fwdebug.py run --gdb GDB --elf ELF --server "<cmd ...>" --port N --scenario S.json --log F
                 [--console PORT --baud B] [--ready-text TEXT]
      Start the GDB server (attach mode - the skill must NOT pass reset or halt-on-connect
      options), connect GDB over its machine interface (MI), check that the target runs this ELF
      (the first and last bytes of each loadable segment read back, read-only - GDB's
      compare-sections needs a qCRC the ST-LINK server answers wrongly), then run the steps. The core is halted while GDB is
      attached; whatever happens (timeout, error, Ctrl+C) the engine deletes its breakpoints,
      detaches and stops the server so the firmware runs on. It never loads, erases or resets.
      Gate: "DEBUG: PASS (n/m steps)" exit 0, "DEBUG: FAIL ..." exit 1.

Scenario JSON (steps run in order; the core is halted between steps). An app's own scenarios go
into <app>/scenarios/; keys starting with "_" (e.g. "_doc") are comments.
  {"_doc": "what this checks",
   "steps": [
    {"name": "hit cmd_led", "break": "cmd_led", "send": "led 1 on", "timeout": 5},
    {"name": "arg", "print": "argc", "expect": "3"},
    {"name": "step 2", "step": 2},
    {"name": "who writes", "watch": "g_count", "send": "info", "expect_change": true, "timeout": 5},
    {"name": "no fault", "read": "CFSR", "expect": "0x00000000"},
    {"name": "fault regs ok", "read": "0xE000ED2C", "expect_re": "^0x0+$"}
  ]}
  break    location (function, file.c:line); one-shot; continue, optionally send a console line,
           wait for the hit (timeout s, default 5) - FAIL if it is not hit
  watch    expression; one-shot write watchpoint (deleted after the step); continue (+ send), wait
           for the trigger; expect_change (default true) = the value must differ. Old/new values
           are read by the engine (the ST-LINK server reports a hit as SIGTRAP). The core stops
           a few instructions AFTER the write - possibly already in a called function - so the
           result names the stop point and its caller; the writer is usually the caller.
  print    C expression evaluated while halted; expect (exact) or expect_re against GDB's value
           text, e.g. a char* prints as 0x200001fa "on" -> "expect_re": "\"on\""
  step     N source lines (step over calls)
  read     a 32-bit word: CPUID DHCSR ICSR VTOR CFSR HFSR DFSR MMFAR BFAR, or an address
Console replies: a command sent while the core is halted runs after the next continue or the
detach; the replies printed after the detach are logged (rx) and shown as "CONSOLE after detach:".
Halting changes timing: never mix these steps with timing checks; a watchdog may reset the MCU
while it is halted (the scenario then fails on the next step).
"""
import argparse
import json
import queue
import re
import subprocess
import sys
import threading
import time

REGS = {"CPUID": 0xE000ED00, "ICSR": 0xE000ED04, "VTOR": 0xE000ED08, "CFSR": 0xE000ED28,
        "HFSR": 0xE000ED2C, "DFSR": 0xE000ED30, "MMFAR": 0xE000ED34, "BFAR": 0xE000ED38,
        "DHCSR": 0xE000EDF0}
CFSR_BITS = {0: "IACCVIOL", 1: "DACCVIOL", 3: "MUNSTKERR", 4: "MSTKERR", 5: "MLSPERR",
             8: "IBUSERR", 9: "PRECISERR", 10: "IMPRECISERR", 11: "UNSTKERR", 12: "STKERR",
             13: "LSPERR", 16: "UNDEFINSTR", 17: "INVSTATE", 18: "INVPC", 19: "NOCP",
             20: "STKOF", 24: "UNALIGNED", 25: "DIVBYZERO"}
HFSR_BITS = {1: "VECTTBL", 30: "FORCED", 31: "DEBUGEVT"}
PARTS = {0xC20: "Cortex-M0", 0xC60: "Cortex-M0+", 0xC23: "Cortex-M3", 0xC24: "Cortex-M4",
         0xC27: "Cortex-M7", 0xD20: "Cortex-M23", 0xD21: "Cortex-M33", 0xD22: "Cortex-M55",
         0xD23: "Cortex-M85", 0xD24: "Cortex-M52"}


def bits(value, table):
    return [name for bit, name in sorted(table.items()) if value >> bit & 1]


# ------------------------------------------------------------------------------ status decode
def do_decode(a):
    h = lambda s: int(s, 16) if s else None
    cpuid, dhcsr = h(a.cpuid), h(a.dhcsr)
    cfsr, hfsr, mmfar, bfar = h(a.cfsr), h(a.hfsr), h(a.mmfar), h(a.bfar)
    if cpuid is not None:
        part = cpuid >> 4 & 0xFFF
        print(f"CORE: cpuid=0x{cpuid:08X} {PARTS.get(part, f'part 0x{part:03X}')} "
              f"r{cpuid >> 20 & 0xF}p{cpuid & 0xF}")
    state = "unknown"
    if dhcsr is not None:
        flags = [n for b, n in ((25, "S_RESET_ST"), (24, "S_RETIRE_ST"), (19, "S_LOCKUP"),
                                (18, "S_SLEEP"), (17, "S_HALT"), (0, "C_DEBUGEN")) if dhcsr >> b & 1]
        state = ("lockup" if dhcsr >> 19 & 1 else "halted" if dhcsr >> 17 & 1 else
                 "sleeping" if dhcsr >> 18 & 1 else "running")
        print(f"CORE: dhcsr=0x{dhcsr:08X} {' '.join(flags) or '-'} -> {state}"
              + ("  (reset since the last read)" if dhcsr >> 25 & 1 else ""))
    faults = []
    if cfsr is not None:
        faults += bits(cfsr, CFSR_BITS)
        print(f"FAULT: cfsr=0x{cfsr:08X} {' '.join(bits(cfsr, CFSR_BITS)) or 'none'}")
    if hfsr is not None:
        faults += bits(hfsr, HFSR_BITS)
        print(f"FAULT: hfsr=0x{hfsr:08X} {' '.join(bits(hfsr, HFSR_BITS)) or 'none'}")
    if cfsr is not None and cfsr >> 7 & 1 and mmfar is not None:
        print(f"FAULT: mmfar=0x{mmfar:08X} (valid: MMARVALID)")
    if cfsr is not None and cfsr >> 15 & 1 and bfar is not None:
        print(f"FAULT: bfar=0x{bfar:08X} (valid: BFARVALID)")
    bad = bool(faults) or state == "lockup"
    print(f"DEBUG: STATUS {state} fault={','.join(faults) or 'none'}")
    return 1 if bad else 0


# ------------------------------------------------------------------------------ GDB/MI driver
class MI:
    def __init__(self, gdb, elf, log):
        self.p = subprocess.Popen([gdb, "--interpreter=mi3", "-nx", "-q", elf], stdin=subprocess.PIPE,
                                  stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
                                  encoding="utf-8", errors="replace", bufsize=1)
        self.q, self.log, self.token, self.running = queue.Queue(), log, 100, False
        self.console, self.pending = [], None      # pending: a *stopped seen while waiting for a result
        threading.Thread(target=self._read, daemon=True).start()

    def _read(self):
        for line in self.p.stdout:
            line = line.rstrip("\r\n")
            self.log.write(f"{time.strftime('%H:%M:%S')} gdb< {line}\n")
            self.q.put(line)

    def cmd(self, c, timeout=10):
        """send one MI command; return (class, rest) of its result record"""
        self.token += 1
        tok = str(self.token)
        self.log.write(f"{time.strftime('%H:%M:%S')} gdb> {tok}{c}\n")
        self.p.stdin.write(f"{tok}{c}\n")
        self.p.stdin.flush()
        end = time.time() + timeout
        while time.time() < end:
            try:
                line = self.q.get(timeout=0.2)
            except queue.Empty:
                continue
            if line.startswith("~"):
                self.console.append(json.loads(line[1:]) if line[1:2] == '"' else line[1:])
            elif line.startswith("*running"):
                self.running = True
            elif line.startswith("*stopped"):
                self.running = False
                self.pending = line
            if line.startswith(tok + "^"):
                cls, _, rest = line[len(tok) + 1:].partition(",")
                return cls, rest
        return "timeout", ""

    def go(self, c):
        """resume command (-exec-continue / -exec-next): a later *stopped belongs to it"""
        self.pending = None
        return self.cmd(c)

    def wait_stopped(self, timeout):
        if self.pending:
            line, self.pending = self.pending, None
            return line
        end = time.time() + timeout
        while time.time() < end:
            try:
                line = self.q.get(timeout=0.2)
            except queue.Empty:
                continue
            if line.startswith("~"):
                self.console.append(json.loads(line[1:]) if line[1:2] == '"' else line[1:])
            if line.startswith("*stopped"):
                self.running = False
                return line
        return None


def elf_segments(path):
    """(physical load address, file bytes) of each PT_LOAD segment of a 32-bit little-endian ELF"""
    import struct
    raw = open(path, "rb").read()
    if raw[:4] != b"ELF" or raw[4] != 1:
        raise SystemExit("DEBUG: FAIL not a 32-bit ELF")
    phoff, = struct.unpack_from("<I", raw, 28)
    phentsize, phnum = struct.unpack_from("<HH", raw, 42)
    segs = []
    for i in range(phnum):
        p_type, p_offset, _vaddr, p_paddr, p_filesz = struct.unpack_from("<5I", raw, phoff + i * phentsize)
        if p_type == 1 and p_filesz:
            segs.append((p_paddr, raw[p_offset:p_offset + p_filesz]))
    return segs


def field(rec, name):
    m = re.search(name + r'="((?:[^"\\]|\\.)*)"', rec or "")
    return m.group(1).encode().decode("unicode_escape") if m else ""


def where(rec):
    return f"{field(rec, 'func') or '?'} {field(rec, 'file')}:{field(rec, 'line')}".strip()


def do_run(a):
    import shlex
    scen = json.load(open(a.scenario, encoding="utf-8"))
    log = open(a.log, "w", encoding="utf-8", newline="\n")
    ser = None
    if a.console:
        try:
            import serial
            ser = serial.Serial(a.console, a.baud, timeout=0.1)
        except Exception as e:                                    # noqa: BLE001
            print(f"DEBUG: FAIL cannot open the console {a.console}: {e}")
            return 1
    # Windows takes the command line as one string (quoted paths with spaces stay intact)
    cmdline = a.server if sys.platform == "win32" else shlex.split(a.server)
    server = subprocess.Popen(cmdline, stdout=subprocess.PIPE,
                              stderr=subprocess.STDOUT, text=True, encoding="utf-8", errors="replace")
    srv_q = queue.Queue()

    def drain():
        for line in server.stdout:
            log.write(f"{time.strftime('%H:%M:%S')} srv  {line.rstrip()}\n")
            srv_q.put(line)
    threading.Thread(target=drain, daemon=True).start()
    ready, end = False, time.time() + 20
    while time.time() < end and server.poll() is None:
        try:
            if a.ready_text.lower() in srv_q.get(timeout=0.2).lower():
                ready = True
                break
        except queue.Empty:
            pass
    if not ready:
        server.kill()
        print(f"DEBUG: FAIL the GDB server did not start (log {a.log})")
        return 1
    mi = MI(a.gdb, a.elf, log)
    results = []
    attached = False
    try:
        mi.cmd("-gdb-set mi-async on")
        cls, rest = mi.cmd(f"-target-select extended-remote localhost:{a.port}", 20)
        if cls != "connected":
            print(f"DEBUG: FAIL GDB could not attach ({cls} {field(rest, 'msg')})")
            return 1
        attached = True
        mi.wait_stopped(2)
        mi.pending = None
        # Does the board run this ELF? Compare the first and last bytes of every loadable segment
        # (vector table included) with target memory - read-only. (GDB's compare-sections relies on
        # the server's qCRC, which ST-LINK_gdbserver answers wrongly: every section "MIS-MATCHED".)
        checked, bad = 0, []
        for paddr, data in elf_segments(a.elf):
            for off in sorted({0, max(0, len(data) - 64)}):
                chunk = data[off:off + 256]
                cls, rest = mi.cmd(f"-data-read-memory-bytes 0x{paddr + off:08X} {len(chunk)}")
                m = re.search(r'contents="([0-9a-fA-F]+)"', rest)
                checked += 1
                if not m or bytes.fromhex(m.group(1)) != chunk:
                    bad.append(f"0x{paddr + off:08X}")
        if bad or not checked:
            print(f"DEBUG: FAIL the board does not run this ELF (differs at {', '.join(bad) or 'no segment checked'}) "
                  "- flash the app first")
            return 1
        print(f"IMAGE: board runs this ELF ({checked} ranges of the loadable segments match, read back)")
        for i, st in enumerate(scen.get("steps", []), 1):
            name = st.get("name", f"step {i}")
            tmo = float(st.get("timeout", 5))
            ok, info = False, ""
            if "break" in st or "watch" in st:
                if "break" in st:
                    cls, rest = mi.cmd(f'-break-insert -t "{st["break"]}"')
                    num = field(rest, "number")
                else:
                    cls, rest = mi.cmd(f'-break-watch "{st["watch"]}"')
                    num = field(rest, "number")
                if cls != "done":
                    results.append((name, False, f"cannot set ({field(rest, 'msg')})"))
                    print(f"FAIL {name}: cannot set ({field(rest, 'msg')})")
                    continue
                before = None
                if "watch" in st:
                    c2, r2 = mi.cmd(f'-data-evaluate-expression "{st["watch"]}"')
                    before = field(r2, "value") if c2 == "done" else None
                mi.go("-exec-continue")
                if st.get("send") and ser:
                    time.sleep(0.3)
                    ser.reset_input_buffer()
                    ser.write((st["send"] + "\r").encode())
                    log.write(f"{time.strftime('%H:%M:%S')} tx   {st['send']}\n")
                stop = mi.wait_stopped(tmo)
                if stop is None:
                    mi.cmd("-exec-interrupt")
                    mi.wait_stopped(5)
                    info = f"not hit within {tmo:g} s"
                elif "break" in st:
                    ok = 'reason="breakpoint-hit"' in stop
                    info = f"stopped at {where(stop)}" + ("" if ok else f" ({field(stop, 'reason')})")
                else:
                    # ST-LINK_gdbserver reports a watchpoint hit as a plain SIGTRAP: GDB then gives no
                    # old/new values, so the engine reads the expression before and after itself
                    trig = ('reason="watchpoint-trigger"' in stop or
                            ('reason="signal-received"' in stop and 'signal-name="SIGTRAP"' in stop))
                    old, new = field(stop, "old"), field(stop, "new")
                    if not new:
                        c2, r2 = mi.cmd(f'-data-evaluate-expression "{st["watch"]}"')
                        old, new = before or "?", (field(r2, "value") if c2 == "done" else "?")
                    ok = trig and (old != new or not st.get("expect_change", True))
                    info = f"{st['watch']} {old} -> {new}, stopped at {where(stop)}"
                    c2, r2 = mi.cmd("-stack-list-frames 0 1")
                    funcs = re.findall(r'func="([^"]+)"', r2) if c2 == "done" else []
                    if len(funcs) > 1:
                        info += f" (called from {funcs[1]})"
                if "watch" in st and num:
                    mi.cmd(f"-break-delete {num}")
            elif "print" in st:
                cls, rest = mi.cmd(f'-data-evaluate-expression "{st["print"]}"')
                val = field(rest, "value") if cls == "done" else f"error: {field(rest, 'msg')}"
                ok = cls == "done" and (("expect" not in st or val == str(st["expect"])) and
                                        ("expect_re" not in st or re.search(st["expect_re"], val) is not None))
                info = f"{st['print']} = {val}"
            elif "step" in st:
                n, last = int(st["step"]), None
                for _ in range(n):
                    mi.go("-exec-next")
                    last = mi.wait_stopped(tmo)
                    if last is None:
                        break
                ok = last is not None
                info = f"{n} line(s) -> {where(last)}" if last else "step did not finish"
            elif "read" in st:
                key = str(st["read"]).upper()
                addr = REGS.get(key) or int(str(st["read"]), 16)
                cls, rest = mi.cmd(f"-data-read-memory-bytes 0x{addr:08X} 4")
                m = re.search(r'contents="([0-9a-fA-F]+)"', rest)
                val = f"0x{int.from_bytes(bytes.fromhex(m.group(1)), 'little'):08X}" if m else "unreadable"
                ok = bool(m) and (("expect" not in st or val.lower() == str(st["expect"]).lower()) and
                                  ("expect_re" not in st or re.search(st["expect_re"], val) is not None))
                info = f"{key} = {val}"
            else:
                info = "unknown step type"
            results.append((name, ok, info))
            print(f"{'PASS' if ok else 'FAIL'} {name}: {info}")
    except KeyboardInterrupt:
        results.append(("interrupted", False, "Ctrl+C"))
    finally:
        if attached:                                           # never leave the core halted
            if mi.running:
                mi.cmd("-exec-interrupt")
                mi.wait_stopped(5)
            mi.cmd("-break-delete")
            cls, _ = mi.cmd("-target-detach", 10)
            print(f"DETACH: {'done - the firmware runs on' if cls == 'done' else 'FAILED (' + cls + ') - check the board'}")
        try:
            mi.cmd("-gdb-exit", 5)
        except (OSError, ValueError):
            pass
        for p in (mi.p, server):
            try:
                p.terminate()
                p.wait(5)
            except Exception:                                  # noqa: BLE001
                p.kill()
        if ser:
            if attached:
                time.sleep(1.0)
                for line in ser.read(4096).decode(errors="replace").splitlines():
                    if line.strip():
                        log.write(f"{time.strftime('%H:%M:%S')} rx   {line.strip()}\n")
                        print(f"CONSOLE after detach: {line.strip()}")
            ser.close()
        log.close()
    n_ok = sum(1 for r in results if r[1])
    ok = results and n_ok == len(results)
    print(f"DEBUG: {'PASS' if ok else 'FAIL'} ({n_ok}/{len(results)} steps, log {a.log})")
    return 0 if ok else 1


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="action", required=True)
    d = sub.add_parser("decode")
    for k in ("cpuid", "dhcsr", "cfsr", "hfsr", "mmfar", "bfar"):
        d.add_argument(f"--{k}")
    r = sub.add_parser("run")
    r.add_argument("--gdb", required=True)
    r.add_argument("--elf", required=True)
    r.add_argument("--server", required=True, help="GDB server command line (attach mode)")
    r.add_argument("--port", type=int, required=True)
    r.add_argument("--scenario", required=True)
    r.add_argument("--log", required=True)
    r.add_argument("--console")
    r.add_argument("--baud", type=int, default=115200)
    r.add_argument("--ready-text", default="Waiting for debugger connection")
    a = ap.parse_args()
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace", line_buffering=True)
    except AttributeError:
        pass
    return do_decode(a) if a.action == "decode" else do_run(a)


if __name__ == "__main__":
    sys.exit(main())
