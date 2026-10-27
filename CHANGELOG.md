# Changelog

All notable changes to this repo. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/);
versions follow [Semantic Versioning](https://semver.org/) and match `version` in
`.claude-plugin/plugin.json`. Verification results per board are in each board profile's
verification log, not here.

## [Unreleased]

### Added
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

### Changed
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
