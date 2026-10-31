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
- 2026-10-31 `push-to-light` on hardware (app `pt-vb`, SDK 1.3.0, GCC 13.3.1, scons 4.10.0, pyOCD
  0.2.9): build PASS 0 warnings, app.hex `01a50306...`; discover IDENTITY PASS; the board's previous
  firmware was backed up first (read-only savemem of the 2 MB code flash, kept outside git); flash:
  9 sectors erased, 519 pages, 66360 bytes read back equal - the first GCC 13.3 image on the board.
  `msh_status.py`: 11 msh commands (`info`, `led`, `btn` + built-ins), 4 threads, memheap pools
  `sdram` + `heap` - MSH: PASS. Test `push_to_light.json`: step "spec commands exported by the
  image" PASS, RESULT PASS 17/17 (10 interactive steps skipped - nobody looked at the LEDs).
- 2026-10-31 profile: `FSP_PROJECT=vision_board_openmv` - new apps take the FSP side from the openmv
  project (all driver-recipe instances generated, no driver enabled). New push-to-light app (`fsp2-vb`):
  build PASS 0 warnings, app.hex 0x02000000..0x02013244 (`37fd66c0...`); flash: 9 sectors erased, 613 pages,
  78404 bytes read back equal; `msh_status.py` MSH: PASS (same 11 commands, 4 threads, devices uart9 + pin);
  test `push_to_light.json` RESULT PASS 17/17 (10 interactive steps skipped by the runner); the owner then tested
  KEY0 and the LEDs by hand on this image and reported it working (KEY0 is IRQ10 in the openmv FSP pin setup).
- 2026-10-31 recipe `rw007` (+ `spi1`) applied to a push-to-light app (openmv FSP): build PASS (0 warnings in the
  app; 3 in RT-Thread's wlan_mgnt.c), flash 237460 bytes read back equal, MSH: PASS with RW007 threads and
  devices, msh `wifi scan` found 3 access points, push-to-light test 17/17. Then `wifi join` to the
  developer's access point (credentials not recorded): connected, DHCP address, `ping www.rt-thread.org`
  4 replies 57-127 ms.
