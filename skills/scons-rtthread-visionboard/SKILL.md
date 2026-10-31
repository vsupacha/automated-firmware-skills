---
name: scons-rtthread-visionboard
description: Firmware workflow for the RT-Thread Vision Board (Renesas RA8D1, Cortex-M85) with RT-Thread 5.0.2, its scons build and the board SDK from RT-Thread Studio - check tools and folder paths, create a standalone RT-Thread app from the SDK's blink project plus a layered template (board -> func -> hal_entry.c with msh commands), already synced as an RT-Thread Studio project (GCC 13.3), open it in RT-Thread Studio, build it with scons and a manifest, discover the board's ART-Link CMSIS-DAP probe with pyOCD (read-only CPUID check), flash code flash only (never the option-setting memory) with read-back, and run automated and interactive msh tests (RGB LED, KEY0). Use when asked to create, build, flash (แฟลช) or test Vision Board / RA8D1 RT-Thread firmware, open such an app in RT-Thread Studio, or how to use this skill (ขอวิธีใช้, มีคำสั่งอะไรบ้าง, help). Not for Renesas e2 studio / FSP-only projects, Keil MDK, or other RA boards without a profile.
license: MIT
compatibility: Claude Code or another agent that runs bash; Windows 10/11 + Git Bash, Python 3 + pyserial; needs RT-Thread Studio with the VISION-BOARD SDK (scons, GCC 13.3, pyOCD); uses this repo's lib/ and boards/ (install the whole plugin or clone the repo)
---

# RT-Thread Vision Board firmware workflow (RT-Thread + scons + pyOCD)

