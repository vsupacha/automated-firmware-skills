# TESAIoT PSOC Edge E84 DevKit

= Infineon PSOC Edge E84 AI Kit ([../kit-pse84-ai/](../kit-pse84-ai/README.md)) on the **QWA309 base
board**. Everything on the AI Kit applies; this sheet adds the base board. Tool-independent.

| Profile | Skill | Status |
| --- | --- | --- |
| [modus-pdl-edgitalk/](modus-pdl-edgitalk/README.md) | `skills/modus-pdl-edgitalk` (ModusToolbox), `BOARD_EXTENDS=kit-pse84-ai` | AI-Kit I/O verified; SW4/SW5 blocked by camera |

Sources: TESAIoT SDK <https://github.com/tesaiot/tesaiot-pse84-devkit-sdk>, docs J4, J5 and
"Peripherals at a glance" <https://tesaiot.github.io/tesaiot-pse84-devkit-sdk/sdk/mtb-mpy/index.html>.

## QWA309 base-board I/O

| Item | Pin / bus | Notes | Verified |
| --- | --- | --- | --- |
| **SW4** | P17.5 | active low, needs run-time pull-up (not in the BSP). **Also the USB-host VBUS enable** (buttons and USB joystick are exclusive) and the DVP camera RESET line | config yes; reads 0 with camera plugged in |
| **SW5** | P17.7 | active low, run-time pull-up; DVP camera PWDN line | same as SW4 |
| CS select switch | - | enables the base-board I2C; **must be selected** for base-board buttons and CapSense. Unselected, the base firmware prints `PSOC,ERR,<ms>,I2C,START-W,...` every 100 ms | lab report 2026-10-03 |
| CapSense BTN0/BTN1 + slider | PSoC 4000T @ 0x08 on the display/touch I2C (P17.0/P17.1, CM55-owned) | not GPIO | no |
| DFR0522 16×8 RGB LED matrix | I2C @ 0x10 on the header I2C (SCB5, shared with display/touch, CM55-owned) | no discrete GPIO LEDs on the base board | no |
| Pots VR1..VR4 | P15.4..P15.7 (SAR ch 4..7) | knob map {5,4,6,7}: VR1/VR2 traces swapped | no |
| Header GPIO | P13.0/3/4/5/6/7 | | no |
| Header PWM | P13.3 (+ P13.4 complement) | | no |
| Header UART | SCB9 P15.0 RX / P15.1 TX | | no |

Older docs name the buttons SW9/SW10 or SW5/SW6; add-on boards may carry their own "SW1" -
always say which board a button is on.

## Kit peripherals (from the TESAIoT SDK docs, not verified here)

BMI270 IMU, BMM350 magnetometer, DPS368 pressure, SHT40 temperature/humidity, BGT60TR13C radar,
OV7675 camera (DVP), PDM microphone, 4.3" MIPI DSI touch display, CYW55513 Wi-Fi/BT,
512 Mb QSPI NOR, 128 Mb octal HyperRAM, mikroBUS ×3.

## Hardware quirks

- With the DVP camera plugged in, SW4/SW5 read 0 permanently - unplug the camera to use them.
- Display firmware needs a USB power cycle after flashing (debugger reset leaves the display dead).
- Factory firmware prints nothing on the KitProg3 UART.
