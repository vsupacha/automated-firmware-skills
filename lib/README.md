# lib - code shared by every skill

| Path | Used by | What |
| --- | --- | --- |
| `common.sh` | every `skills/*/scripts/env.sh` | board profile lookup (project before repo), path safety, `need_user` (`ACTION:` + exit 10), `.gitignore` merging |
| `fwtest.py` | every `skills/*/scripts/serial_test.py` (thin wrapper) | Stage 8 engine: data-driven serial tests from `tests/*.json` |
| `func/` | modus-psoc-e84, cubemx-stm32c5 (`new_app.sh` copies it into each app) | logic layer in portable C: console, led, button - depends only on `board.h` |
| `check_layers.py` | stage 4 (M2), any skill's app | include / vendor-call / `#if BOARD_*` rules per layer: `LAYERS: PASS` |
| `host_test.sh`, `host/` | stage 5 (M2) | builds `func/` (default `lib/func`) with the fake board `host/board.h` and runs `host/test_func.c` on the PC: `HOST: PASS` |

`func/` is the portable middle layer of the architecture (docs/workflow.md, M2; the `board.h`
contract is docs/board-api.md): it may include
only `board.h` and the C library. A new skill implements `board.h` for its boards and reuses
`func/` unchanged. pio-rpi-pico-2w still has C++ copies (templates/_common/src/func) - to be
merged here.
