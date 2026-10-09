# RT-Thread Vision Board - scons-rtthread-visionboard profile

Board profile of the `scons-rtthread-visionboard` skill: `board.env` (SDK version and example
project, GCC/pyOCD package versions, board define, labels, pyOCD target, expected CPUID, code-flash
range). Hardware: [../README.md](../README.md).

| Item | Value |
| --- | --- |
| SDK | RT-Thread Studio `VISION-BOARD` 1.3.0, project `vision_board_blink_led` (RT-Thread 5.0.2, FSP 5.1.0) |
| Build | scons 4.10.0 (Studio's env-new, Python 3.11.9), GNU Arm 13.3.1 |
| IDE | RT-Thread Studio, workspace `<apps>/.rtstudio`, project synced by `scons --target=eclipse` |
| Flash | pyOCD 0.36.0 (Studio package 0.2.9) + `Renesas.RA_DFP` 6.1.0, target `R7FA8D1BH`, 1 MHz SWD; `app.hex` = code flash only |

## Verification log

- 2026-10-09 skill `scons-rtthread-visionboard` created (RT-Thread Studio on Windows 11 + Git Bash).
  check_tools `missing/bad=0`. discover: ART-Link CMSIS-DAP `0416:7687`, VCP present, CPUID
  `0x410FD232` (Cortex-M85 r0p2), core `Running [Secure]` - IDENTITY PASS (attach, no halt).
  - The SDK project's FSP build also emits option-setting sections (`.option_setting_ofs/_sas/_s`
    at 0x0300A100.., `.option_setting_data_flash_s` at 0x27030080): build.sh removes them from
    `app.hex`, flash.sh refuses anything outside code flash.
  - `hello-world` (app `vb-hello`, GCC 10.2.1 + scons 3.1.2 at that time): build PASS 0 warnings,
    app.hex `84f19357...`; flash: 8 sectors erased, 511 pages, 65332 bytes read back equal; test
    PASS 9/9 (`board=vision-board`, five 1 s "hello, world" lines, msh alive).
  - `uart-btn-led` (app `vb-btn`): build PASS 0 warnings - built, not flashed.
  - IDE path (owner in RT-Thread Studio): the SDK project's toolchain 10.2.1 failed in Studio's own
    build -> 13.3 builds; Studio's "sync scons to project" renamed the project to `project`
    (RT-Thread 5.0.2 `--project-name` default). new_app.sh now sets GCC 13.3, the project-name
    default and runs the scons sync itself: `.cproject` identical to Studio's synced one; a new app
    (`vb-sync`) built in Studio without a sync prompt (owner: build passed). scons + GCC 13.3.1
    (`vb-chk`) build PASS 0 warnings - not flashed.
- 2026-10-09 template `uart-btn-led` renamed `push-to-light` (same code apart from the app
  name) - build PASS 0 warnings; new template `blink` (LED1 every 0.5 s) - build PASS 0
  warnings. Both built only, not flashed (the earlier results above were with the old name).
