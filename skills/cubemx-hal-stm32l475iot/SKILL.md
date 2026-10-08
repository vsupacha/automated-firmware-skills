---
name: cubemx-hal-stm32l475iot
description: Firmware workflow for the ST B-L475E-IOT01A IoT node (STM32L475VG) with classic STM32CubeMX 6.18 (headless), the STM32CubeL4 HAL and CMake on Windows - check the pinned tools (all-users or per-user installs), create the .ioc from the CubeMX board configuration plus the USART1 console on the ST-LINK virtual COM port, generate the CMake project, open it in STM32CubeIDE for VS Code, write layered code (board -> func -> app_main), build with a manifest, discover the ST-LINK/V2-1, flash behind identity gates, run automated and interactive UART tests (B1 USER, LED2), regenerate after .ioc changes, clean. Use when asked to create, build, flash (แฟลช) or test B-L475E-IOT01A / STM32L475 firmware with STM32CubeMX, open such an app in VS Code, or how to use this skill (ขอวิธีใช้, มีคำสั่งอะไรบ้าง, help). Not for STM32CubeMX2 boards, B-L4S5I/B-U585I kits or STM32CubeIDE projects.
---

# B-L475E-IOT01A firmware workflow (STM32CubeMX + STM32CubeL4 HAL + CMake)

Gated stages, the same contract as every skill in this repo (`docs/workflow.md`). Do them in
order; do not start a stage until the previous gate passed. **Windows + Git Bash only**
(STM32CubeMX for Windows, STM32Cube bundles, `cygpath`, `taskkill`). The CubeMX machinery
(headless script mode, overlay, build gate) is shared with `cubemx-hal-stm32f407disco`; the
hardware stages (ST-LINK + virtual COM port) with `cubemx2-hal2-stm32c562nucleo`.

```
1 tools ─► 2 discover + project ─► 3 code ─► 4 build ─► 5 flash ─► 6 test ─► 7 clean
check_tools  discover (ST-LINK)    src/board  build.sh   flash.sh   serial_test  clean.sh
             new_app / regen       src/func
             open_ide (VS Code)    app_main.c
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
| M1 bring-up | 1 setup, 2 create, 2d IDE, 3 build | Stage 1, Stage 2 steps 2-4 (+ `regen.sh`, `open_ide.sh`), Stage 4 |
| M1 bring-up (board) | 4 connect, 5 flash, 6 test, 7 debug *(planned)* | Stage 2 step 1, Stage 5, Stage 6 |
| M2 board support | 8 board drivers *(planned)*, 9 layer check, 10 host test *(optional)* | Stage 3 (rules, shared `lib/func`, `check_layers.py`, `host_test.sh`) |
| M3 execution, M4 components, M5 application | 11 execution + trace, 12 components, 13 profile *(planned)* | - |
| - | 14 export *(planned)*, 15 port *(planned)* | Extending |
| - | 16 clean | Stage 7 |

**Exit codes:** 0 gate passed, 1 failed, 2 warnings, **10 = developer action needed**. On exit 10
the script's last line is `ACTION: <TYPE> <what to do>` (SETUP, CONNECT, APPROVE, CHOOSE...): tell
the user exactly that, wait for their OK, then re-run the same command. Never work around an
ACTION yourself - installing STM32CubeMX, firmware packages, bundles or drivers, plugging hardware
and approving flashes or deletions are the developer's.

**Release scope:** `<repo>/milestones.env` lists the active milestones (this release: **M1**).
M1 includes the board stages: discover, flash and serial tests run when the developer asks for
them, and **every flash needs the developer's yes first** (`flash.sh --yes` only after they said
yes in chat, or `FLASH_POLICY=auto` that they wrote into their own bench file). Scripts of an
inactive milestone (e.g. M2 `check_layers.py`) stop with `ACTION: SETUP ... not active`; never
edit `milestones.env` or set `FW_ACTIVE_MILESTONES` yourself - relay the ACTION like any other.

## Help menu (answer this first when asked how to use the skill)

When the user asks for help, usage or the command list ("ขอวิธีใช้หน่อย", "มีคำสั่งอะไรบ้าง", "help"),
run `bash "$SKILL/scripts/help.sh"` (Thai) or `help.sh --en`, show the output as-is, then offer the
next step (usually Stage 1). Do not run other stages.

`$SKILL` below = the folder containing this SKILL.md. Always quote: `bash "$SKILL/scripts/x.sh"`.
Repo layout this skill needs:

```
<repo>/skills/cubemx-hal-stm32l475iot/        this skill (SKILL.md, scripts/, reference/, templates/)
<repo>/lib/func/                              shared C logic layer, copied into every app's src/func
<repo>/lib/fwtest.py                          serial test engine (serial_test.py wraps it)
<repo>/boards/<id>/README.md                  board hardware (tool-independent)
<repo>/boards/<id>/cubemx-hal-stm32l475iot/   board profile: board.env, README (verification log)
<repo>/apps/                                  apps workspace when working inside the repo
```

Workspace `$L4_WS`: `<repo>/apps` inside the repo checkout, otherwise `./apps`. Board profiles:
`<project>/boards/<id>/cubemx-hal-stm32l475iot/` first, then `<repo>/boards` (override
`L4_BOARDS_DIR`). STM32CubeMX: installed for all users (`C:\Program Files\STMicroelectronics\STM32Cube\STM32CubeMX`)
or per user (`%LOCALAPPDATA%\Programs\STM32CubeMX`) - both are searched (override `CUBEMX_HOME`);
its firmware repository comes from CubeMX's own settings. STM32Cube bundles: `%LOCALAPPDATA%\stm32cube`
(override `STM32CUBE_ROOT`).

## What an app looks like

```
apps/<app>/
  <app>.ioc             STM32CubeMX configuration - the source of truth (commit it)
  src/                  our layered code: board/, func/ (copy of lib/func), app_main.c (commit it)
  tests/<spec>.json     test contract, the same specs as the other skills (commit it)
  l4-app.env            record: board, template, where the .ioc came from, CubeMX version
  <app>.code-workspace  VS Code workspace: mx/, src/, tests/ as folders (open_ide.sh; git-ignored)
  mx/                   generated CMake project (CubeMX-owned + overlay; git-ignored)
  .mx/ logs/            CubeMX scripts, build/flash/test logs (git-ignored)
