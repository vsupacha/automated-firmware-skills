# ESP32-S3-BOX - pio-arduino-esp32s3box profile

Board profile of the `pio-arduino-esp32s3box` skill: `board.env` (pinned platform, board id,
define, labels, expected identity). Hardware: [../README.md](../README.md). Same board facts as the
`pio-espidf-esp32s3box` profile; the Arduino variant `esp32s3box` sets flash (16 MB), PSRAM (octal,
`qio_opi`) and USB CDC on boot.

| Item | Value |
| --- | --- |
| PlatformIO platform | `platformio/espressif32@6.12.0` (registry, exact version) |
| Framework | arduino-esp32 2.0.17 (`framework-arduinoespressif32` 3.20017.241212), GCC 8.4.0 |
| Board id / env | `esp32s3box` / `esp32_s3_box` |
| Console | `Serial` = HWCDC (USB Serial/JTAG), handed to func/ and the sketch as a `Stream&` (`board_console()`) |
| Flash map | bootloader 0x0, partitions 0x8000, `boot_app0.bin` (OTA data) 0xe000, sketch 0x10000 - from `pio project metadata` |

## Verification log

- 2026-10-07 skill `pio-arduino-esp32s3box` created (PlatformIO 6.2.0, espressif32 6.12.0,
  arduino-esp32 2.0.17, Windows 11 + Git Bash); discover IDENTITY PASS (as the ESP-IDF profile).
  - `hello-world` (app `ard-hello-box`): build PASS 0 warnings (C func compiled by gcc, C++ by g++,
    all with -Wextra), firmware.bin `de995bb8...`; flash 4/4 regions hash-verified; test PASS 9/9
    - stdout -> Serial redirect works.
  - `uart-btn-led` (app `ard-btn-box`): build PASS, firmware.bin `6e70c626...`; flash 4/4; automatic
    test PASS 13/13; interactive PASS 5/5 (`EVT btn1=pressed name=BOOT pin=GPIO0 led1=1`,
    `LED led1=1`) on the first attempt.
  - Afterwards `#include <Arduino.h>` was removed from both main.cpp templates (check_layers.py:
    vendor header in the execution layer, nothing used from it); rebuilt PASS 0 warnings
    (firmware.bin `44521a7c...` / `f503e3a6...`) - built, never flashed (superseded below).
- 2026-10-07 code rewritten in Arduino style at the owner's request: every file includes
  `<Arduino.h>`; func/ is Arduino C++ (Stream/Print console, millis() debounce, pin read-back
  through board.h) instead of the shared C lib/func + stdout redirect; main.cpp prints with
  `console_out().println/printf`. Clean builds PASS 0 warnings: hello-world `4af9e582...`,
  uart-btn-led `51daf391...`. Flashed 4/4 each; hello-world test PASS 9/9; uart-btn-led automatic
  PASS 13/13, interactive PASS 5/5 (`EVT btn1=pressed name=BOOT pin=GPIO0 led1=1`, `LED led1=1`
  read back from the pin). **Observed by the user:** the LCD backlight lit after the BOOT press.
