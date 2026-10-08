# Workflow contract for every skill

Every skill in `skills/` drives one toolchain with one framework for one board, named
**`<toolchain>-<framework>-<board>`** (lowercase, hyphens only between the three parts), e.g.
`cubemx-hal-stm32f407disco`, `cubemx2-hal2-stm32c562nucleo`, `pio-espidf-esp32s3box`,
`modus-pdl-edgitalk`. Related boards of the same MCU may share a skill as extra board profiles
(`boards/<id>/<skill>/`), e.g. KIT_PSE84_AI and TESAIoT under `modus-pdl-edgitalk`.
All skills follow the same milestones, stage numbers, script names, gate lines and exit codes, so
an agent (or a developer) can drive any board the same way and a port to another MCU/toolchain is
proven by the **same tests**. These board skills are the M1 outcome; skills of the later milestones
(board drivers, execution models, components, profiling) build on them through the `board.h` API.

Reference implementations:

| Skill | Toolchain | Board | Notes |
| --- | --- | --- | --- |
| [modus-pdl-edgitalk](../skills/modus-pdl-edgitalk/SKILL.md) | ModusToolbox, make, OpenOCD | Edgi-Talk, TESAIoT | vendor IDE toolchain, external probe |
| [cubemx2-hal2-stm32c562nucleo](../skills/cubemx2-hal2-stm32c562nucleo/SKILL.md) | STM32CubeMX2 CLI, CMake, STM32CubeProgrammer | NUCLEO-C562RE | code generator, on-board ST-LINK |
| [pio-arduino-rpipico2w](../skills/pio-arduino-rpipico2w/SKILL.md) | PlatformIO, picotool | Pico 2 W | native USB, no probe |
| [pio-espidf-esp32s3box](../skills/pio-espidf-esp32s3box/SKILL.md) | PlatformIO + ESP-IDF, esptool | ESP32-S3-BOX | USB Serial/JTAG, no probe; shares `lib/func` |
| [cubemx-hal-stm32n6570dk](../skills/cubemx-hal-stm32n6570dk/SKILL.md) | STM32CubeMX 6.18 (headless), STM32CubeN6 HAL, CMake | STM32N6570-DK | M1 build stages only; FSBL in internal SRAM; shares `lib/func` |
| [cubemx-hal-stm32f407disco](../skills/cubemx-hal-stm32f407disco/SKILL.md) | STM32CubeMX 6.18 (headless), STM32CubeF4 HAL, CMake | STM32F407G-DISC1 | M1 build stages only; console SWO output (ST-LINK/V2, no VCP); shares `lib/func` |
| [cubemx-hal-stm32l475iot](../skills/cubemx-hal-stm32l475iot/SKILL.md) | STM32CubeMX 6.18 (headless), STM32CubeL4 HAL, CMake, STM32CubeProgrammer | B-L475E-IOT01A | M1 incl. board stages; ST-LINK/V2-1 VCP console (RX by interrupt: no USART FIFO); shares `lib/func` |
| [pio-arduino-esp32s3box](../skills/pio-arduino-esp32s3box/SKILL.md) | PlatformIO + Arduino, esptool | ESP32-S3-BOX | same board, Arduino style: `<Arduino.h>` API in every layer, own Arduino func/ |

## Milestones: bottom-up, one firmware layer at a time

The milestones follow how an embedded developer brings up firmware - bottom-up, each layer proven
**on the real board** before the next one is generated on top of it. The outcome of each milestone
is a **collection of skills + scripts** that can do that milestone's jobs on its own; each layer's
output (pin map, `board.h` API, component APIs) is the catalog the next layer's generation may use,
so an agent never calls APIs that were not built and tested first.

