# Changelog

All notable changes to this repo. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/);
versions follow [Semantic Versioning](https://semver.org/) and match `version` in
`.claude-plugin/plugin.json`. Verification results per board are in each board profile's
verification log, not here.

## [Unreleased]

### Removed
- 2026-11-01: RT-Thread skills `scons-rtthread-visionboard` and `scons-rtthread-titanboard`, boards
  `vision-board` and `titan-board` and the `firmware-rtthread` plugin moved to the new repository
  automated-firmware-skills-rtthread (RT-Thread builds, flashes and tests differently). `lib/msh.py`
  stays here for `fwtest.py`'s optional `command_list`. The entries below about the Vision Board,
  the Titan Board, recipes, `msh_status.py` and the RT-Thread `update_tools.sh` describe work that
  now lives in that repository.

### Added
- New board skill `mcux-sdk-frdmmcxn947` (NXP FRDM-MCXN947, MCXN947 Cortex-M33 core 0) with the
  MCUXpresso SDK 26.09 (west), Kitware CMake and the MCUXpresso Installer tools - M1 stages 1-3
  (check_tools, new_app from `west export_app` + trim, open_ide writing the MCUXpresso for VS Code
  project files directly, build with the IDE's preset) and board stages 4-6 (discover, LinkServer flash
  behind identity + internal-flash gates, serial tests); debug planned. NXP tools only (no
  ST cube-cmake / CLT tools). Vendor plugin `firmware-mcuxpresso`.
- Step-by-step guides per board skill: `skills/<skill>/README.md` (English) and `README_TH.md`
  (Thai) - install, what to ask Claude, the Git Bash commands, board notes; linked from the README
  skills table, each board README and README_TH.md (which also shows the per-vendor plugins). The
  earlier Thai guides of the C5, Edgi-Talk and Pico skills are folded into the new ones.
- Per-PC apps workspace: `lib/fw_workspace.sh` (`show` / `set <dir>` / `unset`, saved in
  `~/.fw-skills.env`) and `lib/fwpaths.py` for the Python tools. `new_app.sh` (all board skills)
  stops with `ACTION: CHOOSE` when no workspace was chosen and `<project>/apps` is in a synced
  folder or too long for the toolchain. See docs/workflow.md "Apps workspace".
- README: Requirements and Quick start; `CONTRIBUTING.md`, `SECURITY.md`, this changelog.
- SKILL.md frontmatter: `license` and `compatibility` (Agent Skills specification).
- Tool updates: `IDE_EXT_VERSION` in the STM32 and ModusToolbox board profiles (the extension
  version the IDE path was proven with; `check_tools.sh` warns when VS Code updated it) and
  `update_tools.sh <board> [--apply --yes]` in the STM32 CubeMX skills: compares every pin with
  this PC, asks with `ACTION: APPROVE`, re-pins and logs "not re-qualified yet". See
  docs/workflow.md "Tool updates".
- RT-Thread msh in the tools (`lib/msh.py`): the Vision Board tests first check that the image's
  `help` lists every command the spec sends (step `command list`), and new `msh_status.py` (stage 7
  status without a probe) reads version, exported commands, threads with stack use, heap and devices
  from the running image.
  Reads both heap formats (small heap and memheap pools). Vision Board `push-to-light` tested on
  hardware (GCC 13.3 image, 17/17).
- New skill `scons-rtthread-titanboard` + board `titan-board` (RT-Thread Titan Board, Renesas RA8P1,
  RT-Thread 5.1.0, SDK Titan-Board 1.0.2 from RT-Thread Studio; base project `Titan_template`). Blink and
  push-to-light tested on the board (17/17); the factory MRAM is backed up before the first flash. 15
  Kconfig recipes derived from the SDK's `project/Titan_*` examples (ADC, CANFD, Ethernet, GPT/PWM,
  HyperRAM, OSPI flash + LittleFS, I2C2, buzzer PWM, RS485, RTC, SD card, SPI0, USB PCDC, WDT, Wi-Fi);
  applied together and built, not yet run on the board. The on-board RA4M2 CMSIS-DAP is v2 only: on
  Windows it needs WinUSB with a device interface GUID (documented).
- `lib/msh.py` reads RT-Thread 5.1.0's `ps` layout (name first, tcb address last).
- recipe.py (both RT-Thread skills): `derive` handles project Kconfig preprocessor paths
  (`RTT_DIR := ...`), `apply` copies a package shared by two recipes once.
- `recipe.sh apply <app> <recipe>... [--yes]`: writes what `check` asks for (never FSP), backs up
  replaced files, re-checks, re-syncs the Studio project; dry run without `--yes`. The drv_gpio.c fix
  moved to the `base` recipe and `new_app.sh` (every new app). Nine recipes in one app: READY, build PASS.
- Recipes `usb-cdc` (TinyUSB CDC on the user USB-OTG port) and `at-cdc` (RT-Thread AT server on a CDC
  rt_device + AT command layer `src/at/` on the function layer) - tested on the board (AT 12/12).
  `usb-cdc` patches the SDK's drv_gpio.c (every rt_pin_mode() re-applied the FSP pin setup and
  switched the USB port away). recipe.py: skill files, `inserts`, `patches`, value overrides.
