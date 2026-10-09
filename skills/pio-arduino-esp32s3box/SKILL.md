---
name: pio-arduino-esp32s3box
description: Firmware workflow for the Espressif ESP32-S3-BOX (ESP32-S3) with PlatformIO and the Arduino framework (arduino-esp32) - check tools and folder paths, create a PlatformIO Arduino app from a layered template (board -> func -> setup/loop) written with the Arduino API (Arduino.h), with the platform pinned to an exact version, build it with a manifest of every image and its flash map, discover the board over its USB Serial/JTAG (chip, MAC = USB serial, flash size, security state), flash with esptool behind identity gates and hash verification, and run automated serial tests. Use when asked to create, build, flash (แฟลช) or test ESP32-S3-BOX firmware with PlatformIO and Arduino (บอร์ด ESP32-S3-BOX, Arduino), add an ESP32-S3 board profile, or when the user asks how to use this skill / what commands exist (ขอวิธีใช้, มีคำสั่งอะไรบ้าง, help). For ESP-IDF use pio-espidf-esp32s3box. Not for the Arduino IDE / arduino-cli, MicroPython, the BOX-Lite or BOX-3.
---

# ESP32-S3-BOX firmware workflow (PlatformIO + Arduino)

Gated stages, the same contract as every skill in this repo (`docs/workflow.md`). Do them in order;
do not start a stage until the previous gate passed. Each stage has a script in `scripts/` and
details in `reference/`. Bash: Git Bash on Windows (Claude's Bash tool), or Linux/macOS.
Sister skill: `pio-espidf-esp32s3box` (same board with ESP-IDF, C code over `lib/func`) - same board
facts, bench file and test specs; pick by framework. This skill's code is Arduino style throughout.

```
1 tools ─► 2 discover + project ─► 3 code ─► 4 build ─► 5 flash ─► 6 test ─► 7 clean
check_tools  discover (esptool)    src/board  build.sh   flash.sh   serial_test  clean.sh
             new_app               src/func
                                   main.cpp
```

**Two paths after Stage 2** (`docs/workflow.md`): the developer may code in VS Code at any
time - the **IDE path** (`new_app.sh` already opened the app; `open_ide.sh <app>` reopens it; they
build, flash and debug with the vendor extension's buttons) - or let you run the stages - the
**script path** (build, layer checks, flash, tests behind their gates). Ask which one when it is
not clear. On the IDE path, stop after stage 2d and run scripts only when asked ("build it", "test
it"); never overwrite files the developer is editing. Both paths share the app folder and build
outputs, so switching is always possible: on the script path re-run the gates from Stage 3.

## Milestones, stage numbers and developer actions

This skill implements the shared contract in `docs/workflow.md` (repo root):

| Milestone | Shared stage | In this file |
| --- | --- | --- |
| M1 bring-up | 1 setup, 2 create, 2d IDE, 3 build | Stage 1, Stage 2 step 2, Stage 4 |
| M1 bring-up (board) | 4 connect, 5 flash, 6 test, 7 debug *(planned)* | Stage 2 step 1, Stage 5 (+ backup), Stage 6 |
| M2 board support | 8 board drivers *(planned)*, 9 layer check, 10 host test *(not for Arduino C++)* | Stage 3 (Arduino-style rules, `check_layers.py`) |
| M3 execution, M4 components, M5 application | 11 execution + trace, 12 components, 13 profile *(planned)* | - |
| - | 14 export *(planned)*, 15 port *(planned)* | Extending |
| - | 16 clean | Stage 7 |

**Exit codes:** 0 gate passed, 1 failed, 2 warnings, **10 = developer action needed**. On exit 10
the script's last line is `ACTION: <TYPE> <what to do>` (SETUP, CONNECT, APPROVE, CHOOSE ...):
tell the user exactly that, wait for their OK, then re-run the same command (with `--yes` /
`--serial` when the action says so). Never work around an ACTION yourself - installing tools,
changing system or git settings, plugging hardware and approving flashes or deletions are the
developer's.

**Release scope:** `<repo>/milestones.env` lists the active milestones (this release: **M1**).
M1 includes the board stages: discover, flash and serial tests run when the developer asks for
them, and **every flash needs the developer's yes first** (`flash.sh --yes` only after they said
yes in chat, or `FLASH_POLICY=auto` that they wrote into their own bench file). Scripts of an
inactive milestone (e.g. M2 `check_layers.py`) stop with `ACTION: SETUP ... not active`; never
edit `milestones.env` or set `FW_ACTIVE_MILESTONES` yourself - relay the ACTION like any other.

## Help menu (answer this first when asked how to use the skill)

When the user asks for help, usage or the list of commands ("ขอวิธีใช้หน่อย", "มีคำสั่งอะไรบ้าง",
"help"), run `bash "$SKILL/scripts/help.sh"` (Thai) or `help.sh --en` and show its output as-is.
Then offer the next step that fits (usually Stage 1). Do not run other stages.

`$SKILL` below = the folder containing this SKILL.md. Always quote: `bash "$SKILL/scripts/x.sh"`.
This skill is part of the automated-firmware-skills repo and needs the repo layout:

```
<repo>/skills/pio-arduino-esp32s3box/        this skill (SKILL.md, scripts/, reference/, templates/)
<repo>/boards/<id>/README.md                 board hardware (tool-independent)
<repo>/boards/<id>/pio-arduino-esp32s3box/   board profile: board.env, README (verification log)
<repo>/apps/                                 apps workspace when working inside the repo
```

The apps workspace `$ESP_WS`: `<repo>/apps` inside the repo checkout, otherwise `./apps`. Board
profiles: `<project>/boards/<id>/pio-arduino-esp32s3box/` first, then `<repo>/boards` (override
`ESP_BOARDS_DIR`). The `ESP_*` variables are shared with `pio-espidf-esp32s3box`.

## What an app looks like

```
apps/<app>/
  platformio.ini        pinned platform (exact version), board, framework = arduino,
                        -DBOARD_<ID>, -Wall -Wextra for src/
  src/board/            board layer: pins, Serial, pinMode/digitalWrite/digitalRead (board.h/.cpp)
  src/func/             services in Arduino C++: console (Stream/Print), led, button (millis())
  src/main.cpp          the sketch: setup() + loop()
  tests/<spec>.json     test contract (the same specs as the other skills)
  arduino-app.env       record: board, template, env, platform
  .pio/ logs/           build outputs and logs (git-ignored)
  <app>.code-workspace  VS Code workspace for PlatformIO IDE - open_ide.sh makes it (git-ignored)
```

## Board type vs bench instance

- **Board type** (`boards/<id>/`): `README.md` = hardware; `pio-arduino-esp32s3box/board.env` =
  pinned platform, PlatformIO board id (its variant sets flash, PSRAM, USB CDC on boot),
  `BOARD_DEFINE`, `BTN_LABELS`/`LED_LABELS`, expected identity.
- **Bench instance** (`<workspace>/.bench/<id>.env`, board stages): USB serial (= MAC address) and COM port of
  one board on one PC, shared with `pio-espidf-esp32s3box`. Never write a serial or COM port into
  `boards/`.

| id | board | status |
| --- | --- | --- |
| `esp32-s3-box` | Espressif ESP32-S3-BOX, 2021 model (ESP32-S3, 16 MB flash, 8 MB PSRAM) | see `boards/esp32-s3-box/pio-arduino-esp32s3box/README.md` |

## Hardware quick reference

Use the **silkscreen name** with the user. Details: `boards/esp32-s3-box/README.md`.

| Board | Button | LED | Console |
| --- | --- | --- | --- |
| ESP32-S3-BOX | **BOOT** GPIO0, active low (held at reset = download mode); RESET; MUTE is a hardware mic mute, not a user button | **no user LED** - LED1 = **LCD backlight** GPIO45 (`TFT_BL`, strapping pin, driven after boot) | `Serial` = USB Serial/JTAG (HWCDC) `303A:1001` on the USB-C port |

## Stage 1 - Tools and folder paths

```bash
bash "$SKILL/scripts/check_tools.sh" <board-id> [--ws <workspace>]
```
Checks the workspace path (no spaces or non-ASCII, ≤100 characters), PlatformIO Core (called by
full path: `~/.platformio/penv/Scripts/pio.exe`; do not put penv on PATH), the pinned platform and
its packages (`framework-arduinoespressif32` 2.0.17, `toolchain-xtensa-esp32s3` GCC 8.4, esptool),
git + `core.longpaths` (Windows), python (+ pyserial, optional: tests use PlatformIO's python), and
lists Espressif USB devices. Read-only. **Gate:** `missing/bad=0`; report every WARN. Missing
PlatformIO: tell the user to install it - don't install it yourself. Changing git config is the
user's call - ask.

## Stage 2 - Discover the board, create the project

1. **Discover:** `bash "$SKILL/scripts/discover.sh" <board-id> [--serial <usb-serial>]`
   - lists Espressif USB devices (USB serial = the chip's MAC), then esptool reads chip, features,
     MAC, flash size and the security state. It writes nothing but **resets the chip** (the running
     firmware restarts) - say so.
   - **Gate:** `IDENTITY: PASS` (chip ESP32-S3, MAC = USB serial, flash = profile, secure boot and
     flash encryption disabled) + `Saved ...` (bench file). Several boards: `--serial`.
2. **Create the app:** `bash "$SKILL/scripts/new_app.sh" <board-id> <app-name> [<workspace>] [template]`
   - copies `templates/_common/src` (board + func layers) and the template's `src/` + `tests/`,
     writes `platformio.ini` and `arduino-app.env`. No network needed.
   - **Gate:** `Created ...`.
3. **Open in the IDE (stage 2d, automatic):** at the end, `new_app.sh` runs
   `bash "$SKILL/scripts/open_ide.sh" <app>` (`--no-open` on new_app/open_ide: no window). It writes
   `<app>.code-workspace` (the app folder, PlatformIO IDE recommended) and opens it in VS Code;
   PlatformIO IDE picks up `platformio.ini`. The developer can then Build (same env and
   `.pio/build/<env>` as build.sh), Upload, open the Serial Monitor and edit `src/` from the
   PlatformIO toolbar (PlatformIO IDE writes its own `.vscode/` - git-ignored). **Gate:**
   `IDE: READY <workspace>` + `IDE: OPENED`; exit 10 `ACTION: SETUP` = VS Code or PlatformIO IDE is
   missing (new_app.sh only reports it). See docs/workflow.md "IDE handoff".

## Stage 3 - Code in layers

Read `reference/layering.md` before writing code. Rules:
Arduino style: every file includes `<Arduino.h>` and uses the Arduino API - `millis()`,
`Print`/`Stream` (`print`, `println`, `printf`), `pinMode`/`digitalWrite`/`digitalRead`, `HIGH`/`LOW`.
No ESP-IDF calls, no C stdio (`printf`, `stdout`) - output goes through `console_out()`.
- `src/board/` - **only** place for pin numbers (variant macros such as `TFT_BL`), the console port
  (`Serial`, returned as a `Stream&` by `board_console()`), pin I/O calls and
  `#if defined(BOARD_xxx)`.
- `src/func/` - services (console, led, button) on the Arduino API + `board.h`; 1-based numbers
  like the silkscreen. No pins, no `Serial` directly.
- `src/main.cpp` - the sketch: `setup()` (init + banner) and `loop()` (poll the services); state is
  file-static. Print with `console_out().println(...)` / `.printf(...)` (`println` ends lines with
  CR LF). `loop()` must not block: no long `delay()`, time things with `millis()`.
- Keep the console protocol: `OK ...`, `ERR ...`, `EVT ...`, `<TAG> k=v ...`,
  `INFO ... board=<id> ...` then `READY` - tests depend on it.
- Templates: `hello-world` (1 s print), `blink` (LED1 every 0.5 s), `push-to-light` (console LED commands, BOOT toggles the LCD
  backlight, `EVT` lines). `help.sh` lists them from `description.txt`.
- Libraries: `lib_deps = owner/name @ 1.2.3` (exact version) in `platformio.ini`; wrap anything that
  touches hardware in `board/`.

**Check the layers (M2 - gated, stops with `ACTION: SETUP` until enabled):**
`python <repo>/lib/check_layers.py <app-dir>` → `LAYERS: PASS` (`<Arduino.h>` is allowed in every
layer; pin I/O and `Serial` only in `board/`). `host_test.sh` does not cover this skill: it tests
the C `lib/func`, and this func/ is Arduino C++.

## Stage 4 - Build

```bash
bash "$SKILL/scripts/build.sh" <app-dir> [--clean] [--allow-warnings]
```
`pio run` with the app's env, log in `<app>/logs/` (about 20 s once the platform is installed).
**Gate:** `BUILD: PASS` = pio exit 0, `firmware.bin`/`.elf`, `bootloader.bin`, `partitions.bin`
present, **0 warnings in `src/`** (C and C++; exit 2 = fix them). Use `--clean` for a full warning
check. `.pio/build/<env>/manifest.txt` (pio + platform version, every package, sizes, the flash map
PlatformIO would upload - bootloader 0x0, partitions 0x8000, `boot_app0.bin` 0xe000, sketch
0x10000 - and the sha256 of every image) is written **only on PASS**.

## Stage 5 - Flash

**Ask the user before every flash** (board, app, firmware.bin sha256 prefix): it replaces the
bootloader, partition table and app. Offer a backup first if the board holds firmware they care
about:
```bash
bash "$SKILL/scripts/backup.sh" <board-id>        # optional: whole flash -> <repo>/backup/ (minutes)
bash "$SKILL/scripts/flash.sh" <app-dir> --yes
```
`FLASH_POLICY=auto` in this board's bench file replaces `--yes` for a dedicated lab board - only
the developer writes it, never you. discover, backup, flash and test hold a per-board lock: `board
'<id>' is in use` means another run has the board - wait.
Gates inside: every image of the manifest's flash map matches its sha256 → board with the bench
USB serial → esptool identity (as discover) → `write_flash` of the map (flash mode/size/freq kept as
built), every region "Hash of data verified" → hard reset → the console port is back.
**Gate:** `FLASH: PASS (4/4 regions ...)`. Never use `pio run -t upload` (no gates).

## Stage 6 - Test (after flashing)

```bash
~/.platformio/penv/Scripts/python "$SKILL/scripts/serial_test.py" auto <app>/tests/<spec>.json <app>/logs/test-<ts>.log --board <id> [--interactive | --only-interactive]
```
PlatformIO's python has pyserial (the system python may not). `auto` = the USB Serial/JTAG port
with this board's MAC. Opening the port does not reset the sketch. Default `--sync` sends `info`
until `READY`, checks `board=<id>`, runs the steps. Interactive steps (press BOOT, look at the LCD
backlight) only with `--interactive`: tell the user exactly what to do first, and to keep the USB
cable still (a jolt drops the port). **Gate:** `RESULT: PASS`. `led?` reads the GPIO level back;
only a human confirms the backlight lit.

## Stage 7 - Clean

```bash
bash "$SKILL/scripts/clean.sh" [--apps] [<workspace>]          # dry run
bash "$SKILL/scripts/clean.sh" [--apps] [<workspace>] --yes    # delete (ask the user first)
```
- default: **build outputs only** (`<app>/.pio`). Sources, tests, logs, `.bench` are kept.
- `--apps`: also deletes **whole apps** made by `new_app.sh` (`arduino-app.env`) - the user's code
  - and `.bench`. Only when the user explicitly asks; name the apps. `APP_PUBLISHED=1` apps keep
  sources.
- Never touches `~/.platformio` (shared by all PlatformIO projects).

## Extending the skill

- **Another ESP32-S3 board:** copy `boards/_template/` to `boards/<id>/`, fill `README.md` and
  `pio-arduino-esp32s3box/board.env` (`pio boards esp32s3` for the board id; check its variant's
  `pins_arduino.h`), add a `BOARD_<ID>` block to `templates/_common/src/board/board.h` and its I/O
  table to `board.cpp`. Never invent a board id or pins - stop and ask.
- **New template:** `templates/<name>/src/main.cpp` + `tests/<name>.json` + `description.txt`.
- **Platform update:** change `PIO_PLATFORM` in the board profile (exact version), rebuild every
  template, compare the manifests, re-test on hardware, log it - never float to "latest".

## Reporting (always)

Report verification levels separately: **source matches → built → flashed → booted (READY) →
tested (PASS n/m) → observed by a human**. Quote the firmware.bin sha256, platform version and log
paths. Add a dated line to `boards/<id>/pio-arduino-esp32s3box/README.md` (verification log) when a
board fact is newly verified.

## Safety rules

- Never burn eFuses (`espefuse.py`), enable flash encryption or secure boot - irreversible. Stop
  and ask.
- Identity gate before every write (chip, MAC = bench serial, flash size, security off); never
  flash an image without a PASS manifest. Ask before every flash and before `clean.sh --yes`.
- Never run installers or change drivers without asking.