```

**Where the .ioc comes from:** `new_app.sh` runs `MX_START` (`loadboard B-L475E-IOT01A1 nomode`:
the CubeMX board configuration - labelled pins, SWD, the 80 MHz clock tree, without the board's
sensors/radios) and the profile's `MX_CONFIG` (`set mode USART1 Asynchronous` + `set pin PB6
USART1_TX` / `PB7 USART1_RX`: the ST-LINK virtual COM port, 115200 8N1). The `-A1` and `-A2`
board variants have the same CubeMX configuration. Change the hardware with the STM32CubeMX GUI on
`<app>.ioc`, then `regen.sh`.

## Board type vs bench instance

- **Board type** (`boards/<id>/`): `README.md` = hardware; `cubemx-hal-stm32l475iot/board.env` =
  pinned CubeMX, firmware package and bundle versions, `MX_START`, `MX_CONFIG`, `BOARD_DEFINE`,
  `BTN_LABELS`, expected ST-LINK board / device name / device ID.
- **Bench instance** (`<workspace>/.bench/<id>.env`, written by `discover.sh`): `PROBE_SERIAL`
  (ST-LINK) and `CONSOLE_PORT` (its virtual COM port). Override with `L4_PROBE_SERIAL` /
  `L4_CONSOLE`. Never write them into `boards/`.

| id | board | status |
| --- | --- | --- |
| `b-l475e-iot01a` | ST B-L475E-IOT01A (STM32L475VGT6, ST-LINK/V2-1 with VCP) | see `boards/b-l475e-iot01a/cubemx-hal-stm32l475iot/README.md` |

## Hardware quick reference

| Board | Button | LED | Console |
| --- | --- | --- | --- |
| B-L475E-IOT01A | **B1 USER** (blue) PC13, pull-up, **pressed = low**; black B2 = RESET | **LED2** green PB14, active high (LED1 PA5 is left to Arduino D13 / SPI1) | USART1 PB6/PB7 → ST-LINK/V2-1 VCP, 115200; **no RX FIFO** - console RX by interrupt |

## Stage 1 - Tools and folder paths

```bash
bash "$SKILL/scripts/check_tools.sh" <board-id> [--ws <workspace>]
```
Checks the workspace path (no spaces/non-ASCII, ≤100 characters), STM32CubeMX (pinned version, its
bundled java), the CubeMX repository and the pinned `STM32Cube_FW_L4` package (+ the board's BSP),
GNU Tools for STM32 / CMake / Ninja / STM32CubeProgrammer bundles, python + pyserial (board stages) and the
IDE (VS Code + STM32CubeIDE for VS Code, warning only). Every tool row says **GLOBAL** (installed
for all users) or **LOCAL** (per user). Read-only. **Gate:** `missing/bad=0`.

## Stage 2 - Discover the board, create the project

1. **Discover (stage 4 connect, read-only):** `bash "$SKILL/scripts/discover.sh" <board-id> [--serial <sn>]`
   - lists ST-LINKs, hot-plug connects (no reset, no write) and checks the board name the ST-LINK
     reports (`STM32L4IO`), the device name and the device ID (0x415); saves the bench file.
   - **Gate:** `IDENTITY: PASS`. Several ST-LINKs: `--serial` (it never guesses). No board yet?
     Skip to step 2.
2. **Create:** `bash "$SKILL/scripts/new_app.sh" <board-id> <app> [<workspace>] [template] [--no-open]`
   - copies `lib/func` + `templates/_common/src` + the template, then one headless CubeMX run
     (`MX_START`, `MX_CONFIG`, save `<app>.ioc`, generate `mx/`), then `overlay.py`. 30 s - 2 min.
   - **Gate:** `REGEN: PASS` and `Created ...` (any `KO`, lost file or missing `exit` fails it).
3. **After any .ioc change:** `bash "$SKILL/scripts/regen.sh" <app>` - regenerates `mx/` (USER CODE
   sections survive) and re-applies the overlay. **Gate:** `REGEN: PASS`.
4. **Open in the IDE (stage 2d, automatic):** at the end, `new_app.sh` runs
   `bash "$SKILL/scripts/open_ide.sh" <app>` (`--no-open`: no window). It opens
   `<app>.code-workspace` - never the app folder - in VS Code; `new_app`/`regen` have pre-written
   the STM32CubeIDE for VS Code setup of `mx/` from the board profile (`.settings/ide.store.json`,
   `.settings/bundles.store.json` with the pinned bundle versions, `.vscode/settings.json` for
   cube-cmake, `.vscode/launch.json` = the extension's default ST-LINK launch), so the extension
   configures and indexes the project without a prompt (seen 2026-10-07). The developer can then
   build (CMake preset, same `mx/build/Debug` as build.sh), flash + debug (F5) and edit `src/`.
   **Gate:** `IDE: READY <workspace>` + `IDE: OPENED`; exit 10 `ACTION: SETUP` = VS Code or the
   extension is missing (new_app.sh only reports it). See docs/workflow.md "IDE handoff".

## Stage 3 - Code in layers

Read `reference/layering.md` first. Rules:
- `src/board/` - **only** place for GPIO ports/pins, HAL/CMSIS calls, `#if defined(BOARD_xxx)`.
  `board_init()` configures LED2 and B1 itself; the console uses the generated `huart1` (blocking
  TX through `_write`, RX by the USART1 RXNE interrupt into a ring buffer - `USART1_IRQHandler`
  lives in `board.c`, so keep the USART1 interrupt **disabled** in the `.ioc` NVIC settings).