- `scons-rtthread-visionboard` build.sh: the warning gate counts only the app's `src/` (it also
  counted RT-Thread files under `.../src/`).
- `lib/fwtest.py`: serial write timeout (a CDC device that stops reading fails the run instead of
  blocking it); a spec can turn the msh command-list check off (`"command_list": false`).
- Recipe `sdcard-fat` (software component on `sdcard`): FAT with write access on the SD card -
  `check` also verifies files (`board/ports/mnt.c` from the msc project: the base's copy never mounts
  the card) and source facts (elm-FAT read-write, mkfs, msh file commands); serial test spec writes,
  reads back and deletes `/fwtest/a.txt` - tested on the board (11/11, file kept across a reboot).
- `lib/fwtest.py`: a step with neither `expect` nor `expect_re` is send-only and passes once sent
  (msh `rm` prints nothing; it used to fail).
- Vision Board Wi-Fi: recipes `spi1` + `rw007` applied to a push-to-light app and run on the board -
  msh `wifi scan`, `wifi join`, `ping` work (status `tested`); SKILL.md describes applying a recipe by
  hand and keeps Wi-Fi credentials and network data out of files and logs.
- `scons-rtthread-visionboard` apps take their FSP side (configuration.xml, ra/, ra_gen/, linker
  scripts) from `FSP_PROJECT` = `vision_board_openmv`, which generates every peripheral the driver
  recipes need; Kconfig and board/ stay blink's, so no driver is enabled. Unused interrupt handlers
  get weak stubs; dave2d is always compiled.
- HW driver recipes for `scons-rtthread-visionboard` (Kconfig level): `recipes/drivers/*.json` for
  `i2c1-soft spi1 rw007 sci3-i2c sdcard pwm6`, each derived (`recipe.sh derive`) from the one SDK
  example project whose README is about that hardware;
  `recipe.sh check <app> <recipe>...` resolves them with kconfiglib and lists the FSP instances, board
  ports, packages and board/Kconfig blocks an app needs first (read-only).
- `update_tools.sh` for `scons-rtthread-visionboard`: compares the RT-Thread Studio SDK Manager
  packages pinned in the profile (board support package, GNU Arm toolchain, pyOCD) with the versions
  installed side by side; same gates as the STM32 skills.

- Per-vendor plugins: `firmware-stm32`, `firmware-platformio`, `firmware-modustoolbox`,
  `firmware-rtthread` (each pulls in `firmware-tools`), next to the all-in-one
  `automated-firmware-skills`; a vendor plugin loads up to about 1,000 tokens of skill descriptions
  instead of about 3,300. Version 0.2.0 in every entry.
- `tools/board_status.py`: writes and checks the demo-level tables from `boards/index.json`
  (profile field `renamed` for the ` *` footnote); the validator runs the check.
- Behaviour evals in `evals/` for `claude plugin eval` (flash asks first, clean dry-runs first,
  unknown board stops, `ACTION: CHOOSE` is relayed); first run 4/4.

- pio-arduino-rpipico2w: `unit_test.sh` (prototype) - Unity tests of `func/` (led, button,
  console; 12 cases) against a fake board, built with `pio test`, flashed through `flash.sh` after
  the user's approval, results read on the board: 12/12 on a Pico 2 W. New apps get `test/` and
  `[env:<env>_unit]`.
- pio-arduino-esp32s3box: the same unit-test prototype (12 cases, 12/12 on an ESP32-S3-BOX);
  `flash.sh --env <pio-env>` programs another build of the app behind the same manifest and identity
  gates; results are read by `scripts/unity_read.py` (start byte) because the USB Serial/JTAG drops
  output and cannot be reset by `pio test`; `unit_test.sh --read-only`; build.sh's flash map is
  the shared `pio_flash_map` in env.sh.
- cubemx-hal-stm32f407disco: stage 4 connect (`discover.sh`) and stage 5 flash (`flash.sh`, asks
  first) through the on-board ST-LINK/V2 (no virtual COM port, reports no board name, so several
  ST-LINKs stop with `ACTION: CHOOSE`). blink flashed on an STM32F4DISCOVERY and seen blinking
  (observed); the test stage (SWO reader) is still planned.
- New board skill `cubemx-hal-stm32wb55nucleo` (ST NUCLEO-WB55RG, STM32WB55RG Cortex-M4 core) with
  classic STM32CubeMX 6.18.1 + STM32CubeWB 1.24.0, ported from the L475 skill: create, build,
  connect, flash (asks first; CM4 application only, the wireless stack is not touched) and serial
  tests; debug planned. Its `.ioc` starts with `loadboard NUCLEO-WB55RG nomode` + `clearpinout`
  (without it CubeMX refuses USART1). hello-world tested on the board (9/9), push-to-light
  observed (SW1/SW2 pressed, 6/6, LED1/LED2 seen). In the
  `firmware-stm32` and all-in-one plugins. STM32CubeMX2 1.1.2 cannot create a WB55 project yet.
