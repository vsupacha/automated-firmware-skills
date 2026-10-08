#!/usr/bin/env python3
"""Stage 6 (test): data-driven serial test runner - UNO R4 WiFi UART console via the USB bridge.

Usage:
  python serial_test.py <port|auto> <spec.json> <log> [--board ID] [--sync | --wait-boot]
         [--boot-timeout S] [--wait-port S] [--interactive | --only-interactive] [--only REGEX]

"auto" = the COM port whose USB serial (of the ESP32-S3 USB bridge) is this PC's bench USB_SERIAL.
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
    "env_prefix": "UNO",
    "serial_key": "USB_SERIAL",
    "serial_env": "USB_SERIAL",
    "vid_key": "USB_VID",
    "default_vid": "2341",
    "title": "UNO R4 WiFi Arduino serial test runner (UART via the ESP32-S3 USB bridge)",
})
