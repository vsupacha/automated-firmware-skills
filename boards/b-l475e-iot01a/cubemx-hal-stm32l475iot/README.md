# B-L475E-IOT01A - cubemx-hal-stm32l475iot profile

Board profile of the `cubemx-hal-stm32l475iot` skill: `board.env` (pinned STM32CubeMX, firmware
package and bundles, `MX_START`, `MX_CONFIG`, identity gate). Hardware: [../README.md](../README.md).

| Item | Value |
| --- | --- |
| STM32CubeMX | 6.18.1 (classic), headless script mode through its bundled java |
| Firmware package | STM32Cube_FW_L4 V1.18.2 (HAL, CMSIS, BSP B-L475E-IOT01) |
| Starting `.ioc` | `loadboard B-L475E-IOT01A1 nomode` (CubeMX board configuration: pin labels, clocks 80 MHz, SWD) |
| `MX_CONFIG` | `set mode USART1 Asynchronous`, `set pin PB6 USART1_TX`, `set pin PB7 USART1_RX` (ST-LINK VCP, 115200 8N1) |
| Generation | `project toolchain CMake` into `<app>/mx` (single project), Windows paths |
| Build | CMake 4.4.0+st.1 + Ninja 1.13.2+st.1 + GNU Tools for STM32 14.3.1+st.2, preset `Debug` |
| Image | `mx/build/Debug/mx.elf` (+ `mx.hex`), internal flash |
| Console | USART1 on the ST-LINK/V2-1 virtual COM port (`huart1`), console input by polling |
| User I/O | LED2 PB14, B1 USER PC13 (configured in `board_init()`, not only by `MX_GPIO_Init()`) |

## Verification log

- 2026-10-07 skill `cubemx-hal-stm32l475iot` created from `cubemx-hal-stm32f407disco` (classic
  CubeMX) + the C5 skill's M3 scripts (ST-LINK + VCP). check_tools `missing/bad=0` (CubeMX 6.18.1
  found as a LOCAL per-user install).
- 2026-10-07 `uart-btn-led` (app `iot-l475`): create REGEN PASS in 24 s; the generated project has
  USART1 Asynchronous on PB6/PB7 (AF7, 115200, `huart1`), SYSCLK 80 MHz, the `app_main()` hook.
  Opened in VS Code: STM32CubeIDE for VS Code 3.11.0 configured `mx/` with cube-cmake and GCC
  14.3.1+st.2 into `mx/build/Debug` and set up code indexing, no prompt. Developer editing by hand
  (IDE path); not built by the scripts yet, nothing flashed.
- 2026-10-08 M3 on hardware (Windows 11 + Git Bash, `FW_ACTIVE_MILESTONES="M1 M3"` for the session):
  - discover.sh: ST-LINK/V2-1 FW V2J46M32, board `STM32L4IO`, device
    `STM32L4x1/STM32L475xx/STM32L476xx/STM32L486xx`, ID 0x415, 3.23 V, VCP found -> `IDENTITY: PASS`
    (the first run failed on a wrong `EXPECTED_DEVICE_NAME` guess; the profile now holds the values read).
  - `iot-l475` (uart-btn-led, template code unchanged) build PASS 0 warnings, ELF `69b04e19...`,
    `FLASH: PASS`; serial test **FAIL** 6/13: RX bytes dropped ("led 1 off" -> "led 1 of") - board.c
    polled RDR while the echo blocked TX, and the L4 USART has no RX FIFO.
  - Fix in the skill template: RXNE interrupt into a 256-byte ring buffer (`USART1_IRQHandler` in
    board.c). Build PASS 0 warnings, LAYERS PASS, ELF `7c8a8c5a...`, `FLASH: PASS` (verified + reset).
  - serial test **RESULT: PASS 13/13** (7 skipped: one LED, one button, interactive steps).
  - interactive **RESULT: PASS 5/5**: B1 USER pressed by the owner -> `EVT btn1=pressed name=B1
    pin=PC13 led1=1`; the owner saw LED2 on after the press.
- 2026-10-09 template `uart-btn-led` renamed `push-to-light` (same code apart from the app
  name) - build PASS 0 warnings; new template `blink` (LED1 every 0.5 s) - build PASS 0
  warnings. Both built only, not flashed (the earlier results above were with the old name).
