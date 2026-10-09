# STM32N6570-DK - cubemx-hal-stm32n6570dk profile

Board profile of the `cubemx-hal-stm32n6570dk` skill: `board.env` (pinned STM32CubeMX, firmware
package and bundles, `MX_TEMPLATE_IOC`, `MX_CONFIG`). Hardware: [../README.md](../README.md).

| Item | Value |
| --- | --- |
| STM32CubeMX | 6.18.1 (classic), headless script mode through its bundled java |
| Firmware package | STM32Cube_FW_N6 V1.4.1 (HAL, CMSIS, BSP STM32N6570-DK) |
| Starting `.ioc` | `Projects/STM32N6570-DK/Templates/Template/Template.ioc` of the package: FSBL only, FullSecure, 800 MHz |
| `MX_CONFIG` | `set context FSBL USART1`, `set mode USART1 Asynchronous`, `set pin PE5 USART1_TX`, `set pin PE6 USART1_RX` |
| Generation | `project toolchain CMake` into `<app>/mx` (top level + `FSBL/` external project), Windows paths |
| Build | CMake 4.4.0+st.1 + Ninja 1.13.2+st.1 + GNU Tools for STM32 14.3.1+st.2, preset `Debug` |
| Image | `mx/FSBL/build/mx_FSBL.elf`, linked for AXISRAM2 (255 KB FSBL region) |

## Verification log

- 2026-10-07 skill `cubemx-hal-stm32n6570dk` created (M1 only; Windows 11 + Git Bash). Board not
  connected - nothing run on hardware.
  - `hello-world` (app `hello-n6`): create (one CubeMX run) REGEN PASS, build PASS 0 warnings
    (text 55,600 B), ELF `cc9034c7...`; `regen.sh` re-run: overlay idempotent, rebuild PASS; a planted
    unused variable gave `BUILD: WARNINGS` (exit 2) as intended.
  - `uart-btn-led` (app `btn-n6`): create REGEN PASS, build PASS 0 warnings (text 58,188 B), ELF
    `b00b2d83...`.
  - LED/button polarity and the SMPS overdrive pin taken from the STM32CubeN6 BSP, not yet seen on
    hardware.
- 2026-10-07 first contact with the board (read-only, STM32CubeProgrammer 2.23.0): hot-plug connect
  fails ("Unable to get core ID") in flash boot and in development boot; with BOOT1 at 1-3, reset,
  then connect under reset (`mode=UR reset=HWrst`): device ID 0x486, STM32N6xx rev Z, Cortex-M55,
  3.29 V. VS Code debug failed before the switch change ("Error in initializing ST-LINK device").
  Input for the board stages: discover/flash must connect under reset and check the boot mode first.
- 2026-10-09 template `uart-btn-led` renamed `push-to-light` (same code apart from the app
  name); new template `blink` (LED1 every 0.5 s) - not built yet (STM32Cube_FW_N6 is not
  installed on the PC that made the change).
