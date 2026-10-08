---
name: scons-rtthread-visionboard
description: Firmware workflow for the RT-Thread Vision Board (Renesas RA8D1, Cortex-M85) with RT-Thread 5.0.2, its scons build and the board SDK from RT-Thread Studio - check tools and folder paths, create a standalone RT-Thread app from the SDK's blink project plus a layered template (board -> func -> hal_entry.c with msh commands), already synced as an RT-Thread Studio project (GCC 13.3), open it in RT-Thread Studio, build it with scons and a manifest, discover the board's ART-Link CMSIS-DAP probe with pyOCD (read-only CPUID check), flash code flash only (never the option-setting memory) with read-back, and run automated and interactive msh tests (RGB LED, KEY0). Use when asked to create, build, flash (แฟลช) or test Vision Board / RA8D1 RT-Thread firmware, open such an app in RT-Thread Studio, or how to use this skill (ขอวิธีใช้, มีคำสั่งอะไรบ้าง, help). Not for Renesas e2 studio / FSP-only projects, Keil MDK, or other RA boards without a profile.
---

# RT-Thread Vision Board firmware workflow (RT-Thread + scons + pyOCD)

Gated stages, the same contract as every skill in this repo (`docs/workflow.md`). Do them in order;
do not start a stage until the previous gate passed. Each stage has a script in `scripts/` and
details in `reference/`. Bash: Git Bash on Windows (Claude's Bash tool). Every tool comes from an
**RT-Thread Studio** install: the Vision Board SDK (BSP 1.3.0: RT-Thread 5.0.2 + FSP), GNU Arm,
the RT-Thread env (scons) and RT-Thread's pyOCD with the Renesas RA packs.

```
1 tools ─► 2 project + IDE ─► 3 build ─► 4 connect ─► 5 flash ─► 6 test ─► 16 clean
check_tools  new_app            build.sh   discover     flash.sh   serial_test  clean.sh
             open_ide (Studio)  (scons)    (pyOCD)      (pyOCD)    (msh)
```

**Two paths after Stage 2** (`docs/workflow.md`): the developer may code in RT-Thread Studio at any
time - the **IDE path** (`new_app.sh` already imported the app; `open_ide.sh <app>` starts Studio;
they build, download and debug with Studio's buttons) - or let you run the stages - the **script
path** (build, flash, tests behind their gates). Ask which one when it is not clear. On the IDE
path, stop after stage 2d and run scripts only when asked ("build it", "test it"); never overwrite
files the developer is editing. Both paths share the app folder and sources (Studio builds into
`Debug/`, build.sh into the app folder), so switching is always possible.

## Milestones, stage numbers and developer actions

This skill implements the shared contract in `docs/workflow.md` (repo root):

| Milestone | Shared stage | In this file |
| --- | --- | --- |
| M1 bring-up | 1 setup, 2 create, 2d IDE, 3 build | Stage 1, Stage 2, Stage 3 |
| M1 bring-up (board) | 4 connect, 5 flash, 6 test, 7 debug *(Studio's pyOCD debug; script planned)* | Stage 4, Stage 5, Stage 6 |
| M2 board support | 8 board drivers *(planned)*, 9 layer check, 10 host test *(planned)* | Stage 3 rules, `check_layers.py` |
| M3 execution, M4 components, M5 application | 11 execution + trace, 12 components, 13 profile *(planned)* | - |
| - | 14 export *(planned)*, 15 port *(planned)* | Extending |
| - | 16 clean | Stage 7 |

**Exit codes:** 0 gate passed, 1 failed, 2 warnings, **10 = developer action needed**. On exit 10
the script's last line is `ACTION: <TYPE> <what to do>` (SETUP, CONNECT, APPROVE, CHOOSE ...):
tell the user exactly that, wait for their OK, then re-run the same command (with `--yes` /
`--serial` when the action says so). Never work around an ACTION yourself - installing tools,
closing Studio, plugging hardware and approving flashes or deletions are the developer's.

**Release scope:** `<repo>/milestones.env` lists the active milestones (this release: **M1**).
M1 includes the board stages, and **every flash needs the developer's yes first** (`flash.sh
--yes` only after they said yes in chat, or `FLASH_POLICY=auto` that they wrote into their own
bench file). Scripts of an inactive milestone (e.g. M2 `check_layers.py`) stop with
`ACTION: SETUP ... not active`; never edit `milestones.env` or set `FW_ACTIVE_MILESTONES` yourself.

## Help menu (answer this first when asked how to use the skill)

When the user asks for help, usage or the list of commands ("ขอวิธีใช้หน่อย", "มีคำสั่งอะไรบ้าง",
"help"), run `bash "$SKILL/scripts/help.sh"` (Thai) or `help.sh --en` and show its output as-is.
Then offer the next step that fits (usually Stage 1). Do not run other stages.

`$SKILL` below = the folder containing this SKILL.md. Always quote: `bash "$SKILL/scripts/x.sh"`.
This skill is part of the automated-firmware-skills repo and needs the repo layout:

```
<repo>/skills/scons-rtthread-visionboard/       this skill (SKILL.md, scripts/, reference/, templates/)
<repo>/boards/<id>/README.md                    board hardware (tool-independent)
<repo>/boards/<id>/scons-rtthread-visionboard/  board profile: board.env, README (verification log)
<repo>/apps/                                    apps workspace when working inside the repo
```

The apps workspace `$RTT_WS`: `<repo>/apps` inside the repo checkout, otherwise `./apps`; the
Studio workspace is `<apps>/.rtstudio` (per-PC metadata, git-ignored). Board profiles:
`<project>/boards/<id>/scons-rtthread-visionboard/` first, then `<repo>/boards` (override
`RTT_BOARDS_DIR`). Overrides: `RTT_STUDIO_HOME`, `RTT_PROBE_SERIAL`, `RTT_CONSOLE`.

## What an app looks like

```
apps/<app>/                 (~38 MB: a standalone copy - Studio needs real folders)
  SConstruct SConscript rtconfig.py rtconfig.h Kconfig    RT-Thread project (rtconfig.py: GCC, -DBOARD_<ID>)
  board/ ra/ ra_gen/ ra_cfg/ script/                      the SDK project's BSP + FSP (generated - do not edit)
  rt-thread/                                              RT-Thread 5.0.2 (without docs/examples)
  libraries/HAL_Drivers/                                  RT-Thread drivers for RA
  src/board/board_io.*    board layer: pins (BSP_IO_PORT_xx_PIN_yy), rt_pin_* calls
  src/func/               services in C: led, button (debounce with the kernel tick)
  src/hal_entry.c         execution: hal_entry() in the main thread + msh commands
  src/SConscript          compiles src/board + src/func (-Wextra)
  tests/<spec>.json       test contract (msh flavour: `led` / `btn` instead of `led?` / `btn?`)
  .project .cproject .settings/  RT-Thread Studio project (named <app>, GCC 13.3, synced with scons)
  rtt-app.env             record: board, template, SDK, GCC
  build/ logs/ Debug/     build outputs and logs (git-ignored; Debug/ = Studio's build)
```

## Board type vs bench instance

- **Board type** (`boards/<id>/`): `README.md` = hardware; `scons-rtthread-visionboard/board.env` =
  SDK version + example project, GCC/pyOCD package versions, `BOARD_DEFINE`, labels, pyOCD target,
  expected CPUID, code-flash range.
- **Bench instance** (`<workspace>/.bench/<id>.env`, board stages): probe serial (ART-Link unique id
  = USB serial of its VCP) and COM port of one board on one PC. Never write them into `boards/`.

| id | board | status |
| --- | --- | --- |
| `vision-board` | RT-Thread Vision Board: RA8D1 (R7FA8D1BH) Cortex-M85 480 MHz, 2 MB flash, 1 MB SRAM, 32 MB SDRAM | see `boards/vision-board/scons-rtthread-visionboard/README.md` |

## Hardware quick reference

Use the **silkscreen name** with the user. Details: `boards/vision-board/README.md`.

| Board | Button | LED | Console |
| --- | --- | --- | --- |
| Vision Board | **KEY0** P907 (pressed = low, assumed - the test checks it) | RGB LED, common anode (on = low): LED1 P102 = blue; LED2 P106, LED3 PA07 = red/green (the interactive test asks the colour) | msh on `uart9` = ART-Link VCP, 115200 |

## Stage 1 - Tools and folder paths

```bash
bash "$SKILL/scripts/check_tools.sh" <board-id> [--ws <workspace>]
```
Checks the workspace path (no spaces or non-ASCII, ≤100 characters), RT-Thread Studio (GLOBAL or
LOCAL install), the SDK `VISION-BOARD 1.3.0`, GNU Arm 13.3, the RT-Thread env's scons (env-new:
Python 3.11 + scons 4.10, as Studio; else env Python 2.7), pyOCD + the `Renesas.RA_DFP` pack,
python + pyserial, connected probes. Read-only. **Gate:** `missing/bad=0`; report every WARN.
Missing pieces are installed in Studio's SDK Manager by the user - never by you.

## Stage 2 - Create the project and open it in the IDE

1. **Create:** `bash "$SKILL/scripts/new_app.sh" <board-id> <app-name> [<workspace>] [template] [--no-open]`
   - copies the SDK project `vision_board_blink_led` (without pictures/Keil files), `rt-thread/`
     (without documentation/examples) and `libraries/HAL_Drivers`, then `templates/_common/src` +
     the template's `src/` and `tests/` (about 15 s, 38 MB).
   - patches the copy: `rtconfig.py` (GCC + `-DBOARD_<ID>`), the Studio project (name = app,
     toolchain = GCC 13.3, `-DBOARD_<ID>`), and the app's `rt-thread/tools/options.py` default
     `--project-name` = app (RT-Thread 5.0.2 would rename it to `project` on every Studio sync).
   - runs **Studio's scons sync** (`scons --target=eclipse --project-name=<app>`): `.cproject`
     include paths/excludes from the SConscripts, `rtconfig_preinc.h`, `makefile.targets` - Studio
     builds a new app at once, without a sync prompt.
   - **Gate:** `Created ...` (the script stops if the sync result is missing).
2. **Open in the IDE (stage 2d, automatic):** `new_app.sh` runs `bash "$SKILL/scripts/open_ide.sh"
   <app>`: a headless Eclipse import into the Studio workspace `<apps>/.rtstudio` (once per app,
   ~15 s; impossible while Studio runs - then `ACTION: SETUP` says File > Import), then starts
   Studio on that workspace (`--no-open`: import only). **Gate:** `IDE: READY <workspace>` +
   `IDE: OPENED`. In Studio: Build (hammer, into `Debug/`), RT-Thread Settings (rewrites
   `rtconfig.h` - then re-run build.sh), Download/Debug (pyOCD). **Studio's Download writes
   `rtthread.hex`, which contains the FSP option-setting sections** - tell the developer; the
   script path never writes them.

## Stage 3 - Code in layers, build

Read `reference/layering.md` before writing code. Rules:
- `src/board/` - **only** place for pin numbers (`BSP_IO_PORT_xx_PIN_yy`), `rt_pin_*` calls and
  `#if defined(BOARD_xxx)`. The header is `board_io.h` (the BSP's `board/board.h` is on the path).
- `src/func/` - services on `board_io.h` + the kernel API (`rtthread.h`: ticks); 1-based numbers.
- `src/hal_entry.c` - `hal_entry()` (RT-Thread's main thread) and msh commands
  (`MSH_CMD_EXPORT_ALIAS(fn, name, desc)`: the name is a C identifier - no `?`; the description
  is bare tokens - no commas). Print with `rt_kprintf` ("\n" becomes CR LF on the console).
- Keep the console protocol: `OK ...`, `ERR ...`, `EVT ...`, `<TAG> k=v ...`,
  `INFO ... board=<id> ...` then `READY`; msh adds its prompt `msh />` and answers unknown
  commands with `<cmd>: command not found.` - tests match without `^`.
- Templates: `hello-world` (1 s print with `rt_thread_delay_until`), `uart-btn-led` (msh `info`,
  `led <n> on|off|toggle`, `led`, `btn`; KEY0 toggles LED1, `EVT` lines).

```bash
bash "$SKILL/scripts/build.sh" <app-dir> [--clean] [--allow-warnings]
```
scons with GCC 13.3 (about 5 s). **Gate:** `BUILD: PASS` = scons exit 0, `rtthread.elf`, **0
warnings in `src/`**, and `app.hex` (= the ELF without `.option_setting_*`) inside code flash
`0x02000000..0x02200000`. `build/manifest.txt` (GCC, scons, RT-Thread version, sizes, sha256 of
`rtthread.elf` and `app.hex`, the address range) is written **only on PASS**.

**Layer check (M2 - gated):** `python <repo>/lib/check_layers.py <app-dir>/src` once M2 is active
(not run yet for this skill).

## Stage 4 - Connect

```bash
bash "$SKILL/scripts/discover.sh" <board-id> [--serial <probe-serial>]
```
Lists CMSIS-DAP probes (pyOCD), then attaches **without halt or reset** and reads CPUID - the
firmware keeps running, nothing is written. **Gate:** `IDENTITY: PASS` (ART-Link probe, target
R7FA8D1BH answers, CPUID `0x410FD232` = Cortex-M85 r0p2, its VCP present) + `Saved ...`. No
answer: a new board may need RST held while connecting (BSP note) - relay the ACTION; never
change security settings (DLM, ID code, TrustZone boundaries) to get in.

## Stage 5 - Flash

**Ask the user before every flash** (board, app, app.hex sha256 prefix and range). Offer a backup
of the current code flash (pyOCD can read it) if they care about the firmware on the board.
```bash
bash "$SKILL/scripts/flash.sh" <app-dir> --yes
```
Gates inside: app.hex = the manifest's sha256 and inside code flash → probe with the bench serial
→ identity (CPUID) → `pyocd flash --erase=auto` (only the touched sectors) + reset → every byte
of app.hex read back (attach) and compared. **Gate:** `FLASH: PASS (... bytes read back equal)`.
Option-setting memory, data flash and the QSPI flash are never written.

## Stage 6 - Test (after flashing)

```bash
python "$SKILL/scripts/serial_test.py" auto <app>/tests/<spec>.json <app>/logs/test-<ts>.log --board <id> [--interactive | --only-interactive]
```
`auto` = the COM port whose USB serial is the bench probe serial. Default `--sync` sends `info`
until `READY`, checks `board=<id>`, runs the steps. Interactive steps (LED colours, press KEY0)
only with `--interactive`: tell the user what to look at first. **Gate:** `RESULT: PASS`. `led`
reads the pins back; only a human confirms the colours.

## Stage 7 - Clean

```bash
bash "$SKILL/scripts/clean.sh" [--apps] [<workspace>]          # dry run
bash "$SKILL/scripts/clean.sh" [--apps] [<workspace>] --yes    # delete (ask the user first)
```
- default: **build outputs only** (`build/`, `rtthread.*`, `app.hex`). Sources, tests, logs kept.
- `--apps`: also deletes **whole apps** made by `new_app.sh` (`rtt-app.env`), `.bench` and the
  Studio workspace `.rtstudio` - close Studio first. Only when the user explicitly asks.
- Never touches RT-Thread Studio or its SDK packages.

## Extending the skill

- **Another board of the SDK family:** copy `boards/_template/` to `boards/<id>/`, fill `README.md`
  and `scons-rtthread-visionboard/board.env` (SDK name/version/project, pyOCD target, CPUID, code
  flash range), add a `BOARD_<ID>` block to `templates/_common/src/board/board_io.h` and its pin
  table to `board_io.c`. Never invent pins - stop and ask.
- **New template:** `templates/<name>/src/hal_entry.c` + `tests/<name>.json` + `description.txt`.
- **SDK / GCC update:** change `BSP_VERSION` / `GCC_VERSION` in the profile, re-create the apps,
  compare manifests, re-test on hardware, log it.

## Reporting (always)

Report verification levels separately: **source matches → built → flashed (read back) → booted
(READY) → tested (PASS n/m) → observed by a human**. Quote the app.hex sha256, the SDK/GCC versions
and log paths. Add a dated line to `boards/<id>/scons-rtthread-visionboard/README.md` when a board
fact is newly verified.

## Safety rules

- Never write the option-setting memory (OFS, SAS, security attribution, ID code), change the
  device lifecycle (DLM) or TrustZone boundaries, or erase data flash / QSPI - irreversible or
  lock-out risks. Stop and ask.
- Identity gate before every write; never flash an image without a PASS manifest. Ask before every
  flash and before `clean.sh --yes`. Never run installers or update the probe firmware.
