---
name: mcux-sdk-frdmmcxn947
description: Firmware workflow for the NXP FRDM-MCXN947 (MCXN947, Cortex-M33 core 0) with the MCUXpresso SDK (GitHub west workspace), CMake and the MCUXpresso Installer tools on Windows - check the SDK and NXP tools (never ST tools), create an app from the SDK hello_world example (west export_app) trimmed to clocks and pin mux with a layered board/func/app_main source tree, write the MCUXpresso for VS Code project files directly and open it there, build with the same CMake preset as the IDE and a manifest, discover the MCU-Link, flash with LinkServer behind identity and region gates (never PFR / FlexSPI, never an MCU-Link firmware update), run automated and interactive UART tests (SW2/SW3, RGB LED), clean. Debug is planned. Use when asked to create, build, flash (แฟลช) or test FRDM-MCXN947 / MCXN947 / MCX N firmware with the MCUXpresso SDK, open such an app in VS Code, or how to use this skill (ขอวิธีใช้, มีคำสั่งอะไรบ้าง, help). Not for Zephyr, MCUXpresso IDE projects, core 1 or the NPU.
license: MIT
compatibility: Claude Code or another agent that runs bash; Windows 10/11 + Git Bash, Python 3; needs the MCUXpresso SDK 26.09 west workspace, the MCUXpresso Installer tools (Arm GNU 14.2, Ninja, west venv) and Kitware CMake 3.30+; uses this repo's lib/ and boards/ (install the whole plugin or clone the repo)
---

# FRDM-MCXN947 firmware workflow (MCUXpresso SDK + CMake)

Gated stages, the same contract as every skill in this repo (`docs/workflow.md`). Do them in
order; do not start a stage until the previous gate passed. **Windows + Git Bash only.**
**NXP tools only:** the build uses the MCUXpresso Installer's Arm GNU toolchain and Ninja and
Kitware CMake - never ST's `cube-cmake`, STM32CubeCLT CMake/Ninja/GCC or any other vendor's
tools, even when they come first on PATH or in the VS Code user settings.

```
1 tools ─► 2 create ─► 2d IDE ─► 2e code ─► 3 build ─► 4 connect ─► 5 flash ─► 6 test ─► 16 clean
check_tools  new_app     open_ide   src/board   build.sh   discover    flash.sh   serial_test  clean.sh
             (export_app) (VS Code) src/func
                                    app_main.c
```

**Two paths after Stage 2** (`docs/workflow.md`): the developer may code in VS Code at any
time - the **IDE path** (`new_app.sh` already opened the app; `open_ide.sh <app>` reopens it; they
build, flash and debug with MCUXpresso for VS Code) - or let you run the stages - the **script
path** (build behind its gate). Ask which one when it is not clear. On the IDE path, stop after
stage 2d and run scripts only when asked; never overwrite files the developer is editing. Both
paths use the same CMake preset `debug` and the same `debug/` folder, so switching is always possible.

## Main path (script path)

