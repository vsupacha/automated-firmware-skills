---
name: cubemx-hal-stm32n6570dk
description: Firmware workflow for the ST STM32N6570-DK (STM32N657, Cortex-M55) with classic STM32CubeMX 6.18 in headless script mode, the STM32CubeN6 HAL and CMake - check the pinned CubeMX, firmware package and STM32Cube build bundles, create the hardware configuration (.ioc) from ST's FSBL-only reference template plus the board's console settings, generate the CMake project headlessly, write layered code (board -> func -> app_main) hooked into the generated main.c, and build with the pinned GCC/CMake/Ninja and a build manifest. Milestone M1 (setup, create, build); flash and test are planned. Use when asked to create, generate, regenerate or build STM32N6 / STM32N6570-DK firmware with STM32CubeMX (บอร์ด STM32N6570-DK), or when the user asks how to use this skill / what commands exist (ขอวิธีใช้, มีคำสั่งอะไรบ้าง, help). Not for STM32CubeMX2 boards (STM32C5: cubemx2-hal2-stm32c562nucleo), STM32CubeIDE projects or the Appli/secure-boot project structures.
---

# STM32N6570-DK firmware workflow (STM32CubeMX + STM32CubeN6 HAL + CMake)

Gated stages, the same contract as every skill in this repo (`docs/workflow.md`). Do them in
order; do not start a stage until the previous gate passed. **Windows + Git Bash only**
(STM32CubeMX for Windows, STM32Cube bundles, `cygpath`, `taskkill`). This release covers
**milestone M1**; the hardware stages (discover, flash, test) come after the key boards.

```
1 tools ─► 2 project + VS Code ─► 3 code ─► 4 build ─► (5 flash, 6 test: planned) ─► 7 clean
check_tools  new_app    src/board  build.sh                                     clean.sh
             regen      src/func
             open_ide
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
| M1 bring-up | 1 setup, 2 create, 2d IDE, 3 build | Stage 1, Stage 2 (+ `regen.sh`), Stage 4 |
| M1 bring-up (board) | 4 connect, 5 flash, 6 test, 7 debug | **planned** for this skill |
| M2 board support | 8 board drivers *(planned)*, 9 layer check, 10 host test *(optional)* | Stage 3 (rules, shared `lib/func`, `check_layers.py`, `host_test.sh`) |
| M3 execution, M4 components, M5 application | 11 execution + trace, 12 components, 13 profile *(planned)* | - |
| - | 14 export *(planned)*, 15 port *(planned)* | Extending |
| - | 16 clean | Stage 7 |

**Exit codes:** 0 gate passed, 1 failed, 2 warnings, **10 = developer action needed**. On exit 10
the script's last line is `ACTION: <TYPE> <what to do>` (SETUP, ...): tell the user exactly that,
wait for their OK, then re-run the same command. Never work around an ACTION yourself -
installing STM32CubeMX, firmware packages or bundles (myST login, licences) is the developer's.

**Release scope:** `<repo>/milestones.env` lists the active milestones (this release: **M1**).
This skill has the M1 build stages only; its board stages (connect, flash, test) are planned.
Never edit `milestones.env` or set `FW_ACTIVE_MILESTONES` yourself.

## Help menu (answer this first when asked how to use the skill)

When the user asks for help, usage or the command list ("ขอวิธีใช้หน่อย", "มีคำสั่งอะไรบ้าง", "help"),
run `bash "$SKILL/scripts/help.sh"` (Thai) or `help.sh --en`, show the output as-is, then offer the
next step (usually Stage 1). Do not run other stages.

`$SKILL` below = the folder containing this SKILL.md. Always quote: `bash "$SKILL/scripts/x.sh"`.
Repo layout this skill needs:

```
<repo>/skills/cubemx-hal-stm32n6570dk/        this skill (SKILL.md, scripts/, reference/, templates/)
<repo>/lib/func/                              shared C logic layer, copied into every app's src/func
<repo>/boards/<id>/README.md                  board hardware (tool-independent)
<repo>/boards/<id>/cubemx-hal-stm32n6570dk/   board profile: board.env, README (verification log)
<repo>/apps/                                  apps workspace when working inside the repo
```

Workspace `$N6_WS`: `<repo>/apps` inside the repo checkout, otherwise `./apps`. Board profiles:
`<project>/boards/<id>/cubemx-hal-stm32n6570dk/` first, then `<repo>/boards` (override
`N6_BOARDS_DIR`). STM32CubeMX: `C:\Program Files\STMicroelectronics\STM32Cube\STM32CubeMX`
(override `CUBEMX_HOME`); its firmware repository comes from CubeMX's own settings.

## What an app looks like

```
apps/<app>/
  <app>.ioc         STM32CubeMX configuration - the source of truth for clocks/peripherals (commit it)
  src/              our layered code: board/, func/ (copy of lib/func), app_main.c (commit it)
  tests/<spec>.json test contract, the same specs as the other skills (commit it)
  n6-app.env        record: board, template, where the .ioc came from, CubeMX version
  <app>.code-workspace  VS Code workspace: mx/, src/, tests/ as folders (open_ide.sh; git-ignored)
  mx/               generated CMake project: FSBL/ (CubeMX-owned + overlay; git-ignored)
  .mx/ logs/        CubeMX scripts and logs (git-ignored)
