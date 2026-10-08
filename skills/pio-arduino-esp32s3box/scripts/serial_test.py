#!/usr/bin/env python3
"""Stage 6 (test): data-driven serial test runner - ESP32-S3 USB Serial/JTAG console.

Usage:
  python serial_test.py <port|auto> <spec.json> <log> [--board ID] [--sync | --wait-boot]
         [--boot-timeout S] [--wait-port S] [--interactive | --only-interactive] [--only REGEX]

"auto" = the USB Serial/JTAG port whose USB serial (the chip's MAC) is this PC's bench USB_SERIAL.
Needs pyserial: run it with PlatformIO's python (~/.platformio/penv/Scripts/python) if the system
python has none. The engine and the spec.json keys are documented in <repo>/lib/fwtest.py.
"""
import sys
from pathlib import Path

HERE = Path(__file__).resolve()
sys.path.insert(0, str(HERE.parents[3] / "lib"))
import fwtest  # noqa: E402

fwtest.run({
    "skill_dir": HERE.parent.parent,
    "env_prefix": "ESP",
    "serial_key": "USB_SERIAL",
    "serial_env": "USB_SERIAL",
    "vid_key": "USB_VID",
    "default_vid": "303A",
    "title": "ESP32-S3-BOX Arduino serial test runner (USB Serial/JTAG, HWCDC)",
})
