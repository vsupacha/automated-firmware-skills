---
name: cubemx2-hal2-stm32c562nucleo
description: End-to-end firmware workflow for STM32C5 boards (NUCLEO-C562RE) with the STM32CubeMX2 CLI on Windows - check the pinned STM32Cube bundles and packs, discover the on-board ST-LINK, create the hardware configuration (.ioc2) from the board with the pinned board pack, generate the CMake project headlessly, write layered code (board -> func -> app_main) hooked into the generated main.c, build with the pinned GCC/CMake/Ninja, flash with STM32CubeProgrammer behind identity gates (ST-LINK board, device name and ID), run automated UART tests over the ST-LINK virtual COM port, regenerate after .ioc2 changes, and clean build outputs. Use when asked to create, build, flash (แฟลช) or test STM32C5 / NUCLEO-C562RE firmware with STM32CubeMX2 (บอร์ด Nucleo), start from an existing .ioc2, regenerate after a CubeMX change, add an STM32C5 board profile, or when the user asks how to use this skill / what commands exist (ขอวิธีใช้, มีคำสั่งอะไรบ้าง, help). Not for classic STM32CubeMX (.ioc) projects or other STM32 families.
---

# STM32C5 firmware workflow (STM32CubeMX2)

Six gated stages plus a clean step, the same contract as every skill in this repo
(`docs/workflow.md`). Do them in order; do not start a stage until the previous gate passed.
**Windows + Git Bash only** (STM32Cube bundles for Windows, `taskkill`, `cygpath`).

```
1 tools ─► 2 discover + project ─► 3 code ─► 4 build ─► 5 flash ─► 6 test ─► 7 clean
check_tools  discover (ST-LINK)    src/board  build.sh   flash.sh   serial_test  clean.sh
             new_app / regen       src/func
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
| M1 bring-up | 1 setup, 2 create, 2d IDE, 3 build | Stage 1, Stage 2 step 2 (+ `regen.sh`), Stage 4 |
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

When the user asks for help, usage or the command list ("ขอวิธีใช้หน่อย", "มีคำสั่งอะไรบ้าง", "help"),
run `bash "$SKILL/scripts/help.sh"` (Thai) or `help.sh --en`, show the output as-is, then offer the
next step (usually Stage 1). Do not run other stages.

`$SKILL` below = the folder containing this SKILL.md. Always quote: `bash "$SKILL/scripts/x.sh"`.
Repo layout this skill needs:

```
<repo>/skills/cubemx2-hal2-stm32c562nucleo/        this skill (SKILL.md, scripts/, reference/, templates/)
<repo>/boards/<id>/README.md          board hardware (tool-independent)
<repo>/boards/<id>/cubemx2-hal2-stm32c562nucleo/    this skill's board profile: board.env, README (verification log)
<repo>/apps/                          apps workspace when working inside the repo
```

Workspace `$CUBE_WS`: `<repo>/apps` inside the repo checkout, otherwise `./apps`. Board profiles:
`<project>/boards/<id>/cubemx2-hal2-stm32c562nucleo/` first, then `<repo>/boards` (override `CUBE_BOARDS_DIR`).
STM32Cube bundles + packs: `%LOCALAPPDATA%\stm32cube` (override `STM32CUBE_ROOT`).

## What an app looks like

```
apps/<app>/
  <app>.ioc2        STM32CubeMX2 hardware configuration - the source of truth (commit it)
  src/              our layered code: board/, func/, app_main.c (commit it)
  tests/<spec>.json test contract (commit it)
  cubemx-app.env    record: board, template, how the .ioc2 was made, software project, preset
  mx/               generated CMake project (CubeMX-owned, rewritten by regen.sh; git-ignored)
  .mx/              working copy of the .ioc2 + backend logs (git-ignored)
  logs/             build/flash/test logs (git-ignored)
  <app>.code-workspace  VS Code workspace (mx/, src/, tests/) - open_ide.sh makes it (git-ignored)
