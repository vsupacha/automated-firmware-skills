# Espressif ESP32-S3-BOX (2021)

AIoT development kit with an ESP32-S3, 2.4" touch LCD, two microphones and a speaker. This sheet
is the **original ESP32-S3-BOX** - not the ESP32-S3-BOX-Lite (no touch, three front buttons) and
not the ESP32-S3-BOX-3 (2023, other pins). Tool-independent hardware sheet.

| Profile | Skill | Status |
| --- | --- | --- |
| [pio-espidf-esp32s3box/](pio-espidf-esp32s3box/README.md) | `skills/pio-espidf-esp32s3box` (PlatformIO + ESP-IDF) | verified on hardware (backlight seen) |
| [pio-arduino-esp32s3box/](pio-arduino-esp32s3box/README.md) | `skills/pio-arduino-esp32s3box` (PlatformIO + Arduino) | verified on hardware (backlight seen) |

## Bring-up demos

| Demo | Uses | `pio-espidf-esp32s3box` | `pio-arduino-esp32s3box` |
| --- | --- | --- | --- |
| hello-world | console: USB Serial/JTAG | tested | tested |
| blink | LED1 = LCD backlight | built | built |
| push-to-light | BTN1 = BOOT toggles LED1 | observed * | observed * |

Levels: built < flashed < tested (automatic test PASS) < interactive (a person pressed a
button) < observed (a person saw the LED). \* = verified under its earlier name `uart-btn-led`
(renamed 2026-10-09, same code). Dated evidence: the profile README of each skill.

## Required tools

### pio-espidf-esp32s3box

- PlatformIO Core 6.2, Git, Python 3. The first build installs espressif32 6.12.0 + ESP-IDF 5.5
  and sets up ESP-IDF's python environment. Discover/flash/test use PlatformIO's own python
  (pyserial + esptool come with it).
- Workspace path without spaces, ≤100 characters.

### pio-arduino-esp32s3box

- PlatformIO Core 6.2, Git, Python 3. The first build installs espressif32 6.12.0 +
  arduino-esp32 2.0.17 (GCC 8.4). Discover/flash/test use PlatformIO's own python
  (pyserial + esptool come with it).
- Workspace path without spaces, ≤100 characters.

## Commands

### pio-espidf-esp32s3box

```bash
S=skills/pio-espidf-esp32s3box/scripts
```

| Stage | Command | Gate |
| --- | --- | --- |
| 0 help | `bash $S/help.sh [--en]` | - |
| 1 setup | `bash $S/check_tools.sh <board> [--ws <workspace>]` | `missing/bad=0` |
| 4 connect | `bash $S/discover.sh <board> [--serial <usb-serial>]` | `IDENTITY: PASS` |
| 2 create | `bash $S/new_app.sh <board> <app> [<workspace>\|""] [template]` | `Created ...` |
| 2d open in IDE (run by new_app) | `bash $S/open_ide.sh apps/<app> [--no-open]` - VS Code + the toolchain extension, on the same project as the scripts | `IDE: READY` |
| 3 build | `bash $S/build.sh apps/<app> [--clean] [--allow-warnings]` | `BUILD: PASS` |
| 5 backup (optional, factory firmware) | `bash $S/backup.sh <board>` | `BACKUP: PASS` |
| 5 flash | `bash $S/flash.sh apps/<app> --yes` | `FLASH: PASS` |
| 6 test | `~/.platformio/penv/Scripts/python $S/serial_test.py auto apps/<app>/tests/<spec>.json apps/<app>/logs/test.log --board <board> [--interactive]` | `RESULT: PASS` |
| 16 clean | `bash $S/clean.sh [--apps] [--yes]` | `CLEAN: done` |

Board: `esp32-s3-box`. Templates: `hello-world`, `blink`, `push-to-light` (LED1 = LCD backlight, BTN1 = BOOT).
The app's `src/func` is the shared `lib/func`; ESP-IDF settings live in `sdkconfig.defaults`.

### pio-arduino-esp32s3box

```bash
S=skills/pio-arduino-esp32s3box/scripts
```

