# Arduino UNO R4 WiFi - pio-arduino-unor4wifi profile

Board profile of the `pio-arduino-unor4wifi` skill: `board.env` (pinned platform and toolchain,
board id, define, labels, USB ids, expected loader identity, sketch offset). Hardware:
[../README.md](../README.md).

| Item | Value |
| --- | --- |
| PlatformIO platform | `platformio/renesas-ra@1.7.0` (registry, exact version) |
| Framework | Arduino UNO R4 core (`framework-arduinorenesas-uno` 1.4.1), GCC 7.2.1 (`toolchain-gccarmnoneeabi` 1.70201.0) |
| Board id / env | `uno_r4_wifi` / `uno_r4_wifi` |
| Console | `Serial` = UART to the ESP32-S3 bridge (USB CDC), 115200, handed to func/ and the sketch as a `Stream&` (`board_console()`); `console_printf()` because the core's `Print` has no `printf` |
| Flash | `firmware.bin` from 0x4000 through the bridge (bossac 1.9.1, sam-ba), no read-back |

## Verification log

- 2026-10-08 skill `pio-arduino-unor4wifi` created (PlatformIO 6.2.0, renesas-ra 1.7.0, UNO R4
  core 1.4.1, Windows 11 + Git Bash). check_tools `missing/bad=0`.
  - discover: USB `2341:1002`; bossac info = "Arduino Bootloader (SAM-BA extended) 2.0
    [Arduino:IKXYZ]", device `nRF52840-QIAA` (emulated), security false, nothing locked -
    IDENTITY PASS.
  - `uart-btn-led` (app `uno-btn`): build PASS 0 warnings, firmware.bin `4bc694b0...` - built,
    not flashed.
  - `hello-world` (app `uno-hello`): build PASS 0 warnings, firmware.bin `1d732e8d...`. First flash
    with `bossac --verify`: 9/9 pages written, then "SAM-BA operation failed" at verify and no
    reset - the RA4M1 stayed silent (a standalone `bossac --reset` found no loader). flash.sh now
    uses `--erase --write --reset` like the Arduino IDE and PlatformIO: second flash 9/9 pages +
    reset, then test PASS 9/9 (`board=uno-r4-wifi`, five 1 s "hello, world" lines, console alive).
- 2026-10-09 `hello-world` re-tested PASS 9/9. `uart-btn-led` (app `uno-btn`, firmware.bin
  `4bc694b0...`): flash 10/10 pages + reset; automatic test PASS 13/13 (8 skipped: one LED, no
  button); interactive PASS 4/4 twice (`OK led1=1`, `OK led1=0`). **Observed by the user:** LED L
  (D13) on, then off.
