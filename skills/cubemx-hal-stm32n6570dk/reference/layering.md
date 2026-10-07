# Stage 3 - Layered code (STM32N6, CubeMX + HAL)

```
src/app_main.c      application: app_main() wiring, command table, policies
  │ uses
src/func/*.c/.h     services from <repo>/lib/func (console, led, button) - shared unchanged with
  │ uses             the modus-pdl-edgitalk, cubemx2-hal2-stm32c562nucleo and pio-espidf-esp32s3box skills
src/board/board.*   board adaptation: SMPS overdrive pin, LED/button GPIO tables (HAL), console
  │ uses             on the generated huart1 (TX via HAL, RX polled), _write() for printf
mx/ (generated)     main(): caches, HAL_Init, SystemClock_Config (800 MHz), MX_GPIO_Init,
                    MX_USART1_UART_Init; STM32CubeN6 HAL, CMSIS, startup, AXISRAM2 linker script
```

Call chain (mx/FSBL/Src/main.c, overlay in USER CODE sections):
`main()` → caches → `HAL_Init()` → **`board_early_init()`** (USER CODE Init: SMPS overdrive) →
`SystemClock_Config()` → `MX_GPIO_Init()` → `MX_USART1_UART_Init()` → **`app_main()`**
(USER CODE 2, never returns) → `board_init()` → services.

Rules
- Dependency direction is strictly downward; `func/` and `app_main.c` never include HAL headers.
- A board difference goes in `board/` (an `#elif` I/O table) or in the board's `.ioc` - never
  `#ifdef` in `func/`.
- Hardware owned by CubeMX (clocks, peripherals, their pins) is configured in `<app>.ioc` (FSBL
  context) and used through the generated handle (`huart1`); simple user I/O is configured at run
  time in `board.c`.
- `src/**/*.c` is compiled into the FSBL target with `-Wall -Wextra` (overlay in
  `mx/FSBL/CMakeLists.txt`); the build gate allows 0 warnings there.
- The image runs from internal SRAM (AXISRAM2, 255 KB for the FSBL); keep it small.
- The console UART is polled: keep the main loop non-blocking, time things with `board_millis()`.

## Console protocol (test contract)

| Line | Meaning |
| --- | --- |
| `READY` | boot finished, accepting commands (printed after `INFO ...`) |
| `INFO app=<name> v=<ver> board=<id> ...` | identity - the test checks `board=<id>` |
| `OK ...` / `ERR <reason>` | command result |
| `EVT ...` | asynchronous event (`EVT btn1=pressed name=USER1 pin=PC13 led1=1`) |
| `<TAG> k=v ...` | state report (`LED led1=0 led2=0`, `BTN btn1=0`) |