- `src/func/` - services (console, led, button) copied from `<repo>/lib/func` - shared unchanged
  with the other C skills; a reusable new service goes into `lib/func` (board.h only).
- `src/app_main.c` - `app_main()` wiring + application logic, called from `USER CODE BEGIN 2`.
- Never edit `mx/` outside USER CODE sections. Peripherals: enable them in `<app>.ioc`, regenerate,
  then wrap the generated handle in `board/`.
- Console protocol: `READY`, `INFO app=.. board=<id>`, `OK ...`, `ERR ...`, `EVT ...` over the VCP.
- Templates: `hello-world` (prints every 1 s), `uart-btn-led` (console `led`/`btn` commands, B1
  toggles LED2). Tests: `tests/<spec>.json` - the same specs as the other skills.

**Check the layers (M2 - gated, stops with `ACTION: SETUP` until enabled):**
`python <repo>/lib/check_layers.py <app-dir>` → `LAYERS: PASS`, and
`bash <repo>/lib/host_test.sh <app-dir>` → `HOST: PASS` (the app's `func/` on the PC, fake board).

## Stage 4 - Build

```bash
bash "$SKILL/scripts/build.sh" <app> [--clean] [--allow-warnings]
```
`cmake --preset Debug` + `cmake --build --preset Debug` in `mx/` with the pinned bundles on PATH.
**Gate:** `BUILD: PASS` = exit 0, `mx/build/Debug/mx.elf` present, **0 warnings in `src/`** (exit
2 = fix them). Writes `mx.hex` and `mx/build/Debug/manifest.txt` (CubeMX + firmware package + tool
versions, SYSCLK, `.ioc` sha256, ELF/HEX sha256, size) **only on PASS** - flash.sh requires it.

## Stage 5 - Flash

**Ask the user before every flash** (board, app, ELF sha256 prefix): it overwrites the board's
firmware. Then:
```bash
bash "$SKILL/scripts/flash.sh" <app> --yes [--elf <known-good.elf>]
```
`FLASH_POLICY=auto` in this board's bench file replaces `--yes` for a dedicated lab board - only
the developer writes it, never you. discover, flash and test hold a per-board lock: `board '<id>'
is in use` means another run has the board - wait; delete the lock only after the user confirms
that run is gone.
Gates: ELF matches the PASS manifest → bench ST-LINK connected → hot-plug identity (ST-LINK board
`STM32L4IO`, device name `STM32L4x1/STM32L475xx...`, device ID 0x415; stops on signs of read-out
protection) → `-c port=SWD sn=<sn> mode=UR reset=HWrst -d <elf> -v -rst`. **Gate:** `FLASH: PASS`
(`Download verified successfully`).

## Stage 6 - Test (after flashing)

```bash
python "$SKILL/scripts/serial_test.py" auto <app>/tests/<spec>.json <app>/logs/test-<ts>.log --board <id> [--interactive | --only-interactive]
```
`auto` = the VCP of the bench ST-LINK. Syncs with `info` until `READY`, checks `board=<id>`, runs
the steps; steps for a second LED/button are skipped (`leds=1 btns=1`). Interactive steps (press
B1 USER, look at LED2) only with `--interactive`, after telling the user exactly what to do - the
button press must come within 30 s. **Gate:** `RESULT: PASS`. `led?` reads the GPIO output
register back.

## Stage 7 - Clean

```bash
bash "$SKILL/scripts/clean.sh" [--apps] [<workspace>]          # dry run
bash "$SKILL/scripts/clean.sh" [--apps] [<workspace>] --yes    # delete (ask the user first)
```
Default: `mx/build` and `.mx` only. `--apps`: whole apps (`l4-app.env`) incl. the user's `.ioc` and
`src/`, plus `.bench` - only when explicitly asked. `mx/` itself is kept (regen.sh).

## Extending

- **Another STM32L4 board in the CubeMX board database:** copy `boards/_template/`, fill `README.md`
  + `cubemx-hal-stm32l475iot/board.env` (`MX_START` with its CubeMX board name, `MX_CONFIG` for its
  console UART, expected ST-LINK board / device name / ID from `discover.sh`), add its `#elif`
  I/O table in `templates/_common/src/board/board.c` (and its console UART + IRQ if not USART1) and
  the `BOARD_NAME` mapping in `board.h`. A different board may later get a skill of its own name.
- **Tool/package update:** change the versions in the profile, re-run every template through
  create → build → flash → test, compare manifests, log it.

## Reporting (always)

Report levels separately: **source matches → generated → built → flashed → booted (READY) →
tested (PASS n/m) → observed by a human**. Quote ELF sha256, CubeMX/package/tool versions, log
paths. Add a dated line to `boards/<id>/cubemx-hal-stm32l475iot/README.md` when a board fact is
newly verified.

## Safety rules

- Identity gates before every write; never flash an ELF without a PASS manifest (except `--elf`
  chosen by the user) or a board whose ST-LINK board / device name / ID don't match.
- Never change option bytes, read-out protection (RDP) or security settings; never mass-erase or
  upgrade the ST-LINK firmware without asking.
- Ask before every flash and before `clean.sh --yes`.
- CubeMX runs headless through its own java on scripts the skill writes; the scripts end that java
  process tree themselves - never kill other STM32CubeMX / STM32CubeIDE processes.
