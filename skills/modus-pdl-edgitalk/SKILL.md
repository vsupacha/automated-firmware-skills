---
name: modus-pdl-edgitalk
description: End-to-end firmware workflow for Infineon PSOC Edge E84 (PSE84) boards - RT-Thread Edgi-Talk, TESAIoT DevKit, KIT_PSE84_AI / KIT_PSE84_EVAL - with native ModusToolbox on Windows - check dev tools and folder paths, discover the KitProg3 board, create a Project Creator app with a board BSP overlay, write layered code (board -> func -> main), build, flash with identity/life-cycle gates via OpenOCD, run automated UART tests, list and start from Infineon ModusToolbox code examples, and clean build outputs. Use when asked to create, build, flash (แฟลช) or test PSOC Edge / PSE84 / E84 firmware (บอร์ด PSOC Edge), list or start from ModusToolbox examples for E84, port an app to another E84 board, add an E84 board profile, or when the user asks how to use this skill / what commands exist (ขอวิธีใช้, มีคำสั่งอะไรบ้าง, help). Not for PSoC 6 or other MCU families.
---

# PSOC Edge E84 firmware workflow

Six gated stages plus a clean step. Do them in order; do not start a stage until the previous
gate passed. Each stage has a script in `scripts/` and details in `reference/`.
**Windows + Git Bash only** (Claude's Bash tool is Git Bash; in PowerShell `bash` may be WSL).

```
1 tools ─► 2 discover + project ─► 3 code ─► 4 build ─► 5 flash ─► 6 test ─► 7 clean
check_tools  discover (board)      board/     build.sh   flash.sh   serial_test  clean.sh
             examples / new_app    func/ main
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
| M1 skeleton | 1 setup, 2 create, 3 build | Stage 1, Stage 2 step 2, Stage 4 |
| M2 layering | 4 layer check, 5 host test | Stage 3 (rules, shared `lib/func`, `check_layers.py`, `host_test.sh`) |
| M3 hardware | 6 connect, 7 flash, 8 test, 9 debug *(planned)* | Stage 2 step 1, Stage 5, Stage 6 |
| M4 porting | 10 port *(planned)* | Extending |
| - | 11 clean | Stage 7 |

**Exit codes:** 0 gate passed, 1 failed, 2 warnings, **10 = developer action needed**. On exit 10
the script's last line is `ACTION: <TYPE> <what to do>` (SETUP, CONNECT, POWER_CYCLE, JUMPER,
APPROVE, CHOOSE): tell the user exactly that, wait for their OK, then re-run the same command
(with `--yes` / `--serial` when the action says so). Never work around an ACTION yourself -
installing tools, accepting licences, changing drivers/system settings, plugging hardware and
approving flashes or deletions are the developer's.

**Release scope:** `<repo>/milestones.env` lists the active milestones (this release: **M1
only**). M3 scripts (discover, identity check, backup, flash, serial test) are implemented and were
verified on hardware, but stop with `ACTION: SETUP ... not active` until the developer enables M3
there (or exports `FW_ACTIVE_MILESTONES="M1 M3"`). Never edit `milestones.env` or set that variable
yourself - relay the ACTION like any other.

## Help menu (answer this first when asked how to use the skill)

When the user asks for help, usage, or the list of commands ("ขอวิธีใช้หน่อย", "ใช้ยังไง",
"มีคำสั่งอะไรบ้าง", "help", "what can you do"), run `bash "$SKILL/scripts/help.sh"` (Thai) or
`help.sh --en` and show its output as-is (it lists example requests, the script behind each, and
the boards/templates installed). Then offer the next step that fits (usually Stage 1). Do not run
any other stage just because help was asked.

When the user asks what ModusToolbox examples exist for E84 / a board ("ขอรายการ example",
"มี example bluetooth ไหม"), run `examples.sh <board> [words]` (needs GitHub; cached 1 day) and
show the list; `--detail <id>` for one example. Ask which board if it is not clear - the list
depends on the BSP (`kit-pse84-ai`/`tesaiot` → KIT_PSE84_AI, `edgi-talk` → KIT_PSE84_EVAL_EPC2).

`$SKILL` below = the folder containing this SKILL.md. Always quote: `bash "$SKILL/scripts/x.sh"`.
This skill is part of the automated-firmware-skills repo and needs the repo layout:

```
<repo>/skills/modus-pdl-edgitalk/        this skill (SKILL.md, scripts/, reference/, templates/)
<repo>/boards/<id>/README.md          board hardware (tool-independent)
<repo>/boards/<id>/modus-pdl-edgitalk/    this skill's board profile: board.env, overlays, README
<repo>/apps/                          apps workspace when working inside the repo
```

The apps workspace `$PSE84_WS` (override by setting it): `<repo>/apps` when the current directory
is inside the repo checkout, otherwise `./apps` of the current directory (e.g. skill installed as a
plugin). Board profiles are looked up in `<project>/boards/<id>/modus-pdl-edgitalk/` first (the user's own
boards, next to the workspace - survives skill updates), then `<repo>/boards` (override
`PSE84_BOARDS_DIR`). `new_app.sh` writes `<workspace>/.gitignore` if missing. Backups (`backup.sh`) go to
`$PSE84_BACKUP_DIR` = the workspace's parent `/backup` (git-ignored). Keep LF line endings
(`.gitattributes` enforces it in git).

## Board type vs bench instance

- **Board type** (`boards/<id>/`, in the repo, same for every copy of that board):
  `README.md` = hardware (pins, LEDs, buttons, on-board parts, connectors), shared by all skills;
  `modus-pdl-edgitalk/board.env` (BSP id/version/base hash, overlay, `BOARD_DEFINE`, `BTN_LABELS`,
  expected device + life cycle, OpenOCD target cfg), `modus-pdl-edgitalk/README.md` (BSP delta,
  tool quirks, verification log), overlays (`modus-pdl-edgitalk/design.modus`).
- **Bench instance** (`<workspace>/.bench/<id>.env`, per PC + board, written by `discover.sh`):
  `PROBE_SERIAL`, `CONSOLE_PORT`. Override with env `PSE84_PROBE_SERIAL` / `PSE84_CONSOLE`.
  Never write a probe serial or COM port into `boards/`.

| id | board | base BSP | status |
| --- | --- | --- | --- |
| `edgi-talk` | RT-Thread Edgi-Talk | `KIT_PSE84_EVAL_EPC2` 1.4.0 + clock overlay | verified on HW |
| `kit-pse84-ai` | PSOC Edge E84 AI Kit, on-board I/O only | `KIT_PSE84_AI` 1.4.0, no overlay | verified on HW |
| `tesaiot` | TESAIoT DevKit = AI Kit + QWA309 base board (`BOARD_EXTENDS=kit-pse84-ai`, adds SW4/SW5) | inherited | AI-Kit I/O verified; SW4/SW5 blocked by camera |

`BOARD_EXTENDS=<parent>` in `board.env` loads the parent profile first; the child sets only what
differs (`BOARD_ID`, `BOARD_DEFINE`, `BTN_LABELS`, extras). C code sees only `-DBOARD_<ID>`;
`board/board.h` maps it to names and extras (e.g. `BOARD_HAS_QWA309`).

Unknown board → `boards/_template/modus-pdl-edgitalk/README.md`. Empty profile values make scripts stop with a
message naming the missing variable - fill them, don't guess silently.

## Hardware quick reference - switches and LEDs

Use the **silkscreen name** when talking to a user (`BTN_LABELS`), never the macro name.
Polarity always from the BSP: `CYBSP_LED_STATE_ON` (1 on all three), `CYBSP_BTN_PRESSED` (0).

| Board | Switch (silkscreen → pin) | LEDs (→ pin) |
| --- | --- | --- |
| Edgi-Talk | **SW2** = `CYBSP_USER_BTN1` (`CYBSP_SW2`) P8[3], pull-up. `CYBSP_USER_BTN2` (SW4, P8[7]) is an eval-kit leftover - **not populated**. | LED1 red P16[7], LED2 green P16[6], LED3 blue P16[5] (`CYBSP_USER_LED1..3`) |
| KIT_PSE84_AI (on-board) | **SW1** = user button = `CYBSP_USER_BTN1` (`CYBSP_SW1`) P7[0]; SW2 = RESET. Verified on our kit 2026-10-03 - the TESAIoT SDK docs call the user button "SW2": trust the silkscreen of the board in front of you | LED1 P10[7], LED2 P10[5] (no TCPWM route), RGB red/blue/green P20[6]/P20[5]/P20[4] = `CYBSP_USER_LED3/4/5` (TCPWM0 grp1 lines 265/264/263 → hardware dimming) |
| QWA309 base board (TESAIoT) | **SW4** P17.5, **SW5** P17.7 - not in the BSP: configure at run time (`Cy_GPIO_Pin_FastInit(..., CY_GPIO_DM_PULLUP, 1, HSIOM_SEL_GPIO)`), active low, debounce ≥50 ms. Older docs call them SW9/SW10 or SW5/SW6. **P17.5 is also the USB-host VBUS enable** (buttons and USB joystick are exclusive) and both nets are the DVP camera RESET/PWDN lines: **with the camera plugged in they read 0 permanently** (seen 2026-10-03) - unplug the camera to use SW4/SW5. **QWA309 has a CS select switch that enables its I2C**: with it selected the base-board buttons and CapSense work; without it the TESAIoT base firmware prints `PSOC,ERR,<ms>,I2C,START-W,...` every 100 ms and sees no presses (reported by the lab, 2026-10-03). Check that switch first when base-board I/O is dead. CapSense BTN0/BTN1 + slider = PSoC 4000T @0x08 on the CM55-owned display/touch I2C (P17.0/P17.1) - not GPIO. | No discrete GPIO LEDs. DFR0522 16×8 RGB matrix @0x10 on the header I2C (SCB5, shared with display/touch, owned by CM55) |

QWA309 extras for later groups: pots VR1..VR4 = P15.4..P15.7 (SAR GPIO ch 4..7, knob map
{5,4,6,7} - VR1/VR2 traces swapped), header GPIO P13.0/3/4/5/6/7, header PWM P13.3 (+P13.4
complement), header UART SCB9 P15.0 RX / P15.1 TX. Source: TESAIoT SDK docs J4, J5 and
"Peripherals at a glance" - https://tesaiot.github.io/tesaiot-pse84-devkit-sdk/sdk/mtb-mpy/index.html
(add-on boards may carry their own "SW1"; always say which board a button is on).

## Stage 1 - Tools and folder paths

> **WARNING - folder names.** ModusToolbox (make, configurators, OpenOCD) breaks when a path
> contains **spaces** or **non-English (non-ASCII) characters, e.g. Thai**. This applies to the
> workspace/app folder, the Windows user (home) folder, and the ModusToolbox install folder.
> Use only English letters, digits, `-` and `_`. A Thai Windows user name needs ModusToolbox
> installed and the workspace placed outside the home folder (e.g. `C:/pse84-ws`). Cloud-synced
> folders (Dropbox/OneDrive) work but can lock files during getlibs/build - pause sync if a build
> fails with "permission denied" / "resource busy".

```bash
bash "$SKILL/scripts/check_tools.sh" <board-id> [--fix] [--ws <workspace>]
```
Checks the paths above (`BAD` = must fix; `new_app`, `build`, `flash` also refuse unsafe paths),
then ModusToolbox tools (version vs profile), project-creator/device-configurator CLIs,
modus-shell, Programming Tools (OpenOCD, fw-loader), Arm GCC, Edge Protect Security Suite,
git, python + pyserial, and lists Infineon COM ports. `--fix` only installs pyserial (user pip).
Anything else missing: tell the user what to install (ModusToolbox Setup) - never run installers
needing admin rights yourself. **Gate:** `missing/bad=0`; report every WARN (reference/tools.md).

## Stage 2 - Discover the board, create the project

1. **Discover (needs the board, read-only):** `bash "$SKILL/scripts/discover.sh" <board-id> [--serial <s>]`
   - lists KitProg3 probes + their USB-UART COM ports, picks the only one (or `--serial`),
     runs `identity_check.sh` (attach with `ENABLE_ACQUIRE 0`: no reset/erase; checks probe
     serial + detected device), then saves the bench file.
   - **Gate:** `IDENTITY: PASS` + `Saved ...`. On FAIL stop and report (wrong board/probe, probe
     busy in another tool, locked chip). Re-run after changing board or USB port.
   - No board yet? Skip to step 2 - creating and building need no hardware.
2. **Create the app:** `bash "$SKILL/scripts/new_app.sh" <board-id> <app-name> [<workspace>] [template]`
   - clones the pinned template app, Project Creator with the base BSP (auto-detects the BSP
     folder), optional pinned BSP replacement (`BSP_SOURCE=git:...`), checks BSP version and the
     **base `design.modus` sha256**, applies overlays (hash-checked), regenerates
     `GeneratedSource/`, copies the code template, adds and verifies `-DBOARD_<ID>`.
   - **Gate:** ends with `Created ...`. Read library versions later in `build/manifest.txt`
     (library drift, reference/project.md).
   - **From a ModusToolbox code example:** `new_app.sh <board-id> <app> [<workspace>] --example <id>`
     (ids from `examples.sh`, prefix `mtb-example-psoc-edge-` optional). Pinned to the example's
     newest release for that BSP (`--example-commit <tag>` to choose); overlays/regeneration/board
     define as usual, but the example's code is kept - no layered template. Before flashing, read
     the example README's hardware needs (radio, display, buttons, phone app...) and compare with
     `boards/<id>/README.md`; write `tests/<app>.json` from the README's expected UART output.
   - Never hand-edit `GeneratedSource/`; edit `design.modus` and regenerate with
     `device-configurator-cli --build <design.modus>` (no `--library`).
- **Open in the IDE (stage 2d, automatic):** at the end, `new_app.sh` runs
  `bash "$SKILL/scripts/open_ide.sh" <app>` (`--no-open`: no window; `--refresh` re-runs it after
  a library/BSP change or on another PC). It runs ModusToolbox's own `make vscode` (`.vscode/` +
  `<app>.code-workspace` for proj_cm33_s / proj_cm33_ns / proj_cm55 - this PC's tool paths, so
  git-ignored) and opens the workspace in VS Code + Infineon ModusToolbox for VS Code. The
  developer can then build (Build task = the same Makefiles and `build/` as build.sh), program,
  debug per core (Launch/Attach configurations) and use the Device Configurator from the IDE.
  `make vscode` (tools 3.9) writes tasks/settings in an older format than extension 1.12 expects;
  `scripts/vscode_fix.py` applies the extension's own "Fix Tasks" / "Fix Settings" rules right after
  it (CY_TOOLS_PATHS in every task, TOOLCHAIN=GCC_ARM CONFIG=Debug, Build & Program / Quick Program
  and per-core tasks, absolute openocdPath, gccPath, clangd instead of cpptools IntelliSense), so
  the Assistant does not ask. A newer extension that still asks: accept its fix.
  **Gate:** `IDE: READY <workspace>` + `IDE: OPENED`; exit 10 `ACTION: SETUP` = VS Code or the
  extension is missing (new_app.sh only reports it). See docs/workflow.md "IDE handoff".

## Stage 3 - Code in layers

Read `reference/layering.md` before writing code. Rules:
- `proj_cm33_ns/board/` - **only** place for `CYBSP_*` aliases, `Cy_*` pin/SCB calls and
  `#if defined(BOARD_xxx)` (e.g. `BOARD_NUM_BUTTONS` when the BSP declares unpopulated I/O).
- `proj_cm33_ns/func/` - reusable services (led, button, console, sensors...). Use `board.h` only.
- `main.c` - wiring + application logic. Uses `func/` (and `board_init`) only.
- Keep `proj_cm33_s` (secure) untouched. Keep the console protocol stable: `OK ...`, `ERR ...`,
  `EVT ...`, `<TAG> k=v ...`, `INFO ... board=<id> leds=N btns=M` then `READY` - tests depend on it.
- Write/extend `tests/<app>.json` from the task requirements before the code; gate board-
  dependent steps with `requires_re` (spec keys: `scripts/serial_test.py` docstring).
- Templates: `<repo>/lib/func` (shared logic layer, copied into every app's `proj_cm33_ns/func`) +
  `templates/_common/` (`board/` layer) +
  one app template on top: `uart-btn-led` (console + LED commands + buttons), `button-led`
  (hold a button → its LED lights; reports silkscreen name + pin; `pins?` shows pin config).
  Board extras not in the BSP (QWA309 buttons) are configured at run time in `board.c`.
- `hello-world` (1 s print), `dual-core-ipc` (CM33 console + CM55 worker over a shared-memory
  mailbox: `ipc?`, `ping <n>`, `led55 <1|2> on|off`; template `shared/` is copied to `<app>/shared`
  and `INCLUDES+=../shared` added to both cores). `help.sh` lists templates from `description.txt`.
- Multi-core work (CM55 owns a peripheral, IPC mailbox): reference/layering.md "Dual-core".

**Check the layers (M2 - gated like M3, stops with `ACTION: SETUP` until enabled):**
`python <repo>/lib/check_layers.py <app-dir>` → `LAYERS: PASS` (exit 2 = warnings to fix), and
`bash <repo>/lib/host_test.sh <app-dir>` → `HOST: PASS` (the app's `func/` unit-tested on the PC
against a fake board, no hardware). Fix a violation in the layer the message names.

## Stage 4 - Build

```bash
bash "$SKILL/scripts/build.sh" <app-dir> [--clean] [--getlibs] [--allow-warnings]
```
Runs `make build -j8` in modus-shell with the pinned tools dir (getlibs automatically if
`mtb_shared` is missing), logs to `<app>/logs/`.
**Gate:** `BUILD: PASS` = make exit 0, fresh `app_combined.hex`, secure image signed, 0 warnings.
Exit 2 = warnings (fix them). `build/manifest.txt` (tools, exact libraries, sha256 of every
artifact) is written **only on PASS** - flash.sh requires it.

## Stage 5 - Flash

**First flash on a board with firmware worth keeping (factory demo):** back it up first -
`bash "$SKILL/scripts/backup.sh" <board-id>` reads the SMIF app area (default 0x60000000 + 12 MB)
through the flash bank into `$PSE84_BACKUP_DIR` (.bin/.hex/.sha256; clean.sh keeps it). Restore with
`flash.sh <app> --yes --hex <backup>.hex`.

**Ask the user before every flash** (board, app, hex sha256 prefix). Then:
```bash
bash "$SKILL/scripts/flash.sh" <app-dir> --yes [--hex <known-good.hex>]
```
`FLASH_POLICY=auto` in this board's bench file replaces `--yes` for a dedicated lab board - only
the developer writes it, never you. discover, flash and test hold a per-board lock: `board '<id>'
is in use` means another run has the board - wait; delete the lock only after the user confirms
that run is gone.
Gates inside: app made for this board → hex matches the PASS manifest → read-only identity →
acquire-only attach (resets, writes nothing) with **device + life cycle check** → program,
verify, reset. Never flash a single-core hex; boot order is S-M33 → NS-M33 → M55.
**Gate:** `FLASH: PASS` (`verified N bytes`). Exit 10 after PASS = `ACTION: POWER_CYCLE`: ask the
user to unplug/replug USB, wait for their OK, then test with `--wait-port 60`.

## Stage 6 - Test (after flashing)

```bash
python "$SKILL/scripts/serial_test.py" auto <app>/tests/<spec>.json <app>/logs/test-<ts>.log --board <id> [--interactive | --only-interactive] [--wait-port 60]
```
`auto` = this board's COM port (bench file). Default `--sync` mode sends `info` every second
until `READY` (handles boot time and replugs), checks the running image reports `board=<id>`,
then runs the steps. `--wait-boot` instead listens from before flashing (to capture the banner).
Interactive steps (press a button, look at an LED) run only with `--interactive` /
`--only-interactive`: first tell the user exactly what to do (prompts use `BTN_LABELS`), then run.
**Gate:** `RESULT: PASS`. A human-observed result is a separate level - ask and record it.

## Stage 7 - Clean (reset the apps workspace)

```bash
bash "$SKILL/scripts/clean.sh" [--apps] [<workspace>]          # dry run: lists what would go
bash "$SKILL/scripts/clean.sh" [--apps] [<workspace>] --yes    # delete (ask the user first)
```
- default: **build outputs only** - `<app>/build`, `proj_*/build`, `proj_*/libs`, `mtb_shared`,
  `.cache`. App sources, tests, logs and `.bench` are kept (rebuild with `build.sh <app> --getlibs`).
- `--apps`: also deletes **whole apps** created by `new_app.sh` (folders with `pse84-app.env`) -
  the user's source code - and `.bench`. Use only when the user explicitly asks to remove apps;
  name the apps in your question. Published apps (`APP_PUBLISHED=1`) still lose only build outputs.
  The skill, `boards/` and files without `pse84-app.env` are never touched.
- Retries locked files (Dropbox/OneDrive/antivirus); `CLEAN: INCOMPLETE` (exit 1) lists what is
  still locked - pause sync and re-run. Seen on Dropbox 2026-10-03; the second run completed.
- Show the dry-run list and get the user's OK before `--yes`; suggest saving logs/code first.
  Board facts belong in `boards/<id>/README.md` / `boards/<id>/modus-pdl-edgitalk/README.md` (kept).

## Several boards on one PC

Every board needs its own bench entry: `discover.sh <board-id> --serial <probe>` (with more than
one probe connected, discover refuses to guess). All E84 boards report the same MPN, so the
identity check cannot tell an Edgi-Talk from an AI Kit: the probe serial is the only link. One
serial may be registered to only one board id (`kit-pse84-ai` and `tesaiot` are the same AI Kit -
pick one). Flash/test then pick the right probe/COM port by board id; `flash.sh` refuses an app
made for another board. Verified 2026-10-03: Edgi-Talk + TESAIoT connected together, hello-world
built, flashed and tested PASS on both from a fresh workspace.

## Sharing (committing to the repo)

Everything PC- or board-specific lives under the workspace `apps/` (`mtb_shared`, `.cache`,
`.bench` = probe serials and COM ports, `<app>/build`, `<app>/logs`) or `backup/` next to it
(flash dumps of *your* boards) - all git-ignored. The skill and `boards/` hold no user names,
absolute paths, serials or COM ports; tools are located at run time (`env.sh`), and the receiver
runs Stage 1 + discover.

To publish an app as a sample: build PASS (and ideally test PASS) first, add `APP_PUBLISHED=1` to
its `pse84-app.env`, delete `.mtbqueryapi` files (they hold local paths), and commit sources,
`bsps/` (incl. `GeneratedSource/`), `tests/` and `pse84-app.env` - never `build/`, `libs/`, `logs/`.

## Extending the skill

- **New board:** copy `boards/_template/` to `boards/<id>/`, fill `README.md` and
  `modus-pdl-edgitalk/board.env`, and add the `BOARD_<ID>` block - name, button/LED names, extras - to
  `templates/_common/proj_cm33_ns/board/board.h` and `board.c`. A board built on another one:
  `BOARD_EXTENDS=<parent>` and only the differences.
  - **User's own board (skill installed as a plugin):** put the profile in the *project*,
    `<project>/boards/<id>/modus-pdl-edgitalk/board.env` - the plugin folder is replaced on update.
    After `new_app.sh`, add the `BOARD_<ID>` block to the **app's** `proj_cm33_ns/board/board.h`
    (until then the image reports `board=generic-pse84` and the test's board check fails).
    Offer to contribute the board to the repo when it is verified.
- **New app template:** `templates/<name>/proj_cm33_ns/main.c` (+ more files if needed) and
  `templates/<name>/tests/<name>.json`. `templates/_common/` (board + func layers) is copied first,
  so a template contains only the application layer. Names starting with `_` are not templates.
- **New service:** add `func/<svc>.c/.h` to `<repo>/lib/func` when reusable (it must include only
  `board.h`; it is shared with other skills), else to the app template.
- Keep scripts and `.env` files LF; keep everything PC-specific out of the skill (bench files,
  COM ports, serials, user paths) - it must stay copyable.
- Dual-core CM33↔CM55 mailbox: template `dual-core-ipc`, rules in reference/layering.md
  "Dual-core", tested sample `apps/led-cm33-uart-cm55`.

## Reporting (always)

Report verification level precisely and separately: **source matches → built → flashed →
booted (READY seen) → tested (PASS n/m) → observed by a human**. Never claim a later level
without a log line proving it. Quote hex sha256, tool/library versions, log paths. Add a dated
line to `boards/<id>/modus-pdl-edgitalk/README.md` (verification log) when a board-level fact is newly
verified; hardware facts (pins, parts) go to `boards/<id>/README.md`.

## Safety rules

- Identity + life-cycle gates before every flash; never flash a board whose serial/device/life
  cycle don't match. Never change life cycle, provision, or write OTP/eFuse.
- Never flash an image built for another board profile or a hex without a PASS manifest
  (except an explicit `--hex` recovery image the user chose).
- Ask before erase/program and before `clean.sh --yes`.
- Don't run vendor installers, driver updates or KitProg3 firmware/mode changes (fw-loader)
  without asking. EPC4 parts or unknown life cycles: stop and ask.