| Stage | Command | Gate |
| --- | --- | --- |
| 0 help | `bash $S/help.sh [--en]` | - |
| 1 setup | `bash $S/check_tools.sh <board> [--ws <workspace>]` | `missing/bad=0` |
| 4 connect | `bash $S/discover.sh <board> [--serial <usb-serial>]` | `IDENTITY: PASS` |
| 2 create | `bash $S/new_app.sh <board> <app> [<workspace>\|""] [template]` | `Created ...` |
| 2d open in IDE (run by new_app) | `bash $S/open_ide.sh apps/<app> [--no-open]` - VS Code + the toolchain extension, on the same project as the scripts | `IDE: READY` |
| 3 build | `bash $S/build.sh apps/<app> [--clean] [--allow-warnings]` | `BUILD: PASS` |
| 5 backup (optional, factory firmware) | `bash $S/backup.sh <board>` | `BACKUP: PASS` |
| 5 flash | `bash $S/flash.sh apps/<app> --yes` | `FLASH: PASS` |
| 6 test | `~/.platformio/penv/Scripts/python $S/serial_test.py auto apps/<app>/tests/<spec>.json apps/<app>/logs/test.log --board <board> [--interactive]` | `RESULT: PASS` |
| 16 clean | `bash $S/clean.sh [--apps] [--yes]` | `CLEAN: done` |

Board: `esp32-s3-box`. Templates: `hello-world`, `blink`, `push-to-light` (LED1 = LCD backlight, BTN1 = BOOT).
The app's `src/func` is the shared `lib/func`; ESP-IDF settings live in `sdkconfig.defaults`.

Same commands and gates as pio-espidf-esp32s3box with `S=skills/pio-arduino-esp32s3box/scripts`;
the code is Arduino style (`<Arduino.h>`, `setup()`/`loop()`, Print/Stream, `millis()`), and flash.sh
writes four regions (bootloader, partitions, `boot_app0`, sketch).

Run from the repo root in Git Bash. Exit code 10 = do what the `ACTION:` line says, then
re-run; common options: [docs/workflow.md](../../docs/workflow.md#common-options).

## Hardware

Sources: Espressif esp-box repository, hardware overview of the ESP32-S3-BOX and the esp-bsp
`esp-box` board support package; PlatformIO `espressif32` 6.12.0 board `esp32s3box`.

"Verified" = seen on hardware with a dated log line in a profile README. "Vendor docs" = taken from
Espressif's documentation, not yet checked by us on this board.

## MCU and USB

| Item | Value | Verified |
| --- | --- | --- |
| MCU | ESP32-S3 (QFN56) rev v0.1, dual Xtensa LX7 240 MHz, 16 MB flash, 8 MB embedded PSRAM | yes (esptool 2026-10-07) |
| USB | USB-C to the ESP32-S3 native USB (GPIO19/20): USB Serial/JTAG `303A:1001`, the same in the ROM download mode, the bootloader and the app; USB serial number = the chip's MAC address | `303A:1001` seen 2026-10-07 |
| Console | USB Serial/JTAG (no UART bridge chip) | yes (2026-10-07) |
| Debug | built-in USB JTAG of the ESP32-S3 (OpenOCD `esp32s3.cfg`), no external probe | vendor docs |
| Download mode | hold **BOOT**, press **RESET**; esptool also resets into it over USB Serial/JTAG | vendor docs |

## User I/O

| Silkscreen / name | Pin | Active level | Notes | Verified |
| --- | --- | --- | --- | --- |
| **BOOT** button | GPIO0 | low (external pull-up) | strapping pin: held at reset = download mode; free to read at run time | yes (2026-10-07, interactive test) |
| RESET button | EN | - | chip reset, not readable | - |
| **MUTE** button | (GPIO1 = mute state) | - | hardware mute of the microphones with a red LED; latching, not a plain user button | vendor docs, not used |
| Touch "home" circle | touch controller (I2C) | - | not a GPIO | not used |
| User LEDs | none | - | the green power LED and the red mute LED are not software controlled | vendor docs |
| LCD backlight | GPIO45 | high = on | used as **LED1** by the skill's board layer (observable without an LCD driver); GPIO45 is a strapping pin, driven only after boot | yes (2026-10-07, lit after BOOT press, seen by the user) |

## On-board parts (not used by the M1 templates)

| Part | Bus / pins | Verified |
| --- | --- | --- |
| LCD 2.4" 320x240 ILI9342C | SPI: SCLK GPIO7, MOSI GPIO6, CS GPIO5, DC GPIO4, RST GPIO48 | vendor docs |
| Touch TT21100, codecs ES8311 (DAC) + ES7210 (ADC) | I2C: SDA GPIO8, SCL GPIO18 | vendor docs |
| I2S audio | MCLK GPIO2, BCLK GPIO17, WS GPIO47, DOUT GPIO15, DIN GPIO16; speaker amplifier enable GPIO46 | vendor docs |

## Safety notes

- Never burn eFuses (`espefuse.py`), enable flash encryption or secure boot: irreversible.
- GPIO0, GPIO3, GPIO45, GPIO46 are strapping pins - do not drive them during reset.
