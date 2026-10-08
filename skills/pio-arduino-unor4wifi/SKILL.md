---
name: pio-arduino-unor4wifi
description: Firmware workflow for the Arduino UNO R4 WiFi (Renesas RA4M1) with PlatformIO and the Arduino UNO R4 core (renesas-ra platform) - check tools and folder paths, create a PlatformIO Arduino app from a layered template (board -> func -> setup/loop) written with the Arduino API, with the platform pinned to an exact version, open it in VS Code with PlatformIO IDE, build it with a manifest, discover the board through its ESP32-S3 USB bridge (USB serial, loader identity), flash the sketch with bossac behind identity gates, and run automated serial tests (console + LED L; the board has no user button). Use when asked to create, build, flash (แฟลช) or test UNO R4 WiFi firmware with PlatformIO (บอร์ด Arduino UNO R4 WiFi), or how to use this skill (ขอวิธีใช้, มีคำสั่งอะไรบ้าง, help). Not for the Arduino IDE / arduino-cli, the UNO R4 Minima, the classic UNO R3, or the board's ESP32-S3 bridge firmware.
---

# Arduino UNO R4 WiFi firmware workflow (PlatformIO + Arduino)

Gated stages, the same contract as every skill in this repo (`docs/workflow.md`). Do them in order;
do not start a stage until the previous gate passed. Each stage has a script in `scripts/` and
details in `reference/`. Bash: Git Bash on Windows (Claude's Bash tool), or Linux/macOS.
Code is Arduino style throughout (like `pio-arduino-esp32s3box`, whose func layer this one copies;
here output uses `console_printf()` because the Renesas core's `Print` has no `printf`).

```
1 tools ─► 2 discover + project ─► 3 code ─► 4 build ─► 5 flash ─► 6 test ─► 7 clean
check_tools  discover (bossac)     src/board  build.sh   flash.sh   serial_test  clean.sh
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
| M1 bring-up (board) | 4 connect, 5 flash, 6 test, 7 debug *(planned: needs an SWD probe)* | Stage 2 step 1, Stage 5, Stage 6 |
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
<repo>/skills/pio-arduino-unor4wifi/         this skill (SKILL.md, scripts/, reference/, templates/)
<repo>/boards/<id>/README.md                 board hardware (tool-independent)
<repo>/boards/<id>/pio-arduino-unor4wifi/    board profile: board.env, README (verification log)
<repo>/apps/                                 apps workspace when working inside the repo
```

The apps workspace `$UNO_WS`: `<repo>/apps` inside the repo checkout, otherwise `./apps`. Board
profiles: `<project>/boards/<id>/pio-arduino-unor4wifi/` first, then `<repo>/boards` (override
`UNO_BOARDS_DIR`). Bench overrides: `UNO_USB_SERIAL`, `UNO_CONSOLE`.

## What an app looks like

```
apps/<app>/
  platformio.ini        pinned platform (exact version), board, framework = arduino,
                        -DBOARD_<ID>, -Wall -Wextra for src/
  src/board/            board layer: pins, Serial, pinMode/digitalWrite/digitalRead (board.h/.cpp)
  src/func/             services in Arduino C++: console (Stream/Print + console_printf), led,
                        button (millis())
  src/main.cpp          the sketch: setup() + loop()
  tests/<spec>.json     test contract (the same specs as the other skills, plus LED-look steps)
  arduino-app.env       record: board, template, env, platform
  .pio/ logs/           build outputs and logs (git-ignored)
  <app>.code-workspace  VS Code workspace for PlatformIO IDE - open_ide.sh makes it (git-ignored)
```

## Board type vs bench instance

- **Board type** (`boards/<id>/`): `README.md` = hardware; `pio-arduino-unor4wifi/board.env` =
  pinned platform + toolchain, PlatformIO board id, `BOARD_DEFINE`, labels, USB ids, expected
  loader identity, sketch offset.
- **Bench instance** (`<workspace>/.bench/<id>.env`, board stages): USB serial (of the board's
  ESP32-S3 USB bridge) and COM port of one board on one PC. Never write a serial or COM port into
  `boards/`.

| id | board | status |
| --- | --- | --- |
| `uno-r4-wifi` | Arduino UNO R4 WiFi (ABX00087): RA4M1 48 MHz, 256 KB flash, 32 KB RAM; ESP32-S3 USB bridge + WiFi | see `boards/uno-r4-wifi/pio-arduino-unor4wifi/README.md` |

## Hardware quick reference

Use the **silkscreen name** with the user. Details: `boards/uno-r4-wifi/README.md`.

| Board | Button | LED | Console |
| --- | --- | --- | --- |
| UNO R4 WiFi | **no user button** - only RESET (the template's button steps are skipped) | LED1 = yellow **L** on D13 (P102), active high; the 12x8 LED matrix and TX/RX LEDs are not used | `Serial` = RA4M1 UART to the ESP32-S3 bridge = the USB-C COM port (`2341:1002`), 115200 |

## Stage 1 - Tools and folder paths

```bash
bash "$SKILL/scripts/check_tools.sh" <board-id> [--ws <workspace>]
```
Checks the workspace path (no spaces or non-ASCII, ≤100 characters), PlatformIO Core (called by
full path: `~/.platformio/penv/Scripts/pio.exe`; do not put penv on PATH), the pinned platform and
its packages (`framework-arduinorenesas-uno` 1.4.1, `toolchain-gccarmnoneeabi@1.70201.0` = GCC
7.2.1, `tool-bossac` 1.9.1), git + `core.longpaths` (Windows), python (+ pyserial, optional: tests
use PlatformIO's python), lists Arduino USB devices, and checks VS Code + PlatformIO IDE. Read-only.
**Gate:** `missing/bad=0`; report every WARN. Missing PlatformIO: tell the user to install it -
don't install it yourself. Changing git config is the user's call - ask.

## Stage 2 - Discover the board, create the project

1. **Discover:** `bash "$SKILL/scripts/discover.sh" <board-id> [--serial <usb-serial>]`
   - lists Arduino USB devices (VID 2341), then a 1200 baud touch starts the bridge's loader and
     `bossac --info --reset` reads it. It writes nothing but **restarts the sketch** - say so.
   - The bridge **emulates** a SAM-BA loader: it reports "Arduino Bootloader (SAM-BA extended) 2.0"
     and a fixed placeholder device (`nRF52840-QIAA`), not the RA4M1 - the RA4M1 is only readable
     over SWD. The sketch's INFO line (`board=uno-r4-wifi`) is the target proof after flashing.
   - **Gate:** `IDENTITY: PASS` (PID 1002, loader + device as the profile, security false, nothing
     locked) + `Saved ...` (bench file). Several boards: `--serial`.
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
`Print`/`Stream` (`print`, `println`), `pinMode`/`digitalWrite`/`digitalRead`, `HIGH`/`LOW`.
Formatted output: `console_printf(...)` (func/console.h, up to 127 characters per call) - the
Renesas core's `Print` has **no** `printf`. No C stdio (`printf`, `stdout`), no FSP/HAL calls
outside `board/`.
- `src/board/` - **only** place for pin numbers (`LED_BUILTIN`, `Dn`), the console port
  (`Serial`, returned as a `Stream&` by `board_console()`), pin I/O calls and
  `#if defined(BOARD_xxx)`.
- `src/func/` - services (console, led, button) on the Arduino API + `board.h`; 1-based numbers
  like the silkscreen. No pins, no `Serial` directly.
- `src/main.cpp` - the sketch: `setup()` (init + banner) and `loop()` (poll the services); state is
  file-static. `loop()` must not block: no long `delay()`, time things with `millis()`.
- Keep the console protocol: `OK ...`, `ERR ...`, `EVT ...`, `<TAG> k=v ...`,
  `INFO ... board=<id> ...` then `READY` - tests depend on it.
- Templates: `hello-world` (1 s print), `uart-btn-led` (console LED commands; `btns=0` on this
  board, so its button steps are skipped and two interactive steps ask the user to look at LED L).
  `help.sh` lists them from `description.txt`.
- Libraries: `lib_deps = owner/name @ 1.2.3` (exact version) in `platformio.ini`; wrap anything that
  touches hardware (LED matrix, WiFiS3) in `board/`.

**Check the layers (M2 - gated, stops with `ACTION: SETUP` until enabled):**
`python <repo>/lib/check_layers.py <app-dir>` → `LAYERS: PASS` (`<Arduino.h>` is allowed in every
layer; pin I/O and `Serial` only in `board/`). `host_test.sh` does not cover this skill (Arduino C++).

## Stage 4 - Build

```bash
bash "$SKILL/scripts/build.sh" <app-dir> [--clean] [--allow-warnings]
```
`pio run` with the app's env, log in `<app>/logs/` (under 10 s once the platform is installed).
**Gate:** `BUILD: PASS` = pio exit 0, `firmware.bin`/`.elf` present, the reset vector of
`firmware.bin` inside the sketch region (from `APP_OFFSET` 0x4000), **0 warnings in `src/`** (exit
2 = fix them). Use `--clean` for a full warning check. `.pio/build/<env>/manifest.txt` (pio +
platform version, every package, sizes, `flash 0x4000 firmware.bin`, the sha256 of firmware.bin and
.elf) is written **only on PASS**.

## Stage 5 - Flash

**Ask the user before every flash** (board, app, firmware.bin sha256 prefix): it replaces the
sketch. There is no backup: the bridge's loader cannot read flash (say so if the board holds a
sketch they care about). The Arduino loader below 0x4000 and the ESP32-S3 bridge firmware are never
written.
```bash
bash "$SKILL/scripts/flash.sh" <app-dir> --yes
```
`FLASH_POLICY=auto` in this board's bench file replaces `--yes` for a dedicated lab board - only
the developer writes it, never you. discover, flash and test hold a per-board lock: `board '<id>'
is in use` means another run has the board - wait.
Gates inside: firmware.bin matches the manifest's sha256 and offset → board with the bench USB
serial → identity (as discover) → 1200 baud touch → `bossac --erase --write --reset` (every page
written) → the console port is back. **No read-back verify:** `--verify` fails on this loader
("SAM-BA operation failed") and then skips the reset, leaving the RA4M1 in the loader - the INFO
line of Stage 6 is the proof the image runs. **Gate:** `FLASH: PASS (firmware.bin n/n pages ...)`.
Never use `pio run -t upload` (no gates).

## Stage 6 - Test (after flashing)

```bash
~/.platformio/penv/Scripts/python "$SKILL/scripts/serial_test.py" auto <app>/tests/<spec>.json <app>/logs/test-<ts>.log --board <id> [--interactive | --only-interactive]
```
PlatformIO's python has pyserial (the system python may not). `auto` = the COM port with this
board's USB serial. Opening the port does not reset the sketch (only a 1200 baud open does).
Default `--sync` sends `info` until `READY`, checks `board=<id>`, runs the steps. Interactive steps
(look at LED L on, then off) only with `--interactive`: tell the user what to look at first.
**Gate:** `RESULT: PASS`. `led?` reads the pin back; only a human confirms the LED lit.

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

- **Another RA4M1 board (e.g. UNO R4 Minima):** copy `boards/_template/` to `boards/<id>/`, fill
  `README.md` and `pio-arduino-unor4wifi/board.env`, add a `BOARD_<ID>` block to
  `templates/_common/src/board/board.h` and its I/O table to `board.cpp`. The Minima uploads with
  dfu-util over native USB (no bridge): discover/flash need their own path - never reuse the bossac
  gates unchecked. Never invent a board id or pins - stop and ask.
- **New template:** `templates/<name>/src/main.cpp` + `tests/<name>.json` + `description.txt`.
- **Platform update:** change `PIO_PLATFORM` (and `TOOLCHAIN_VERSION`) in the board profile (exact
  versions), rebuild every template, compare the manifests, re-test on hardware, log it.

## Reporting (always)

Report verification levels separately: **source matches → built → flashed (written, not read
back) → booted (READY) → tested (PASS n/m) → observed by a human**. Quote the firmware.bin sha256,
platform version and log paths. Add a dated line to `boards/<id>/pio-arduino-unor4wifi/README.md`
(verification log) when a board fact is newly verified.

## Safety rules

- Never write the ESP32-S3 bridge firmware (espflash / esptool on the bridge) or the Arduino
  loader - recovering them needs Arduino's firmware updater. Stop and ask.
- Identity gate before every write (loader, bench serial, security off, nothing locked); never
  flash an image without a PASS manifest. Ask before every flash and before `clean.sh --yes`.
- Never run installers or change drivers without asking.