<!-- main-path -->
The whole automated flow, in order, from the repository root. Board id `frdm-mcxn947`; `<app>` is the
folder `new_app.sh` prints (in this PC's apps workspace). Other templates: replace `blink`.

```bash
S=skills/mcux-sdk-frdmmcxn947/scripts
bash $S/check_tools.sh frdm-mcxn947                         # 1 tools:   line with missing/bad=0
bash $S/new_app.sh frdm-mcxn947 my-app "" blink --no-open   # 2 create:  "Created <app>" (prints the app folder)
bash $S/build.sh <app>                                      # 3 build:   BUILD: PASS
bash $S/discover.sh frdm-mcxn947                            # 4 connect: IDENTITY: PASS (read-only, needs the board)
bash $S/flash.sh <app>                                      # 5 flash:   stops with ACTION: APPROVE; after the developer's yes add --yes -> FLASH: PASS
python $S/serial_test.py auto <app>/tests/blink.json <app>/logs/test.log --board frdm-mcxn947   # 6 test:    RESULT: PASS
```

A stage passed only when its gate line is printed. Exit code 10 with an `ACTION:` line means: stop,
relay it to the developer, and re-run the same command after they acted - never add `--yes` on
your own. The sections below explain these stages; IDE handoff, debug, unit tests, tool updates
and clean are optional.

## Milestones, stage numbers and developer actions

This skill implements the shared contract in `docs/workflow.md` (repo root):

| Milestone | Shared stage | In this file |
| --- | --- | --- |
| M1 bring-up | 1 setup, 2 create, 2d IDE, 3 build | Stage 1, Stage 2, Stage 2d, Stage 3 |
| M1 bring-up (board) | 4 connect, 5 flash, 6 test; 7 debug *(planned - proven by hand: docs/related-work.md "NXP FRDM-MCXN947")* | Stage 4, Stage 5, Stage 6 |
| M2 board support | 8 board drivers *(planned)*, 9 layer check, 10 host test *(optional)* | Stage 2e (rules, shared `lib/func`, `check_layers.py`, `host_test.sh`) |
| M3 execution, M4 components, M5 application | 11 execution + trace, 12 components, 13 profile *(planned)* | - |
| - | 14 export *(planned)*, 15 port *(planned)* | Extending |
| - | 16 clean | Stage 16 |

**Exit codes:** 0 gate passed, 1 failed, 2 warnings, **10 = developer action needed**. On exit 10
the script's last line is `ACTION: <TYPE> <what to do>` (SETUP, APPROVE, CHOOSE...): tell the user
exactly that, wait for their OK, then re-run the same command. Never work around an ACTION
yourself - installing the SDK or tools, plugging the board, registering the SDK in VS Code
(`--register-sdk` edits the user's VS Code settings) and approving flashes or deletions are the developer's.

**Release scope:** `<repo>/milestones.env` lists the active milestones (this release: **M1**).
M1 includes the board stages: discover, flash and serial tests run when the developer asks for
them, and **every flash needs the developer's yes first** (`flash.sh --yes` only after they said
yes in chat, or `FLASH_POLICY=auto` that they wrote into their own bench file).
Scripts of an inactive milestone (e.g. M2 `check_layers.py`) stop with `ACTION: SETUP ... not
active`; never edit `milestones.env` or set `FW_ACTIVE_MILESTONES` yourself.

## Help menu (answer this first when asked how to use the skill)

When the user asks for help, usage or the command list ("ขอวิธีใช้หน่อย", "มีคำสั่งอะไรบ้าง", "help"),
run `bash "$SKILL/scripts/help.sh"` (Thai) or `help.sh --en`, show the output as-is, then offer the
next step (usually `check_tools.sh frdm-mcxn947`). `$SKILL` = this skill's folder.

## What an app looks like

```
<workspace>/<app>/
  CMakeLists.txt, prj.conf, Kconfig   SDK app (project "app"); builds every .c/.h under src/ (commit)
  frdmmcxn947_cm33_core0/   board_files.cmake, frdmmcxn947/clock_config.*, hello_world/pin_mux.*,
                            hello_world.mex (MCUXpresso Config Tools), prj.conf (commit)
  src/                      board/ (board.c, board.h), func/ (copy of lib/func), main.c, app_main.* (commit)
  tests/<spec>.json         test contract, the same specs as the other skills (commit)
  CMakePresets.json         presets debug / release (commit)
  mcux_include.json, .vscode/   per-PC tool paths + MCUXpresso project files (open_ide.sh; git-ignored)
  mcx-app.env               record: board, template, SDK version, how it was made
  debug/ logs/              build tree (debug/app_cm33_core0.elf), logs (git-ignored)
```

**Where it comes from:** `new_app.sh` runs `west export_app examples/demo_apps/hello_world -b
frdmmcxn947 -Dcore_id=cm33_core0 --bf` in the SDK, then `mcux_app.py trim`: removes the example's
`hello_world.c`, the SDK `board.c/board.h` (our `src/board/board.h` replaces it - the SDK one also
defines `BOARD_NAME`), `hardware_init.c`, `app.h` and unused board configs, keeps
`clock_config.*` (PLL 150 MHz) and `pin_mux.*` (console + SWO pins), turns the SDK debug console
off in `prj.conf` and adds `-Wno-error` (the SDK compiles with `-Werror`; build.sh's gate decides).

## Board type vs bench instance

- **Board type** (`boards/<id>/`): `README.md` = hardware; `mcux-sdk-frdmmcxn947/board.env` =
  pinned SDK and tool versions, the SDK board / core / example, `BOARD_DEFINE`, `BTN_LABELS`,
  expected probe identity (`EXPECTED_TARGET`, `EXPECTED_PROBE_BOARD`, `LINKSERVER_DEVICE`).
- **This PC:** the SDK folder (`MCUX_SDK_ROOT` in the environment or `~/.fw-skills.env`, default
  `C:/mcux-26.09`) and the apps workspace.
- **Bench instance** (`<workspace>/.bench/<id>.env`, written by `discover.sh`): `PROBE_SERIAL`
  (MCU-Link) and `CONSOLE_PORT` (its VCOM). Override with `MCX_PROBE_SERIAL` / `MCX_CONSOLE`.
  Never write PC-specific paths, serials or COM ports into `boards/`.

| id | board | status |
| --- | --- | --- |
| `frdm-mcxn947` | NXP FRDM-MCXN947 (MCXN947VDF, MCU-Link CMSIS-DAP + VCOM) | see `boards/frdm-mcxn947/mcux-sdk-frdmmcxn947/README.md` |

## Hardware quick reference

| Board | Button | LED | Console |
| --- | --- | --- | --- |
| FRDM-MCXN947 | **SW2** P0_23 (wakeup), **SW3** P0_6 (ISP - held at reset = ROM bootloader), pull-up, **pressed = low**; SW1 = reset | RGB LED D2, active low: **red** P0_10, **green** P0_27, **blue** P1_2 | LP_FLEXCOMM4 (FRO 12 MHz) → MCU-Link VCOM, 115200; RX by interrupt into a ring buffer |

## Stage 1 - Tools and folder paths

```bash
bash "$SKILL/scripts/check_tools.sh" frdm-mcxn947
```
Checks the workspace path, the SDK (`mcuxsdk/MCUX_VERSION` = 26.09.00, board and example present),
Arm GNU 14.2, Ninja 1.13.2 and the west venv in `~/.mcuxpressotools`, Kitware CMake >= 3.30 (ST
copies are skipped and a WARN shows when ST's CMake comes first on PATH), LinkServer (board
stages), python + pyserial, VS Code + MCUXpresso for VS Code and whether the SDK is registered in
VS Code. **Gate:** `missing/bad=0`. The SDK install line it prints (`west init ... --mr v26.09.00`,
`west update_board --set board frdmmcxn947`) is the developer's to run; `update_board` fetches
several GB (all boards' examples, middleware) - fetching only the needed repositories is fine
(core, CMSIS, examples, components, devices/MCX, tool_data, FreeRTOS kernel + upstream).

## Stage 2 - Create the project

```bash
bash "$SKILL/scripts/new_app.sh" frdm-mcxn947 <app> "" [hello-world|blink|push-to-light] [--no-open]
```
**Gate:** `TRIM: PASS` and `Created <folder>`. The first run on a PC without a chosen workspace
stops with `ACTION: CHOOSE` (apps live outside cloud-synced folders). ~20 s, no network, no board.

## Stage 2d - Open in the IDE

```bash
bash "$SKILL/scripts/open_ide.sh" <app> [--no-open] [--register-sdk] [--refresh]
```
Writes the MCUXpresso for VS Code project files the way the extension's Import Project does:
`.vscode/mcuxpresso-tools.json` (`sdk-v2-freestanding`), `settings.json` (`cmake.cmakePath` =
Kitware CMake for this app), `launch.json` (LinkServer "Debug"), `CMakePresets.json` +
`mcux_include.json` (per-PC paths, `CMAKE_MAKE_PROGRAM` = NXP Ninja). Existing files are kept
(`launch.json` holds the probe choice); `--refresh` rewrites the per-PC ones. **Gate:** `IDE: READY`
(+ `IDE: OPENED`). Exit 10 when VS Code / the extension is missing, or the SDK is not in VS Code's
`mcuxpresso.sdks`: `--register-sdk` adds it - **only after the developer agreed** (user-wide setting).

## Stage 2e - Code in layers

- `src/board/` - **only** place for pins, `fsl_` driver calls, `#if defined(BOARD_xxx)`.
  `board_init()` calls the SDK `BOARD_InitPins()` / `BOARD_InitBootClocks()`, sets up the LEDs and
  buttons with `fsl_port` / `fsl_gpio` (PORT pins need the input buffer on to read buttons) and the
  console on LPUART4 (blocking TX through `_write`; RX handler registered with
  `LP_FLEXCOMM_SetIRQHandler` - `fsl_lpflexcomm.c` owns `LP_FLEXCOMM4_IRQHandler`).
- `src/func/` - services (console, led, button, gesture) copied from `<repo>/lib/func` - shared
  unchanged with the other C skills; a reusable new service goes into `lib/func` (board.h only).
- `src/app_main.c` - `app_main()` wiring + application logic; `src/main.c` only calls it.
- Pins / clocks: MCUXpresso Config Tools on the `.mex` in the board folder regenerate
  `pin_mux.*` / `clock_config.*`; never put pin code anywhere but `src/board/`.
- Console protocol: `READY`, `INFO app=.. board=<id>`, `OK ...`, `ERR ...`, `EVT ...` over the VCOM.
- Templates: `hello-world` (prints every 1 s), `blink` (red LED every 0.5 s), `push-to-light`
  (console `led`/`btn` commands, SW2/SW3 toggle red/green). Tests: `tests/<spec>.json`.

**Check the layers (M2 - gated):** `python <repo>/lib/check_layers.py <app-dir>` → `LAYERS: PASS`.

## Stage 3 - Build

```bash
bash "$SKILL/scripts/build.sh" <app> [--clean] [--allow-warnings]
```
Refreshes the per-PC preset files, then `cmake --preset debug` + `cmake --build --preset debug`
with Kitware CMake (the same preset and `debug/` folder as the VS Code Build button). **Gate:**
`BUILD: PASS` = exit 0, `debug/app_cm33_core0.elf` present, **0 warnings in `src/`** (exit 2 = fix
them), no ST tool in the CMake cache. Writes `app_cm33_core0.hex` and `debug/manifest.txt` (SDK and
tool versions, ELF/HEX sha256, size) **only on PASS**.

## Stage 4 - Connect (discover the board)

```bash
bash "$SKILL/scripts/discover.sh" frdm-mcxn947 [--serial <probe-serial>]
```
Read-only: `LinkServer probes --json` + `LinkServer probe <serial> dapinfo` (CMSIS-DAP info of the
MCU-Link - no target access, no reset). **Gate:** `IDENTITY: PASS` = the probe reports target
`MCXN947VDF` and board `FRDM-MCXN947`; writes the bench file (probe serial + VCOM port, found by
the probe's USB serial number). Several probes: picks the one reporting `MCXN947:FRDM-MCXN947`, else
`ACTION: CHOOSE`. No probe: `ACTION: CONNECT` (USB-C J17).

## Stage 5 - Flash

**Ask the user first** (board, app, ELF sha256 prefix), then:
```bash
bash "$SKILL/scripts/flash.sh" <app> --yes [--elf <file>]
```
Gates, in order: the ELF matches the PASS manifest (`--elf` skips only this one) -> every load
segment inside internal flash 0x00000000-0x00200000 (never PFR / IFR / FlexSPI; checked before
anything touches the probe) -> approval -> bench probe connected -> dapinfo identity -> `LinkServer
flash -p <serial> -u none MCXN947:FRDM-MCXN947 load` (`-u none`: never an MCU-Link firmware
update) -> `verify` -> `probe <serial> wiretimedreset 100` (`verify` leaves the core halted).
**Gate:** `FLASH: PASS (programmed + verified n section(s) + reset)`.

## Stage 6 - Test (after flashing)

```bash
python "$SKILL/scripts/serial_test.py" auto <app>/tests/<spec>.json <app>/logs/test.log --board frdm-mcxn947 --sync [--interactive]
```
`auto` = the VCOM port of the bench probe. `--board` checks that the running image reports
`board=frdm-mcxn947` and names the buttons SW2/SW3 in interactive prompts. **Gate:**
`RESULT: PASS (n/m passed, k skipped)`. Interactive steps need a person at the board: say which
button to press **before** you start the run (the person cannot see the runner's prompts), press
one button at a time, and allow time between steps.

## Stage 7 - Debug (planned)

`LinkServer gdbserver -u none -a --gdb-port 3333 MCXN947:FRDM-MCXN947` + `lib/fwdebug.py` ran the
push-to-light scenario 7/7 by hand (docs/related-work.md); `debug.sh` is not written yet.

## Stage 16 - Clean

```bash
bash "$SKILL/scripts/clean.sh" [--apps] [<workspace>]          # dry run
bash "$SKILL/scripts/clean.sh" [--apps] [<workspace>] --yes    # delete (ask the user first)
```
Default: `debug/`, `release/`, `build_tmp/` only. `--apps`: whole apps (`mcx-app.env`) incl. the
user's `src/`, plus `.bench` - only when explicitly asked. The SDK folder is never touched.

## Extending

- **Another MCX N board in the SDK:** copy `boards/_template/`, fill `README.md` +
  `mcux-sdk-frdmmcxn947/board.env` (`SDK_BOARD`, `SDK_DEVICE`, board/pin-mux folders of the
  exported example), add its `#elif` I/O table in `templates/_common/src/board/board.c` and the
  `BOARD_NAME` mapping in `board.h`. A different board may later get a skill of its own name.
- **SDK or tool update:** change the versions in the profile, re-run every template through
  create → build (→ flash → test once the board stages exist), compare manifests, log it.

## Reporting (always)

Report levels separately: **created → built → flashed → booted (READY) → tested (PASS n/m) →
observed by a human**. Quote ELF sha256, SDK / tool versions, log paths. Add a dated line to
`boards/frdm-mcxn947/mcux-sdk-frdmmcxn947/README.md` when a board fact is newly verified.

## Safety rules

- Never use ST tools (or another vendor's) for an NXP app; build.sh fails if one shows up in the
  CMake cache.
- Never edit the VS Code user settings without the developer's OK (`--register-sdk` only on request).
- Identity and region gates before every write; never flash an ELF without a PASS manifest (except
  `--elf` chosen by the user). Ask before every flash; LinkServer always with `-u none` (never
  update the MCU-Link firmware); internal flash only, never PFR / IFR / FlexSPI, never core 1 in M1.
- SW3 is the ISP button: never ask anyone to hold it while the board resets.
- Ask before `clean.sh --yes`. Never delete or update the SDK folder or `~/.mcuxpressotools`.
