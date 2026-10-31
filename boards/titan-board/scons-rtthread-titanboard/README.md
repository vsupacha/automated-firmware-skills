# RT-Thread Titan Board - scons-rtthread-titanboard profile

Board profile of the `scons-rtthread-titanboard` skill: `board.env` (SDK version and example
project, GCC/pyOCD package versions, board define, labels, pyOCD target, expected CPUID, code-MRAM
range, known pyOCD noise). Hardware: [../README.md](../README.md).

| Item | Value |
| --- | --- |
| SDK | RT-Thread Studio `Titan-Board` 1.0.2, project `Titan_template` (RT-Thread 5.1.0, FSP 6.0.0) |
| Build | scons 4.10.0 (Studio's env-new, Python 3.11.9), GNU Arm 13.3.1 |
| IDE | RT-Thread Studio, workspace `<apps>/.rtstudio`, project synced by `scons --target=eclipse` |
| Flash | pyOCD 0.36.0 (Studio package 0.2.9) + `Renesas.RA_DFP` 6.1.0, target `R7KA8P1KF`, 1 MHz SWD; `app.hex` = code MRAM only |

## Verification log

- 2026-10-31 skill `scons-rtthread-titanboard` created from the Vision Board skill (portable PC,
  Windows + Git Bash). check_tools `missing/bad=0`. `hello-world`, `blink`, `push-to-light`: build
  PASS 0 warnings (app ~88 MB).
  - Debugger: "RA4M2 CMSIS-DAP" `045B:201F` is CMSIS-DAP v2 only (WinUSB). Its interface was bound to an
    old libwdi "WinUSB Generic Device" INF without a device interface GUID: libusb could not open it, so
    pyOCD and RT-Thread Studio saw no probe. After the owner installed WinUSB with a GUID (Zadig):
    pyOCD lists "Renesas RA4M2 CMSIS-DAP Probe". discover: CPUID `0x411FD231` (Cortex-M85 r1p1),
    `Running [Secure]` - IDENTITY PASS. pyOCD prints "Error probing AP#2" + an SVD traceback on every
    connect (harmless; `PYOCD_NOISE`).
  - Factory image read on the console: RT-Thread 5.1.0 (Apr 16 2026), LCD frame buffer in OSPI RAM,
    then a hard-fault register dump (no display attached). The 1 MB code MRAM was backed up first.
  - `blink`: flash 3 sectors / 11 pages, 86416 bytes read back equal; msh_status MSH: PASS (5 threads,
    heap 1.39 MB, devices uart8 pin); test `blink.json` PASS 7/7; the owner saw the red LED blink.
  - `push-to-light`: flash 88100 bytes read back equal; test PASS 17/17 (10 interactive steps not run).
  - Recipes (Kconfig level, derived from the SDK projects): 11 READY on a new app; apply + build PASS
    for 10 of them together, for `ospi-flash-fs` + `wifi`, and for `eth` - not run on the board.
