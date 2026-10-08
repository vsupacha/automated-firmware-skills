#!/usr/bin/env python3
"""Stage 6 (test): data-driven serial test runner - Pico 2 W serial test runner (USB CDC console).

Usage:
  python serial_test.py <port|auto> <spec.json> <log> [--board ID] [--sync | --wait-boot]
         [--boot-timeout S] [--wait-port S] [--interactive | --only-interactive] [--only REGEX]

"auto" = the CDC port of the board with this PC's USB serial = chip ID (bench USB_SERIAL).
The engine and the spec.json keys are documented in <repo>/lib/fwtest.py.
"""
import sys
from pathlib import Path

HERE = Path(__file__).resolve()
sys.path.insert(0, str(HERE.parents[3] / "lib"))
import fwtest  # noqa: E402

fwtest.run({
    "skill_dir": HERE.parent.parent,
    "env_prefix": "PICO",
    "serial_key": "USB_SERIAL",
    "serial_env": "USB_SERIAL",
    "vid_key": "USB_VID",
    "default_vid": "2E8A",
    "title": "Pico 2 W serial test runner (USB CDC console)",
})