Gated stages, the same contract as every skill in this repo (`docs/workflow.md`). Do them in order;
do not start a stage until the previous gate passed. Each stage has a script in `scripts/` and
details in `reference/`. Bash: Git Bash on Windows (Claude's Bash tool). Every tool comes from an
**RT-Thread Studio** install: the Vision Board SDK (BSP 1.3.0: RT-Thread 5.0.2 + FSP), GNU Arm,
the RT-Thread env (scons) and RT-Thread's pyOCD with the Renesas RA packs.

```
1 tools ─► 2 project + IDE ─► 3 build ─► 4 connect ─► 5 flash ─► 6 test ─► 7 status ─► 16 clean
check_tools  new_app            build.sh   discover     flash.sh   serial_test  msh_status  clean.sh
             open_ide (Studio)  (scons)    (pyOCD)      (pyOCD)    (msh)        (msh)
             recipe.sh check/apply (2c: drivers + components)
```

**RT-Thread's own strength:** the msh shell is always on the console, and every command the code
exports with `MSH_CMD_EXPORT` / `MSH_CMD_EXPORT_ALIAS` is listed by `help` with its description.
The tools use that: the tests first check that the image exports every command the spec sends, and
`msh_status.py` reads version, commands, threads (stack use), heap and devices from the running image
- no debug probe, no halt. A new app command = one `MSH_CMD_EXPORT_ALIAS(fn, name, description)` in
`src/`; it shows up in `help`, in `msh_status.py` and can be used in `tests/*.json` at once.

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
| M1 bring-up (board) | 4 connect, 5 flash, 6 test, 7 debug *(status over msh: `msh_status.py`; breakpoints: Studio's pyOCD debug, script planned)* | Stage 4, Stage 5, Stage 6, Stage 7 |
| M2 board support | 8 board drivers *(planned)*, 9 layer check, 10 host test *(planned)* | Stage 3 rules, `check_layers.py` |
| M3 execution, M4 components, M5 application | 11 execution + trace, 12 components, 13 profile *(planned)* | - |
| - | 14 export *(planned)*, 15 port *(planned)* | Extending |
| - | 16 clean | Stage 16 |

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
apps/<app>/                 (~40 MB: a standalone copy - Studio needs real folders)
  SConstruct SConscript rtconfig.py rtconfig.h Kconfig    RT-Thread project (rtconfig.py: GCC, -DBOARD_<ID>)
  board/ ra/ ra_gen/ ra_cfg/ script/                      the SDK project's BSP + FSP from FSP_PROJECT (generated - recipes
                                                          add board ports, Kconfig blocks, the AT linker section)
  rt-thread/                                              RT-Thread 5.0.2 (without docs/examples)
  libraries/HAL_Drivers/                                  RT-Thread drivers for RA
  src/board/board_io.*    board layer: pins (BSP_IO_PORT_xx_PIN_yy), rt_pin_* calls
  src/func/               services in C: led, button (debounce with the kernel tick)
  src/hal_entry.c         execution: hal_entry() in the main thread + msh commands
  src/at/                 layer 3b (recipe at-cdc): AT commands on the function layer, a peer of the msh commands
  src/SConscript          compiles src/board + src/func + src/at (-Wextra)
  tests/<spec>.json       test contract (msh flavour: `led` / `btn` instead of `led?` / `btn?`)
  .project .cproject .settings/  RT-Thread Studio project (named <app>, GCC 13.3, synced with scons)
  rtt-app.env             record: board, template, SDK, FSP project, GCC, applied recipes (APP_RECIPES)
  build/ logs/ Debug/     build outputs and logs (git-ignored; Debug/ = Studio's build; logs/recipe-backup-*)
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

**Tool updates (stage 1b):** `bash "$SKILL/scripts/update_tools.sh" <board-id>` compares the SDK
Manager packages pinned in the board profile (`BSP_VERSION`, `GCC_VERSION`, `PYOCD_VERSION`) with the
versions installed side by side on this PC. Read-only. **Gate:** `UPDATE: NONE`, or `UPDATE:
AVAILABLE n` + exit 10 `ACTION: APPROVE` - ask the developer; only after a yes run it again with
`--apply --yes` (re-pins the profile, logs "not re-qualified"), then re-qualify: new_app + build,
flash (asks first) and the tests. Run it after the user installed or updated packages in SDK Manager.

## Stage 2 - Create the project and open it in the IDE

1. **Create:** `bash "$SKILL/scripts/new_app.sh" <board-id> <app-name> [<workspace>|""] [template] [--no-open]`
   - **Workspace (once per PC):** exit 10 `ACTION: CHOOSE` = no apps workspace chosen for this PC
     and `apps/` is in a synced folder or too long. Ask the developer (outside the synced folder,
     e.g. `C:/fw-ws` - recommended - or keep `apps/`), run `bash <repo>/lib/fw_workspace.sh set <dir>`,
     re-run `new_app.sh`; then use the app path it prints (`<workspace>/<app>`) in the later stages
     (docs/workflow.md "Apps workspace").
   - copies the SDK project `vision_board_blink_led` (without pictures/Keil files), `rt-thread/`
     (without documentation/examples) and `libraries/HAL_Drivers`, then `templates/_common/src` +
     the template's `src/` and `tests/` (about 15 s, 40 MB).
   - **FSP side from `FSP_PROJECT`** (profile; Vision Board: `vision_board_openmv`, the SDK project
     that generates the most peripherals - SPI1, SCI3 I2C, SDHI1, GPT6/7/13, IRQ10/11, UART2, flash,
     display, CEU, USB): `configuration.xml`, `ra/`, `ra_cfg/`, `ra_gen/` and the linker scripts are
     copied from it; Kconfig, `.config` and `board/` stay blink's, so **no driver is enabled** - the
     drivers come later through recipes. dave2d is compiled always (the FSP has a drw module), and
     interrupt handlers that only an un-integrated driver would define (USB) get weak empty stubs in
     `board/ports/fsp_unused_irq.c`. Recorded as `APP_FSP` in `rtt-app.env`.
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
   `IDE: OPENED` (`IDE: not opened` with `--no-open`). In Studio: Build (hammer, into `Debug/`), RT-Thread Settings (rewrites
   `rtconfig.h` - then re-run build.sh), Download/Debug (pyOCD). **Studio's Download writes
   `rtthread.hex`, which contains the FSP option-setting sections** - tell the developer; the
   script path never writes them.

**HW driver and software-component recipes (stage 2c, before coding):**
`bash "$SKILL/scripts/recipe.sh" list` names them: hardware `i2c1-soft spi1 rw007 sci3-i2c sdcard pwm6
usb-cdc`, software `sdcard-fat at-cdc` (`requires` pulls in what a recipe needs). A recipe is Kconfig
level (`recipes/drivers/<name>.json`): its values come from the one SDK example project whose README
is about that hardware (`recipe.sh derive`, maintainers), or from the RT-Thread component for software
without an SDK example (`at-cdc`).
1. `bash "$SKILL/scripts/recipe.sh" check <app> <recipe>...` (read-only) resolves them on the app's
   Kconfig tree. **Gate:** `RECIPE: READY` | `RECIPE: ACTION n` (exit 10: `KCONFIG` board/Kconfig block,
   `FSP` instance in `ra_gen/`, `PORT` board port, `PACKAGE` source, `FILE` file from the SDK project or
   the skill, `INSERT` text to add, `PATCH` SDK fix, `SOURCE` source fact) | `RECIPE: FAIL` (pin or
   peripheral taken twice, unknown recipe).
2. `bash "$SKILL/scripts/recipe.sh" apply <app> <recipe>...` lists what it would write
   (`ACTION: APPROVE`, exit 10) - **ask the developer**, then the same with `--yes`: it copies the SDK
   or skill files, patches and inserts, sets the recipe values in `.config` (kconfiglib) and writes
   `rtconfig.h` (RT-Thread's `mk_rtconfig`), records `APP_RECIPES` in `rtt-app.env`, backs up every file
   it replaces to `<app>/logs/recipe-backup-<time>/`, re-checks and re-syncs the Studio project.
   **Gate:** `APPLY: DONE` (then build.sh) | `APPLY: NOT DONE` (exit 10 while an FSP instance is missing -
   the FSP configurator is the developer's step; nothing written).
3. Build, flash, then check on the board what apply printed: `msh_status.py` (devices, commands,
   threads) and the recipe's test spec (`serial_test.py <port> <skill>/recipes/tests/<spec>.json ...`).
New apps already have every FSP instance of the recipes (`FSP_PROJECT`, openmv) and the base recipe's
SDK fix (drv_gpio.c opens IOPORT once). Tested on hardware: `spi1` + `rw007` (msh `wifi scan`,
`wifi join`, `ping`), `sdcard` + `sdcard-fat` (FAT write, kept across a reboot), `usb-cdc` + `at-cdc`
(AT commands on the user USB port, layer 3b `src/at/`; the CDC test needs a data cable on the user
USB-OTG port: `serial_test.py COMx <skill>/recipes/tests/at_cdc.json <log> --board <id>`); the others are
`prepared`. All nine together build (2026-10-31). See `recipes/README.md`.

**Wi-Fi (rw007) over msh:** `wifi scan` (no credentials), `wifi join <ssid> <password>`,
`wifi status`, `ifconfig`, `ping <host>`. Credentials come from the developer only; never write
them, the SSID list or addresses into files, logs (`--log`), reports or git. Auto-connect is off:
a reset forgets the join.

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
- Templates: `hello-world` (1 s print with `rt_thread_delay_until`), `blink` (LED1 every 0.5 s), `push-to-light` (msh `info`,
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

Spec format (`tests/*.json` keys, JSON escaping, what is not measured): `docs/workflow.md`
"Test specs" in the repo root.

```bash
python "$SKILL/scripts/serial_test.py" auto <app>/tests/<spec>.json <app>/logs/test-<ts>.log --board <id> [--interactive | --only-interactive]
```
`auto` = the COM port whose USB serial is the bench probe serial. Default `--sync` sends `info`
until `READY`, checks `board=<id>`, then asks `help` and checks that every command the spec sends is
exported by the image (step `command list`; a step that expects `command not found` is left out) -
a stale or wrong image fails there, before the steps run. Then it runs the steps. Interactive steps (LED colours, press KEY0)
only with `--interactive`: tell the user what to look at first. **Gate:** `RESULT: PASS`. `led`
reads the pins back; only a human confirms the colours.

## Stage 7 - Status over msh (no debug probe)

```bash
python "$SKILL/scripts/msh_status.py" auto --board <id> [--json <app>/logs/status-<ts>.json] [--log <app>/logs/status-<ts>.log]
```
Runs only read-only built-in commands on the running image - `version`, `help`, `ps`, `free`,
`list device` - and prints the RT-Thread version, every exported command with its description,
threads (priority, status, stack size, max stack use), heap and devices. No halt, no reset, nothing
written. Use it after a flash, when a test fails ("which commands does this image have?"), or to
watch stack use while developing. **Gate:** `MSH: PASS`; `MSH: WARNINGS n` (exit 2) when a thread
used >= 90 % of its stack or a command did not return to the prompt - report them; `MSH: FAIL` when no
shell answers (image not running, wrong port). Breakpoints / watchpoints stay with Studio's debugger.

## Stage 16 - Clean

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
- Wi-Fi credentials (SSID, password) and network data seen on the board (scan list, IP and MAC
  addresses) never go into files, logs, reports or git - send them to the board only.