```

**Is a .ioc2 file needed?** Yes - every app has one, but nobody has to supply it: `new_app.sh`
creates it from the board (`mx project create-from-board`, pinned board pack) and applies the
profile's `MX_CONFIG` (e.g. USART2 Async). To start from a user's own hardware configuration,
pass `--ioc2 <file>`. Change hardware with the STM32CubeMX2 GUI or CLI on `<app>.ioc2`, then
`regen.sh`.

## Board type vs bench instance

- **Board type** (`boards/<id>/`): `README.md` = hardware; `cubemx2-hal2-stm32c562nucleo/board.env` = board CPN,
  board pack version, `MX_CONFIG`, pinned bundle versions, packs, `BOARD_DEFINE`, `BTN_LABELS`,
  expected ST-LINK board / device name / device ID.
- **Bench instance** (`<workspace>/.bench/<id>.env`, written by `discover.sh`): `PROBE_SERIAL`
  (ST-LINK) and `CONSOLE_PORT` (its virtual COM port - the VCP's USB serial is the probe serial).
  Override with `CUBE_PROBE_SERIAL` / `CUBE_CONSOLE`. Never write them into `boards/`.

| id | board | status |
| --- | --- | --- |
| `nucleo-c562re` | ST NUCLEO-C562RE (STM32C562RET6, STLINK-V3EC) | see `boards/nucleo-c562re/cubemx2-hal2-stm32c562nucleo/README.md` |

## Hardware quick reference

| Board | Button | LED | Console |
| --- | --- | --- | --- |
| NUCLEO-C562RE | **B1** (USER, blue) PC13, pull-down, **pressed = high**; B2 = RESET | **LD1** green PA5, active high | USART2 PA2/PA3 → ST-LINK VCP, 115200 |

## Stage 1 - Tools and folder paths

```bash
bash "$SKILL/scripts/check_tools.sh" <board-id> [--ws <workspace>]
```
Checks the workspace path (no spaces/non-ASCII, ≤100 characters), every **pinned** bundle
(STM32CubeMX2 + its node, GNU Tools for STM32, CMake, Ninja, STM32CubeProgrammer CLI), every
pinned pack, python + pyserial, and lists ST-LINKs with their VCP. Read-only.
**Gate:** `missing/bad=0`. A missing bundle/pack: tell the user to install it with STM32CubeMX2 /
the STM32Cube bundle manager - don't install it yourself; never silently use another version.

## Stage 2 - Discover the board, create the project

1. **Discover (read-only):** `bash "$SKILL/scripts/discover.sh" <board-id> [--serial <sn>]`
   - lists ST-LINKs, hot-plug connects (no reset, no write) and checks the board name the ST-LINK
     reports, the device name and the device ID; saves the bench file.
   - **Gate:** `IDENTITY: PASS`. Several ST-LINKs: `--serial` (it never guesses).
2. **Create the app:** `bash "$SKILL/scripts/new_app.sh" <board-id> <app> [<workspace>] [template] [--ioc2 <file>]`
   - starts a headless STM32CubeMX2 backend (own free port, stopped afterwards), creates
     `<app>.ioc2` from the board + `MX_CONFIG`, copies the template, then runs `regen.sh`.
   - **Gate:** `REGEN: PASS` and `Created ...`.
3. **After any .ioc2 change:** `bash "$SKILL/scripts/regen.sh" <app>` - generates `mx/` from a
   working copy (the app's `.ioc2` stays free of absolute paths), then re-applies the hook:
   `main.c` calls `app_main()`, `CMakeLists.txt` compiles `../src/**/*.c` with `-DBOARD_<ID>` and
   `-Wextra`. **Gate:** `REGEN: PASS`. "overlay failed" = the generated markers changed (new
   STM32CubeMX2) - update `scripts/overlay.py`, never hand-edit `mx/`.
4. **Open in the IDE (stage 2d, automatic):** at the end, `new_app.sh` runs
   `bash "$SKILL/scripts/open_ide.sh" <app>` (`--no-open` on new_app/open_ide: no window). It opens
   `<app>.code-workspace` (`mx/`, `src/`, `tests/` as folders - never the app folder) in VS Code;
   `regen.sh` pre-writes the STM32CubeIDE for VS Code setup of `mx/` from the board profile
   (`.settings/ide.store.json`, `.settings/bundles.store.json` = the pinned bundles,
   `.vscode/settings.json` for cube-cmake, `.vscode/launch.json` = the extension's default ST-LINK
   launch). The developer can then build (CMake preset, same `mx/build/<preset>` as build.sh),
   flash + debug (F5) and edit `src/` in the IDE; hardware changes go through STM32CubeMX2 on the
   `.ioc2` + `regen.sh`. **Gate:** `IDE: READY <workspace>` + `IDE: OPENED`; exit 10
   `ACTION: SETUP` = VS Code or the extension is missing (new_app.sh only reports it). See
   docs/workflow.md "IDE handoff".

## Stage 3 - Code in layers

Read `reference/layering.md` first. Rules:
- `src/board/` - **only** place for GPIO ports/pins, HAL2/LL calls, `#if defined(BOARD_xxx)`.
  User LEDs/buttons are configured at run time here (HAL GPIO); clocks, USART2 and its pins come
  from the generated `mx_system_init()`.
