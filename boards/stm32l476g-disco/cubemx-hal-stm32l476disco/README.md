# STM32L476G-DISCO - cubemx-hal-stm32l476disco profile

Board profile of the `cubemx-hal-stm32l476disco` skill: `board.env` (pinned STM32CubeMX, firmware package and bundles,
`MX_START`, `MX_CONFIG`, identity gate). Hardware: [../README.md](../README.md).

| Item | Value |
| --- | --- |
| STM32CubeMX | 6.18.1 (classic), headless script mode through its bundled java |
| Firmware package | STM32Cube_FW_L4 V1.18.2 (HAL, CMSIS, BSP STM32L476G-Discovery) |
| Starting `.ioc` | `loadboard STM32L476G-DISCO nomode` (CubeMX board configuration: pins, joystick, LEDs, SWD; MSI 4 MHz) |
| `MX_CONFIG` | `set mode USART2 Asynchronous`, `set pin PD5 USART2_TX`, `set pin PD6 USART2_RX` (ST-LINK VCP, 115200 8N1) |
| Generation | `project toolchain CMake` into `<app>/mx` (single project), Windows paths |
| Build | CMake 4.4.0+st.1 + Ninja 1.13.2+st.1 + GNU Tools for STM32 14.3.1+st.2, preset `Debug` |
| Console | USART2 on the ST-LINK/V2-1 virtual COM port (`huart2`), RX by interrupt into a ring buffer |
| User I/O | LD4 PB2, LD5 PE8; joystick center/left/right/up/down PA0/PA1/PA2/PA3/PA5 (configured in `board_init()`) |

## Verification log

- 2026-11-12 skill `cubemx-hal-stm32l476disco` created from `cubemx-hal-stm32l475iot` (owner's names; board id
  `stm32l476g-disco`; prefix `L476_`, app record `l476-app.env`). Home PC, Windows + Git Bash.
  - Board identified read-only: ST-LINK/V2-1 FW V2J32M22, board name `STM32L476G-DK`, device
    STM32L4x1/STM32L475xx/STM32L476xx/STM32L486xx, ID 0x415, rev 4, 3.23 V, VCP present.
  - `loadboard STM32L476G-DISCO nomode` + `set mode USART2 Asynchronous` + PD5/PD6 answer OK (no
    `clearpinout` needed, unlike the WB55); generated clock MSI range 6 = 4 MHz.
  - check_tools `missing/bad=0`. Create REGEN PASS and build PASS 0 warnings: `blink` (app `bl-l476`,
    ELF `ac2a292e...`), `hello-world` (`hw-l476`, `51e3dd84...`), `push-to-light` (`pt-l476`, `7fd139e6...`).
  - discover `IDENTITY: PASS` with 3 ST-LINKs plugged in (picked by board name). `push-to-light`
    flashed with the owner's OK: `FLASH: PASS`; serial test **RESULT: PASS (16/16, 4 skipped)** -
    LD4/LD5 on/off/toggle and read-back, errors, buttons released; the 4 interactive joystick steps
    were not run. `debug.sh status`: Cortex-M4 r0p1 running, fault none.
