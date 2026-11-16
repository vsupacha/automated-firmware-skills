# Audit before the refactor: workflow, tools, guideline clarity (2026-11-15)

Scope: the four firmware repositories under `Firmware_skills` (bare metal = this repo, `-freertos`,
`-rtthread`, `-emblinux`). Audit only: nothing in the four repositories was changed. The CAN test
framework part of the same request is recorded in `CANbus_test_framework/HANDOFF.md`.

Target reader of the guidelines: an agent running Opus 5.5 at low or medium effort.

## Method

1. Static tables of scripts, templates and support skills per skill (shell listing).
2. One clean-room run per repository on the home PC: an Opus subagent that starts from `README.md`,
   may not read `CLAUDE.local.md` / handoff files, creates an app, builds it and stops before any
   board stage. No flash, no board touched.
3. The findings below were re-checked against the files (grep) unless marked "reported only".

## Result of the clean-room builds

| Repository | Board / skill | Effort | Gates reached | From the docs alone |
|---|---|---|---|---|
| bare metal | NUCLEO-C562RE, `cubemx2-hal2-stm32c562nucleo`, push-to-light | medium | tools 0 bad, `REGEN: PASS` (78 s), `BUILD: PASS` 0 warnings | yes |
| FreeRTOS | STM32L476G-DISCO, `cubemx-freertos-stm32l476disco`, blink-rate | medium | tools 0 bad, `REGEN: PASS` (38 s), `BUILD: PASS` 0 warnings | yes |
| RT-Thread | Vision Board, `scons-rtthread-visionboard`, blink | low | tools 0 bad (1 warning: no probe), created (72 s), `BUILD: PASS` 0 warnings | yes |
| EmbLinux | UNO Q, `applab-zephyr-unoq`, blink | medium | tools 0 bad, `CREATE` / `REQ` / `ARCH` / `CODE: PASS`; build stopped with `ACTION: CONNECT` (exit 10) as intended | yes (gen + checks) |

No agent had to read script source to continue. All tools were present on this PC.
Not covered: flash and test (by choice), the first-time `ACTION: CHOOSE` workspace question (the
workspace was already set on this PC), a low-effort run for three of the four repositories.

Test apps left in `C:/fw-ws`: `cr-c5`, `cr-rl4`, `cr-vb` (also imported into `C:/fw-ws/.rtstudio`), `cr-q`.

## Main objective: gen > build > flash > test is the main path

The flow works, but the documents do not present it as one short path. Gaps, most harmful first:

| # | Gap | Where (checked) | Risk for a low/medium-effort agent |
|---|---|---|---|
| A1 | Two stage numberings in one SKILL.md: the diagram says `1 tools > 2 discover + project > 3 code > 4 build > 5 flash > 6 test > 7 clean`; the headings say Stage 3 Build, Stage 7 Debug, Stage 16 Clean | bare metal C5 `SKILL.md:10,15,179,250`; same pattern in the FreeRTOS L476 `SKILL.md` | Runs discover (touches the board) before create, or looks for a "stage 4 build" script |
| A2 | The apps workspace is described two ways: "`<repo>/apps` inside the repo checkout" vs the per-PC `~/.fw-skills.env` | C5 `SKILL.md:72`; FreeRTOS L476 `SKILL.md:78`; board sheet command tables use `apps/<app>` (FreeRTOS `boards/stm32l476g-disco/README.md:44-46`) | Copies `apps/<app>` from the table; the real path is `C:/fw-ws/<app>` |
| A3 | `new_app.sh <board> <app> [<workspace>] [template]`: choosing a template needs an empty `""` third argument; only one README example shows it; `--no-open` is not in the synopsis | C5, L476, Vision Board SKILL.md | Template name taken as the workspace path |
| A4 | EmbLinux: build needs `discover.py` first, the docs say build "asks before creating the app on the board"; `build.py` printed only `ACTION: CONNECT`, no gate line although workflow.md says every stage prints one | emblinux `README.md`, `docs/workflow.md:8` (reported; README mentions discover only in Quick start) | Reports "build failed" or retries |
| A5 | EmbLinux tables show `--yes` inside the command (`run.py <app> --yes`, `clean.py <app> --yes`) | emblinux skill `README.md:13,16` | Passes `--yes` without asking the owner |
| A6 | Wrong or stale statements: RT-Thread `open_ide.sh:50` says GCC 10.2.1 (build uses 13.3); Vision Board `SKILL.md:152` says create takes about 15 s (real 72 s with the headless Studio import); FreeRTOS root README says new_app uses CubeMX2 for all skills | checked | Decides the toolchain is wrong; kills new_app on a short timeout |
| A7 | Copied documents point at things that are not in the repository: FreeRTOS `docs/workflow.md:62,246,264-266` (unit_test.sh, Pico/ESP/WB55, firmware-test), `:172` web-wizard; RT-Thread `docs/workflow.md:172,343` (web-wizard, sensor-debug); FreeRTOS skill `README.md:37-38` installs the bare-metal marketplace | checked | Looks for scripts and skills that do not exist; installs the wrong plugin |
| A8 | Script path style differs: EmbLinux skill README says "from this folder" but lists some scripts without `python scripts/`; its SKILL.md table has no path at all; root README runs from the repo root | reported only | Wrong working directory |
| A9 | Board id is not on the first page (RT-Thread README has no first commands and no `vision-board` id) | reported only | Guesses the board id |

