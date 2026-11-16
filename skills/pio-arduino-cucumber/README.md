# Gravitech Cucumber S - how to use `pio-arduino-cucumber`

Firmware for the Gravitech Cucumber S (ESP32-S2-WROVER with onboard MPU6050, BMP280 and HTS221
sensors and an RGB LED) with PlatformIO + arduino-esp32, from "are my tools installed?" to "tested on
the board", with a gate at every stage. The board layer has **one driver per onboard sensor**, and the
`iot-sensor` template is a ready IoT node (console + optional Wi-Fi/MQTT). You can ask Claude in your
own words or run the same scripts yourself in Git Bash. Thai: [README_TH.md](README_TH.md). The
agent's instructions are in [SKILL.md](SKILL.md).

Status: every template builds with 0 warnings; nothing has been run on a board yet. Demo levels per
template and the exact tool versions: [boards/cucumber-s/README.md](../../boards/cucumber-s/README.md).

| On the board | |
| --- | --- |
| Console | UART0 through the USB-UART bridge (micro-USB next to the TX/RX LEDs) |
| LED1 | blue LED, GPIO2 |
| RGB LED | GPIO18 (`rgb` command, iot-sensor) |
| BTN1 | BOOT (GPIO0) |
| Sensors (I2C SDA 41 / SCL 40) | HTS221 0x5F, MPU6050 0x68, BMP280 0x76 |

## 1. Prepare the PC (once)

- Windows 10/11 with Git for Windows (Git Bash) and Python 3 with `pyserial`.
- PlatformIO Core and Git; the first build installs espressif32 6.12.0 + arduino-esp32 2.0.17 and
  fetches the pinned Adafruit libraries (network needed once per app).
- The USB driver of the board's USB-UART bridge (Windows usually installs it by itself).
- Optional: VS Code and PlatformIO IDE for the IDE path; Claude Code for the agent path.

## 2. Install the plugin

In Claude Code, from your project folder:

```
/plugin marketplace add vsupacha/automated-firmware-skills
/plugin install firmware-platformio@automated-firmware-skills
```

## 3. Ask Claude

| You say | Claude runs | You see |
| --- | --- | --- |
| "How do I use this?" | `help.sh` | the command menu, boards and templates |
| "Check my tools for the Cucumber" | `check_tools.sh cucumber-s` | `missing/bad=0`; every BAD row says what to install |
| "Create the IoT sensor app called cu-iot" | `new_app.sh cucumber-s cu-iot "" iot-sensor` | `Created <app folder>` (first time on a PC: which workspace?) |
| "Build it" | `build.sh <app>` | `BUILD: PASS` with 0 warnings + a manifest (tool + library versions, image hash) |
| "Find my board" | `discover.sh cucumber-s` | `IDENTITY: PASS` - read-only; saves this PC's bridge, port and the chip's MAC |
| "Flash it" | `flash.sh <app> --yes` **after you said yes** | `FLASH: PASS` (4 regions verified; the MAC must match) |
| "Test the sensors one by one" | `serial_test.py auto <app>/tests/i2c_bus.json ...`, then `mpu6050.json`, `bmp280.json`, `hts221.json`, `rgb_led.json` | `RESULT: PASS` per peripheral |
| "Test the IoT app" | `serial_test.py auto <app>/tests/iot_sensor.json ...` | stream, JSON payload, Wi-Fi/MQTT state |
| "Clean up" | `clean.sh` (dry run first) | a list, then deletion only after your yes |

**Wi-Fi and MQTT** - you type these yourself in a serial monitor (PlatformIO IDE's Serial Monitor at
115200): `wifi set <ssid> <password>`, then `mqtt set <host> [port]`. They are stored in the chip's
NVS and survive reflashing; nothing network-specific is in the source or in git. `wifi?` / `mqtt?`
show the state; `wifi forget` / `mqtt off` remove them. The node publishes JSON to
`cucumber/<mac>/sensor` every period and accepts `{"led":1}` or `{"rgb":[r,g,b]}` on
`cucumber/<mac>/cmd`. MQTT here is plain TCP without a login - use a test broker or your own.

## 4. The same without Claude (Git Bash, from the repo root)

```bash
S=skills/pio-arduino-cucumber/scripts
bash $S/check_tools.sh cucumber-s
bash $S/new_app.sh cucumber-s cu-iot "" iot-sensor   # prints: Created <app folder>
bash $S/build.sh <app folder>
bash $S/discover.sh cucumber-s
bash $S/flash.sh <app folder> --yes          # only after you decided to flash
~/.platformio/penv/Scripts/python $S/serial_test.py auto <app folder>/tests/i2c_bus.json <app folder>/logs/test-i2c.log --board cucumber-s
```

Exit codes: 0 pass, 1 fail, 2 warnings that block the gate, **10 = do what the `ACTION:` line says,
then re-run** (SETUP, CONNECT, APPROVE, CHOOSE).

## 5. Notes for this board

- **Layers:** `src/board/board_<dev>.cpp` is the only place that includes a sensor library; the
  headers expose plain structs (`board_imu_t`, `board_baro_t`, `board_hum_t`). `src/func/sensors.cpp`
  turns them into report lines and the JSON payload; `main.cpp` wires commands, the stream and the
  network together. See [docs/board-api.md](../../docs/board-api.md).
- **Two micro-USB ports:** use the one next to the TX/RX LEDs (USB-UART bridge). The other one is
  the ESP32-S2's native USB and is not used by these templates.
- **Identity:** a bridge's USB serial does not identify the chip, so `flash.sh` compares the chip's
  MAC with the one `discover.sh` saved.
- Sensors are on the Cucumber **S** variants only (RS, RIS, MS, MIS).

## More

- [README.md](../../README.md) - concepts, all boards, plugins
- [docs/workflow.md](../../docs/workflow.md) - stages, gates, exit codes, apps workspace
- [boards/cucumber-s/README.md](../../boards/cucumber-s/README.md) - hardware, tool versions, verification log