| Milestone | Builds | Outcome (skills + scripts) | Proven by (on the board) |
| --- | --- | --- | --- |
| **M1 bring-up** | toolchain, project, IDE, build, probe connection, flash, smoke test, debug attach | one skill per toolchain + framework + board (`<toolchain>-<framework>-<board>`) | smoke test PASS; debugger halts at `main` |
| **M2 board support** | BSP drivers behind the `board.h` API, from vendor board configs > netlist > schematic > the developer | board-driver skills + the layer checks | per-peripheral tests (loopback, `WHO_AM_I`, LED seen) + `LAYERS: PASS` |
| **M3 execution model** | bare-metal superloop, RTOS (FreeRTOS), RTOS + stack (Zephyr, RT-Thread) | execution skills + the trace tool | the same logic tests pass under each model; trace rules (order, latency, period, stack) PASS |
| **M4 components** | middleware on M2 + M3: LVGL, USB device classes, file system, network stack ... | one skill per component (adapter to `board.h` + the execution model) | component demo test |
| **M5 application + profiling** | application logic in `func/`, tested on the board with stub/driver inputs; time and memory per function (e.g. a digital filter) | profiling scripts | tests + budgets PASS (cycles, stack, RAM/flash) |

Order: M3 (execution model) comes before M4 (components) because middleware depends on it - LVGL
needs a tick and a lock, a network stack runs with or without an OS, USB needs ISR/task decisions.
For Zephyr / RT-Thread the M2 work is mostly devicetree / Kconfig instead of hand-written drivers,
so the execution model is recorded when the app is created even though it is proven in M3.

**Testing runs through every milestone, on the target.** Each milestone ends with a test on the real
board (`serial_test.py` + `tests/*.json`). Logic is validated on the board with stub or driver
inputs injected through the console, not by running the code on the PC; `host_test.sh` stays an
optional quick check. Timing is only *measured* on hardware (DWT cycle counter, `CCOUNT`, a timer);
memory can be read without it (map file, `-fstack-usage`) - report *estimated* vs *measured*.

**M3 trace (planned design).** Execution flow is checked from a binary event trace, not `printf`
(a UART line costs milliseconds and changes the scheduling it measures): `trace(id, arg)` writes
`{cycles, id, arg}` into a RAM ring buffer (`.noinit`, survives a reset) from ISRs, tasks and the
RTOS trace hooks; after the run the buffer is read over the console (`trace dump`) or by the
debugger (works after a fault), decoded with the event-id table shared by C and Python, and checked
against rules next to the tests - `follows A->B within_us`, `period`, `never`, `stack_free_min_pct`.
Each board supplies `board_cycles()`; the tracer reports its own overhead.

## Stages

Stage numbers are shared by all skills; a skill's SKILL.md maps them to its own sections.

