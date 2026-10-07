# Stage 3 - Layered code (ESP-IDF)

```
src/app_main.c      execution: app_main() wiring, command table, superloop (yields 1 ms per pass)
  │ uses
src/func/*.c/.h     services from <repo>/lib/func, unchanged: console (line editor + dispatch),
  │ uses             led (1-based, read-back), button (debounce, events) - shared with the
  │                  modus-psoc-e84 and cubemx-stm32c5 skills
src/board/board.*   board adaptation: GPIO numbers, ESP-IDF drivers (gpio, usb_serial_jtag,
  │ uses             esp_timer), FreeRTOS delay, BOARD_xxx #if tables
ESP-IDF 5.5         drivers, FreeRTOS, newlib (printf -> USB Serial/JTAG VFS), bootloader
```

Call chain: ROM → 2nd-stage bootloader → ESP-IDF start-up → FreeRTOS `main` task → `app_main()`.

Rules
- Dependency direction is strictly downward; `func/` and `app_main.c` include no ESP-IDF or
  FreeRTOS headers (`check_layers.py` flags them). Time and yielding go through `board_millis()` and
  `board_delay_ms()`.
- A board difference goes in `board/` (the `#if` I/O tables in board.c, `BOARD_NAME` in board.h) or
  in the board's `sdkconfig.board` - never `#ifdef` in `func/`.
- `app_main()` runs in a FreeRTOS task at priority 1. The superloop must call `board_delay_ms(1)`
  each pass (1 kHz tick from `sdkconfig.defaults`): without it the idle task never runs and the task
  watchdog prints warnings into the console every 5 s. Console input is buffered by the USB driver,
  so the 1 ms sleep loses nothing.
- Output: `printf()` goes through the USB Serial/JTAG driver; with no host reading, output is
  dropped after 50 ms instead of blocking. TX line endings are left as written: send `\r\n`.
- Everything in `src/` is compiled with `-Wall -Wextra` (src/CMakeLists.txt); the build gate allows
  0 warnings there.
- Larger features (Wi-Fi, LCD, audio): wrap the ESP-IDF driver/component in `board/` (or a new
  board-level module) and expose a small C API; tasks of their own belong to the execution layer.

## Console protocol (test contract)

| Line | Meaning |
| --- | --- |
| `READY` | boot finished, accepting commands (printed after `INFO ...`) |
| `INFO app=<name> v=<ver> board=<id> ...` | identity - the test checks `board=<id>` |
| `OK ...` / `ERR <reason>` | command result |
| `EVT ...` | asynchronous event (`EVT btn1=pressed name=BOOT pin=GPIO0 led1=1`) |
| `<TAG> k=v ...` | state report (`LED led1=0`, `BTN btn1=0`) |

ESP-IDF's own boot messages (`I (123) ...`) appear before `[APP]`; tests sync with `info`.