- docs/related-work.md: what the STM32CubeMX 6.18.1 and STM32CubeMX2 1.1.2 command lines offer,
  and which commands our scripts rely on that ST does not document.
- On-target unit tests for the CubeMX C skills (prototype on cubemx-hal-stm32wb55nucleo):
  `lib/unity/` (Unity 2.6.1, pinned copy with hashes), `lib/test_func/` (runner with start-byte
  handshake + suites), `lib/unity_read.py`; `unit_test.sh <app>` builds the app's CubeMX project
  again with `-DFW_UNIT=ON` (overlay switch: `test/*.c` replace `src/app_main.c`), flashes it
  behind the identity gates (asks first unless `FLASH_POLICY=auto`) and reads `UNIT: PASS (n/n)`.
- `lib/func/gesture` (short / long / double click from one button's raw level and the time; pure,
  no `board.h`), written test-first: 13 Unity cases incl. tick wrap, red then green on a
  NUCLEO-WB55RG in two TDD cycles.
- `lib/func_dsp/fxscale` (CMSIS-DSP): float -> q31 -> `arm_scale_q31` -> float with per-value scaling
  (frexpf / ldexpf); worst relative error 6e-8 on the board over x 0.01..100, gain 0.01..10
  (bound 1 %). Test-first: one fixed Q format reached 1.31 % on random pairs while corners and a
  grid passed. The CubeMX overlay compiles CMSIS-DSP BasicMath + Support for func/ modules; the
  unit image prints floats (`-u _printf_float`). Unity's per-suite `setUp`/`tearDown` go through
  `lib/test_func/unit.h`.

### Changed
- Layer rule: `func/` and the execution layer may include CMSIS-DSP (`arm_math.h` ...) on Cortex-M
  boards (owner's decision); `lib/check_layers.py` checks the board family from `APP_BOARD` and
  `boards/index.json` and fails such includes on other boards (ESP32-S3). docs/board-api.md, lib/README.
- `serial_test.py` (lib/fwtest.py), sensor-debug and web-wizard read the bench file and apps from
  the same workspace as the shell scripts; project board profiles are looked up in `<project>/boards`.
- B-L475E-IOT01A: hello-world recorded as tested (flashed, 9/9).
- `.gitignore`: local README renders and vendor PDFs under `boards/`.
- Validator: checks `license` / `compatibility` and rejects unquoted `: ` in frontmatter values.
- `.claude-plugin/plugin.json` removed: the marketplace entries are the manifests (one namespace
  each); the install id `automated-firmware-skills@automated-firmware-skills` is unchanged.
- SKILL.md headings and script headers use the shared stage numbers (build 3, connect 4, debug 7,
  clean 16; coding is the new stage 2e); the validator checks number and order.
- `<app>` in commands is defined as the app folder `new_app.sh` prints (workflow.md, every help.sh).
- docs: walkthrough notes for the old milestone plan, related-work order updated, M5 logic as
  portable logic-layer modules wired from `app_main.c`.

### Fixed
- push-to-light specs: the last interactive step expected `^LED led1=1$`, which fails on boards
  with more than one LED (`LED led1=1 led2=1 ...`); now `^LED led1=1( |$)` in every skill.
- `serial_test.py`: a missing or invalid test spec prints an `ERROR` line with the specs that
  exist, instead of a Python traceback.
- cubemx-hal-stm32n6570dk: the SKILL.md description held `STM32C5: ...`, which made its frontmatter
  invalid YAML for strict parsers.

## [0.1.0] - 2026-10-16

First public state (commit `207f8b7`). Milestone M1 bring-up active.

### Added
- Ten board skills `<toolchain>-<framework>-<board>`: modus-pdl-edgitalk,
  cubemx2-hal2-stm32c562nucleo, cubemx-hal-stm32l475iot, cubemx-hal-stm32n6570dk and
  cubemx-hal-stm32f407disco (build stages only), pio-arduino-rpipico2w, pio-espidf-esp32s3box,
  pio-arduino-esp32s3box, pio-arduino-unor4wifi, scons-rtthread-visionboard.
- Gated stages with one script name per stage in every skill: check tools, create, IDE handoff,
  build (warnings block the gate, also across re-runs), connect, flash (asks first, identity
  checked), test (`tests/*.json` engine), clean; stage 7 debug (`debug.sh status | run`) for the
  STM32 C5 and L475 skills.
- Bring-up demos `hello-world`, `blink`, `push-to-light` with shared test specs.
- Tool skills: web-wizard, cleanroom-test, sensor-debug, hw-troubleshooting.
- Board sheets (`boards/`), `boards/index.json` with evidence levels, M2 layer check and optional
  host test (gated), repo validator `tools/validate_skills.py`, plugin and marketplace manifests.

[Unreleased]: https://github.com/vsupacha/automated-firmware-skills/compare/207f8b7...HEAD
[0.1.0]: https://github.com/vsupacha/automated-firmware-skills/tree/207f8b7
