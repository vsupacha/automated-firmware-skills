# RT-Thread Vision Board (RA8D1)

Machine-vision development board by RT-Thread with a Renesas RA8D1 (Arm Cortex-M85) and an on-board
ART-Link (CMSIS-DAP) debugger. Tool-independent hardware sheet.

| Profile | Skill | Status |
| --- | --- | --- |
| [scons-rtthread-visionboard/](scons-rtthread-visionboard/README.md) | `skills/scons-rtthread-visionboard` (RT-Thread 5.0.2 + scons + pyOCD, RT-Thread Studio) | hello-world tested on hardware |

Sources: the Vision Board SDK 1.3.0 in RT-Thread Studio (sdk-bsp-ra8d1-vision-board: README,
`vision_board_blink_led`, `vision_board_openmv` Kconfig/pin data, KiCad schematic labels).

"Verified" = seen on hardware with a dated log line in a profile README. "Vendor docs" = taken from
the SDK, not yet checked by us on this board.

## MCU and USB

| Item | Value | Verified |
| --- | --- | --- |
| MCU | Renesas RA8D1 R7FA8D1BH, Arm Cortex-M85 480 MHz (Helium), 2 MB code flash at 0x02000000, 1 MB SRAM; 32 MB SDRAM, 8 MB QSPI flash on the board | CPUID `0x410FD232` (Cortex-M85 r0p2) read 2026-10-09 |
| Debugger | ART-Link CMSIS-DAP on the DAP-Link USB-C port: `0416:7687`, composite = CMSIS-DAP + virtual COM port + mass storage; pyOCD target `R7FA8D1BH` | yes (2026-10-09) |
| Console | RT-Thread msh on `uart9` (SCI9) -> the ART-Link virtual COM port, 115200 | yes (2026-10-09, hello-world test) |
| Security state | the core runs in Secure state (flat project, no TrustZone split) | read 2026-10-09 (`Running [Secure]`) |
| Option-setting memory | OFS/SAS/security settings at 0x0300A100.., data-flash settings at 0x27030080.. - the FSP build puts `.option_setting_*` sections there | ELF read 2026-10-09; never written by the skill |
| First connection | the BSP notes SWD may be closed on a new board: hold RST while the debugger connects | vendor docs (not needed on this board) |

## User I/O

| Silkscreen / name | Pin | Active level | Notes | Verified |
| --- | --- | --- | --- | --- |
| RGB LED - blue | P102 | low = on (common anode) | **LED1** of the skill's board layer; blinked by the SDK example | vendor docs |
| RGB LED - other colours | P106, PA07 | low = on | **LED2**, **LED3**; red/green order from the OpenMV port - to be confirmed by the interactive test | vendor docs (unverified colours) |
| **KEY0** | P907 | low = pressed (assumed) | input, external pull; `USER_KEY_PIN_NAME` default "p907" in the SDK | vendor docs |
| RST | reset | - | | - |
