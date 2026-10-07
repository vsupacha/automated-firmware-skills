# TESAIoT DevKit - ModusToolbox profile (modus-pdl-edgitalk)

Board hardware (tool-independent): [../README.md](../README.md). Verified for uart-btn-led (milestone 2).

Source SDK: <https://github.com/tesaiot/tesaiot-pse84-devkit-sdk>. Board is built on
Infineon's PSOC Edge E84 AI Kit design; MCU `PSE846GPS2DBZC4A` (per README, unverified).

## Known from upstream docs

- BSP `bsps/TARGET_KIT_PSE84_AI` shipped inside each template (modified vendor BSP).
- Upstream requires ModusToolbox **3.6**; we test **3.9** first (driver issues with 3.6).
- Flash: `make program`; afterwards **power-cycle USB** (debugger reset leaves the display dead).
- Core roles in upstream firmware: CM33_S secure boot, CM33_NS MicroPython/sensors/Wi-Fi,
  CM55 LVGL UI + AI; IPC mailbox between NS and CM55.
- Peripherals: BMI270, BMM350, DPS368, SHT40, BGT60TR13C radar, OV7675, PDM mic, 4.3" MIPI DSI
  touch display, CYW55513 Wi-Fi/BT, 512 Mb QSPI NOR, 128 Mb octal HyperRAM, mikroBUS ×3.

## Verified on hardware (2026-10-03, milestone 2)

| Item | Value | Verified |
| --- | --- | --- |
| Debug USB / probe | KitProg3 CMSIS-DAPv2, FW 2.82.1735 (serial is per board - discover.sh) | yes |
| MCU | `PSE846GPS2DBZC4A` rev B0, EPC2, DEVELOPMENT, VTarget 1.79 V | yes |
| Console | SCB2 P6[5]/P6[7] → KitProg3 USB-UART, 115200 | yes |
| LEDs | LED1 P10[7], LED2 P10[5], LED3..5 = RGB red/blue/green P20[6/5/4] (active high) | LED1/2 by read-back |
| Button | `CYBSP_USER_BTN1` (`CYBSP_SW1`) = silkscreen **SW1 (user) on the AI Kit**, P7[0], active low; SW2 = RESET | yes (pin monitor) |
| QWA309 buttons | SW4 P17.5, SW5 P17.7 (not in BSP; runtime pull-up; P17.5 = USB-host VBUS enable) | config verified (`pins?`: pull-up, GPIO); **read 0 permanently with the DVP camera plugged in** - not yet tested without camera |
| Clocks | vendor `KIT_PSE84_AI` 1.4.0 = TESAIoT BSP (path 0 from external clock); no overlay | yes (boots) |
| Factory firmware | prints nothing on the UART; backup: `backup.sh tesaiot` (12 MB, ~35 s) | backed up |
| Power cycle after flash | not needed for uart-btn-led (upstream display firmware needs it) | yes |

TESAIoT BSP delta vs vendor `KIT_PSE84_AI` v1.2.0 (`modus_diff.py`): ADC pot pins P15[4..7] +
SAR channels, SCB5 = I2C master only, m55_nvm 2.75 → 6 MB (trailer at 0x00B80000), shared-memory
tweaks, CM55 MPU attributes, linker scripts and `ns_start_pse84.c`. Port these when an app needs
the pots, SCB5 or a large CM55 image.

## Verification log

- 2026-10-03 `uart-btn-led` (same template as Edgi-Talk, vendor BSP 1.4.0, no overlay): build
  PASS 0 warnings, hex `1842a7c5...`, flash verified 74,204 bytes, test PASS 16/16 without a USB
  replug, interactive BTN1 (AI Kit SW1) PASS 4/4.
- 2026-10-03 milestone 3, profile split (`tesaiot` extends `kit-pse84-ai`), app `button-led`
  (hex `b8c7...` then rebuilt with SW1 names): build PASS 0 warnings, flash verified 75 KB, auto
  PASS 4/4 (info, button map), SW1 hold → LED1 on / release → off PASS. QWA309 SW4/SW5 stuck at 0
  because the DVP camera holds P17.5/P17.7 low; 60 s pin monitor saw only P7.0 toggling.
- 2026-10-03 lab finding: the QWA309 **CS select switch** enables the base-board I2C; buttons and
  CapSense only work when it is selected. Unselected, the base firmware prints
  `PSOC,ERR,<ms>,I2C,START-W,0,0x00AA2002,<n>` on the KitProg3 UART every 100 ms (seen on a second
  kit running the base firmware, not flashed).
