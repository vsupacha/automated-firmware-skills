# Stage 3 - Layered code (STM32F4, CubeMX + HAL)

```
src/app_main.c      application: app_main() wiring, command table, policies
  │ uses
src/func/*.c/.h     services from <repo>/lib/func (console, led, button) - shared unchanged with
  │ uses             the other C skills
src/board/board.*   board adaptation: LED/button table on the generated GPIO setup, console glue
  │ uses             (_write -> ITM_SendChar = SWO; no input)
mx/ (generated)     main(): HAL_Init, SystemClock_Config (board default, 25 MHz), MX_GPIO_Init
                    (LD3-LD6 outputs, B1 input, SWO on PB3); STM32CubeF4 HAL, CMSIS, startup,
                    flash linker script
```

Call chain (mx/Src/main.c, overlay in USER CODE sections):
`main()` → `HAL_Init()` → `SystemClock_Config()` → `MX_GPIO_Init()` → **`app_main()`** (USER CODE 2,
never returns) → `board_init()` (all LEDs off) → services.

Rules
- Dependency direction is strictly downward; `func/` and `app_main.c` never include HAL headers.
- A board difference goes in `board/` (an `#elif` I/O table) or in the board's `.ioc` - never
  `#ifdef` in `func/`.
- Hardware owned by CubeMX (clocks, pins, peripherals) is configured in `<app>.ioc`; on this board
  even the LED/button pins come from the CubeMX board configuration.
- `src/**/*.c` is compiled into the target with `-Wall -Wextra` (overlay in `mx/CMakeLists.txt`);
  the build gate allows 0 warnings there.
- Console = SWO output only: `printf()` reaches the debugger's SWV/ITM view (port 0) when a
  debugger has SWO enabled with the core clock of the profile (`SYSCLK_HZ`, 25 MHz). Without a
  viewer, output is discarded. `board_console_getc()` never returns data - console commands are
  unavailable on this board; keep the main loop non-blocking anyway (portable code).

## Console protocol (test contract)

| Line | Meaning |
| --- | --- |
| `READY` | boot finished (printed after `INFO ...`) |
| `INFO app=<name> v=<ver> board=<id> ...` | identity - a test checks `board=<id>` |
| `OK ...` / `ERR <reason>` | command result (not reachable here: no input) |
| `EVT ...` | asynchronous event (`EVT btn1=pressed name=B1 pin=PA0 led1=1`) |
| `<TAG> k=v ...` | state report (`LED led1=0 ...`, `BTN btn1=0`) |
