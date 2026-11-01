# lib - code shared by every skill

| Path | Used by | What |
| --- | --- | --- |
| `common.sh` | every `skills/*/scripts/env.sh` | board profile lookup (project before repo), path safety, `need_user` (`ACTION:` + exit 10), `.gitignore` merging |
| `fwtest.py` | every `skills/*/scripts/serial_test.py` (thin wrapper) | Stage 6 engine: data-driven serial tests from `tests/*.json` |
| `fw_workspace.sh` | the developer / agent, once per PC (`new_app.sh` asks with `ACTION: CHOOSE`) | this PC's apps workspace: `show`, `set <dir>`, `unset` (`~/.fw-skills.env`, never in git) |
| `msh.py` | `fwtest.py` (cfg `command_list: "msh"`), the RT-Thread skills (now in automated-firmware-skills-rtthread) | RT-Thread msh console: wait for the prompt, run a command, parse `help` (exported commands), `ps`, `free`, `list device`, `version` (5.0.2 formats) |
| `fwpaths.py` | `fwtest.py`, sensor-debug, web-wizard | the same apps-workspace and `.bench/` rules as `common.sh`, for Python |
| `func/` | modus-pdl-edgitalk, cubemx2-hal2-stm32c562nucleo (`new_app.sh` copies it into each app) | logic layer in portable C: console, led, button - depends only on `board.h`; gesture (short / long / double click) - pure, no `board.h` |
| `check_layers.py` | stage 9 (M2), any skill's app | include / vendor-call / `#if BOARD_*` rules per layer: `LAYERS: PASS` |
| `func_dsp/` | opt-in: `unit_test.sh` (WB55) copies it into `<app>/src/func/`; not copied by `new_app.sh` | func/ modules that need CMSIS-DSP (Cortex-M + a build that compiles CMSIS-DSP): fxscale (float -> q31 -> scale -> float, < 1 % error) |
| `unity/` | `unit_test.sh` of the C skills (copied into `<app>/test/unity`) | Unity 2.6.1, pinned copy (MIT; hashes in `unity/README.md`) |
| `test_func/` | `unit_test.sh` of the C skills (runner + test log refreshed in `<app>/test/` on every run, suites copied when missing); `test_log.c/.h` also copied unchanged into the PlatformIO skills' `templates/_common/test/test_func/` | on-target test runner `test_driver_main.c` (start-byte handshake, owns `setUp`/`tearDown`, `test_driver.h`, prints `TESTLOG:` then `UNIT-DONE`), test log `test_log.c/.h` (`fw_test_log`, magic `FWTL`), Unity suites = test driver cases of `func/` (`test_gesture.c`, `test_fxscale.c`, with their own test stubs) - terms: [docs/workflow.md](../docs/workflow.md#firmware-tests-stage-6-unit-tests-and-tdd) |
| `unity_read.py` | `unit_test.sh` of every skill with unit tests (WB55, Pico 2 W, ESP32-S3-BOX) | reads one Unity run from the board's console after sending the start byte, checks it against the `TESTLOG:` line (counts, `running=0`, `last_fail`, no lost result lines) and prints the gate `UNIT: PASS (n/n, test log agrees)` / `UNIT: FAIL (...)` |
| `host_test.sh`, `host/` | stage 10 (M2, optional) | builds `func/` (default `lib/func`) with the test stub `host/board.h` + `host/test_stub.c` and runs `host/test_func.c` on the PC: `HOST: PASS` |

`func/` is the portable middle layer of the architecture (docs/workflow.md, M2; the `board.h`
contract is docs/board-api.md): it may include
only `board.h` and the C library - and, on Cortex-M boards, CMSIS-DSP (`arm_math.h`; rule and
reasons in docs/board-api.md). Such modules live in `func_dsp/`, not `func/`: `new_app.sh` of every C skill copies
all of `func/` into each app, and only the WB55 skill's build compiles CMSIS-DSP so far.
`check_layers.py` fails these includes on non-Cortex-M boards. A new skill implements `board.h` for its boards and reuses
`func/` unchanged. pio-arduino-rpipico2w still has C++ copies (templates/_common/src/func) - to be
merged here.
