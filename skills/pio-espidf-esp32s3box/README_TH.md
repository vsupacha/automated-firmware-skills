# Espressif ESP32-S3-BOX (2021) - วิธีใช้ `pio-espidf-esp32s3box`

firmware สำหรับ Espressif ESP32-S3-BOX (2021) - ESP32-S3 - ด้วย PlatformIO + ESP-IDF 5.5 ตั้งแต่ "ติดตั้งเครื่องมือครบหรือยัง" จนถึง
"ทดสอบบนบอร์ดผ่านแล้ว" โดยมีด่านตรวจ (gate) ทุกขั้น สั่ง Claude ด้วยภาษาของคุณเอง หรือรัน script ชุดเดียวกันเองใน
Git Bash ก็ได้ ภาษาอังกฤษ: [README.md](README.md) คำสั่งที่ agent ทำตาม: [SKILL.md](SKILL.md)

ขั้นที่ใช้บอร์ด (connect, flash, test) ผ่านการตรวจบนบอร์ดจริงแล้ว ระดับหลักฐานของแต่ละ template และเวอร์ชันเครื่องมือที่แน่นอน:
[boards/esp32-s3-box/README.md](../../boards/esp32-s3-box/README.md)

| บนบอร์ด | |
| --- | --- |
| Console | USB Serial/JTAG |
| LED1 | LCD backlight |
| BTN1 | BOOT |
| Probe / USB | USB Serial/JTAG port |

## 1. เตรียมเครื่อง (ทำครั้งเดียว)

- Windows 10/11 พร้อม Git for Windows (Git Bash) และ Python 3 กับ `pyserial`
- PlatformIO Core และ Git; build ครั้งแรกจะติดตั้ง espressif32 + ESP-IDF 5.5 และ python environment ของมัน (ประมาณ 7 นาที)
- discover, flash และ test ใช้ python ของ PlatformIO เอง (มี pyserial และ esptool มาให้)
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
| "ตรวจเครื่องมือสำหรับ Espressif ESP32-S3-BOX ให้หน่อย" | `check_tools.sh esp32-s3-box` | `missing/bad=0`; แถว BAD บอกว่าต้องติดตั้งอะไร |
| "สร้างแอป push-to-light ชื่อ btn-esp" | `new_app.sh esp32-s3-box btn-esp "" push-to-light` | `Created <โฟลเดอร์แอป>` (ครั้งแรกบนเครื่อง: ถามที่เก็บแอป) |
| "เปิดใน IDE" | `open_ide.sh <app>` (new_app เปิดให้เอง) | `IDE: OPENED` - PlatformIO IDE (VS Code) |
| "build ให้หน่อย" | `build.sh <app>` | `BUILD: PASS` ไม่มี warning + manifest (เวอร์ชันเครื่องมือ, hash ของ image) |
| "สำรองบอร์ดก่อน" | `backup.sh esp32-s3-box` | เก็บ image จากโรงงานไว้ก่อน flash ครั้งแรก |
| "หาบอร์ดที่ต่ออยู่" | `discover.sh esp32-s3-box` | `IDENTITY: PASS` - อ่านอย่างเดียว บันทึก probe และ console port ของเครื่องนี้ |
| "แฟลชเลย" | `flash.sh <app> --yes` **หลังคุณตอบ yes** | `FLASH: PASS` |
| "ทดสอบ" | `serial_test.py auto <app>/tests/push_to_light.json ...` | `RESULT: PASS (n/n passed ...)` |
| "ทดสอบแบบกดปุ่ม" | `serial_test.py auto <app>/tests/push_to_light.json ... --interactive` (แอป push-to-light) | กด BOOT เมื่อถูกบอก แล้วดู LCD backlight |
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
S=skills/pio-espidf-esp32s3box/scripts
bash $S/check_tools.sh esp32-s3-box
bash $S/new_app.sh esp32-s3-box btn-esp "" push-to-light   # พิมพ์: Created <โฟลเดอร์แอป>
bash $S/build.sh <โฟลเดอร์แอป>
bash $S/discover.sh esp32-s3-box
bash $S/flash.sh <โฟลเดอร์แอป> --yes          # เมื่อตัดสินใจ flash แล้วเท่านั้น
~/.platformio/penv/Scripts/python $S/serial_test.py auto <โฟลเดอร์แอป>/tests/push_to_light.json <โฟลเดอร์แอป>/logs/test.log --board esp32-s3-box --interactive
```

`<โฟลเดอร์แอป>` คือที่ `new_app.sh` พิมพ์ออกมา - `apps/btn-esp` หรือเช่น `C:/fw-ws/btn-esp` ถ้าเครื่องตั้ง
workspace ไว้ exit code: 0 ผ่าน, 1 ล้มเหลว, 2 มี warning ที่กั้น gate, **10 = ทำตามบรรทัด `ACTION:` แล้วรันซ้ำ**
(SETUP, CONNECT, APPROVE, CHOOSE)

## 5. หมายเหตุของบอร์ดนี้

- **การ flash:** esptool ผ่าน USB: ตรวจตัวตน (ชิป, MAC = USB serial ที่บันทึกไว้, ขนาด flash, secure boot และ flash encryption ต้องปิด) และ verify ทุกส่วนด้วย hash
- LED1 คือไฟ backlight ของจอ LCD และ BTN1 คือปุ่ม BOOT - บอร์ดนี้ไม่มี LED ธรรมดาให้ผู้ใช้
- `src/func` ของแอปคือ `lib/func` ภาษา C ที่ใช้ร่วมกัน; การตั้งค่า ESP-IDF อยู่ใน `sdkconfig.defaults`
- "สำรองบอร์ด" (`backup.sh esp32-s3-box`) ก่อน flash ครั้งแรก เพื่อเก็บ firmware จากโรงงานไว้

## อ่านต่อ (ภาษาอังกฤษ)

- [README.md](../../README.md) - แนวคิด บอร์ดทั้งหมด plugin
- [docs/workflow.md](../../docs/workflow.md) - ขั้นตอน gate exit code apps workspace การอัปเดตเครื่องมือ
- [boards/esp32-s3-box/README.md](../../boards/esp32-s3-box/README.md) - hardware เวอร์ชันเครื่องมือ verification log
