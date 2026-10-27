# NUCLEO-WB55RG - cubemx-hal-stm32wb55nucleo profile

Board profile of the `cubemx-hal-stm32wb55nucleo` skill: `board.env` (pinned STM32CubeMX, firmware
package and bundles, `MX_START`, `MX_CONFIG`, identity gate). Hardware: [../README.md](../README.md).

| Item | Value |
| --- | --- |
| STM32CubeMX | 6.18.1 (classic), headless script mode through its bundled java |
| Firmware package | STM32Cube_FW_WB V1.24.0 (HAL, CMSIS, BSP P-NUCLEO-WB55.Nucleo) |
| Starting `.ioc` | `loadboard NUCLEO-WB55RG nomode` (CubeMX board configuration: board BSP entry, clocks 32 MHz) |
| `MX_CONFIG` | `clearpinout`, `set mode USART1 Asynchronous`, `set pin PB6 USART1_TX`, `set pin PB7 USART1_RX` (ST-LINK VCP, 115200 8N1) |
| Generation | `project toolchain CMake` into `<app>/mx` (single CM4 project), Windows paths |
| Build | CMake 4.4.0+st.1 + Ninja 1.13.2+st.1 + GNU Tools for STM32 14.3.1+st.2, preset `Debug` |
| Image | `mx/build/Debug/mx.elf` (+ `mx.hex`), internal flash from 0x08000000 (linker script: 512 KB) |
| Console | USART1 on the ST-LINK/V2-1 virtual COM port (`huart1`), RX by interrupt into a ring buffer |
| User I/O | LED1 PB5, LED2 PB0, LED3 PB1, SW1 PC4, SW2 PD0, SW3 PD1 (configured in `board_init()`) |

## Verification log

- 2026-10-27 skill `cubemx-hal-stm32wb55nucleo` created from `cubemx-hal-stm32l475iot` (owner's
  names; M1 incl. board stages, no debug.sh yet). Home PC, Windows 11 + Git Bash.
  - STM32CubeMX2 1.1.2 checked first: board listed, WB packs "metadata only - incompatible",
    `project create-from-board --cpn NUCLEO-WB55RG` = "Board not found" - classic CubeMX instead.
  - CubeMX: after `loadboard NUCLEO-WB55RG nomode`, `set mode USART1 Asynchronous` = KO (also
    with `allmodes`, which leaves USART1 out; OK after `load STM32WB55RGVx`). `clearpinout` first
    makes it OK, with the board and clocks kept. Generated SYSCLK = MSI 32 MHz.
  - check_tools `missing/bad=0`. Create REGEN PASS and build PASS 0 warnings: `hello-world`
    (app `hello-wb`, text 22,032 B, ELF `29003e56...`), `blink` (`blink-wb`, ELF `e153980a...`),
    `push-to-light` (`ptl-wb`, ELF `2b2618ec...`).
  - discover `IDENTITY: PASS` with 2 ST-LINKs plugged in (picked by board name `P-NUCLEO-WB55`):
    FW V2J45M31, device STM32WB5x/35xx, ID 0x495 rev Y, 3.27 V, VCP found. Option bytes read
    only: RDP Level 0, SFSA 0x080CE000, ESE 1.
  - `hello-world` flashed with the owner's OK: `FLASH: PASS` (download verified + reset; the
    board's earlier CM4 image is overwritten, the wireless stack is untouched), serial test
    `RESULT: PASS (9/9 passed, 0 skipped)` - **tested**.
  - `push-to-light` (app `ptl-wb`, ELF `2b2618ec...`) flashed with the owner's OK: `FLASH: PASS`.
    Full run with `--interactive`: every automatic step passed (LED1/LED2 on/off/toggle and
    read-back, errors, buttons released) and the owner pressed SW1 and SW2 (EVT lines seen); the
    last step failed only because the shared spec expected `^LED led1=1$` and this board reports 3
    LEDs (`LED led1=1 led2=1 led3=0`). Spec pattern changed to `^LED led1=1( |$)` in every
    skill's push_to_light.json; re-run `--only-interactive`: `RESULT: PASS (6/6)` - **interactive**.
    The owner saw LED1 (blue) light after SW1 and LED2 (green) after SW2 - **observed**.
    LED3 and SW3 not exercised (the spec covers 2 LEDs / 2 buttons).
- 2026-10-27 on-target unit tests (prototype, `unit_test.sh`), TDD of `lib/func/gesture`. The
  owner wrote `FLASH_POLICY=auto` into this PC's bench file for the loop (identity gates stay).
  Unit image = app `ptl-wb` built with `-DFW_UNIT=ON` (Unity 2.6.1 from `lib/unity`), 0 warnings.
  - Red: stub `gesture_update()` -> `UNIT: FAIL (10 of 12 failed)` - Unity FAIL lines and the
    failing gate seen on hardware.
  - Green: state machine -> `UNIT: PASS (12/12)`. Second cycle: new case "click, then hold" ->
    `UNIT: FAIL (1 of 13)` -> fix -> `UNIT: PASS (13/13)`. Each cycle (build + flash + read) about
    20 s.
  - Gesture demo app `gst-wb` (app-only `app_main.c`: short / long / double click on any button
    toggle LED1 / LED2 / LED3): the owner confirmed it behaves so on the board. A 90 s console
    capture during the owner's tries showed no `EVT` lines - console output of that demo not
    explained yet.
  - `fxscale` (CMSIS-DSP V1.6.0 from the firmware package, q31): stub -> 4 of 17 failed (100 %);
    one fixed Q format (x/2^7, gain/2^4) -> 1 of 17 failed, random pairs 1.31 % (corners 0.82 %);
    block floating point (frexpf + q31 mantissas + ldexpf) -> `UNIT: PASS (17/17)`, worst
    0.000006 %. App build with the CMSIS-DSP block: 0 warnings.

