# Arduino UNO R4 WiFi - วิธีใช้ `pio-arduino-unor4wifi`

firmware สำหรับ Arduino UNO R4 WiFi - R7FA4M1AB3CFM, Renesas RA4M1 - ด้วย PlatformIO + Arduino UNO R4 core ตั้งแต่ "ติดตั้งเครื่องมือครบหรือยัง" จนถึง
"ทดสอบบนบอร์ดผ่านแล้ว" โดยมีด่านตรวจ (gate) ทุกขั้น สั่ง Claude ด้วยภาษาของคุณเอง หรือรัน script ชุดเดียวกันเองใน
Git Bash ก็ได้ ภาษาอังกฤษ: [README.md](README.md) คำสั่งที่ agent ทำตาม: [SKILL.md](SKILL.md)

ขั้นที่ใช้บอร์ด (connect, flash, test) ผ่านการตรวจบนบอร์ดจริงแล้ว ระดับหลักฐานของแต่ละ template และเวอร์ชันเครื่องมือที่แน่นอน:
[boards/uno-r4-wifi/README.md](../../boards/uno-r4-wifi/README.md)

| บนบอร์ด | |
| --- | --- |
| Console | UART via the USB bridge |
| LED1 | L (yellow, D13) |
| BTN1 | none |
| Probe / USB | USB port (the ESP32-S3 USB bridge) |

## 1. เตรียมเครื่อง (ทำครั้งเดียว)

- Windows 10/11 พร้อม Git for Windows (Git Bash) และ Python 3 กับ `pyserial`
- PlatformIO Core และ Git; build ครั้งแรกจะโหลด platform `renesas-ra` ที่ pin ไว้, UNO R4 core, GCC 7.2.1 และ bossac
- บน Windows ไม่ต้องลง driver (เป็น USB CDC มาตรฐาน); python ของ PlatformIO มี pyserial แล้ว
- ไม่บังคับ: VS Code และ PlatformIO IDE (VS Code) สำหรับทาง IDE; Claude Code สำหรับทาง agent

`check_tools.sh` (ข้อ 3) จะบอกสิ่งที่ขาดพร้อมเวอร์ชันที่ board profile pin ไว้

## 2. ติดตั้ง plugin

ใน Claude Code จากโฟลเดอร์โปรเจกต์ของคุณ:

```
/plugin marketplace add vsupacha/automated-firmware-skills
/plugin install firmware-platformio@automated-firmware-skills
```

จะได้ `firmware-tools` มาด้วย ถ้าใช้ `automated-firmware-skills@automated-firmware-skills` จะได้ทุกบอร์ด
เลือกอย่างใดอย่างหนึ่ง

## 3. สั่ง Claude

| คุณพิมพ์ | Claude รัน | สิ่งที่เห็น |
| --- | --- | --- |
| "ขอวิธีใช้หน่อย" | `help.sh` | เมนูคำสั่ง บอร์ด และ template |
| "ตรวจเครื่องมือสำหรับ Arduino UNO R4 WiFi ให้หน่อย" | `check_tools.sh uno-r4-wifi` | `missing/bad=0`; แถว BAD บอกว่าต้องติดตั้งอะไร |
| "สร้างแอป hello-world ชื่อ hello" | `new_app.sh uno-r4-wifi hello "" hello-world` | `Created <โฟลเดอร์แอป>` (ครั้งแรกบนเครื่อง: ถามที่เก็บแอป) |
| "เปิดใน IDE" | `open_ide.sh <app>` (new_app เปิดให้เอง) | `IDE: OPENED` - PlatformIO IDE (VS Code) |
| "build ให้หน่อย" | `build.sh <app>` | `BUILD: PASS` ไม่มี warning + manifest (เวอร์ชันเครื่องมือ, hash ของ image) |
| "หาบอร์ดที่ต่ออยู่" | `discover.sh uno-r4-wifi` | `IDENTITY: PASS` - อ่านอย่างเดียว บันทึก probe และ console port ของเครื่องนี้ |
| "แฟลชเลย" | `flash.sh <app> --yes` **หลังคุณตอบ yes** | `FLASH: PASS` |
| "ทดสอบ" | `serial_test.py auto <app>/tests/hello_world.json ...` | `RESULT: PASS (n/n passed ...)` |
| "ทดสอบแบบกดปุ่ม" | `serial_test.py auto <app>/tests/push_to_light.json ... --interactive` (แอป push-to-light) | ดู L (yellow, D13) เมื่อถูกบอก |
| "clean ให้หน่อย" | `clean.sh` (dry run ก่อน) | แสดงรายการ แล้วลบเมื่อคุณตอบ yes; `--apps` ลบซอร์สของแอปด้วย |