| Milestone | # | Stage | Script (same name in every skill) | Gate | Board |
| --- | --- | --- | --- | --- | --- |
| **M1 bring-up** | 0 | help | `help.sh [--en]` | - | no |
| | 1 | setup | `check_tools.sh <board>` | `missing/bad=0` | no |
| | 2 | create | `new_app.sh <board> <app> [ws] [template]` (+ `regen.sh` for generator tools) | `Created ...` / `REGEN: PASS` | no |
| | 2d | open in IDE | `open_ide.sh <app> [--no-open]` (new_app.sh runs it) - see [IDE handoff](#ide-handoff-stage-2d) | `IDE: READY` | no |
| | 3 | build | `build.sh <app>` | `BUILD: PASS` + manifest | no |
| | 4 | connect | `discover.sh <board>` | `IDENTITY: PASS` | yes |
| | 5 | flash | `flash.sh <app> --yes` (**ask the developer first**) | `FLASH: PASS` | yes |
| | 6 | test | `serial_test.py auto <spec> <log> --board <b> [--interactive]` | `RESULT: PASS` | yes |
| | 7 | debug | `debug.sh` *(planned)*: GDB server, attach, halt at `main`, fault registers, backtrace | `DEBUG: ...` | yes + probe |
| **M2 board support** | 8 | board drivers | *(planned)*: pin/peripheral map from the board sources, `board.h` drivers, per-peripheral `tests/*.json` (run with stage 6) | `RESULT: PASS` per peripheral | yes |
| | 9 | layer check | `python lib/check_layers.py <app>` | `LAYERS: PASS` | no |
| | 10 | host test *(optional)* | `bash lib/host_test.sh [<app>]`: `func/` with a fake `board.h` on the PC | `HOST: PASS` | no |
| **M3 execution model** | 11 | execution + trace | *(planned)*: superloop / RTOS execution layer; trace ring buffer read over the console or the debugger, rules in `tests/*.json` | `TRACE: PASS` | yes |
| **M4 components** | 12 | components | *(planned)*: add a middleware component with its adapter and demo test | `RESULT: PASS` | yes |
| **M5 application + profiling** | 13 | profile | *(planned)*: cycles per function, stack high-water, RAM/flash from the map file, against budgets | `PROFILE: PASS` | yes |
| all | 14 | export | `export_app.sh <app>` *(planned)*: standalone AI-assisted project - see [three ways out](#three-ways-out-of-the-pipeline) | `EXPORT: PASS` | no |
| | 15 | port | `port.sh <app> --to <skill>:<board>` *(planned)* | target passes its milestones with the **same** `tests/*.json` | target |
| | 16 | clean | `clean.sh [--apps] [--yes]` | `CLEAN: done` | no |

Stage 4 (connect) may run before stage 2 - it only needs the board, not an app.

### Three ways out of the pipeline

AI generation is a starting point, never a lock-in. After any gate the developer may leave the
agent-driven path:

```
1 setup ─► 2 create ─┬─► A  IDE path (developer):  2d open_ide ─► edit, build, flash, debug in VS Code
check_tools  new_app │                             (the vendor extension's own buttons)
                     │        ▲ switch any time - same app folder, same build outputs ▼
                     ├─► B  script path (agent):   3 build ─► 4 connect ─► 5 flash ─► 6 test ─► 9 layers ...
                     │
                     └─► C  standalone project:    14 export_app ─► the app + the skills, scripts, board
                                                   profile and tests it uses, as a project of its own
```

- **A - IDE path.** `new_app.sh` ends with stage 2d and opens the app in VS Code, so the developer
  can code, build, flash and debug themselves right after creation or after any later gate.
- **B - script path.** The agent runs the stages behind their gates. A and B share one project:
  the IDE builds the same configuration into the same folder as `build.sh`, and code edited in the
  IDE goes through the same gates when the agent runs the scripts again (`build.sh`,
  `check_layers.py`, `flash.sh` with its identity check, `serial_test.py`).
- **C - standalone AI-assisted project** *(planned, stage 14)*. `export_app.sh` copies the app
  together with the skills, `lib/` scripts, board profile and tests it uses into a project of its
  own (`.claude/skills/`, `CLAUDE.md`, `tests/`), so an agent can keep developing it outside this
  repo - with the same gates, without the other boards and toolchains.
- **Agents follow the developer's choice.** On the IDE path the agent stops after stage 2d and
  only runs scripts when asked ("build it", "test it"); it never overwrites files the developer is
  editing. Asked to continue on the script path, it re-runs the gates from stage 3.

Worked example: [Edgi-Talk on the IDE path](walkthrough-edgi-talk-ide.md) (prompts, outputs, both paths).

**Release scope:** `<repo>/milestones.env` (`ACTIVE_MILESTONES`, override `FW_ACTIVE_MILESTONES`)
lists the milestones a release activates. Scripts of an inactive milestone call
`require_milestone` (lib/common.sh) and stop with `ACTION: SETUP` (exit 10). Enabling a milestone
is the developer's decision, never the agent's. M1 includes the board stages; flashing stays behind
its own approval: `flash.sh` needs `--yes`, which the agent passes only after the developer said yes
(see [Hardware-dependent testing](#hardware-dependent-testing)).

## IDE handoff (stage 2d)

Every skill must hand each app it creates over to the toolchain's IDE, so a developer can take over
at any point - edit the code, build, flash, debug and test by hand - and go back to the scripts
later. The IDE is **VS Code with the toolchain vendor's extension**:

| Toolchain | VS Code extension (`IDE_EXT` in env.sh) | Workspace file | Made by |
| --- | --- | --- | --- |
| ModusToolbox | Infineon ModusToolbox for VS Code (`infineonag.modustoolbox-for-vscode`) | `<app>.code-workspace` + `.vscode/` | ModusToolbox's own `make vscode` (this PC's tool paths: git-ignored, re-made per PC) |
| STM32CubeMX / STM32CubeMX2 | STM32CubeIDE for Visual Studio Code (`stmicroelectronics.stm32-vscode-extension`) | `<app>.code-workspace` (`mx/`, `src/`, `tests/` as folders) + `mx/.settings/*.store.json`, `mx/.vscode/{settings,launch}.json` | `lib/common.sh` `fw_vscode_cube_setup`, from the board profile's pinned bundles |
| PlatformIO | PlatformIO IDE (`platformio.platformio-ide`) | `<app>.code-workspace` (the app folder; `platformio.ini` at its root); PlatformIO IDE adds `.vscode/` | `lib/common.sh` `fw_code_workspace` |

Rules for `open_ide.sh <app> [--no-open]`:

1. **Same project, same outputs.** The IDE must build the same configuration into the same folder as
   `build.sh` (Makefiles + `build/`, CMake preset + `mx/build/<preset>`, PlatformIO env +
   `.pio/build/<env>`) with the same pinned tools - never a second copy of the project.
2. **Open the workspace file, never the app folder** (STM32Cube: CMake project at a workspace
   folder root; ModusToolbox: multi-project apps). IDE files (`<app>.code-workspace`, `.vscode/`)
   are generated - some hold this PC's tool paths - so they are git-ignored for every skill and
   `open_ide.sh` re-makes them on each PC; never put settings a build needs only there.
3. **Gate** `IDE: READY <workspace>` (then `IDE: OPENED`, or `IDE: not opened` with `--no-open`).
   VS Code or the extension missing = `ACTION: SETUP` (exit 10): installing them is the developer's.
   `new_app.sh` runs it at the end (`--no-open` for headless runs) and only reports a missing IDE.
4. Print where the IDE's build / flash / debug / monitor buttons are and how they map to the scripts.
   What a developer does in the IDE (e.g. flashing without the identity gate) is their call; an
   agent still flashes with `flash.sh` behind its gates.

## Exit codes and developer actions

| Exit | Meaning | Agent does |
| --- | --- | --- |
| 0 | gate passed | next stage |
| 1 | failed | read the log, fix, re-run (never skip the gate) |
| 2 | passed with warnings (build, layer check) | fix the warnings in `src/`/`board`/`func`/`main` |
| **10** | **developer action needed** - the script printed `ACTION: <TYPE> <what to do>` | relay the action word for word, wait for the developer's OK, re-run the same command |

`ACTION` types (helper `need_user` in `lib/common.sh`):

| Type | Meaning | Examples |
| --- | --- | --- |
| `SETUP` | install or change the developer's system | ModusToolbox Setup (Infineon account, admin), VS Code + the toolchain extension, STM32CubeMX2 / STM32Cube for VS Code bundles and packs (licence acceptance), PlatformIO, drivers (WinUSB/Zadig), `git core.longpaths`, moving a workspace off an unsafe path |
| `CONNECT` | plug something in / boot mode | board or probe USB, Pico BOOTSEL held at power-up |
| `POWER_CYCLE` | unplug + replug | TESAIoT display firmware after flashing |
| `JUMPER` | switches, solder bridges, accessories | QWA309 CS switch, unplug the DVP camera, Nucleo SB8 (LD1 vs D13) |
| `APPROVE` | irreversible or destructive step | flash (overwrites firmware), `clean.sh --apps`, backups |
| `CHOOSE` | the developer must pick | several boards connected (`--serial`) |
| `PRESS` / `OBSERVE` | inside interactive tests (`ACTION >>>` lines of `serial_test.py`) | press SW1/B1/BOOTSEL, look at an LED |

**Never** done by a skill, even when asked inside a script run (stop and hand over): change device
life cycle / read-out protection / option bytes / OTP / eFuses / secure boot, upgrade probe firmware
(KitProg3 fw-loader, STLinkUpgrade), run installers with admin rights.

Everything else - path checks, versions, packs, identity, generation, layering, build, flash and
verify, serial tests - runs automatically behind the gates.

## Architecture: BSP/drivers > logic > execution (M2-M5)

```
execution   main / app_main / tasks   superloop today; FreeRTOS / Zephyr / RT-Thread tasks (M3)
logic       func/   (lib/func)        portable C services: console, led, button ... board.h only
board       board/  (board.h API)     the port boundary: one API, one implementation per board
BSP/driver  generated / vendor        ModusToolbox BSP, CubeMX mx/, arduino-pico core (never edit)
```

- `lib/func` is shared unchanged by modus-pdl-edgitalk, cubemx2-hal2-stm32c562nucleo and pio-espidf-esp32s3box.
  Arduino skills (pio-arduino-rpipico2w, pio-arduino-esp32s3box) keep an Arduino-style C++ func/ in their
  templates (`<Arduino.h>`, Print/Stream, millis) - same console protocol and tests. It may include only `board.h` and the C library.
- `board.h` is the same API on every board: init, millis/delay, LEDs (write/read/name), buttons
  (read/name/pin), console getc/flush, printf to the console - the contract is
  [board-api.md](board-api.md).
- Checks: `check_layers.py` (includes, vendor calls, `#if BOARD_*` per layer) and the optional
  `host_test.sh` (the func services against `lib/host`'s fake board: console line editing and dispatch, LED
  numbering and read-back, button debounce and events). The host test needs a host C compiler
  (gcc, clang or Visual Studio C++ with the Windows SDK).
- Services expose init/poll functions; the execution layer decides how they run (a superloop calls
  `*_poll()`, an RTOS wraps them in tasks) - this is what makes the M3 execution models mechanical.
- Console protocol (test contract): `READY`, `INFO app=.. v=.. board=<id> ...`, `OK ...`,
  `ERR <reason>`, `EVT ...`, `<TAG> k=v ...`.

## Hardware-dependent testing

- **Board type vs bench instance:** what is the same for every copy of a board is in `boards/`;
  what differs per PC or physical board (probe serial, COM port) is in `<ws>/.bench/<id>.env`,
  written by `discover.sh`. Never commit bench data, user paths or serials.
- Tests skip what the board lacks (`requires_re` on the INFO line) and what needs a human
  (`interactive`); planned: `requires_bench` for bench capabilities (debug probe, loopback wires,
  attached sensors) so a missing tool is reported as *skipped*, not *failed*.
- **One run per board:** discover, flash, test (and backup / identity check) take a lock
  `<ws>/.bench/<id>.lock/` (owner: host, pid, tool, time) for their whole run; a second session gets
  `board '<id>' is in use` (exit 1: wait, re-run). Scripts called by a lock holder inherit it; a lock
  whose process is gone, or that arrived from another PC through a synced folder, is replaced.
- **Flash approval:** `flash.sh` needs `--yes` (the agent asked the developer) unless the
  developer wrote `FLASH_POLICY=auto` into `<ws>/.bench/<id>.env` for a dedicated lab board
  (default `ask`; discover.sh keeps the line when it rewrites the file). Only the file counts - an
  environment variable cannot switch approval off - and an agent never writes it.
- Report verification levels separately: source → generated → built → flashed → booted (READY) →
  tested (PASS n/m) → observed by a human. Add a dated line to `boards/<id>/<skill>/README.md`.

## Repository layout

```
skills/<skill>/SKILL.md, scripts/, reference/, templates/   one skill per toolchain + MCU family
lib/common.sh, lib/fwtest.py, lib/func/                      shared by all skills
boards/<id>/README.md                                        board hardware, tool-independent
boards/<id>/<skill>/                                         that skill's board profile + log
boards/index.json                                            board ids, aliases, MCU, evidence level per profile
lib/host/, host_test.sh, check_layers.py                     M2 checks: layer rules, optional fake-board unit tests
tools/validate_skills.py                                     repo validator (run before every commit)
apps/<app>/                                                  generated projects
apps/.bench/<id>.env                                         per-PC instance data (git-ignored)
```

## Adding a skill (a new toolchain or MCU family)

1. `skills/<toolchain>-<framework>-<board>/SKILL.md` mapping the stage table above to the tool's commands.
2. `scripts/env.sh` sourcing `lib/common.sh`; one script per stage with the gate lines and exit
   codes above; `serial_test.py` as a thin wrapper of `lib/fwtest.py`.
   `open_ide.sh` (stage 2d) hands apps to VS Code + the toolchain's extension (`IDE_EXT`).
3. A `board.h` implementation per board under `templates/_common`, reusing `lib/func`.
4. For each board: `boards/<id>/<skill>/` profile + verification log (`boards/_template/`).
5. hello-world and uart-btn-led templates with the shared test specs; run all M1 stages on hardware.
6. Add the skill to the tables in the top-level `README.md` and its boards to `boards/index.json`.
7. `python tools/validate_skills.py` until `VALIDATE: PASS`.
