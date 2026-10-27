# lib - code shared by every skill

| Path | Used by | What |
| --- | --- | --- |
| `common.sh` | every `skills/*/scripts/env.sh` | board profile lookup (project before repo), path safety, `need_user` (`ACTION:` + exit 10), `.gitignore` merging |
| `fwtest.py` | every `skills/*/scripts/serial_test.py` (thin wrapper) | Stage 6 engine: data-driven serial tests from `tests/*.json` |
| `fw_workspace.sh` | the developer / agent, once per PC (`new_app.sh` asks with `ACTION: CHOOSE`) | this PC's apps workspace: `show`, `set <dir>`, `unset` (`~/.fw-skills.env`, never in git) |
| `fwpaths.py` | `fwtest.py`, sensor-debug, web-wizard | the same apps-workspace and `.bench/` rules as `common.sh`, for Python |
| `func/` | modus-pdl-edgitalk, cubemx2-hal2-stm32c562nucleo (`new_app.sh` copies it into each app) | logic layer in portable C: console, led, button - depends only on `board.h`; gesture (short / long / double click) - pure, no `board.h` |
| `check_layers.py` | stage 9 (M2), any skill's app | include / vendor-call / `#if BOARD_*` rules per layer: `LAYERS: PASS` |
| `func_dsp/` | opt-in: `unit_test.sh` (WB55) copies it into `<app>/src/func/`; not copied by `new_app.sh` | func/ modules that need CMSIS-DSP (Cortex-M + a build that compiles CMSIS-DSP): fxscale (float -> q31 -> scale -> float, < 1 % error) |
| `unity/` | `unit_test.sh` of the C skills (copied into `<app>/test/unity`) | Unity 2.6.1, pinned copy (MIT; hashes in `unity/README.md`) |
| `test_func/` | `unit_test.sh` of the C skills (copied into `<app>/test/` when missing) | on-target test runner `unit_main.c` (start-byte handshake, owns `setUp`/`tearDown`, `unit.h`) + Unity suites of `func/` (`test_gesture.c`, `test_fxscale.c`) |
| `unity_read.py` | `unit_test.sh` of the C skills | reads one Unity run from the board's console after sending the start byte: `UNITY: <tests> <failures> <ignored>` |
| `host_test.sh`, `host/` | stage 10 (M2, optional) | builds `func/` (default `lib/func`) with the fake board `host/board.h` and runs `host/test_func.c` on the PC: `HOST: PASS` |

`func/` is the portable middle layer of the architecture (docs/workflow.md, M2; the `board.h`
contract is docs/board-api.md): it may include
only `board.h` and the C library - and, on Cortex-M boards, CMSIS-DSP (`arm_math.h`; rule and
reasons in docs/board-api.md). Such modules live in `func_dsp/`, not `func/`: `new_app.sh` of every C skill copies
all of `func/` into each app, and only the WB55 skill's build compiles CMSIS-DSP so far.
`check_layers.py` fails these includes on non-Cortex-M boards. A new skill implements `board.h` for its boards and reuses
`func/` unchanged. pio-arduino-rpipico2w still has C++ copies (templates/_common/src/func) - to be
merged here.
