# PSOC Edge E84 AI Kit (KIT_PSE84_AI) - ModusToolbox profile (modus-pdl-edgitalk)

Board hardware (tool-independent): [../README.md](../README.md).

Machine-readable values: `board.env`. Parent profile of `tesaiot` (AI Kit + QWA309 base board).
HW reference: TESAIoT SDK docs J4 / "Peripherals at a glance"
(https://tesaiot.github.io/tesaiot-pse84-devkit-sdk/sdk/mtb-mpy/index.html).

| Item | Value | Verified |
| --- | --- | --- |
| MCU | `PSE846GPS2DBZC4A` rev B0, EPC2, DEVELOPMENT | yes (2026-10-03) |
| BSP | vendor `KIT_PSE84_AI` 1.4.0, no overlay (clock path 0 = external clock on the kit) | yes |
| Console | SCB2 P6[5]/P6[7] → KitProg3 USB-UART, 115200 | yes |
| User button | silkscreen **SW1** = `CYBSP_USER_BTN1` (`CYBSP_SW1`) P7.0, active low. **SW2 = RESET.** The SDK docs call the user button "SW2" - our kit's silkscreen says SW1. | yes (pin monitor + button-led) |
| LEDs | LED1 P10[7], LED2 P10[5] (no TCPWM route); RGB red/blue/green P20[6]/[5]/[4] = `CYBSP_USER_LED3/4/5` (TCPWM0 grp1 lines 265/264/263) | LED1 by read-back |
| Flash backup | `backup.sh <board>` reads 0x60000000 + 12 MB in ~35 s | yes |

## Verification log

- 2026-10-03 `uart-btn-led` and `button-led` (via the `tesaiot` profile, same AI Kit): build PASS,
  flash verified, SW1 hold → `EVT btn1=pressed name=SW1 pin=P7.0 led1=1`, release → `led1=0`.
