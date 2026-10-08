# board.h - the port boundary

`board.h` is the only interface between the logic layer (`lib/func`, copied into each app as
`func/`) and the hardware. Every skill implements it once per board under
`skills/<skill>/templates/_common/.../board/`; `func/` and the execution layer (`main` /
`app_main`) use nothing else. A new board or toolchain is ported when its `board.h` passes the
host tests' expectations below on the PC and the shared `tests/*.json` on the board.

```
execution   main / app_main      may use board.h + func/*.h + the C library
logic       func/  (lib/func)    may use board.h + the C library only
board       board/ (board.h)     this contract; vendor headers stay in board.c
BSP/driver  generated / vendor   never edited
```

## Required API (C, `extern "C"`-safe)

| Item | Meaning |
| --- | --- |
| `BOARD_NAME` | board id string, e.g. `"nucleo-c562re"` - printed in the `INFO` line, tests check `board=<id>` |
| `BOARD_MAX_LEDS`, `BOARD_MAX_BUTTONS` | upper bounds for static tables in `func/` |
| `void board_init(void)` | user I/O + console; after the BSP/generated init |
| `void board_delay_ms(uint32_t ms)` | blocking delay - only for start-up, never in the main loop |
| `uint32_t board_millis(void)` | ms since reset or `board_init`, wraps at 2^32 |
| `void board_fatal(void)` | stop on an unrecoverable error |
| `uint32_t board_led_count(void)` | number of user LEDs |
| `void board_led_write(uint32_t idx, bool on)` | **0-based** index; out of range is ignored |
| `bool board_led_read(uint32_t idx)` | state of the LED: pin read-back where the hardware allows, else the last written state (say so in board.c) |
| `const char *board_led_name(uint32_t idx)` | silkscreen name (`"LD1"`, `"LED1"`) |
| `uint32_t board_button_count(void)` | number of user buttons |
| `bool board_button_is_pressed(uint32_t idx)` | **0-based**, raw level (not debounced), `true` = pressed whatever the polarity |
| `const char *board_button_name(uint32_t idx)` | silkscreen name (`"B1"`, `"SW2"`, `"BOOTSEL"`) |
| `const char *board_button_pin(uint32_t idx)` | pin for reports (`"PC13"`, `"P8.3"`) |
| `bool board_console_getc(char *c)` | non-blocking read; `true` if a byte was read |
| `void board_console_flush(void)` | wait until pending console output is sent |
| `printf()` / `putchar()` | reach the console (retarget in board.c) |

Numbering: `board_*` functions are 0-based (`idx`); `func/` services are 1-based (`num`) like the
silkscreen, so console commands and tests say `led 1`, `btn1`.

## Optional extensions (board-specific, used only by that skill's execution layer)

| Skill | Function | Why |
| --- | --- | --- |
| modus-pdl-edgitalk | `board_start_cm55()` | boot the second core (dual-core apps) |
| modus-pdl-edgitalk | `board_button_diag(idx)` | drive mode / HSIOM / levels of a button pin |

`func/` must not call extensions; an execution layer that does is tied to that skill.

## Current implementations

| Skill | Implementation | Status |
| --- | --- | --- |
| modus-pdl-edgitalk | `templates/_common/proj_cm33_ns/board/board.c` | conforms |
| cubemx2-hal2-stm32c562nucleo | `templates/_common/src/board/board.c` | conforms |
| pio-arduino-rpipico2w | `templates/_common/src/board/board.cpp` | **differs** - 1-based `n`, `board_button_read`, no `board_led_read` / `board_led_name` / `board_button_pin` / `board_console_flush`, `BOARD_ID_NAME`, console via `Print &board_console()`; uses a C++ copy of func. To be merged into this contract and `lib/func`. |
| host (fake) | `lib/host/board.h`, `board_fake.c` | conforms - drives `host_test.sh` |

## Checks

- `lib/host_test.sh` (stage 10, optional) compiles `lib/func` or an app's `func/` against the fake board and
  runs the unit tests: `HOST: PASS`.
- `lib/check_layers.py` (stage 9) checks the include and `#if BOARD_*` rules above in an app:
  `LAYERS: PASS`.
