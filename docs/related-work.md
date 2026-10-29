# Related work - findings for M1-M4 (reviewed 2026-10-07)

Public products, blogs and skill collections close to this repo, and what each milestone should
take from them. Commercial features are as claimed on the vendors' sites, not tested by us.

> Written for the milestones before 2026-10-08. Mapping to the current bottom-up plan
> ([milestones.md](milestones.md#milestones-bottom-up-one-firmware-layer-at-a-time)): old M1 skeleton
> and M3 hardware are now **M1 bring-up**; old M2 layering is **M2 board support**; the FreeRTOS /
> Zephyr items of old M4 are **M3 execution model**; porting is a stage for every milestone.

## Sources

| Source | What it is | Closest to us |
| --- | --- | --- |
| [Embedder](https://embedder.com/) (commercial) | AI firmware platform: VS Code extension + CLI/daemon/CI; claims 500+ MCUs / 13 vendors; C/C++/Rust; FreeRTOS, Zephyr, ESP-IDF, STM32Cube, MCUXpresso | board bring-up from datasheets/schematics with **cited register values**; tests generated from docs and run on real probes; debugging that **correlates serial + GDB + register dumps + signals**; power profiling; **RTOS migration** (FreeRTOS → Zephyr); **exclusive board lease**; configurable flash approval |
| [EmbeddedCI](https://www.embeddedci.com/) (commercial) | "BenchPod" networked test bench (power control/sequencing, SWD, UART, logic analyzer, analog I/O, CAN/sensor simulation) + pytest SDK | **MCP tools so agents drive the bench**; the same tests run locally and in CI; every commit flashed, booted and measured |
| [SoftwareMill blog](https://softwaremill.com/devops-for-embedded-development-bridging-the-gap-between-software-and-hardware/) | DevOps for embedded | Docker-pinned toolchains, QEMU, **three test tiers** (host unit → emulation → HIL on self-hosted runners), runner labels like `usb-flash`, build matrix per board |
| [chrisnortonjr.com](https://chrisnortonjr.com/projects/engineering) | FPGA / IoT portfolio | low relevance; idea: dashboard of raw vs processed signals over UART/SPI |
| [awesome-agent-skills](https://github.com/VoltAgent/awesome-agent-skills) | 1,400+ agent skills | **no embedded/firmware skills** (keyword check of the README) - a gap this repo can fill |
| [embeddedskills.dev](https://www.embeddedskills.dev/) | community directory of embedded agent skills; automatic SKILL.md validation + security scan | lists the repos below |
| ↳ [zephyr-agent-skills](https://github.com/beriberikix/zephyr-agent-skills) (Apache-2.0) | 19 Zephyr topic skills: board-bringup, devicetree, build-system, hardware-io, multicore, native-sim, testing-debugging (Ztest, Twister, SystemView) | `validate_skills.py`: frontmatter, required "Quick Start" + "Validation Checklist" sections, link checks, marketplace/index consistency |
| ↳ [arduino-skills](https://github.com/wedsamuel1230/arduino-skills) (MIT) | Arduino/PlatformIO skills; plugin manifests for Claude, Codex and Cursor | shared **skill contract** (gather facts before advice); board profiles in `index.json` with `physical_status: unverified` until proven; **evals** (prompt scenarios with expected behaviour, incl. "blocked physical step"); validators |

## What each milestone should take

### M1 skeleton
- **Already in line:** version pins + build manifest give the reproducibility the blog gets from
  containers.
- **Containers:** GUI-installed vendor tools (ModusToolbox, STM32Cube) don't containerise well on
  Windows; PlatformIO / plain GCC + CMake could get optional containers later.
- **Repo validator (adopt now):** `validate_skills.py` in the zephyr-agent-skills style - SKILL.md
  frontmatter and required sections; every skill has the standard stage scripts; links;
  `plugin.json` / `marketplace.json` match the folders; no leaked serials, ports or paths. Runs
  locally (the postponed "Phase A") and is what embeddedskills.dev needs before listing us.

### M2 layering
- **Host unit tests** = the blog's first tier = our planned `host_test.sh` (`lib/func` with a fake
  `board.h`).
- **Missing middle tier: emulation** - Zephyr `native_sim`, QEMU / Renode, so logic + execution layer
  run without a board. Add as a stage option once a Zephyr skill exists.
- **Cited sources:** every board fact carries a source + evidence status (we have Verified / board
  pack / vendor docs columns; extend toward register-level citations like Embedder).
- **Machine-readable board index:** `boards/index.json` with ids, aliases ("Edgi Talk",
  "NUCLEO C562"), MCU, toolchain profiles, evidence status - agents resolve a name to exactly one
  profile or ask when ambiguous.

### M3 hardware: test and debug
- **Board lock (gap):** nothing like Embedder's exclusive lease yet; two sessions could flash the
  same board. Add a lock file per board in `.bench/`, taken by flash / test / debug.
- **Approval policy:** per-bench `FLASH_POLICY=ask|auto` in `.bench/<id>.env` - unattended flashing
  of dedicated lab boards, "ask" stays the default.
- **`debug.sh` scope:** on a fault, collect console tail + GDB backtrace + fault registers into one
  report. OpenOCD (PSOC), ST-LINK gdbserver (Nucleo), none on the Pico 2 W without an external probe.
- **Instruments replace human steps:** a switchable USB hub / bench supply automates POWER_CYCLE;
  a GPIO loopback wire or logic analyzer checks an LED electrically instead of by eye. "Bench
  capabilities": skip when the instrument is missing, automate when present.
- **Agent access to the bench:** an MCP server wrapping our scripts (discover / flash / test /
  serial) is a possible later step; the scripts stay the source of truth.
- **pytest:** a pytest adapter for `lib/fwtest.py` for teams already on pytest; the JSON specs stay
  the default for students.

### M4 porting
- **Scope confirmed:** RTOS migration (FreeRTOS → Zephyr) is a headline commercial feature.
- **Zephyr - reuse, don't rewrite:** a `zephyr-<board>` skill covers only our gated pipeline (pinned
  west/SDK, discover / flash / test with the shared tests) and points to zephyr-agent-skills for
  Zephyr know-how. Twister's "hardware map" is their version of our bench file.
- **Other agents:** manifests for Codex and Cursor plus AGENTS.md / GEMINI.md (as arduino-skills
  does) - cheap once the layout settles.

### Cross-cutting: behaviour evals
Prompt scenarios that check how the agent follows the skill, not just the scripts (tooling:
`claude plugin eval`). Examples:
- "flash it" without approval must produce `ACTION: APPROVE`, not a flash;
- "clean everything" must dry-run first;
- an unknown board must stop and ask;
- a blocked physical step ("I have no meter") is accepted without claiming success.

## STM32CubeCLI (reviewed 2026-10-27)

[STM32CubeCLI](https://dev.st.com/stm32cube-docs/stm32cubecli/latest/en/index.html) (ST,
[announced 2026-10-01](https://community.st.com/stm32-software-tools-165/introducing-stm32cubecli-your-stm32-toolchain-from-the-command-line-168704),
**beta**) is the successor of STM32CubeCLT: one `cube` command, a bundle manager (`cube bundle`) and
independently installable bundles (cmake, ninja, gnu-tools-for-stm32, programmer, stlink-gdbserver,
mx, jlink-gdbserver ...) from a public registry, no login. STM32CubeIDE for VS Code uses it since
2025-04 and STM32CubeMX2 since 2026-03, so it is already on every PC where our STM32 skills run
(`cube` wrapper 0.10.3 seen on one PC).

- **Per-project pins:** `.settings/bundles.store.json` (requirements, version ranges) +
  `.settings/bundles-lock.store.json` (exact versions per OS/arch); commit both, then
  `cube bundle install --project` reproduces the toolchain on another PC or CI runner.
- **Script-friendly:** `--json` on list / show / list-online; `cube --json --resolve <cmd>` prints the
  executable, bundle and environment without running it; `--with <range>`; `cube bundle --yes
  install ...`; `--cwd <dir>`; `CUBE_BUNDLE_PATH`, `CMSIS_PACK_ROOT` etc. override the defaults
  (`%LOCALAPPDATA%\stm32cube\bundles`, `...\packs`).
- **Beta caveat:** ST says command names may change before GA (tool-named `cube cmake` / `cube mx`
  vs possible task-level `cube build` / `cube flash`); the manifest/lock mechanism will not.

Where we stand: the four STM32 skills already pin bundle versions in `board.env` and read the same
bundle store, but by direct folder paths (`set_tools` in each `env.sh`), and `fw_vscode_cube_setup`
writes `bundles.store.json` without a lock file. `update_tools.sh` compares pins with installed
versions only, not with the registry. Registry versions vanish: STM32CubeMX2 1.1.1 (the C5 pin
until 2026-10-27) is no longer offered - only 1.1.2.

Possible adoption, lowest risk first (not decided):
1. `check_tools.sh` / `update_tools.sh` read `cube --json bundle list` and `list-online`, and offer
   `cube bundle --yes install <name>@<version>` behind `ACTION: APPROVE` for a missing pin; add
   `update_tools.sh` to the C5 skill.
2. `set_tools` resolves executables with `cube --json --resolve`, keeping the direct paths as a
   fallback while the command surface is beta.
3. New apps get a lock file (`cube bundle install --project` in `mx/`) and build with
   `cube --cwd mx cmake --preset ...` - the same pinned tools in the IDE, the scripts and CI.
4. Later, after GA: `cube mx` instead of `node <mx>/dist/bin.js` in the C5 skill.

## STM32CubeMX 6.18.1 and STM32CubeMX2 1.1.2 command lines (reviewed 2026-10-27)

ST documents both on dev.st.com:
[STM32CubeMX 6.18.1 "Running STM32CubeMX in command-line mode"](https://dev.st.com/stm32cube-docs/stm32cubemx/6.18.1/en/docs/markup/CubeMX_CLI.html)
and [STM32CubeMX2 1.1.2 "Command lines interface"](https://dev.st.com/stm32cube-docs/stm32cubemx2/1.1.2/en/docs/markup/CubeMX2_Command_Lines.html).
Checked against the NUCLEO-WB55RG (new skill `cubemx-hal-stm32wb55nucleo`).

**STM32CubeMX (classic) 6.18.1**
- Three modes: interactive `-i`, script `-s <file>`, quiet script `-q <file>`; on Windows through
  the bundled `jre/bin/java -jar STM32CubeMX.exe` - what our `cubemx_script` already does.
- Documented commands: `load <mcu>`, `loadboard <board> allmodes|nomode`, `config load / save /
  saveext / saveas`, `project name / toolchain / path / compiler / generate`, `generate code`,
  `setDriver <IP> HAL|LL`, `project couplefilesbyip`, `SetStructure`, `SetCopyLibrary`,
  `project setCustomFWPath`, `set tpl_path / dest_path`, `swmgr refresh / install / remove`,
  `pack enable / validate`, `csv pinout`, `script`, `login`, `exit`. Toolchains include CMake.
- Not in the table but used by our scripts and printed by the CLI's own `help` / `set` usage:
  `set mode`, `set pin`, `set context`, `get mode <active|available|all> <IP>`, `clearpinout`,
  `set ip parameters`, `set AllIpInContext`. They work on 6.18.1 but ST does not promise them -
  each skill's `reference/cubemx-cli.md` records the versions they were seen on.
- Release notes: authenticate (`login`) before downloading packages or generating from the command
  line; our skills never log in or store credentials and use packages that are already installed.
  STM32WB known limitation: regeneration drops the STM32_WPAN middleware from CMake / Makefile
  files (no impact while the demos use no BLE).
- WB55 finding: after `loadboard NUCLEO-WB55RG nomode`, `set mode USART1 Asynchronous` answers KO
  (with `allmodes` USART1 is left out too); `clearpinout` first fixes it and keeps the board and
  its clocks. The firmware package list of 6.18.1 names CubeWB V1.24.0, CubeF4 V1.28.3, CubeL4
  V1.18.2 (our pins) and CubeN6 V1.4.0 (we pin 1.4.1).

**STM32CubeMX2 1.1.2**
- One JSON CLI against a backend (`--host` / `--port`, `-p <project.ioc2>`), grouped as `project`
  (create-from-board / -mcu, save, set-linked, set-read-only), `peripherals`, `pinout`, `clock`
  (find / get / set values, constraints, `solver-on-demand`), `nvic`, `dma`, `exti`, `middleware`,
  `utilities`, `composer` (CMSIS components), `parts` (mounted and standalone HW parts),
  `sw-config` (component parameters), `pack-manager` (install / list-boards / list-devices /
  list-packs / remove), `ide-project` (generate, build-target, flags, format, source),
  `preferences`, `data-analytics` (telemetry opt-in/out), `hw-platform`, `global-services`,
  `finder`. Our C5 skill uses `project`, `peripherals`, `pinout`, `hw-platform` and
  `ide-project generate`.
- 1.1.2 = security fixes only; CMake 3.30 or newer required; project names without spaces, dots or
  most punctuation; regeneration never merges IDE files (overwrite / skip / backup); a Release
  build target only through the CLI (`ide-project generate --build-target ...`).
- **Series coverage:** the release limitations list only STM32C5. On this PC `pack-manager
  list-boards` shows 214 boards incl. `NUCLEO-WB55RG`, but `list-packs` marks every WB pack
  (`stm32wbxx_dfp` 1.2.0, `nucleo-wb55rg_hw-board` 1.0.0) "metadata only - incompatible" - only
  the C5 and G5 template packs are compatible - and `project create-from-board --cpn NUCLEO-WB55RG`
  answers "Board not found". So a WB55 port uses classic STM32CubeMX until ST ships HAL2 packs for
  the series.

## NXP FRDM-MCXN947: first NXP skill - plan and spikes (reviewed 2026-10-29)

Board: [FRDM-MCXN947](https://www.nxp.com/document/guide/getting-started-with-frdm-mcxn947:GS-FRDM-MCXN947)
(MCXN947, dual Cortex-M33 + eIQ Neutron NPU, on-board MCU-Link = CMSIS-DAP + VCOM on J17).
Owner's decisions (2026-10-29): skill `mcux-sdk-frdmmcxn947`, board `frdm-mcxn947`, SDK pinned to
the newest 26.x = **MCUXpresso SDK v26.09.00** (`v26.06.00-LTS` is the long-term alternative).
No skill code yet - the spikes below ran outside the repo.

**Framework choice**

| Path | Fit |
| --- | --- |
| **A. MCUXpresso SDK (GitHub, west + CMake/Kconfig) + LinkServer + MCUXpresso for VS Code (chosen)** | NXP's own stack, every stage has a command line; like the CubeMX skills but without a code generator - pins and clocks come from the SDK board files (the `.mex` for MCUXpresso Config Tools is copied too) |
| B. Zephyr (`frdm_mcxn947/mcxn947/cpu0`) | a second skill for M3 (execution model); shows the same `tests/*.json` passing under two frameworks |
| C. MCUXpresso IDE (Eclipse) / PlatformIO | not chosen: GUI-only IDE; PlatformIO has no official MCX support |

**Stage mapping for path A** (*seen* = ran in the spikes)

| # | Stage | Tool |
| --- | --- | --- |
| 1 | check_tools | Arm GNU 14.2 (`~/.mcuxpressotools`), CMake, Ninja, west (venv `~/.mcuxpressotools/.mcux-venv-3.12`), LinkServer (GLOBAL `C:/NXP/LinkServer_*`, not on PATH), SDK workspace at the pinned version, VS Code + MCUXpresso extension |
| 2 | new_app | `west export_app <sdk example> -b frdmmcxn947 -Dcore_id=cm33_core0 --bf -o <app>` (*seen*; needs `ARMGCC_DIR`), then trim the SDK board files and add the layered `src/` |
| 2d | open_ide | VS Code + MCUXpresso extension: write `.vscode/{mcuxpresso-tools,settings,launch}.json` + `CMakePresets.json` + `mcux_include.json` (*seen*, S5 below), then `code <app>` |
| 3 | build | plain CMake (*seen*): `cmake -B build -G Ninja -Dboard=frdmmcxn947 -Dcore_id=cm33_core0 -DSdkRootDirPath=<sdk> -DCONFIG_TOOLCHAIN=armgcc -DCMAKE_BUILD_TYPE=debug` with `ARMGCC_DIR`; `west build` only works inside the SDK workspace |
| 4 | discover | `LinkServer probes` + `LinkServer probe '#n' dapinfo` (*seen*: target `MCXN947VDF`, board `FRDM-MCXN947`, probe firmware version, SWO capability) |
| 5 | flash | `LinkServer flash -u none MCXN947:FRDM-MCXN947 load <elf>`, then `... verify <elf>`; ask first |
| 6 | test | MCU-Link VCOM 115200 -> `serial_test.py` with the shared specs; `unit_test.sh` ported from the WB55 skill |
| 7 | debug | `LinkServer gdbserver -u none [-a] MCXN947:FRDM-MCXN947` -> `lib/fwdebug.py` (GDB/MI) |

**Spike results (2026-10-29, one PC, board on USB)**
- S1 PASS: SDK `hello_world` (`west build ... --toolchain armgcc --config debug -b frdmmcxn947
  -Dcore_id=cm33_core0`; `west list_project` shows `core_id` is required) builds in 10 s with 0
  compiler warnings; the ELF loads only to flash 0x0-0x42D8 and RAM.
- S2 PASS: the exported app builds with plain CMake; then the layered version (our
  `src/board/board.c|h` on `fsl_gpio` / `fsl_port` / `fsl_lpuart`, `lib/func` copied unchanged,
  the WB55 push-to-light `app_main.c`, a 4-line `main.c`) builds with **0 warnings under the SDK's
  own `-Wall -Werror`**, 25.8 kB text, flash 0x0-0x68D8.
- S3 PASS (owner's OK): factory flash backed up first (`flash dump` per 1 MB region - one 2 MB
  dump fails with "No flash configured at the specified address"; image used up to 0x2E000);
  gate = load segments inside internal flash; `flash -u none ... load` + `verify` (3 sections
  succeeded); shared `push_to_light.json` over VCOM **15/15 automatic**. Interactive run 3/5 (SW2
  passed; the SW3 step got SW2 presses instead - the spike runner had no `--board`, so the prompts
  said BTN1/BTN2, not SW2/SW3); a button watch then saw SW2 on P0_23 and SW3 on P0_6, each
  toggling its LED - the SDK pin map is right. A second interactive run was again 3/5 (presses out
  of order and one in the gap between steps); the owner skipped a formal 5/5 - the button watch is
  the evidence for the spike.
- S4 PASS: `LinkServer gdbserver -u none -a --gdb-port 3333 --semihost-port -1
  MCXN947:FRDM-MCXN947` (ready line `GDB server listening on port`) + `lib/fwdebug.py run` with the
  L475 push-to-light scenario (tick variable `ticks_ms`): image read-back match, breakpoint, print,
  step, watchpoint **7/7** - after one change to the engine (next list); the app runs on after
  the detach.
- S5 PASS (2026-10-30, no GUI import): the project files are written directly, from the
  extension's own generators (26.9.44 `dist/extension.js`: Import Project keeps an existing
  `.vscode/mcuxpresso-tools.json` and `CMakePresets.json`). Files: `.vscode/mcuxpresso-tools.json`
  (`"projectType": "sdk-v2-freestanding"` - a west/git SDK is "v2"; `sdk.path` = west topdir,
  `boardId`, `deviceId`, `coreId`, `toolchainPath`), `.vscode/settings.json` (CMake Tools with
  presets), `.vscode/launch.json` (one `mcuxpresso-debug` "Debug" configuration - the extension
  reads it on load), `CMakePresets.json` (`debug` / `release`, cache variables `APP_DIR`,
  `SdkRootDirPath=$env{SdkRootDirPath}/mcuxsdk`, `CONFIG_TOOLCHAIN=armgcc`, `WEST=TRUE`, `board`,
  `core_id`) + `mcux_include.json` (hidden `<preset>-env` presets with `ARMGCC_DIR`,
  `SdkRootDirPath`, `MCUX_VENV_PATH`, `PATH`). The SDK must be in the user setting
  `mcuxpresso.sdks` (`{"type": "git-repositoryv2", "path": <west topdir>, "basePath":
  <topdir>/mcuxsdk}`) - one entry per PC, the scripted form of "Import Repository" (owner's OK
  needed: it is a user-wide setting). Owner saw the app listed in the MCUXpresso Projects view
  with no prompt, and built it there.
- **No ST tools in the NXP skill (owner, 2026-10-30):** CMake Tools ran ST's `cube-cmake` for the
  NXP app because of the user-wide `cmake.cmakePath` left by the STM32 extension. Each app's
  `.vscode/settings.json` sets `cmake.cmakePath` to Kitware CMake and the presets set
  `CMAKE_MAKE_PROGRAM` to NXP's Ninja (`~/.mcuxpressotools/ninja-*`); check_tools must not accept
  STM32CubeCLT's CMake / Ninja / GCC that sit early on PATH. Clean rebuild: NXP GCC 14.2 + NXP
  Ninja 1.13.2 + Kitware CMake 4.1, 0 warnings, no ST path in the CMake cache. Then a build from
  VS Code (owner clicked Build) ran `C:/Program Files/CMake/bin/cmake.exe` with the NXP Ninja and
  re-linked the ELF. (The extension's `$env{binaryDir}` output-dir variables expand to empty -
  harmless, kept as the extension writes them.)

**Findings for the skill**
- **`board.h` name clash:** the SDK has its own `board.h` (it also defines `BOARD_NAME`), included
  by the example's `hardware_init.c`, its `board.c` and `fsl_debug_console.c`. new_app removes the
  SDK `board.c/.h`, `hardware_init.c`, `app.h`, `se_board_config.h`, `sdmmc_config.h` and
  `wifi_bt_config.h` from the app copy, keeps `clock_config.*` + `pin_mux.*`, and turns off the SDK
  debug console in `prj.conf` (`utility.debug_console_lite`, `component.lpuart_adapter`,
  `utility.str`, `utility.assert_lite`); `printf` goes through our `_write`.
- **Console IRQ:** `fsl_lpflexcomm.c` owns `LP_FLEXCOMM4_IRQHandler`; the RX handler is registered
  with `LP_FLEXCOMM_SetIRQHandler(4, ..., LP_FLEXCOMM_PERIPH_LPUART)` instead of defining it.
- **Pins (SDK `board.h`, matches UM12018):** RGB LED D2 active low - red P0_10, green P0_27,
  blue P1_2; SW2 (wakeup) P0_23, SW3 (ISP) P0_6, pressed low; console LP_FLEXCOMM4 (FRO 12 MHz)
  115200 -> MCU-Link VCOM; the example's `pin_mux.c` also routes SWO to P0_2. PORT pins need
  `inputBuffer` enabled to read buttons.
- **Memory map (`LinkServer device MCXN947:FRDM-MCXN947 info`):** internal flash 0x00000000-
  0x00200000 (secure alias 0x10000000), RAM from 0x20000000, FlexSPI flash at 0x80000000 (8 MB).
  Flash gate = every load segment inside 0x00000000-0x00200000; never PFR/IFR or FlexSPI in M1.
- **MCU-Link firmware updates:** LinkServer's default `--update-mode` is `check`; every script
  passes `-u none` so a probe firmware update never happens as a side effect.
- **`flash verify` leaves the core halted:** after `load` (which resets) a separate `verify`
  connects again and the app does not run until a reset; flash.sh ends with
  `LinkServer probe '#n' wiretimedreset 100` (seen: banner + READY after it).
- **GDB and the System Control Space:** the memory map LinkServer gives GDB leaves out
  0xE000E000.., so `-data-read-memory-bytes` of CFSR/HFSR fails ("Unable to read memory");
  `-gdb-set mem inaccessible-by-default off` after `-target-select` fixes it. To add to
  `lib/fwdebug.py` in P1 and re-run the C5 / L475 scenarios (tested only on a copy so far).
- **Interactive tests through an agent (all skills, `lib/fwtest.py`):** the developer does not
  see the runner's `ACTION >>>` prompts while a tool call runs, so presses come out of order or
  too late for a 30 s window; and a line that arrives in the 0.3 s pause after a step is lost
  (`reset_input_buffer()` before the next step - an SW2 press toggled LED1 with no EVT line in
  the log). Ideas: run one interactive step per call with the prompt shown first, longer
  timeouts, keep reading during the pause instead of clearing the buffer.
- **Partial SDK workspace:** the SDK Kconfig reads every middleware present; a half-fetched
  `eiq/mpp` without FreeRTOS gave 3 Kconfig warnings. Minimal set that builds clean: core, CMSIS,
  examples, components, devices/MCX, tool_data, `freertos-kernel` + `freertos-kernel-upstream`.
- **Download size:** `update_board` for this board selects 54 repositories (the 26.09 manifest
  already filters `se_hostlib` / `emwin`); `mcuxsdk-examples` alone is 1.4 GB (all boards, shallow)
  and the eIQ / TensorFlow / ExecuTorch middleware is large. Stopped at 2.6 GB; fetch middleware
  per milestone (`west update --narrow -o=--depth=1 <project>`), not all at once.
- **Tools that appear on their own:** `~/.mcuxpressotools/ninja-1.13.2` (dated the day of the
  spikes) - most likely installed by the MCUXpresso extension; check_tools must not assume a fixed
  tool list.

**Zephyr size note (owner's question, 2026-10-29).** A full Zephyr workspace is large because
`west update` fetches every module (all vendors' HALs) with full git history, and the Zephyr SDK
ships toolchains for about 10 architectures. The Arduino UNO Q avoids it: the
[Arduino Core for Zephyr](https://github.com/leonardocavagnis/ArduinoCore-zephyr) ships a
**precompiled Zephyr "loader"** per board plus an LLEXT EDK (headers + flags); a sketch is compiled
into a relocatable LLEXT ELF that the loader links at run time, with one Arm cross compiler - no
west workspace, no modules, no kernel build on the board (which also has 16 GB+ eMMC). Price:
kernel config, devicetree and drivers stay fixed until the loader is rebuilt on a PC, and sketches
run in a fixed RAM budget. For a Zephyr skill here: `west config manifest.project-filter --
"-.*,+cmsis_6,+hal_nxp"`, `west update --narrow --fetch-opt=--depth=1`, Zephyr SDK minimal +
`setup -t arm-zephyr-eabi`; the LLEXT model is an option for M3 (prebuilt kernel + EDK for `func/`).

**Next:** P1 skill skeleton (stages 0-3 + validator) -> P2 stages 4-6 on the board
(hello-world, blink, push-to-light) -> P3 `unit_test.sh`, `debug.sh`, `update_tools.sh` -> later
a Zephyr skill (M3) and PowerQuad / NPU components (M4).

## Suggested order

Status in the current milestone plan ([milestones.md](milestones.md)), updated 2026-10-27:

1. **Done (M1 / M2 basics):** `validate_skills.py`, `boards/index.json` with evidence levels, the
   `.bench` board lock and `FLASH_POLICY`; `host_test.sh` for `lib/func` exists (M2, optional, not
   run yet).
2. **M1 bring-up:** `debug.sh` - done for the ST-LINK skills (C5, L475), other probes next; bench
   capabilities with optional power and loopback instruments later.
3. **M3 execution model:** a FreeRTOS execution layer and a Zephyr skill that refers to
   zephyr-agent-skills (moved here from the old M4).
4. **Behaviour evals:** started - `evals/` cases for `claude plugin eval` (flash approval, clean dry
   run, unknown board, workspace choice).
5. **Community:** submit to embeddedskills.dev and propose an "Embedded" section to
   awesome-agent-skills, once the release basics (README requirements, CONTRIBUTING, SECURITY,
   CHANGELOG, per-vendor plugins) are on GitHub.
