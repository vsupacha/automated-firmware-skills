# Stage 3 - Layered code

```
src/app_main.c      application: app_main() wiring, command table, policies
  │ uses
src/func/*.c/.h     services: console (line editor + dispatch), led (1-based, read-back),
  │ uses             button (debounce, events) - identical to the modus-psoc-e84 skill's func/
src/board/board.*   board adaptation: GPIO ports/pins, HAL2 + LL calls, BOARD_xxx #ifdefs,
  │ uses             console UART (TX via HAL, RX polled via LL), _write() for printf
mx/ (generated)     mx_system_init(): clocks, USART2 + pins, HAL init; HAL2/LL drivers, CMSIS
```

Call chain: generated `main()` → `mx_system_init()` → `app_main()` (inserted by `regen.sh`).

Rules
- Dependency direction is strictly downward; `func/` and `app_main.c` never include HAL/LL headers.
- A board difference goes in `board/` (an `#elif` user-I/O table) or in the board's `.ioc2`
  configuration - never `#ifdef` in `func/`.
- Hardware owned by CubeMX (clocks, peripherals, their pins) is configured in the `.ioc2` and used
  through the generated `mx_<periph>_..._gethandle()`; simple user I/O may be configured at run
  time in `board.c` (documented there).
- `src/**/*.c` is picked up automatically (CMake glob, re-configured on new files); folders under
  `src/` are include paths only for `src/`, `src/board`, `src/func` - include others relatively.
- Everything in `src/` is compiled with `-Wall -Wextra`; the build gate allows 0 warnings there.
- The main loop must not block: the console UART is polled (1 byte buffer at 115200 baud ≈ 87 µs
  per character). Time things with `board_millis()`, not delays.

## Console protocol (test contract)

| Line | Meaning |
| --- | --- |
| `READY` | boot finished, accepting commands (printed after `INFO ...`) |
| `INFO app=<name> v=<ver> board=<id> ...` | identity - the test checks `board=<id>` |
| `OK ...` / `ERR <reason>` | command result |
| `EVT ...` | asynchronous event (`EVT btn1=pressed name=B1 pin=PC13 led1=1`) |
| `<TAG> k=v ...` | state report (`LED led1=0`, `BTN btn1=0`) |

## Adding a peripheral (recipe)

1. Enable it in `<app>.ioc2` (STM32CubeMX2 GUI, or `mx peripherals enable` / `mx pinout ...`).
2. `regen.sh <app>` - the generated `mx_<periph>.c/.h` appear under `mx/generated/hal/`.
3. Wrap it in `board/` (`board_xxx()` using the generated handle getter).
4. Add a `func/xxx.c/.h` service if it is reusable; register console commands in `app_main.c`.
5. Add test steps to `tests/<app>.json`; build, flash, test.
