# Workflow contract for every skill

Every skill in `skills/` drives one dev tool for one MCU family (`<devtool>-<mcu>`, hyphens only).
All skills follow the same milestones, stage numbers, script names, gate lines and exit codes, so
an agent (or a developer) can drive any board the same way and a port to another MCU/toolchain is
proven by the **same tests**.

Reference implementations:

| Skill | Toolchain | Board | Notes |
| --- | --- | --- | --- |
| [modus-psoc-e84](../skills/modus-psoc-e84/SKILL.md) | ModusToolbox, make, OpenOCD | Edgi-Talk, TESAIoT | vendor IDE toolchain, external probe |
| [cubemx-stm32c5](../skills/cubemx-stm32c5/SKILL.md) | STM32CubeMX2 CLI, CMake, STM32CubeProgrammer | NUCLEO-C562RE | code generator, on-board ST-LINK |
| [pio-rpi-pico-2w](../skills/pio-rpi-pico-2w/SKILL.md) | PlatformIO, picotool | Pico 2 W | native USB, no probe |

## Milestones and stages

| Milestone | # | Stage | Script (same name in every skill) | Gate | Board |
| --- | --- | --- | --- | --- | --- |
| **M1 skeleton** - build a correct project automatically | 0 | help | `help.sh [--en]` | - | no |
| | 1 | setup | `check_tools.sh <board>` | `missing/bad=0` | no |
| | 2 | create | `new_app.sh <board> <app> [ws] [template]` (+ `regen.sh` for generator tools) | `Created ...` / `REGEN: PASS` | no |
| | 3 | build | `build.sh <app>` | `BUILD: PASS` + manifest | no |
| **M2 layering** - BSP/drivers > logic > execution | 4 | layer check | `check_layers.py` *(planned)* | `LAYERS: PASS` | no |
| | 5 | host test | `host_test.sh` *(planned)*: `lib/func` with a fake `board.h` on the PC | `HOST: PASS` | no |
| **M3 hardware** - test and debug on the real board, with the HW/tools available | 6 | connect | `discover.sh <board>` | `IDENTITY: PASS` | yes |
| | 7 | flash | `flash.sh <app> --yes` | `FLASH: PASS` | yes |
| | 8 | test | `serial_test.py auto <spec> <log> --board <b> [--interactive]` | `RESULT: PASS` | yes |
| | 9 | debug | `debug.sh` *(planned)*: GDB server, attach, fault registers, backtrace | `DEBUG: ...` | yes + probe |
| **M4 porting** - other vendors, toolchains, OS | 10 | port | `port.sh <app> --to <skill>:<board> [--os ...]` *(planned)* | target passes M1-M3 with the **same** `tests/*.json` | target |
| all | 11 | clean | `clean.sh [--apps] [--yes]` | `CLEAN: done` | no |

Stage 6 (connect) may run before stage 2 - it only needs the board, not an app.

**Release scope:** `<repo>/milestones.env` (`ACTIVE_MILESTONES`, override `FW_ACTIVE_MILESTONES`)
lists the milestones a release activates. Scripts of an inactive milestone call
`require_milestone` (lib/common.sh) and stop with `ACTION: SETUP` (exit 10). Enabling a milestone
is the developer's decision, never the agent's.

## Exit codes and developer actions

| Exit | Meaning | Agent does |
| --- | --- | --- |
| 0 | gate passed | next stage |
| 1 | failed | read the log, fix, re-run (never skip the gate) |
| 2 | passed with warnings (build) | fix the warnings in `src/`/`board`/`func`/`main` |
| **10** | **developer action needed** - the script printed `ACTION: <TYPE> <what to do>` | relay the action word for word, wait for the developer's OK, re-run the same command |

`ACTION` types (helper `need_user` in `lib/common.sh`):

| Type | Meaning | Examples |
| --- | --- | --- |
| `SETUP` | install or change the developer's system | ModusToolbox Setup (Infineon account, admin), STM32CubeMX2 / STM32Cube for VS Code bundles and packs (licence acceptance), PlatformIO, drivers (WinUSB/Zadig), `git core.longpaths`, moving a workspace off an unsafe path |
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

## Architecture (M2): BSP/drivers > logic > execution

```
execution   main / app_main / tasks   superloop today; FreeRTOS / Zephyr / RT-Thread tasks (M4)
logic       func/   (lib/func)        portable C services: console, led, button ... board.h only
board       board/  (board.h API)     the port boundary: one API, one implementation per board
BSP/driver  generated / vendor        ModusToolbox BSP, CubeMX mx/, arduino-pico core (never edit)
```

- `lib/func` is shared unchanged by modus-psoc-e84 and cubemx-stm32c5 (pio-rpi-pico-2w: C++ copy,
  to be merged). It may include only `board.h` and the C library.
- `board.h` is the same API on every board: init, millis/delay, LEDs (write/read/name), buttons
  (read/name/pin), console getc/flush, printf to the console.
- Services expose init/poll functions; the execution layer decides how they run (a superloop calls
  `*_poll()`, an RTOS wraps them in tasks) - this is what makes M4 OS ports mechanical.
- Console protocol (test contract): `READY`, `INFO app=.. v=.. board=<id> ...`, `OK ...`,
  `ERR <reason>`, `EVT ...`, `<TAG> k=v ...`.

## Hardware-dependent testing (M3)

- **Board type vs bench instance:** what is the same for every copy of a board is in `boards/`;
  what differs per PC or physical board (probe serial, COM port) is in `<ws>/.bench/<id>.env`,
  written by `discover.sh`. Never commit bench data, user paths or serials.
- Tests skip what the board lacks (`requires_re` on the INFO line) and what needs a human
  (`interactive`); planned: `requires_bench` for bench capabilities (debug probe, loopback wires,
  attached sensors) so a missing tool is reported as *skipped*, not *failed*.
- Report verification levels separately: source → generated → built → flashed → booted (READY) →
  tested (PASS n/m) → observed by a human. Add a dated line to `boards/<id>/<skill>/README.md`.

## Repository layout

```
skills/<skill>/SKILL.md, scripts/, reference/, templates/   one skill per toolchain + MCU family
lib/common.sh, lib/fwtest.py, lib/func/                      shared by all skills
boards/<id>/README.md                                        board hardware, tool-independent
boards/<id>/<skill>/                                         that skill's board profile + log
apps/<app>/                                                  generated projects
apps/.bench/<id>.env                                         per-PC instance data (git-ignored)
```

## Adding a skill (a new toolchain or MCU family)

1. `skills/<devtool>-<mcu>/SKILL.md` mapping the stage table above to the tool's commands.
2. `scripts/env.sh` sourcing `lib/common.sh`; one script per stage with the gate lines and exit
   codes above; `serial_test.py` as a thin wrapper of `lib/fwtest.py`.
3. A `board.h` implementation per board under `templates/_common`, reusing `lib/func`.
4. For each board: `boards/<id>/<skill>/` profile + verification log (`boards/_template/`).
5. hello-world and uart-btn-led templates with the shared test specs; run M1 and M3 on hardware.
6. Add the skill to the tables in the top-level `README.md`.
