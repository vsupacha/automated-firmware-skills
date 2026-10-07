# NUCLEO-C562RE - STM32CubeMX2 profile (cubemx-stm32c5)

Board hardware (tool-independent): [../README.md](../README.md). This file: toolchain facts, tool
quirks and the verification log of the `cubemx-stm32c5` skill. Machine-readable values: `board.env`.

## Toolchain

| Item | Value |
| --- | --- |
| STM32CubeMX2 | 1.1.1, headless CLI (`node <mx>/dist/bin.js`, bundled node 22.22.2+st.1) |
| Board project | `mx project create-from-board --cpn NUCLEO-C562RE --pack-version 2.1.0`, then `peripherals enable USART2 --mode Async` |
| Packs | stm32c5xx_dfp 2.1.0, stm32c5xx_hal_drivers 2.1.0 (HAL2), templates_no_os_stm32c5 2.1.0, nucleo-c562re_hw-board 2.1.0 |
| Generation | `ide-project generate --format CMake --source include-packs-from-local --remove-board --build-target .debug_GCC+NUCLEO-C562RE` |
| Build | CMake 4.4.0+st.1 + Ninja 1.13.2+st.1 + GNU Tools for STM32 14.3.1+st.2, preset `debug_GCC_NUCLEO-C562RE` |
| Flash | STM32CubeProgrammer CLI 2.23.0: `-c port=SWD sn=<probe> mode=UR reset=HWrst -d <elf> -v -rst` |

## Tool quirks

- `ide-project generate` writes the **absolute** destination path into the `.ioc2` (`outputPath`):
  the skill generates from a git-ignored working copy, so the app's `.ioc2` stays shareable.
- The backend (`mx start`) has no stop command; it runs as `stm32cubemx2.exe` (Electron) under a
  node launcher. The skill kills the launcher's process tree (`taskkill /T`) on its own port.
- The USART2 mode is named `Async` (not `Asynchronous`).
- The CLI prints a pack-licence notice line on every call - ignore it when parsing JSON.

## Verification log

- 2026-10-07 board-default project + USART2 Async, generated and built with the pinned tools:
  configure + build OK, 0 warnings (experiment before the skill existed). Board not connected.
- 2026-10-07 skill `cubemx-stm32c5` (MX 1.1.1, packs 2.1.0, GCC 14.3.1+st.2, CMake 4.4.0+st.1,
  Programmer 2.23.0, Windows 11 + Git Bash). discover: ST-LINK V3J16M9 reports board
  NUCLEO-C562RE, device STM32C5x, ID 0x44E, rev Y, 512 KB, 3.29 V - IDENTITY PASS (device ID now
  pinned in board.env).
  - `hello-world` (app `hello-nucleo`): create-from-board + USART2 Async + generate 43 s, build PASS
    0 warnings (text 19,424 B), ELF `52d33f14...`; flash: `Download verified successfully`; test
    PASS 9/9 over the ST-LINK VCP (USART2 polled RX, printf via `_write`).
  - `uart-btn-led` (app `btn-led-nucleo`): build PASS 0 warnings, ELF `5720d6cc...`; flash PASS;
    automatic test PASS 13/13 (LD1 on/off/toggle with GPIO read-back); interactive B1 steps not
    run yet (need a human).
- 2026-10-07 interactive test of `btn-led-nucleo` (spec fixed: LED1 forced off first, LED evidence
  only from the `led?` reply): PASS 5/5 - `OK led1=0`, one B1 press → `EVT btn1=pressed name=B1
  pin=PC13 led1=1`, `EVT btn1=released`, read-back `LED led1=1`. B1 run-time read + debounce and
  LD1 drive verified; the first attempt (before the spec fix) showed two toggles - the spec, not
  the firmware, was at fault. **Observed by the user:** LD1 went dark at the start, lit after the
  single B1 press.