- `src/func/` - services (console, led, button) copied from `<repo>/lib/func` - shared unchanged
  with the modus-pdl-edgitalk skill; a reusable new service goes into `lib/func` (board.h only).
- `src/app_main.c` - `app_main()` wiring + application logic.
- Never edit `mx/` (rewritten by `regen.sh`). Peripherals: enable them in the `.ioc2`, regenerate,
  then wrap the generated `mx_<periph>_..._gethandle()` in `board/`.
- Console protocol: `OK ...`, `ERR ...`, `EVT ...`, `<TAG> k=v ...`, `INFO ... board=<id>` then
  `READY`. Keep the main loop non-blocking: the UART is polled (no RX interrupt in the default
  project), so a 1 ms delay in the loop already loses characters.
- Templates: `hello-world`, `blink` (LED1 every 0.5 s), `push-to-light` (B1 toggles LD1). Tests: `tests/<app>.json`.

**Check the layers (M2 - gated, stops with `ACTION: SETUP` until enabled):**
`python <repo>/lib/check_layers.py <app-dir>` → `LAYERS: PASS` (exit 2 = warnings to fix), and
`bash <repo>/lib/host_test.sh <app-dir>` → `HOST: PASS` (the app's `func/` unit-tested on the PC
against a fake board, no hardware). Fix a violation in the layer the message names.

## Stage 4 - Build

```bash
bash "$SKILL/scripts/build.sh" <app> [--clean] [--allow-warnings]
```
`cmake --preset debug_GCC_<CPN>` + `cmake --build` with the pinned tools on PATH.
**Gate:** `BUILD: PASS` = exit 0, ELF present, **0 warnings in `src/`** (exit 2 = fix them).
Writes `<sw>.hex` and `mx/build/<preset>/manifest.txt` (tool versions, packs as linked, `.ioc2`
sha256, ELF/HEX sha256, size) **only on PASS** - flash.sh requires it.

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
Gates: ELF matches the PASS manifest → bench ST-LINK connected → hot-plug identity (ST-LINK board,
device name, device ID; stops on signs of read-out protection) → `-c port=SWD sn=<sn> mode=UR
reset=HWrst -d <elf> -v -rst`. **Gate:** `FLASH: PASS` (`Download verified successfully`).

## Stage 6 - Test (after flashing)

```bash
python "$SKILL/scripts/serial_test.py" auto <app>/tests/<spec>.json <app>/logs/test-<ts>.log --board <id> [--interactive | --only-interactive]
```
`auto` = the VCP of the bench ST-LINK. Syncs with `info` until `READY`, checks `board=<id>`, runs
the steps. Interactive steps (press B1, look at LD1) only with `--interactive`, after telling the
user exactly what to do. **Gate:** `RESULT: PASS`. `led?` reads the GPIO output register back.

## Stage 7 - Clean

```bash
bash "$SKILL/scripts/clean.sh" [--apps] [<workspace>]          # dry run
bash "$SKILL/scripts/clean.sh" [--apps] [<workspace>] --yes    # delete (ask the user first)
```
Default: `mx/build` and `.mx` only. `--apps`: whole apps (`cubemx-app.env`) incl. the user's
`.ioc2` and `src/`, plus `.bench` - only when explicitly asked. `mx/` itself is kept (regen.sh).

## Extending

- **Another STM32C5 board:** `mx finder` / the board pack name, then copy `boards/_template/`,
  fill `README.md` + `cubemx2-hal2-stm32c562nucleo/board.env` (CPN, pack version, `MX_CONFIG` for its VCP UART,
  device name/ID from `discover.sh`, `EXPECTED_STLINK_BOARD`), add its `#elif` user-I/O table in
  `templates/_common/src/board/board.c` and the `BOARD_NAME` mapping in `board.h`.
- **Tool/pack update:** change the versions in the profile, re-run every template through
  create → build → flash → test, compare manifests, log it. Never float to "whatever is installed".

## Reporting (always)

Report levels separately: **source matches → generated → built → flashed → booted (READY) →
tested (PASS n/m) → observed by a human**. Quote ELF sha256, tool/pack versions, log paths. Add a
dated line to `boards/<id>/cubemx2-hal2-stm32c562nucleo/README.md` when a board fact is newly verified.

## Safety rules

- Identity gates before every write; never flash an ELF without a PASS manifest (except `--elf`
  chosen by the user) or a board whose ST-LINK board / device name / ID don't match.
- Never change option bytes, read-out protection (RDP), product state or security settings;
  never mass-erase or upgrade ST-LINK firmware without asking.
- Ask before every flash and before `clean.sh --yes`.
- The headless backend is started and killed by the scripts on their own port; never kill other
  STM32CubeMX2 / STM32CubeIDE processes.
