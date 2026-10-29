# FRDM-MCXN947 - mcux-sdk-frdmmcxn947 profile

Board profile of the `mcux-sdk-frdmmcxn947` skill: `board.env` (pinned MCUXpresso SDK, the NXP
build tools, the SDK example new apps start from, identity values). Hardware: [../README.md](../README.md).

| Item | Value |
| --- | --- |
| SDK | MCUXpresso SDK v26.09.00 (GitHub, west workspace; per-PC folder, default `C:/mcux-26.09`) |
| New app | `west export_app examples/demo_apps/hello_world -b frdmmcxn947 -Dcore_id=cm33_core0 --bf`, then trimmed: SDK `board.c/.h`, `hardware_init.c` and the SDK debug console out; `clock_config.*` + `pin_mux.*` kept; our `src/` in |
| Build | Kitware CMake (>= 3.30) + Ninja 1.13.2 + Arm GNU 14.2.Rel1 from the MCUXpresso Installer, `CMakePresets.json` preset `debug`; never ST tools |
| Image | `debug/app_cm33_core0.elf` (+ `.hex`), internal flash from 0x00000000 (2 MB) |
| Console | LP_FLEXCOMM4 (FRO 12 MHz) 115200 -> MCU-Link VCOM; RX by interrupt into a ring buffer |
| User I/O | RGB LED D2 active low: red P0_10, green P0_27, blue P1_2; SW2 P0_23, SW3 P0_6 (pressed low) |
| IDE | VS Code + MCUXpresso for VS Code 26.9.44 (`sdk-v2-freestanding` project, files written by the skill) |

## Verification log

- 2026-10-29/30 spikes before the skill (docs/related-work.md "NXP FRDM-MCXN947"), home PC:
  layered push-to-light built 0 warnings, flashed with LinkServer + verify, shared
  `push_to_light.json` 15/15 automatic, SW2/SW3 seen by a button watch, debug scenario 7/7, VS Code
  project files written directly and built in the extension. Not with the skill's scripts.
- 2026-10-30 skill `mcux-sdk-frdmmcxn947` created (P1: stages 0-3, board stages planned). Home PC,
  Windows 11 + Git Bash, SDK v26.09.00 (only the repositories a bare-metal app needs).
  - check_tools `missing/bad=0`, 0 warnings (Arm GNU 14.2.Rel1, Ninja 1.13.2, west 1.5.0 from
    the MCUXpresso Installer; Kitware CMake 4.1.0; LinkServer 26.5.59; MCUXpresso for VS Code 26.9.44).
  - new_app (~22 s) + build PASS, 0 warnings, no ST tool in the CMake cache: `hello-world` (text
    22,392 B, ELF `324fc729...`), `blink` (text 22,872 B), `push-to-light` (text 25,096 B, ELF
    `58e8dccf...`). Warning gate checked: one unused variable in `src/` = `BUILD: WARNINGS`, exit 2;
    the next build rebuilt clean and passed. Not flashed with the skill (no flash.sh yet).
  - P2 (same day, owner approved both flashes): discover `IDENTITY: PASS` (MCU-Link firmware 3.128,
    target MCXN947VDF / FRDM-MCXN947, VCOM by probe serial). flash.sh refused an ELF moved to FlexSPI
    (0x80000000) before touching the probe, and stopped with `ACTION: APPROVE` without `--yes`.
    `hello-world` (ELF `324fc729...`) FLASH PASS (3 sections verified + reset), test `RESULT: PASS
    (9/9)`; `push-to-light` (ELF `58e8dccf...`) FLASH PASS, `RESULT: PASS (16/16, 4 interactive
    skipped)`. Board left running push-to-light.