- **แอปแรกบนเครื่อง:** ถ้า `apps/` อยู่ใน Dropbox/OneDrive หรือ path ยาวเกิน `new_app.sh` จะหยุดด้วย
  `ACTION: CHOOSE` แล้ว Claude จะถามว่าจะเก็บแอปที่ไหน (แนะนำโฟลเดอร์ path สั้นนอกโฟลเดอร์ที่ sync เช่น
  `C:/fw-ws`) แล้วบันทึกด้วย `lib/fw_workspace.sh set <dir>` เครื่องนั้นจะไม่ถามอีก
- **สองทาง:** หลังสร้างแอปแล้ว คุณเขียนโค้ด, build, flash และ debug เองใน PlatformIO IDE (VS Code) ได้
  (ทาง IDE) หรือให้ Claude รันขั้นที่มี gate ให้ (ทาง script) ใช้โฟลเดอร์แอปเดียวกัน สลับได้ทุกเมื่อ
- **โค้ดของคุณ** อยู่ใน `src/` แบ่งเป็น layer: `board/` (ขาและ peripheral), `func/` (logic ที่ย้ายบอร์ดได้),
  `app_main` (ตัวเชื่อม) - ดู [docs/board-api.md](../../docs/board-api.md)
- **ไม่มีการ flash จนกว่าคุณจะตอบ yes** Claude จะแสดงบอร์ด แอป และ hash ของ image แล้วรอ
  `flash.sh` ตรวจตัวตนบอร์ดอีกครั้งก่อนเขียน

## 4. ใช้แบบไม่มี Claude (Git Bash จาก root ของ repo)

```bash
S=skills/pio-arduino-unor4wifi/scripts
bash $S/check_tools.sh uno-r4-wifi
bash $S/new_app.sh uno-r4-wifi hello "" hello-world   # พิมพ์: Created <โฟลเดอร์แอป>
bash $S/build.sh <โฟลเดอร์แอป>
bash $S/discover.sh uno-r4-wifi
bash $S/flash.sh <โฟลเดอร์แอป> --yes          # เมื่อตัดสินใจ flash แล้วเท่านั้น
~/.platformio/penv/Scripts/python $S/serial_test.py auto <โฟลเดอร์แอป>/tests/hello_world.json <โฟลเดอร์แอป>/logs/test.log --board uno-r4-wifi
```

`<โฟลเดอร์แอป>` คือที่ `new_app.sh` พิมพ์ออกมา - `apps/hello` หรือเช่น `C:/fw-ws/hello` ถ้าเครื่องตั้ง
workspace ไว้ exit code: 0 ผ่าน, 1 ล้มเหลว, 2 มี warning ที่กั้น gate, **10 = ทำตามบรรทัด `ACTION:` แล้วรันซ้ำ**
(SETUP, CONNECT, APPROVE, CHOOSE)

## 5. หมายเหตุของบอร์ดนี้

- **การ flash:** bossac ผ่าน USB bridge ของบอร์ด หลังตรวจตัวตน (loader, security ปิด, ไม่มีส่วนที่ lock): แตะ 1200 baud เพื่อเข้า loader เขียนเฉพาะส่วนของ sketch โดย loader ของ Arduino ยังอยู่
- บอร์ดนี้**ไม่มีปุ่มให้ผู้ใช้**: push-to-light ใช้ได้แค่คำสั่ง LED ทาง console และ test จะให้คุณดูไฟ L แทนการกดปุ่ม
- loader อ่าน flash ไม่ได้: ไม่มี backup และไม่มีการอ่านกลับเพื่อ verify; บรรทัด `INFO` ตอน test เป็นตัวยืนยันว่ารัน image ไหน

## อ่านต่อ (ภาษาอังกฤษ)

- [README.md](../../README.md) - แนวคิด บอร์ดทั้งหมด plugin
- [docs/workflow.md](../../docs/workflow.md) - ขั้นตอน gate exit code apps workspace การอัปเดตเครื่องมือ
- [boards/uno-r4-wifi/README.md](../../boards/uno-r4-wifi/README.md) - hardware เวอร์ชันเครื่องมือ verification log
