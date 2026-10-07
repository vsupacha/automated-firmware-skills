# Stage 3 - Layered code (STM32L4, CubeMX + HAL)

```
src/app_main.c      application: app_main() wiring, command table, policies
  │ uses
src/func/*.c/.h     services from <repo>/lib/func (console, led, button) - shared unchanged with
  │ uses             the other C skills
src/board/board.*   board adaptation: LED2/B1 table and pin setup, console glue
  │ uses             (_write -> HAL_UART_Transmit on huart1; RX: USART1 RXNE interrupt -> ring buffer)
mx/ (generated)     main(): HAL_Init, SystemClock_Config (board default, 80 MHz), MX_GPIO_Init,
                    MX_USART1_UART_Init (PB6/PB7, 115200 8N1); STM32CubeL4 HAL, CMSIS, startup,
                    flash linker script
```

Call chain (mx/Src/main.c, overlay in USER CODE sections):
`main()` → `HAL_Init()` → `SystemClock_Config()` → `MX_GPIO_Init()` → `MX_USART1_UART_Init()` →
**`app_main()`** (USER CODE 2, never returns) → `board_init()` (LED2 off, B1 input with pull-up,
console RX interrupt on) → services.

Rules
- Dependency direction is strictly downward; `func/` and `app_main.c` never include HAL headers.
- A board difference goes in `board/` (an `#elif` I/O table) or in the board's `.ioc` - never
  `#ifdef` in `func/`.
- Hardware owned by CubeMX (clocks, peripherals) is configured in `<app>.ioc`. The LED and button
  pins are also set up in `board_init()`, so they work whatever `loadboard ... nomode` keeps.
- `src/**/*.c` is compiled into the target with `-Wall -Wextra` (overlay in `mx/CMakeLists.txt`);
  the build gate allows 0 warnings there.
- Console RX: the STM32L4 USART has **no RX FIFO** (one byte in RDR). Polling it while the
  console echoes with blocking TX drops bytes ("led 1 off" arrived as "led 1 of", 2026-10-08), so
  `board.c` owns `USART1_IRQHandler` and fills a 256-byte ring buffer; `board_console_getc()`
  reads from it. Keep the USART1 global interrupt **disabled** in the `.ioc` NVIC page - otherwise
  CubeMX generates a second `USART1_IRQHandler` in `stm32l4xx_it.c` and the link fails.

## Console protocol (test contract)

| Line | Meaning |
| --- | --- |
| `READY` | boot finished (printed after `INFO ...`) |
| `INFO app=<name> v=<ver> board=<id> ...` | identity - a test checks `board=<id>` |
| `OK ...` / `ERR <reason>` | command result |
| `EVT ...` | asynchronous event (`EVT btn1=pressed name=B1 pin=PC13 led1=1`) |
| `<TAG> k=v ...` | state report (`LED led1=0`, `BTN btn1=0`) |
