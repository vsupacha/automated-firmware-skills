# Gravitech Cucumber S - วิธีใช้ `pio-arduino-cucumber`

firmware สำหรับ Gravitech Cucumber S (ESP32-S2-WROVER มีเซนเซอร์บนบอร์ด MPU6050, BMP280, HTS221 และ RGB LED)
ด้วย PlatformIO + arduino-esp32 ตั้งแต่ "ติดตั้งเครื่องมือครบหรือยัง" จนถึง "ทดสอบบนบอร์ดผ่านแล้ว" โดยมีด่านตรวจ (gate)
ทุกขั้น board layer มี **driver แยกตัวละหนึ่งไฟล์สำหรับเซนเซอร์แต่ละตัว** และ template `iot-sensor` เป็นโหนด IoT
พร้อมใช้ (console + Wi-Fi/MQTT ถ้าต้องการ) สั่ง Claude ด้วยภาษาของคุณเอง หรือรัน script ชุดเดียวกันเองใน Git Bash ก็ได้
ภาษาอังกฤษ: [README.md](README.md) คำสั่งที่ agent ทำตาม: [SKILL.md](SKILL.md)

สถานะ: ทุก template build ผ่าน 0 warning ยังไม่ได้รันบนบอร์ดจริง ระดับหลักฐานและเวอร์ชันเครื่องมือ:
[boards/cucumber-s/README.md](../../boards/cucumber-s/README.md)

| บนบอร์ด | |
| --- | --- |
| Console | UART0 ผ่านชิป USB-UART (micro-USB ข้าง LED TX/RX) |
| LED1 | LED สีน้ำเงิน GPIO2 |
| RGB LED | GPIO18 (คำสั่ง `rgb` ใน iot-sensor) |
| BTN1 | BOOT (GPIO0) |
| เซนเซอร์ (I2C SDA 41 / SCL 40) | HTS221 0x5F, MPU6050 0x68, BMP280 0x76 |

## 1. เตรียมเครื่อง (ทำครั้งเดียว)

- Windows 10/11 พร้อม Git for Windows (Git Bash) และ Python 3 กับ `pyserial`
- PlatformIO Core และ Git; build ครั้งแรกจะติดตั้ง espressif32 6.12.0 + arduino-esp32 2.0.17 และดาวน์โหลด
  ไลบรารี Adafruit ที่ pin ไว้ (ต้องมีเน็ตครั้งแรกของแต่ละแอป)
- driver USB ของชิป USB-UART บนบอร์ด (ปกติ Windows ติดตั้งให้เอง)
- ไม่บังคับ: VS Code + PlatformIO IDE สำหรับทาง IDE; Claude Code สำหรับทาง agent

## 2. ติดตั้ง plugin

```
/plugin marketplace add vsupacha/automated-firmware-skills
/plugin install firmware-platformio@automated-firmware-skills
```

## 3. สั่ง Claude

| คุณพูดว่า | Claude รัน | สิ่งที่เห็น |
| --- | --- | --- |
| "ขอวิธีใช้" | `help.sh` | เมนูคำสั่ง บอร์ด และ template |
| "ตรวจเครื่องมือสำหรับ Cucumber" | `check_tools.sh cucumber-s` | `missing/bad=0` |
| "สร้างแอป IoT ชื่อ cu-iot" | `new_app.sh cucumber-s cu-iot "" iot-sensor` | `Created <โฟลเดอร์แอป>` |
| "build ให้หน่อย" | `build.sh <app>` | `BUILD: PASS` 0 warning + manifest |
| "หาบอร์ด" | `discover.sh cucumber-s` | `IDENTITY: PASS` อ่านอย่างเดียว บันทึกพอร์ตและ MAC ของชิป |
| "แฟลชเลย" | `flash.sh <app> --yes` **หลังคุณตอบตกลง** | `FLASH: PASS` (MAC ต้องตรง) |
| "ทดสอบเซนเซอร์ทีละตัว" | `serial_test.py` กับ `i2c_bus.json`, `mpu6050.json`, `bmp280.json`, `hts221.json`, `rgb_led.json` | `RESULT: PASS` ทีละอุปกรณ์ |
| "ทดสอบแอป IoT" | `serial_test.py` กับ `iot_sensor.json` | stream, JSON, สถานะ Wi-Fi/MQTT |

**Wi-Fi และ MQTT** - พิมพ์เองใน serial monitor (115200): `wifi set <ssid> <password>` แล้ว
`mqtt set <host> [port]` ค่าจะเก็บใน NVS ของชิป แฟลชใหม่ก็ไม่หาย ไม่มีค่าเครือข่ายใดอยู่ในซอร์สหรือ git
`wifi?` / `mqtt?` ดูสถานะ, `wifi forget` / `mqtt off` ลบค่า โหนดจะ publish JSON ไปที่ `cucumber/<mac>/sensor`
ทุกรอบ และรับ `{"led":1}` หรือ `{"rgb":[r,g,b]}` ที่ `cucumber/<mac>/cmd` (MQTT แบบ TCP ไม่มีรหัสผ่าน - ใช้ broker
ทดสอบหรือของเครือข่ายตัวเอง)

## 4. ใช้เองโดยไม่ผ่าน Claude (Git Bash จาก root ของ repo)

```bash
S=skills/pio-arduino-cucumber/scripts
bash $S/check_tools.sh cucumber-s
bash $S/new_app.sh cucumber-s cu-iot "" iot-sensor
bash $S/build.sh <โฟลเดอร์แอป>
bash $S/discover.sh cucumber-s
bash $S/flash.sh <โฟลเดอร์แอป> --yes          # เมื่อตัดสินใจแฟลชแล้วเท่านั้น
```

## 5. หมายเหตุของบอร์ดนี้

- ไฟล์ `src/board/board_<dev>.cpp` เป็นที่เดียวที่ include ไลบรารีเซนเซอร์; header ให้แค่ struct ธรรมดา
  `src/func/sensors.cpp` แปลงเป็นบรรทัดรายงานและ JSON; `main.cpp` ผูกคำสั่ง stream และเครือข่ายเข้าด้วยกัน
- micro-USB มีสองช่อง: ใช้ช่องข้าง LED TX/RX (USB-UART) อีกช่องเป็น USB ของ ESP32-S2 เอง ไม่ได้ใช้
- เซนเซอร์มีเฉพาะรุ่น **S** (RS, RIS, MS, MIS)

## เพิ่มเติม

- [README_TH.md](../../README_TH.md) ของ repo, [docs/workflow.md](../../docs/workflow.md),
  [boards/cucumber-s/README.md](../../boards/cucumber-s/README.md)
