# Infineon PSOC Edge E84 AI Kit (KIT_PSE84_AI)

Tool-independent hardware sheet, **on-board I/O of the AI Kit only**. The TESAIoT DevKit is this
kit on the QWA309 base board: see [../tesaiot/](../tesaiot/README.md).

| Profile | Skill | Status |
| --- | --- | --- |
| [modus-psoc-e84/](modus-psoc-e84/README.md) | `skills/modus-psoc-e84` (ModusToolbox) | verified on hardware |

Sources: Infineon KIT_PSE84_AI documentation; TESAIoT SDK docs J4 / "Peripherals at a glance"
<https://tesaiot.github.io/tesaiot-pse84-devkit-sdk/sdk/mtb-mpy/index.html>.

## MCU and debug

| Item | Value | Verified |
| --- | --- | --- |
| MCU | `PSE846GPS2DBZC4A` rev B0, EPC2, life cycle DEVELOPMENT, VTarget 1.79 V | yes (2026-10-03) |
| Debug | on-board KitProg3, CMSIS-DAPv2 | yes |
| Console | SCB2 P6[5] RX / P6[7] TX → KitProg3 USB-UART, 115200 | yes |
| Clock | path 0 from an external clock present on the kit (stock BSP boots as-is) | yes |

## User I/O

| Silkscreen | Pin | Active level | Verified |
| --- | --- | --- | --- |
| **SW1** = user button | P7[0] | low | yes (pin monitor + button-led) |
| SW2 | RESET | - | yes |
| LED1 | P10[7] | high | yes (read-back) |
| LED2 | P10[5] (no TCPWM route) | high | yes (read-back) |
| RGB red / blue / green | P20[6] / P20[5] / P20[4] (TCPWM0 grp1 lines 265/264/263 → hardware dimming) | high | not yet |

Note: the TESAIoT SDK docs call the user button "SW2"; the silkscreen on our kit says SW1 - trust
the board in front of you.

## On-board parts

| Part | Function | Verified |
| --- | --- | --- |
| QSPI NOR (app area 0x60000000, 12 MB read by `backup.sh` in ~35 s) | external flash | yes |
| Sensors, radar, mic, camera connector, Wi-Fi/BT | see [../tesaiot/README.md](../tesaiot/README.md) (listed there from the TESAIoT SDK docs, which do not separate AI Kit and base-board parts) | no |