```

**Opening an app in VS Code (STM32CubeIDE for VS Code):** open `<app>.code-workspace` (File >
Open Workspace from File), **not the app folder**. The extension accepts a workspace folder only
when its CMake project sits at the folder root - the app folder holds `mx/` and `mx/FSBL/` below
it, so discovery stops with "The workspace folder ... contains multiple CMake projects". In the
workspace, `mx/` is its own folder: the extension discovers it, installs the STM32N6 device pack
(`stm32n6xx_dfp`) on first use and indexes the code; its files (`.settings/`, `.vscode/`, `.clangd`)
stay inside `mx/`. Build with `build.sh` - the extension's own build uses the same presets.

**Where the .ioc comes from:** `new_app.sh` starts from ST's FSBL-only reference template in the
firmware package (`MX_TEMPLATE_IOC`: 800 MHz, caches, FullSecure, Appli/ExtMemLoader off) and
applies the profile's `MX_CONFIG` CubeMX commands (USART1 in the FSBL context, PE5/PE6). Change the
hardware with the STM32CubeMX GUI on `<app>.ioc`, then `regen.sh`.

## Board type vs bench instance

- **Board type** (`boards/<id>/`): `README.md` = hardware; `cubemx-hal-stm32n6570dk/board.env` =
  pinned CubeMX and firmware package versions, `MX_TEMPLATE_IOC`, `MX_CONFIG`, `BOARD_DEFINE`,
  labels, pinned bundle versions.
- **Bench instance** (`<workspace>/.bench/<id>.env`): board stages, not used yet.

| id | board | status |
| --- | --- | --- |
| `stm32n6570-dk` | ST STM32N6570-DK (STM32N657X0H3Q, STLINK-V3EC) | see `boards/stm32n6570-dk/cubemx-hal-stm32n6570dk/README.md` |

## Hardware quick reference

| Board | Button | LEDs | Console |
| --- | --- | --- | --- |
| STM32N6570-DK | **USER1** PC13, pull-down, **pressed = high** | **LED1** green PO1 active **high**; **LED2** red PG10 active **low** | USART1 PE5 TX / PE6 RX → ST-LINK VCP, 115200 |

The CPU runs at 800 MHz only with the external SMPS at overdrive voltage (PF4 high):
`board_early_init()` sets it before `SystemClock_Config()`, as ST's template does.

## Stage 1 - Tools and folder paths

```bash
bash "$SKILL/scripts/check_tools.sh" <board-id> [--ws <workspace>]
```
Checks the workspace path (no spaces/non-ASCII, ≤100 characters), STM32CubeMX (pinned version, its
bundled java), the CubeMX repository and the pinned `STM32Cube_FW_N6` package (+ the board's BSP),
GNU Tools for STM32 / CMake / Ninja bundles. Read-only. **Gate:** `missing/bad=0`. A missing package:
the user installs it in STM32CubeMX (Help > Manage embedded software packages) - not you.

## Stage 2 - Create the project

1. **Create:** `bash "$SKILL/scripts/new_app.sh" <board-id> <app> [<workspace>] [template]`
   - copies `lib/func` + `templates/_common/src` + the template, then one headless CubeMX run:
     load ST's template `.ioc`, apply `MX_CONFIG`, save `<app>.ioc`, generate `mx/` (CMake);
     then `overlay.py` hooks the app in. About 2 minutes (CubeMX start-up).
   - **Gate:** `REGEN: PASS` and `Created ...`. Any CubeMX command answering `KO`, a lost generated
     file or a CubeMX that never reaches `exit` fails the gate.
2. **After any .ioc change:** `bash "$SKILL/scripts/regen.sh" <app>` - regenerates `mx/` (USER CODE
   sections survive) and re-applies the overlay. **Gate:** `REGEN: PASS`. "OVERLAY: FAIL" = a new
   CubeMX changed the generated markers - update `scripts/overlay.py`, never hand-edit `mx/`.
3. **Open in the IDE (stage 2d, automatic):** at the end, `new_app.sh` runs
   `bash "$SKILL/scripts/open_ide.sh" <app>` (`--no-open` on new_app/open_ide: no window). It opens
   `<app>.code-workspace` - never the app folder - in VS Code; `new_app`/`regen` have pre-written
   the STM32CubeIDE for VS Code setup of `mx/` from the board profile (`.settings/ide.store.json`,
   `.settings/bundles.store.json` with the pinned bundle versions, `.vscode/settings.json` for
   cube-cmake, `.vscode/launch.json` = the extension's default ST-LINK launch), so the extension
   configures and indexes the project without a prompt. The developer can then build (CMake
   preset, same `mx/build/<preset>` as build.sh), flash + debug (F5) and edit `src/` in the IDE.
   **Gate:** `IDE: READY <workspace>` + `IDE: OPENED`; exit 10 `ACTION: SETUP` = VS Code or the
   extension is missing (new_app.sh only reports it). See docs/workflow.md "IDE handoff".

## Stage 3 - Code in layers

Read `reference/layering.md` first. Rules:
- `src/board/` - **only** place for GPIO ports/pins, HAL calls, `#if defined(BOARD_xxx)`. User LEDs
  and buttons are configured at run time here (HAL GPIO); clocks, caches and USART1 come from the
  generated code (`huart1`).
