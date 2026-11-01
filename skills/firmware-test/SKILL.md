---
name: firmware-test
description: Firmware unit testing on the board - procedure, tools and pass criteria for on-target unit tests of func/ code and test-driven development (red, green, refactor) with Unity, for the board skills that have unit_test.sh (pio-arduino-rpipico2w and pio-arduino-esp32s3box through PlatformIO, cubemx-hal-stm32wb55nucleo through CubeMX + CMake). Use when the user wants to test a func/ module on the target, write a test first, check a change with unit tests, read the test log, or asks what a test driver, test stub or test log is. Tests run in a separate test image; nothing is flashed without the developer's yes.
license: MIT
compatibility: Windows 10/11 with Git Bash and Python 3 + pyserial; a board skill of this repository that has a unit_test.sh script, with its toolchain (PlatformIO, or STM32CubeMX + the STM32Cube bundles); the board on USB for the flash and read steps.
---

# Firmware unit tests on the board (procedure, tools, criteria)

Contract and terms: docs/workflow.md "Firmware tests (stage 6 unit tests) and TDD". This skill is
the procedure; the board skill does create / build / connect / flash (`$SKILL` = that skill's
folder, `<repo>` = this repository).

## Terms (use them exactly)

- **module under test** - a `func/` module (`led`, `button`, `console`, `gesture`, `fxscale` ...).
- **test driver** - the test code above the module: Unity cases that call it and check the results,
  and the runner that starts them. PlatformIO: `test/test_func/test_driver.cpp`; CubeMX (WB55):
  `test/test_driver_main.c` (runner) + suites `test/test_<module>.c`.
- **test stub** - stands in for the layer below the module (`board.h`): inputs the test sets (time,
  button level, console text, a failing LED write), outputs it records (LED level, write count,
  console output). PlatformIO: `test/test_func/test_stub.cpp/.h` with `test_stub_*` controls;
  a suite's own stub clock (`test_stub_now`); host tests: `<repo>/lib/host/test_stub.c`.
- **test log** - the verdicts in RAM (`fw_test_log`, magic `FWTL`), printed after Unity's summary
  as `TESTLOG: cases=.. passed=.. failed=.. running=0 last_fail=..`, then `UNIT-DONE`
  (`<repo>/lib/test_func/test_log.c/.h`).
- **device driver** - the real driver below the board layer (HAL, Arduino core). Never call it
  "the driver" of a test.

## Procedure

1. **Check the skill has unit tests**: `$SKILL/scripts/unit_test.sh` exists (Pico 2 W, ESP32-S3-BOX,
   WB55 today). Other skills: say so - porting it is a separate task.
2. **Build once** (no board): `bash "$SKILL/scripts/unit_test.sh" <app> --build-only`. The script
   adds `test/` (and the PlatformIO `[env:<env>_unit]`) to an app that has none, refreshes the test
   log files, and keeps an old-layout `test/` (pre-rename names) under `logs/`. **Gate:**
   `UNIT-BUILD: PASS` with the image sha256; the WB55 also needs 0 warnings in `src/` and `test/`.
3. **Write the test first** (red): one new case - PlatformIO: a `static void test_<what>(void)` in
   `test_driver.cpp` plus its `RUN_TEST` line; WB55: a case in `test/test_<module>.c` plus
   `RUN_TEST` in that suite (a module meant for every skill: `<repo>/lib/func` + `<repo>/lib/test_func`).
   Set stub inputs before the call, check stub outputs after it. Leave the new behaviour empty.
4. **Run**: `bash "$SKILL/scripts/unit_test.sh" <app>` - it builds and stops with
   `ACTION: APPROVE`. Show the board, app and image hash, **ask the developer**, then re-run with
   `--yes` (skip the question only when the developer wrote `FLASH_POLICY=auto` into the bench file;
   never write it yourself). Red expected: `UNIT: FAIL` naming the new case. A new test that passes
   at once tests nothing - fix the test, not the code.
5. **Green**: the smallest `func/` change, step 4 again -> `UNIT: PASS (n/n, test log agrees)`.
6. **Refactor** with the tests green, run again; then put the app back (`flash.sh <app> --yes`,
   asks first) and run the template's serial spec (`serial_test.py`), so the app still behaves.
7. **Report** red and green runs separately: case, log file `<app>/logs/unit-<stamp>.log`, gate
   line. Record a dated line in the board log only when the developer asks.

## Tools

| Tool | Use |
| --- | --- |
| `$SKILL/scripts/unit_test.sh <app> [--yes] [--build-only \| --read-only]` | build the test image, flash it (asks), read and check the results |
| `--read-only` | only read a test image already on the board (reset or replug first: a finished run sends nothing more; ESP32-S3-BOX after `ACTION: POWER_CYCLE`) |
| `--filter <glob>` (PlatformIO) | `pio test -f`: only some `test/test_*` suites |
| `<repo>/lib/unity_read.py <port> <log> [--timeout S]` | the reader the scripts use: start byte, Unity lines, `TESTLOG:`, gate |
| `<repo>/lib/host_test.sh [<app>]` | optional (M2): `func/` against the host test stub on the PC (`HOST: PASS`), needs a host C compiler |

## Pass criteria

- `UNIT: PASS (n/n, test log agrees)`: Unity's summary with 0 failures, one result line per test,
  and the test log line with `running=0`, `cases` = tests, `failed` = failures, `passed + failed =
  cases`, `last_fail` = Unity's last failing case (`-` when none).
- `UNIT: FAIL (<reason>)` on a failed case, no summary within `--timeout`, lost result lines, no
  `TESTLOG:` line (an old test image: rebuild) or a disagreeing test log.
- TDD evidence = a red run before the change and a green run after it, same case, logs kept.
- Levels stay honest: built (`UNIT-BUILD: PASS`) != flashed != tested (`UNIT: PASS`); a case with
  the test stub proves the module's logic, not the board's LED or button.

## Safety

- Never flash a test image without the developer's yes (or their `FLASH_POLICY=auto`); the test
  image replaces the app until `flash.sh <app> --yes`.
- Cases must not depend on each other's order; `setUp` resets the test stub; a test image never
  writes flash or option bytes.
- Do not edit `milestones.env`; `unit_test.sh` needs M1 active for the board steps.
