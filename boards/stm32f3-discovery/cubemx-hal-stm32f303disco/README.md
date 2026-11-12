# STM32F3DISCOVERY - cubemx-hal-stm32f303disco profile

Board profile of the `cubemx-hal-stm32f303disco` skill: `board.env` (pinned STM32CubeMX, firmware
package and bundles, `MX_START`, `MX_CONFIG`, identity gate). Hardware: [../README.md](../README.md).

| Item | Value |
| --- | --- |
| STM32CubeMX | 6.18.1 (classic), headless script mode through its bundled java |
| Firmware package | STM32Cube_FW_F3 V1.11.6 (HAL, CMSIS, BSP STM32F3-Discovery) |
| Starting `.ioc` | `loadboard STM32F3DISCOVERY nomode` (CubeMX board configuration: pins, LD3-LD10, B1, SWD, clocks 48 MHz) |
| `MX_CONFIG` | `set mode SYS Trace_Asynchronous_SW` (SWO on PB3) |
| Generation | `project toolchain CMake` into `<app>/mx` (single project), Windows paths |
| Build | CMake 4.4.0+st.1 + Ninja 1.13.2+st.1 + GNU Tools for STM32 14.3.1+st.2, preset `Debug` |
| Image | `mx/build/Debug/mx.elf` (+ `mx.hex`), internal flash |
| Console | SWO output only (ITM port 0), SYSCLK 48 MHz (board default) |
| User I/O | LD3-LD10 PE8-PE15 and B1 PA0, set up by the generated `MX_GPIO_Init()` |

## Verification log

- 2026-11-12 skill `cubemx-hal-stm32f303disco` created from `cubemx-hal-stm32f407disco` (owner's
  names; board id `stm32f3-discovery`; console SWO as on the F4, owner's choice). Home PC,
  Windows + Git Bash, STM32CubeProgrammer 2.23.0.
  - Board identified read-only: ST-LINK/V2 FW V2J45S0 (no board name, no VCP), device
    STM32F302xB-xC/STM32F303xB-xC/F358xx, ID 0x422, rev Y, Cortex-M4, 2.93 V.
  - check_tools `missing/bad=0`. Create REGEN PASS and build PASS 0 warnings: `blink` (app `bl-f3`,
    ELF `3e9b0c91...`), `hello-world` (`hw-f3`, ELF `85c27da7...`), `push-to-light` (`pt-f3`, ELF
    `dfe4dc88...`). The generated `MX_GPIO_Init()` sets all eight LEDs and B1; clock PLL x12 = 48 MHz.
  - discover `IDENTITY: PASS`. `blink` flashed with the owner's OK: `FLASH: PASS` (download verified
    + reset); the owner saw LD3 (red) blink - **observed**. No SWO reader, so not tested.
  - CubeMX CLI on this board (for the FreeRTOS skill): `set mode SYS TIM6` (HAL timebase) and
    `set mode FREERTOS CMSIS_V2` / `CMSIS_V1` answer OK; `get mode all` does not list middleware.