Suggested fix shape (for the owner's decision, not done): one short "Main path" block at the top of
every SKILL.md with exactly four command lines (create, build, flash, test), the real workspace
variable, one numbering only, and everything else (IDE handoff, debug, unit tests, recipes,
update_tools) under "Optional".

## Tools: completeness per skill

Required stage scripts: check_tools, new_app, build, discover, flash, serial test, clean, help.
`-` = present. Brackets = optional stage.

| Repository | Skill | Missing required | Missing optional |
|---|---|---|---|
| bare metal | cubemx-hal-stm32n6570dk | discover, flash, serial_test | debug, unit_test |
| bare metal | cubemx-hal-stm32f407disco, cubemx-hal-stm32f303disco | serial_test (console is SWO, no reader yet) | debug, unit_test |
| bare metal | cubemx-hal-stm32l475iot, -l476disco, cubemx2-hal2-stm32c562nucleo | - | unit_test |
| bare metal | cubemx-hal-stm32wb55nucleo, pio-arduino-rpipico2w, -esp32s3box, -cucumber | - | debug |
| bare metal | mcux-sdk-frdmmcxn947, modus-pdl-edgitalk, pio-arduino-unor4wifi, pio-espidf-esp32s3box | - | debug, unit_test |
| FreeRTOS | cubemx-freertos-stm32f303disco | serial_test (SWO) | debug, unit_test |
| FreeRTOS | cubemx-freertos-stm32l476disco, cubemx2-freertos-stm32c562nucleo | - | unit_test |
| RT-Thread | scons-rtthread-visionboard, -titanboard, -edgitalk | - | debug (Studio only) |
| EmbLinux | applab-zephyr-unoq | help (no help script); validator not mentioned in README | debug, unit test, update_tools |

Other tool notes: C5 `help.sh` does not list `debug.sh` (the word appears only as "debug yourself in
VS Code"); a stray `scripts/__pycache__` in three skills; EmbLinux `lib/fw_workspace.sh` is
bash-only while its README lists only Python and adb.

## Minor objective: basic components

### Peripheral drivers in the board layer

| Component | Bare metal | FreeRTOS | RT-Thread | EmbLinux (UNO Q) |
|---|---|---|---|---|
| LED / GPIO | yes | yes | yes | yes (MCU LED by RPC, Linux LED) |
| Button | yes, raw (not debounced) | yes, raw | yes (Vision KEY0 level marked "assumed") | no button on the board; virtual press over REST |
| UART console | yes (C5 polled, L4/WB55 interrupt + ring buffer) | yes (interrupt, per-task lines, mutex) | yes (msh) | logs + MCU monitor channel |
| Tick / delay | yes (HAL tick) | yes (TIM6 tick, vTaskDelay) | yes (kernel) | n/a |
| Timer / PWM API | **no** | **no** | PWM recipes only; no general timer recipe | n/a |
| CAN | **no** (no template, no board API, no MX config, although C5 / F4 / L4 have CAN) | **no** | Titan Board `can.json` recipe only | n/a |
| I2C / SPI | Cucumber sensors only | no | recipes | Bricks |
| RTOS pieces | n/a | tasks, notifications, console mutex, `tasks` status; **no queue example** | threads, msh | services, RPC, REST |

The missing CAN driver matters for the CAN test framework: its DUT firmware (`demo_firmware`,
NUCLEO-C562RE, FDCAN1) lives in the workshop project, and the C5 skill gives no CAN starting point.

### Support tool skills per repository

| Skill | Bare metal | FreeRTOS | RT-Thread | EmbLinux |
|---|---|---|---|---|
| firmware-test | yes | no (referenced by link) | yes | no |
| cleanroom-test | yes | yes | no | no |
| hw-troubleshooting | yes | no | no | no |
| sensor-debug | yes | no (referenced) | no (referenced) | no |
| web-wizard | yes | no (referenced by link) | no (referenced by link) | no |

No repository other than bare metal says what to use instead of a missing support skill.

## Not verified in this audit

- Flash and test stages, any board.
- Guideline behavior at low effort for bare metal, FreeRTOS and EmbLinux (run at medium).
- Rows marked "reported only".
- PlatformIO, ModusToolbox, MCUXpresso, classic-CubeMX bare-metal skills (one board per repository).

## Applied after the audit (2026-11-15, owner's yes)

A1-A3 in the board SKILL.md files of the bare-metal (13 of 14; the MCX skill already had them), FreeRTOS
(3) and RT-Thread (3) repositories: one stage numbering in the diagram (shared numbers, discover = stage 4
connect, with a note that it is not needed before create or build), the per-PC workspace wording, and the
`new_app.sh` synopsis with `[<workspace>|""]`, `[--no-open]` and one example line. Validators: PASS with
the same warnings as before (7 / 1 / 2). Not changed: board sheet command tables that still say
`apps/<app>`, skill README guides, the EmbLinux repository (its gaps are A4, A5, A8).

EmbLinux A4, A5, A8 (same day, owner's yes): `--yes` removed from the command tables of the skill README and
SKILL.md (commands are shown without it; the rule "run without, add `--yes` only after a yes" is stated
once); discover is marked as needed once per PC before build / run / test; workflow.md says an `ACTION:`
line replaces the gate line when a stage did not run; the `ACTION: CONNECT` text now says what to do; one
script-path rule (short names in tables = `python <skill folder>/scripts/<name>`), Git Bash listed in the
requirements. Validator PASS (75 checks). Checked without a board: build / run / clean stop with the new
`ACTION: CONNECT` text, exit 10. Not checked: the `ACTION: APPROVE` stops with a board attached.

## Applied 2026-11-16 (owner: revise all skills and docs)

Main path block at the top of every board SKILL.md in the four repositories; `help.sh` shows `flash.sh <app>
[--yes]` and lists `debug.sh`; board sheets say `<app folder>`; A6 (GCC text, create time, CubeMX2 wording), A7
(FreeRTOS guides install their own plugin, workflow.md says what is not in the repository) and A9 (RT-Thread
README quick start with board ids) fixed; every README names the related repositories and where the support tool
skills are. Still open: decision 2 (CAN, timer drivers) and 5 (test apps); the missing stage scripts in the tools
table. No clean-room run was repeated after these edits.

## Decisions for the owner

1. A1-A3 are applied (see above). Still open: a four-line "Main path" block at the top of every SKILL.md, and `apps/<app>` in the board sheets.
2. Which missing basic components to add first: CAN (C5 FDCAN) and a timer API are the two that
   are absent everywhere.
3. Support skills: copy firmware-test / cleanroom-test / hw-troubleshooting / sensor-debug into the
   three other repositories, or state "use the bare-metal repository's skill" in each README.
4. EmbLinux: A4/A5/A8 are applied (see above). `help.py [--en]` added the same day (validator PASS, 77 checks).
5. Keep or delete the clean-room test apps in `C:/fw-ws`.
