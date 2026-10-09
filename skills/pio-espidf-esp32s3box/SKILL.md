---
name: pio-espidf-esp32s3box
description: Firmware workflow for the Espressif ESP32-S3-BOX (ESP32-S3) with PlatformIO and the ESP-IDF framework - check tools and folder paths, create a PlatformIO ESP-IDF app from a layered template (board -> func -> app_main) that reuses the shared C logic layer, with the platform pinned to an exact version, build it with a manifest of every image and the resolved sdkconfig, discover the board over its USB Serial/JTAG (chip, MAC = USB serial, flash size, security state), flash with esptool behind identity gates and hash verification, and run automated serial tests. Use when asked to create, build, flash (แฟลช) or test ESP32-S3-BOX / ESP32-S3 firmware with PlatformIO or ESP-IDF (บอร์ด ESP32-S3-BOX), add an ESP32-S3 board profile, or when the user asks how to use this skill / what commands exist (ขอวิธีใช้, มีคำสั่งอะไรบ้าง, help). Not for Arduino-ESP32 sketches, idf.py projects outside PlatformIO, MicroPython, the ESP32-S3-BOX-Lite or BOX-3 (no profile yet).
---

# ESP32-S3-BOX firmware workflow (PlatformIO + ESP-IDF)

Gated stages, the same contract as every skill in this repo (`docs/workflow.md`). Do them in order;
do not start a stage until the previous gate passed. Each stage has a script in `scripts/` and
details in `reference/`. Bash: Git Bash on Windows (Claude's Bash tool), or Linux/macOS.

```
1 tools ─► 2 discover + project ─► 3 code ─► 4 build ─► 5 flash ─► 6 test ─► 7 clean
check_tools  discover (esptool)    src/board  build.sh   flash.sh   serial_test  clean.sh
             new_app               src/func
                                   app_main.c
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
| M2 board support | 8 board drivers *(planned)*, 9 layer check, 10 host test *(optional)* | Stage 3 (rules, shared `lib/func`, `check_layers.py`, `host_test.sh`) |
| M3 execution, M4 components, M5 application | 11 execution + trace, 12 components, 13 profile *(planned)* | - |
| - | 14 export *(planned)*, 15 port *(planned)* | Extending |
| - | 16 clean | Stage 7 |

**Exit codes:** 0 gate passed, 1 failed, 2 warnings, **10 = developer action needed**. On exit 10
the script's last line is `ACTION: <TYPE> <what to do>` (SETUP, CONNECT, APPROVE, CHOOSE ...):
tell the user exactly that, wait for their OK, then re-run the same command. Never work around an
ACTION yourself - installing tools, changing system or git settings, plugging hardware and
approving deletions are the developer's.

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
<repo>/skills/pio-espidf-esp32s3box/        this skill (SKILL.md, scripts/, reference/, templates/)
<repo>/lib/func/                            shared C logic layer, copied into every app's src/func
<repo>/boards/<id>/README.md                board hardware (tool-independent)
<repo>/boards/<id>/pio-espidf-esp32s3box/   board profile: board.env, sdkconfig.board, README (log)
<repo>/apps/                                apps workspace when working inside the repo
```

The apps workspace `$ESP_WS`: `<repo>/apps` inside the repo checkout, otherwise `./apps`. Board
profiles: `<project>/boards/<id>/pio-espidf-esp32s3box/` first, then `<repo>/boards` (override
`ESP_BOARDS_DIR`). `new_app.sh` adds its lines to `<workspace>/.gitignore`.

## What an app looks like

```
apps/<app>/
  platformio.ini        pinned platform (exact version), board, framework = espidf
  CMakeLists.txt        ESP-IDF project file (project name = app name)
  sdkconfig.defaults    the skill's defaults + the board's sdkconfig.board (commit it)
  src/CMakeLists.txt    the app component: every src/**/*.c, -DBOARD_<ID>, -Wall -Wextra
  src/board/            board layer (GPIOs, ESP-IDF drivers)
  src/func/             copy of <repo>/lib/func (console, led, button)
  src/app_main.c        execution layer: app_main() superloop
  tests/<spec>.json     test contract (the same specs as the other skills)
  esp-app.env           record: board, template, env, platform
  sdkconfig.<env>       generated by the first build from sdkconfig.defaults (git-ignored)
  .pio/ logs/           build outputs and logs (git-ignored)
  <app>.code-workspace  VS Code workspace for PlatformIO IDE - open_ide.sh makes it (git-ignored)
```

## Board type vs bench instance

- **Board type** (`boards/<id>/`): `README.md` = hardware; `pio-espidf-esp32s3box/board.env` =
  pinned platform, PlatformIO board id, `BOARD_DEFINE`, `BTN_LABELS`/`LED_LABELS`, expected
  identity; `sdkconfig.board` = flash size/mode, PSRAM.
- **Bench instance** (`<workspace>/.bench/<id>.env`, board stages): USB serial (= MAC address) and COM port of
  one board on one PC. Never write a serial or COM port into `boards/`.

| id | board | status |
| --- | --- | --- |
| `esp32-s3-box` | Espressif ESP32-S3-BOX, 2021 model (ESP32-S3, 16 MB flash) | see `boards/esp32-s3-box/pio-espidf-esp32s3box/README.md` |

## Hardware quick reference

Use the **silkscreen name** with the user. Details: `boards/esp32-s3-box/README.md`.

| Board | Button | LED | Console |
| --- | --- | --- | --- |
| ESP32-S3-BOX | **BOOT** GPIO0, active low (held at reset = download mode); RESET; MUTE is a hardware mic mute, not a user button | **no user LED** - LED1 = **LCD backlight** GPIO45 (strapping pin, driven after boot) | USB Serial/JTAG `303A:1001` on the USB-C port |

## Stage 1 - Tools and folder paths

```bash
bash "$SKILL/scripts/check_tools.sh" <board-id> [--ws <workspace>]
```
Checks the workspace path (no spaces or non-ASCII, ≤100 characters - ESP-IDF's CMake/ninja and its
python environment break on them), PlatformIO Core (called by full path:
`~/.platformio/penv/Scripts/pio.exe`; do not put penv on PATH), the pinned platform and the
packages ESP-IDF builds with (`framework-espidf`, `toolchain-xtensa-esp-elf`, esptool, cmake,
ninja), git + `core.longpaths` (Windows), python + pyserial (board stages only), and lists Espressif USB
devices. Read-only. **Gate:** `missing/bad=0`; report every WARN. Missing PlatformIO: tell the user
to install it - don't install it yourself. Changing git config is the user's call - ask.

## Stage 2 - Discover the board, create the project

1. **Discover:** `bash "$SKILL/scripts/discover.sh" <board-id> [--serial <usb-serial>]`
   - lists Espressif USB devices (USB serial = the chip's MAC), then esptool reads chip, features,
     MAC, flash size and the security state. It writes nothing but **resets the chip** (the running
     firmware restarts) - say so.
   - **Gate:** `IDENTITY: PASS` (chip ESP32-S3, MAC = USB serial, flash = profile, secure boot and
     flash encryption disabled) + `Saved ...` (bench file). Several boards: `--serial`.
2. **Create the app:** `bash "$SKILL/scripts/new_app.sh" <board-id> <app-name> [<workspace>] [template]`
   - copies `<repo>/lib/func` to `src/func`, `templates/_common` (board layer, `src/CMakeLists.txt`,
`sdkconfig.defaults`) and the template's `src/` + `tests/`, appends the board's `sdkconfig.board`,
writes `CMakeLists.txt`, `platformio.ini`, `esp-app.env`. No network needed.
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
- `src/board/` - **only** place for GPIO numbers, ESP-IDF driver calls (`gpio_*`,
  `usb_serial_jtag_*`, `esp_timer_*`, FreeRTOS) and `#if defined(BOARD_xxx)`.
- `src/func/` - shared services from `<repo>/lib/func`, unchanged (board.h + C library only). A new
  reusable service goes into `lib/func`.
- `src/app_main.c` - `app_main()` wiring + application logic. The superloop ends every pass with
  `board_delay_ms(1)`: ESP-IDF runs it as a FreeRTOS task, and a loop that never yields starves the
  idle task and trips the task watchdog.
- Keep the console protocol: `OK ...`, `ERR ...`, `EVT ...`, `<TAG> k=v ...`,
  `INFO ... board=<id> ...` then `READY` - tests depend on it.
- Templates: `hello-world` (1 s print), `blink` (LED1 every 0.5 s), `push-to-light` (console LED commands, BOOT toggles the LCD
  backlight, `EVT` lines). `help.sh` lists them from `description.txt`.
- ESP-IDF components: add them to `PRIV_REQUIRES` in `src/CMakeLists.txt`; managed components
  (`idf_component.yml`) with exact versions only, and commit `dependencies.lock`.
- sdkconfig: change `sdkconfig.defaults` (or the board's `sdkconfig.board`), delete
  `sdkconfig.<env>`, rebuild - never hand-edit `sdkconfig.<env>`.

**Check the layers (M2 - gated, stops with `ACTION: SETUP` until enabled):**
`python <repo>/lib/check_layers.py <app-dir>` → `LAYERS: PASS`, and
`bash <repo>/lib/host_test.sh <app-dir>` → `HOST: PASS` (the app's `func/` on the PC, fake board).

## Stage 4 - Build

```bash
bash "$SKILL/scripts/build.sh" <app-dir> [--clean] [--allow-warnings]
```
`pio run` with the app's env, log in `<app>/logs/`. The first build on a PC sets up ESP-IDF's
python environment (minutes, network); a clean build of an app takes a few minutes, later builds
seconds. **Gate:** `BUILD: PASS` = pio exit 0, `firmware.bin`/`.elf`, `bootloader.bin`,
`partitions.bin` present, **0 warnings in `src/`** (exit 2 = fix them). Use `--clean` for a full
warning check. `.pio/build/<env>/manifest.txt` (pio + platform version, every package, sizes,
sha256 of the four images and of `sdkconfig.<env>`) is written **only on PASS**.

## Stage 5 - Flash

**Ask the user before every flash** (board, app, firmware.bin sha256 prefix): it replaces the
bootloader, partition table and app - the factory demo stops booting. Offer a backup first:
```bash
bash "$SKILL/scripts/backup.sh" <board-id>        # optional: whole flash -> <repo>/backup/ (minutes)
bash "$SKILL/scripts/flash.sh" <app-dir> --yes
```
`FLASH_POLICY=auto` in this board's bench file replaces `--yes` for a dedicated lab board - only
the developer writes it, never you. discover, backup, flash and test hold a per-board lock: `board
'<id>' is in use` means another run has the board - wait.
Gates inside: bootloader/partitions/firmware match the PASS manifest → board with the bench USB
serial → esptool identity (as discover) → `write_flash` at the offsets from ESP-IDF's
`flasher_args.json`, every region "Hash of data verified" → hard reset → the console port is back.
**Gate:** `FLASH: PASS (3/3 regions ...)`. Never use `pio run -t upload` (no gates).

## Stage 6 - Test (after flashing)

```bash
~/.platformio/penv/Scripts/python "$SKILL/scripts/serial_test.py" auto <app>/tests/<spec>.json <app>/logs/test-<ts>.log --board <id> [--interactive | --only-interactive]
```
PlatformIO's python has pyserial (the system python may not). `auto` = the USB Serial/JTAG port
with this board's MAC. Opening the port does not reset the app. Default `--sync` sends `info`
until `READY`, checks `board=<id>`, runs the steps. Interactive steps (press BOOT, look at the
LCD backlight) only with `--interactive`: tell the user exactly what to do first.
**Gate:** `RESULT: PASS`. `led?` reads the GPIO level back; only a human confirms the backlight lit.

## Stage 7 - Clean

```bash
bash "$SKILL/scripts/clean.sh" [--apps] [<workspace>]          # dry run
bash "$SKILL/scripts/clean.sh" [--apps] [<workspace>] --yes    # delete (ask the user first)
```
- default: **build outputs only** (`.pio`, `sdkconfig.<env>`, `managed_components`). Sources,
  `sdkconfig.defaults`, tests, logs, `.bench` are kept.
- `--apps`: also deletes **whole apps** made by `new_app.sh` (`esp-app.env`) - the user's code -
  and `.bench`. Only when the user explicitly asks; name the apps. `APP_PUBLISHED=1` apps keep sources.
- Never touches `~/.platformio` (shared by all PlatformIO projects).

## Extending the skill

- **Another ESP32-S3 board** (BOX-3, BOX-Lite, DevKitC): copy `boards/_template/` to
  `boards/<id>/`, fill `README.md`, `pio-espidf-esp32s3box/board.env` (`pio boards esp32s3` for the
  board id) and `sdkconfig.board`, add a `BOARD_<ID>` block to
  `templates/_common/src/board/board.h` and its I/O table to `board.c`. Never invent a board id or
  pins - if the vendor docs disagree, stop and ask. (A board that is not a BOX may later justify a
  skill named for its own board.)
- **New template:** `templates/<name>/src/app_main.c` + `tests/<name>.json` + `description.txt`.
- **Platform update:** change `PIO_PLATFORM` in the board profile (exact version), rebuild every
  template, compare the manifests, log it - never float to "latest".

## Reporting (always)

Report verification levels separately: **source matches → built → flashed → booted (READY) →
tested (PASS n/m) → observed by a human**. Quote the firmware.bin sha256, platform version and log paths. Add a dated line to
`boards/<id>/pio-espidf-esp32s3box/README.md` (verification log) when a board fact is newly verified.

## Safety rules

- Never burn eFuses (`espefuse.py`), enable flash encryption or secure boot, or write the
  bootloader/partition table of a board with protection enabled - irreversible. Stop and ask.
- Identity gate before every write (chip, MAC = bench serial, flash size, security off); never
  flash an image without a PASS manifest. Ask before every flash and before `clean.sh --yes`.
- Never run installers or change drivers without asking.
