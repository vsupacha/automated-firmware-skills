---
name: pio-arduino-rpipico2w
description: End-to-end firmware workflow for the Raspberry Pi Pico 2 W (RP2350) with PlatformIO and the arduino-pico core - check tools and folder paths, discover the board by its USB serial / chip ID (also in BOOTSEL), create a PlatformIO app from a layered template (board -> func -> main) with the platform pinned to a commit, build with a manifest, flash with picotool behind identity gates (chip type, flash size, chip ID), run automated serial tests, and clean build outputs. Use when asked to create, build, flash (แฟลช) or test Pico 2 W / RP2350 firmware with PlatformIO or Arduino (บอร์ด Pico 2 W), add an RP2350 board profile, or when the user asks how to use this skill / what commands exist (ขอวิธีใช้, มีคำสั่งอะไรบ้าง, help). Not for RP2040 Picos, Pico SDK (CMake) projects or MicroPython.
---

# Raspberry Pi Pico 2 W firmware workflow (PlatformIO)

Six gated stages plus a clean step, the same contract as every skill in this repo
(`docs/workflow.md`). Do them in order; do not start a stage until the previous gate passed.
Each stage has a script in `scripts/` and details in `reference/`.
Bash: Git Bash on Windows (Claude's Bash tool), or Linux/macOS.

```
1 tools ─► 2 discover + project ─► 3 code ─► 4 build ─► 5 flash ─► 6 test ─► 7 clean
check_tools  discover (board)      src/board  build.sh   flash.sh   serial_test  clean.sh
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
| M1 bring-up (board) | 4 connect, 5 flash, 6 test, 7 debug *(planned)* | Stage 2 step 1, Stage 5, Stage 6 |
| M2 board support | 8 board drivers *(planned)*, 9 layer check, 10 host test *(optional)* | Stage 3 (rules, shared `lib/func`, `check_layers.py`, `host_test.sh`) |
| M3 execution, M4 components, M5 application | 11 execution + trace, 12 components, 13 profile *(planned)* | - |
| - | 14 export *(planned)*, 15 port *(planned)* | Extending |
| - | 16 clean | Stage 7 |

**Exit codes:** 0 gate passed, 1 failed, 2 warnings, **10 = developer action needed**. On exit 10
the script's last line is `ACTION: <TYPE> <what to do>` (SETUP, CONNECT, POWER_CYCLE, JUMPER,
APPROVE, CHOOSE): tell the user exactly that, wait for their OK, then re-run the same command
(with `--yes` / `--serial` when the action says so). Never work around an ACTION yourself -
installing tools, accepting licences, changing drivers/system settings, plugging hardware and
approving flashes or deletions are the developer's.

**Release scope:** `<repo>/milestones.env` lists the active milestones (this release: **M1**).
M1 includes the board stages: discover, flash and serial tests run when the developer asks for
them, and **every flash needs the developer's yes first** (`flash.sh --yes` only after they said
yes in chat, or `FLASH_POLICY=auto` that they wrote into their own bench file). Scripts of an
inactive milestone (e.g. M2 `check_layers.py`) stop with `ACTION: SETUP ... not active`; never
edit `milestones.env` or set `FW_ACTIVE_MILESTONES` yourself - relay the ACTION like any other.

## Help menu (answer this first when asked how to use the skill)

When the user asks for help, usage or the list of commands ("ขอวิธีใช้หน่อย", "มีคำสั่งอะไรบ้าง",
"help", "what can you do"), run `bash "$SKILL/scripts/help.sh"` (Thai) or `help.sh --en` and show
its output as-is. Then offer the next step that fits (usually Stage 1). Do not run other stages.

`$SKILL` below = the folder containing this SKILL.md. Always quote: `bash "$SKILL/scripts/x.sh"`.
This skill is part of the automated-firmware-skills repo and needs the repo layout:

```
<repo>/skills/pio-arduino-rpipico2w/        this skill (SKILL.md, scripts/, reference/, templates/)
<repo>/boards/<id>/README.md          board hardware (tool-independent)
<repo>/boards/<id>/pio-arduino-rpipico2w/   this skill's board profile: board.env, README (verification log)
<repo>/apps/                          apps workspace when working inside the repo
```

The apps workspace `$PICO_WS`: `<repo>/apps` when the current directory is inside the repo
checkout, otherwise `./apps` (e.g. skill installed as a plugin). Board profiles are looked up in
`<project>/boards/<id>/pio-arduino-rpipico2w/` first (the user's own boards), then `<repo>/boards`
(override `PICO_BOARDS_DIR`). `new_app.sh` adds its lines to `<workspace>/.gitignore`.

## Board type vs bench instance

- **Board type** (`boards/<id>/`): `README.md` = hardware (pins, LED, BOOTSEL, CYW43439);
  `pio-arduino-rpipico2w/board.env` = PlatformIO platform (pinned commit), board id, core, `BOARD_DEFINE`,
  `BTN_LABELS`, expected chip + flash size, USB IDs.
- **Bench instance** (`<workspace>/.bench/<id>.env`, written by `discover.sh`): `USB_SERIAL`
  (= the chip ID, unique per board, the same in BOOTSEL and in a sketch) and `CONSOLE_PORT`.
  Override with `PICO_USB_SERIAL` / `PICO_CONSOLE`. Never write a serial or COM port into `boards/`.

| id | board | status |
| --- | --- | --- |
| `rpi-pico-2w` | Raspberry Pi Pico 2 W (RP2350A, 4 MB, CYW43439) | verified on hardware |

## Hardware quick reference

Use the **silkscreen name** with the user. Details: `boards/rpi-pico-2w/README.md`.

| Board | Button | LED | Console |
| --- | --- | --- | --- |
| Pico 2 W | **BOOTSEL** (read at run time with the core's `BOOTSEL`; held at power-up = USB boot mode). **No reset button.** | one LED on the CYW43439 Wi-Fi module (`LED_BUILTIN` = 64, not an RP2350 GPIO; no read-back) | USB CDC of the sketch (`2E8A:F00F`) |

GP23/24/25/29 belong to the CYW43439 - never hand them out as GPIO. ADC: GP26/27/28 only.

## Stage 1 - Tools and folder paths

```bash
bash "$SKILL/scripts/check_tools.sh" <board-id> [--ws <workspace>]
```
Checks the workspace path (no non-ASCII characters, ≤100 characters - Windows' 260-char limit),
PlatformIO Core (called by full path: `~/.platformio/penv/Scripts/pio.exe`; do not put penv on
PATH), the pinned platform (installed by the first build if missing), picotool, git and
`core.longpaths` (Windows), python + pyserial, and lists RP2 USB devices. Read-only.
**Gate:** `missing/bad=0`; report every WARN. Missing PlatformIO: tell the user to install it
(`python -m pip install -U platformio` or the VS Code extension) - don't install it yourself.
Changing git config (`core.longpaths`) is the user's call - ask.

## Stage 2 - Discover the board, create the project

1. **Discover (read-only):** `bash "$SKILL/scripts/discover.sh" <board-id> [--serial <usb-serial>]`
   - lists RP2 devices: sketch mode (CDC port) or BOOTSEL (no port; blank boards start here).
   - BOOTSEL: picotool checks chip type, flash size and that the chip ID equals the USB serial.
     Sketch mode: USB IDs + serial (chip type is checked by flash.sh in BOOTSEL).
   - **Gate:** `IDENTITY: PASS` + `Saved ...`. More than one board: `--serial` (it never guesses).
   - No board yet? Skip to step 2.
2. **Create the app:** `bash "$SKILL/scripts/new_app.sh" <board-id> <app-name> [<workspace>] [template]`
   - writes `platformio.ini` (pinned platform commit, board, core, `-D<BOARD_DEFINE>`,
     `-Wall -Wextra` for `src/` only), copies `templates/_common/src` + the template's `src/` and
     `tests/`, records `pico-app.env`. No network needed.
   - **Gate:** ends with `Created ...`.
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
- `src/board/` - **only** place for pin numbers, `LED_BUILTIN`, `BOOTSEL`, `#if defined(BOARD_xxx)`.
  `board.h` maps `-DBOARD_<ID>` to `BOARD_ID_NAME` (not `BOARD_NAME`: arduino-pico defines that).
- `src/func/` - reusable services (console, led, button...). Include `../board/board.h` only.
- `src/main.cpp` - `setup()`/`loop()` wiring + application logic. Uses `func/` and `board_init()`.
- Keep the console protocol: `OK ...`, `ERR ...`, `EVT ...`, `<TAG> k=v ...`,
  `INFO ... board=<id> ...` then `READY` - tests depend on it.
- Write/extend `tests/<app>.json` from the requirements before the code; gate board-dependent steps
  with `requires_re` (spec keys: `scripts/serial_test.py` docstring).
- Templates: `hello-world` (1 s print), `blink` (LED1 every 0.5 s), `push-to-light` (console LED commands, BOOTSEL toggles the
  LED, `EVT` lines). `help.sh` lists them from `description.txt`.
- Libraries: add `lib_deps = ...` with an exact version (`owner/name @ 1.2.3`), never unpinned.

**Check the layers (M2 - gated, stops with `ACTION: SETUP` until enabled):**
`python <repo>/lib/check_layers.py <app-dir>` → `LAYERS: PASS` (exit 2 = warnings to fix).
`host_test.sh` does not cover this skill yet: its `func/` is a C++ copy, to be merged into
`lib/func` (docs/board-api.md).

## Stage 4 - Build

```bash
bash "$SKILL/scripts/build.sh" <app-dir> [--clean] [--allow-warnings]
```
`pio run` with the app's env, log in `<app>/logs/`. The first build may install the pinned platform
and the arduino-pico framework (~1.5 GB, git clone); later builds take seconds.
**Gate:** `BUILD: PASS` = pio exit 0, firmware present, **0 warnings in `src/`** (exit 2 = fix them).
An incremental build only recompiles changed files: use `--clean` for a full warning check.
`.pio/build/<env>/manifest.txt` (pio version, platform commit, every package version, RAM/flash
use, sha256 of uf2/elf/bin) is written **only on PASS** - flash.sh requires it.

## Stage 5 - Flash

**Ask the user before every flash** (board, app, uf2 sha256 prefix). There is no backup step: an
arduino-pico sketch cannot be read back usefully - say so if the board holds firmware they care about.
```bash
bash "$SKILL/scripts/flash.sh" <app-dir> --yes [--uf2 <known-good.uf2>]
```
`FLASH_POLICY=auto` in this board's bench file replaces `--yes` for a dedicated lab board - only
the developer writes it, never you. discover, flash and test hold a per-board lock: `board '<id>'
is in use` means another run has the board - wait; delete the lock only after the user confirms
that run is gone.
Gates inside: uf2 matches the PASS manifest → board with the bench serial found → if a sketch
runs, 1200-baud touch to reboot into BOOTSEL → picotool identity (chip, flash size, chip ID =
bench serial, secure boot off) → `picotool load -v -x` (program, verify 100%, run) → the sketch's
CDC port is back (bench `CONSOLE_PORT` updated if the COM number changed).
**Gate:** `FLASH: PASS`. "not found in BOOTSEL": the running sketch has no USB serial (or crashed)
- ask the user to unplug, hold BOOTSEL, plug in, release, then re-run.

## Stage 6 - Test (after flashing)

```bash
python "$SKILL/scripts/serial_test.py" auto <app>/tests/<spec>.json <app>/logs/test-<ts>.log --board <id> [--interactive | --only-interactive]
```
`auto` = the CDC port with this board's USB serial. Default `--sync` sends `info` every second
until `READY`, checks the image reports `board=<id>`, then runs the steps. Interactive steps
(press BOOTSEL, look at the LED) run only with `--interactive`: first tell the user exactly what
to do, then run. **Gate:** `RESULT: PASS`. The LED state reported by `led?` is the commanded
state (no read-back on this board) - only a human can confirm the LED really lit.

## Stage 7 - Clean

```bash
bash "$SKILL/scripts/clean.sh" [--apps] [<workspace>]          # dry run
bash "$SKILL/scripts/clean.sh" [--apps] [<workspace>] --yes    # delete (ask the user first)
```
- default: **build outputs only** (`<app>/.pio`). Sources, tests, logs, `.bench` are kept.
- `--apps`: also deletes **whole apps** made by `new_app.sh` (`pico-app.env`) - the user's code -
  and `.bench`. Only when the user explicitly asks; name the apps. `APP_PUBLISHED=1` apps keep sources.
- Never touches `~/.platformio` (shared by all PlatformIO projects).

## Extending the skill

- **Another RP2350 board** (Pico 2, a custom board): copy `boards/_template/` to `boards/<id>/`
  (or `<project>/boards/<id>/` for the user's own board), fill `README.md` and
  `pio-arduino-rpipico2w/board.env` (`pio boards rp2350` for the board id; USB hwids from
  `pio boards <id> --json-output`), add a `BOARD_<ID>` block to `templates/_common/src/board/board.h`
  (for a project board: to the app's copy after `new_app.sh`). Never invent a board id - if
  `pio boards` has no exact match, stop and ask.
- **New template:** `templates/<name>/src/main.cpp` + `tests/<name>.json` + `description.txt`.
  `templates/_common/src` (board + func layers) is copied first.
- **Platform update:** change `PIO_PLATFORM` in the board profile (new commit), rebuild every
  template, compare the manifests, re-test on hardware, log it - never float on the branch head.

## Reporting (always)

Report verification levels separately: **source matches → built → flashed → booted (READY) →
tested (PASS n/m) → observed by a human**. Never claim a level without a log line. Quote the uf2
sha256, platform commit and log paths. Add a dated line to `boards/<id>/pio-arduino-rpipico2w/README.md`
(verification log) when a board-level fact is newly verified.

## Safety rules

- Identity gate before every write: chip type, flash size, chip ID = bench serial. Never flash a
  board whose identity does not match, or with secure boot enabled - stop and ask.
- Never flash a uf2 without a PASS manifest (except an explicit `--uf2` image the user chose).
- Ask before every flash and before `clean.sh --yes`.
- Never write OTP, never enable secure boot or change boot keys (`picotool otp`, `picotool
  partition`), never bind USB drivers (Zadig) or run installers without asking.