- `src/func/` - services (console, led, button) copied from `<repo>/lib/func` - shared unchanged
  with the modus-pdl-edgitalk, cubemx2-hal2-stm32c562nucleo and pio-espidf-esp32s3box skills; a reusable new
  service goes into `lib/func` (board.h only).
- `src/app_main.c` - `app_main()` wiring + application logic, called from `USER CODE BEGIN 2`.
- Never edit `mx/` outside USER CODE sections. Peripherals: enable them in `<app>.ioc` (FSBL
  context), regenerate, then wrap the generated handle in `board/`.
- Console protocol: `OK ...`, `ERR ...`, `EVT ...`, `<TAG> k=v ...`, `INFO ... board=<id>` then
  `READY`. The UART is polled (no RX interrupt): keep the main loop non-blocking.
- Templates: `hello-world`, `uart-btn-led` (USER1 toggles LED1). Tests: `tests/<app>.json`.

**Check the layers (M2 - gated, stops with `ACTION: SETUP` until enabled):**
`python <repo>/lib/check_layers.py <app-dir>` → `LAYERS: PASS`, and
`bash <repo>/lib/host_test.sh <app-dir>` → `HOST: PASS` (the app's `func/` on the PC, fake board).

## Stage 4 - Build

```bash
bash "$SKILL/scripts/build.sh" <app> [--clean] [--allow-warnings]
```
`cmake --preset Debug` + `cmake --build --preset Debug` in `mx/` with the pinned bundles on PATH;
the generated top level builds `FSBL/` as an external project. **Gate:** `BUILD: PASS` = exit 0,
`mx/FSBL/build/mx_FSBL.elf` present, **0 warnings in `src/`** (exit 2 = fix them). Writes
`mx_FSBL.hex` and `mx/FSBL/build/manifest.txt` (CubeMX + firmware package + tool versions, `.ioc`
sha256, ELF/HEX sha256, size) **only on PASS**.

## Stage 5 - Flash, Stage 6 - Test (planned)

Not implemented in this skill yet. The FSBL image runs from internal SRAM: in development boot
mode (BOOT1 switch 1-3) a debugger loads and runs it; booting from external flash needs a signed
image. Do not improvise either with STM32CubeProgrammer - say the hardware stages are planned and
stop after `BUILD: PASS`.

## Stage 7 - Clean

```bash
bash "$SKILL/scripts/clean.sh" [--apps] [<workspace>]          # dry run
bash "$SKILL/scripts/clean.sh" [--apps] [<workspace>] --yes    # delete (ask the user first)
```
Default: `mx/build`, `mx/FSBL/build` and `.mx` only. `--apps`: whole apps (`n6-app.env`) incl. the
user's `.ioc` and `src/`, plus `.bench` - only when explicitly asked. `mx/` itself is kept (regen.sh).

## Extending

- **Another STM32N6 board** (NUCLEO-N657X0-Q): copy `boards/_template/`, fill `README.md` +
  `cubemx-hal-stm32n6570dk/board.env` (its own ST template `.ioc` in the firmware package,
  `MX_CONFIG` for its VCP UART), add its `#elif` I/O table in `templates/_common/src/board/board.c`
  and the `BOARD_NAME` mapping in `board.h`. A different board may later get a skill of its own name.
- **Tool/package update:** change the versions in the profile, re-run every template through
  create → build, compare manifests, log it. Never float to "whatever is installed".

## Reporting (always)

Report levels separately: **source matches → generated → built → flashed → booted (READY) →
tested (PASS n/m) → observed by a human**. With the build stages only, the highest level is **built**. Quote ELF
sha256, CubeMX/package/tool versions, log paths. Add a dated line to
`boards/<id>/cubemx-hal-stm32n6570dk/README.md` when something is newly verified.

## Safety rules

- Never program OTP fuses, change the product state or security settings, or write external flash
  with an unsigned image - stop and ask.
- Ask before `clean.sh --yes`.
- CubeMX runs headless through its own java on scripts the skill writes; the scripts end that java
  process tree themselves - never kill other STM32CubeMX / STM32CubeIDE processes.
