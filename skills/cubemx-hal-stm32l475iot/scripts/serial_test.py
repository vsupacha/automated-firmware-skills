#!/usr/bin/env python3
"""Stage 8 (test): data-driven serial test runner - STM32L4 UART test runner (ST-LINK virtual COM port).

Usage:
  python serial_test.py <port|auto> <spec.json> <log> [--board ID] [--sync | --wait-boot]
         [--boot-timeout S] [--wait-port S] [--interactive | --only-interactive] [--only REGEX]

"auto" = the virtual COM port of this PC's ST-LINK (bench PROBE_SERIAL).
The engine and the spec.json keys are documented in <repo>/lib/fwtest.py.
"""
import sys
from pathlib import Path

HERE = Path(__file__).resolve()
sys.path.insert(0, str(HERE.parents[3] / "lib"))
import fwtest  # noqa: E402

fwtest.run({
    "skill_dir": HERE.parent.parent,
    "env_prefix": "L4",
    "serial_key": "PROBE_SERIAL",
    "serial_env": "PROBE_SERIAL",
    "vid_key": "PROBE_VID",
    "default_vid": "0483",
    "title": "STM32L4 UART test runner (ST-LINK virtual COM port)",
})
