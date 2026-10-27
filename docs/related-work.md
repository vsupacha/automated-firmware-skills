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
