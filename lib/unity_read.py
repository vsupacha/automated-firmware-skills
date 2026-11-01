#!/usr/bin/env python3
"""Read one Unity run from a board's unit-test image and check it against the test log (unit_test.sh).

The test images (STM32: lib/test_func/test_driver_main.c; Pico 2 W / ESP32-S3-BOX: their
test/test_func/test_driver.cpp) print "UNIT-WAIT ..." once a second until a byte arrives on the
console, so the run is never missed, whenever the port is opened. Then Unity's result lines and
summary, then the test log line, then "UNIT-DONE":

    <file>:<line>:<test>:PASS|FAIL|IGNORE[: message]
    <n> Tests <f> Failures <i> Ignored
    TESTLOG: cases=<n> passed=<p> failed=<f> running=0 last_fail=<test|->
    UNIT-DONE

This reader opens the port with pyserial's defaults (DTR and RTS asserted together: no reset on
the ST-LINK VCP, no reset / download mode on the ESP32-S3 USB Serial/JTAG; the Pico's USB CDC sees
DTR as "port open"), sends a newline every 0.5 s until the first result line, and reads up to
"UNIT-DONE". A board that already ran its tests sends nothing more: reset it first.

Checks (all must hold for PASS):
  - Unity's summary arrived and reports 0 failures;
  - as many result lines as the summary counts (no lost output);
  - the test log line arrived, with running=0 (no case cut off), cases = Unity's tests,
    failed = Unity's failures, passed + failed = cases, and last_fail = the last FAIL result.

Usage: unity_read.py <port> <log> [--timeout S]
Prints each result, "UNITY: <tests> <failures> <ignored>", the TESTLOG line, problems as
"UNITY-ERR ...", and the gate "UNIT: PASS (n/n, test log agrees)" or "UNIT: FAIL (<reason>)".
Exit 0 = PASS, 1 = FAIL.
"""
import re
import sys
import time

import serial

RESULT_RE = re.compile(r"^(.+?):(\d+):(\w+):(PASS|FAIL|IGNORE)(?::\s*(.*))?$")
SUMMARY_RE = re.compile(r"^(\d+) Tests (\d+) Failures (\d+) Ignored")
TESTLOG_RE = re.compile(r"^TESTLOG: cases=(\d+) passed=(\d+) failed=(\d+) running=(\d+) last_fail=(\S+)")
DONE = "UNIT-DONE"
AFTER_SUMMARY_S = 3.0      # an image without a test log: stop waiting this long after the summary


def open_port(port):
    # pyserial's defaults, as serial_test.py: DTR and RTS asserted together. The USB Serial/JTAG
    # sends nothing until the host asserts DTR, and (1,1) is not a reset state - changing only one
    # of the two lines is what resets the chip (or puts it into download mode).
    return serial.Serial(port, 115200, timeout=0.2)


def read_run(port, timeout):
    s = open_port(port)
    t0, last_kick, started, t_summary = time.time(), 0.0, False, None
    buf, lines = "", []
    while time.time() - t0 < timeout:
        if t_summary is not None and time.time() - t_summary > AFTER_SUMMARY_S:
            break
        if not started and time.time() - last_kick > 0.5:
            s.write(b"\n")
            last_kick = time.time()
        try:
            chunk = s.read(512).decode("utf-8", "replace")
        except serial.SerialException:           # the port re-enumerated: open it again
            s.close()
            time.sleep(0.5)
            s = open_port(port)
            continue
        buf += chunk
        done = False
        while "\n" in buf:
            line, buf = buf.split("\n", 1)
            line = line.rstrip("\r")
            lines.append(line)
            if RESULT_RE.match(line):
                started = True
            if SUMMARY_RE.match(line):
                t_summary = time.time()
            if line.strip() == DONE:
                done = True
        if done:
            break
    s.close()
    return lines


def check(lines, timeout):
    """-> (ok, reason, printable lines)"""
    out, results, summary, tlog = [], [], None, None
    for line in lines:
        m = RESULT_RE.match(line)
        if m:
            results.append((m.group(3), m.group(4)))
            out.append(f"  {m.group(3)}  [{m.group(4)}]" + (f"  {m.group(5)}" if m.group(5) else ""))
        m = SUMMARY_RE.match(line)
        if m:
            summary = tuple(int(x) for x in m.groups())
        m = TESTLOG_RE.match(line.strip())
        if m:
            tlog = (int(m.group(1)), int(m.group(2)), int(m.group(3)), int(m.group(4)), m.group(5))
    if summary is None:
        out.append(f"UNITY-ERR no Unity summary within {timeout:.0f} s ({len(lines)} lines received)")
        return False, "no Unity summary", out
    tests, fails, ign = summary
    out.append(f"UNITY: {tests} {fails} {ign}")
    if tlog is not None:
        out.append("TESTLOG: cases=%d passed=%d failed=%d running=%d last_fail=%s" % tlog)
    if len(results) != tests:
        return False, f"{len(results)} result lines for {tests} tests - output lost", out
    if tlog is None:
        return False, "no TESTLOG line after the summary (old test image? rebuild with unit_test.sh)", out
    cases, passed, failed, running, last_fail = tlog
    fail_names = [n for n, r in results if r == "FAIL"]
    want_last = fail_names[-1] if fail_names else "-"
    if running != 0:
        return False, f"test log: running={running} (a case did not finish)", out
    if cases != tests or failed != fails or passed + failed != cases:
        return False, (f"test log disagrees: cases={cases} passed={passed} failed={failed} "
                       f"vs Unity {tests} tests {fails} failures"), out
    if last_fail != want_last[:31]:              # the record keeps TEST_LOG_NAME - 1 characters
        return False, f"test log last_fail={last_fail}, Unity's last failure {want_last}", out
    if tests == 0:
        return False, "0 tests ran", out
    if fails:
        return False, f"{fails} of {tests} failed (last: {want_last}), test log agrees", out
    note = f", {ign} ignored" if ign else ""
    return True, f"{tests - ign}/{tests}{note}, test log agrees", out


def main():
    args = sys.argv[1:]
    if len(args) < 2:
        sys.exit(__doc__)
    port, log = args[0], args[1]
    timeout = float(args[args.index("--timeout") + 1]) if "--timeout" in args else 60.0
    lines = read_run(port, timeout)
    with open(log, "a", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines) + "\n")
    ok, reason, out = check(lines, timeout)
    print("\n".join(out))
    print(f"UNIT: {'PASS' if ok else 'FAIL'} ({reason})")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
