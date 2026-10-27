#!/usr/bin/env python3
"""Read one Unity run from a board whose test image waits for a start byte (unit_test.sh, step 3).

The ESP32-S3 USB Serial/JTAG drops output while no host reads the port, and PlatformIO's test
runner cannot reset the chip through it, so `pio test --without-building --without-uploading`
sees nothing. The test image (test/test_func/test_main.cpp) prints "UNIT-WAIT ..." once a second
until it receives a byte; this reader opens the port without touching DTR/RTS (no reset, no
download mode: DTR and RTS stay asserted together, as pyserial opens them), sends a newline, and records Unity's output up to its summary.

Usage: unity_read.py <port> <log> [--timeout S]
Prints each test result and "UNITY: <tests> <failures> <ignored>"; exit 0 = summary seen with 0
failures, 1 = failures or no summary within the timeout.
"""
import re
import sys
import time

import serial

RESULT_RE = re.compile(r"^(.+?):(\d+):(\w+):(PASS|FAIL|IGNORE)(?::\s*(.*))?$")
SUMMARY_RE = re.compile(r"^(\d+) Tests (\d+) Failures (\d+) Ignored")


def open_port(port):
    # pyserial's defaults, as serial_test.py: DTR and RTS asserted together. The USB Serial/JTAG
    # sends nothing until the host asserts DTR, and (1,1) is not a reset state - changing only one
    # of the two lines is what resets the chip (or puts it into download mode).
    return serial.Serial(port, 115200, timeout=0.2)


def main():
    args = sys.argv[1:]
    if len(args) < 2:
        sys.exit(__doc__)
    port, log = args[0], args[1]
    timeout = float(args[args.index("--timeout") + 1]) if "--timeout" in args else 60.0
    s = open_port(port)
    t0, last_kick, started = time.time(), 0.0, False
    buf, lines, summary = "", [], None
    while time.time() - t0 < timeout and summary is None:
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
        while "\n" in buf:
            line, buf = buf.split("\n", 1)
            line = line.rstrip("\r")
            lines.append(line)
            if RESULT_RE.match(line):
                started = True
            m = SUMMARY_RE.match(line)
            if m:
                summary = tuple(int(x) for x in m.groups())
    s.close()
    with open(log, "a", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines) + "\n")
    for line in lines:
        m = RESULT_RE.match(line)
        if m:
            print(f"  {m.group(3)}  [{m.group(4)}]" + (f"  {m.group(5)}" if m.group(5) else ""))
    if summary is None:
        print(f"UNITY-ERR no Unity summary within {timeout:.0f} s ({len(lines)} lines received)")
        return 1
    print(f"UNITY: {summary[0]} {summary[1]} {summary[2]}")
    return 0 if summary[1] == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
