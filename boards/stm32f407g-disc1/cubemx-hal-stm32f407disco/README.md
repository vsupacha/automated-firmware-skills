# STM32F407G-DISC1 - cubemx-hal-stm32f407disco profile

Board profile of the `cubemx-hal-stm32f407disco` skill: `board.env` (pinned STM32CubeMX, firmware
package and bundles, `MX_START`, `MX_CONFIG`). Hardware: [../README.md](../README.md).

| Item | Value |
| --- | --- |
| STM32CubeMX | 6.18.1 (classic), headless script mode through its bundled java |
| Firmware package | STM32Cube_FW_F4 V1.28.3 (HAL, CMSIS, BSP STM32F4-Discovery) |
| Starting `.ioc` | `loadboard STM32F407G-DISC1 nomode` (CubeMX board configuration: pins, LD3-LD6, B1, SWD, clocks) |
| `MX_CONFIG` | `set mode SYS Trace_Asynchronous_SW` (SWO on PB3) |
| Generation | `project toolchain CMake` into `<app>/mx` (single project), Windows paths |
| Build | CMake 4.4.0+st.1 + Ninja 1.13.2+st.1 + GNU Tools for STM32 14.3.1+st.2, preset `Debug` |
| Image | `mx/build/Debug/mx.elf` (+ `mx.hex`), internal flash |
| Console | SWO output only (ITM port 0), SYSCLK 25 MHz (board default) |

## Verification log

- 2026-10-07 board identified read-only (STM32CubeProgrammer 2.23.0, hot-plug): ST-LINK/V2 FW
  V2J46S0, device ID 0x413 (STM32F405xx/F407xx/F415xx/F417xx), rev Z, Cortex-M4, 3.23 V.
- 2026-10-07 skill `cubemx-hal-stm32f407disco` created (M1 only; Windows 11 + Git Bash).
  check_tools `missing/bad=0`.
  - `hello-world` (app `hello-f4`): create REGEN PASS, build PASS 0 warnings (text 13,044 B), ELF
    `7c0319f3...`.
  - `uart-btn-led` (app `btn-f4`): create REGEN PASS, build PASS 0 warnings (text 15,648 B), ELF
    `6e81ee0f...`. All app sources compiled with -Wall -Wextra and `-DBOARD_STM32F407G_DISC1`.
  - Nothing flashed (M1); SWO output not yet seen on hardware.
- 2026-10-09 template `uart-btn-led` renamed `push-to-light` (same code apart from the app
  name) - build PASS 0 warnings; new template `blink` (LED1 every 0.5 s) - build PASS 0
  warnings. Both built only, not flashed (the earlier results above were with the old name).
- 2026-10-27 board stages 4 connect + 5 flash added (`discover.sh`, `flash.sh`, from the L475
  skill; no VCP on this ST-LINK, so no console port). Home PC, STM32CubeProgrammer 2.23.0:
  check_tools `missing/bad=0`; discover `IDENTITY: PASS` (ST-LINK/V2 FW V2J46S0 reports no board
  name, device STM32F405xx/F407xx/F415xx/F417xx, ID 0x413, 3.23 V).
  - `blink` (app `blink-f4`, template unchanged): build PASS 0 warnings (text 13,400 B), ELF
    `6f766437...`; flashed with the user's OK: `FLASH: PASS` (download verified + reset). The user
    saw LD3 (orange) blinking - **observed**. No SWO reader, so not tested.
  - Same app with a local change in `app_main.c` only (LED1..LED4 lit one at a time, 0.5 s each):
    build PASS 0 warnings, ELF `85d2b924...`, `FLASH: PASS`; the user saw LD3 orange, LD4 green,
    LD5 red, LD6 blue light in turn - all four LED pins of `board.c` confirmed on hardware. Not a
    repo template.
  - Not checked on hardware: button B1 (push-to-light), SWO output, hello-world.
