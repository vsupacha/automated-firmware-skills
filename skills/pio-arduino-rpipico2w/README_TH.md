# Raspberry Pi Pico 2 W - วิธีใช้ `pio-arduino-rpipico2w`

firmware สำหรับ Raspberry Pi Pico 2 W - RP2350A - ด้วย PlatformIO + arduino-pico ตั้งแต่ "ติดตั้งเครื่องมือครบหรือยัง" จนถึง
"ทดสอบบนบอร์ดผ่านแล้ว" โดยมีด่านตรวจ (gate) ทุกขั้น สั่ง Claude ด้วยภาษาของคุณเอง หรือรัน script ชุดเดียวกันเองใน
Git Bash ก็ได้ ภาษาอังกฤษ: [README.md](README.md) คำสั่งที่ agent ทำตาม: [SKILL.md](SKILL.md)

ขั้นที่ใช้บอร์ด (connect, flash, test) ผ่านการตรวจบนบอร์ดจริงแล้ว ระดับหลักฐานของแต่ละ template และเวอร์ชันเครื่องมือที่แน่นอน:
[boards/rpi-pico-2w/README.md](../../boards/rpi-pico-2w/README.md)

| บนบอร์ด | |
| --- | --- |
| Console | USB CDC |
| LED1 | LED (on the Wi-Fi module) |
| BTN1 | BOOTSEL |
| Probe / USB | USB port (no debug probe needed) |

## 1. เตรียมเครื่อง (ทำครั้งเดียว)

- Windows 10/11 พร้อม Git for Windows (Git Bash) และ Python 3 กับ `pyserial`
- PlatformIO Core (pip หรือ VS Code extension) และ Git; build ครั้งแรกจะโหลด platform ที่ pin ไว้และ arduino-pico (~1.5 GB)
- บน Windows ให้รัน `git config --global core.longpaths true` ก่อน build ครั้งแรก
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
| "ตรวจเครื่องมือสำหรับ Raspberry Pi Pico 2 W ให้หน่อย" | `check_tools.sh rpi-pico-2w` | `missing/bad=0`; แถว BAD บอกว่าต้องติดตั้งอะไร |
| "สร้างแอป push-to-light ชื่อ btn-led" | `new_app.sh rpi-pico-2w btn-led "" push-to-light` | `Created <โฟลเดอร์แอป>` (ครั้งแรกบนเครื่อง: ถามที่เก็บแอป) |
| "เปิดใน IDE" | `open_ide.sh <app>` (new_app เปิดให้เอง) | `IDE: OPENED` - PlatformIO IDE (VS Code) |
| "build ให้หน่อย" | `build.sh <app>` | `BUILD: PASS` ไม่มี warning + manifest (เวอร์ชันเครื่องมือ, hash ของ image) |
| "หาบอร์ดที่ต่ออยู่" | `discover.sh rpi-pico-2w` | `IDENTITY: PASS` - อ่านอย่างเดียว บันทึก probe และ console port ของเครื่องนี้ |
| "แฟลชเลย" | `flash.sh <app> --yes` **หลังคุณตอบ yes** | `FLASH: PASS` |
| "ทดสอบ" | `serial_test.py auto <app>/tests/push_to_light.json ...` | `RESULT: PASS (n/n passed ...)` |
| "รัน unit test" | `unit_test.sh <app>` - ถามก่อน แล้ว `--yes` | `UNIT: PASS (12/12)` - Unity test ของ `func/` บนบอร์ด (prototype); หลังจากนั้นบอร์ดรัน image ของ test จนกว่าจะ flash แอปกลับ |
| "ทดสอบแบบกดปุ่ม" | `serial_test.py auto <app>/tests/push_to_light.json ... --interactive` (แอป push-to-light) | กด BOOTSEL เมื่อถูกบอก แล้วดู LED (on the Wi-Fi module) |
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
S=skills/pio-arduino-rpipico2w/scripts
bash $S/check_tools.sh rpi-pico-2w
bash $S/new_app.sh rpi-pico-2w btn-led "" push-to-light   # พิมพ์: Created <โฟลเดอร์แอป>
bash $S/build.sh <โฟลเดอร์แอป>
bash $S/discover.sh rpi-pico-2w
bash $S/flash.sh <โฟลเดอร์แอป> --yes          # เมื่อตัดสินใจ flash แล้วเท่านั้น
python $S/serial_test.py auto <โฟลเดอร์แอป>/tests/push_to_light.json <โฟลเดอร์แอป>/logs/test.log --board rpi-pico-2w --interactive
```

`<โฟลเดอร์แอป>` คือที่ `new_app.sh` พิมพ์ออกมา - `apps/btn-led` หรือเช่น `C:/fw-ws/btn-led` ถ้าเครื่องตั้ง
workspace ไว้ exit code: 0 ผ่าน, 1 ล้มเหลว, 2 มี warning ที่กั้น gate, **10 = ทำตามบรรทัด `ACTION:` แล้วรันซ้ำ**
(SETUP, CONNECT, APPROVE, CHOOSE)

## 5. หมายเหตุของบอร์ดนี้

- **การ flash:** picotool ผ่าน USB: flash.sh สั่ง reboot sketch ที่รันอยู่เข้า BOOTSEL ให้เอง (แตะ 1200 baud) ตรวจตัวตน (ชิป, ขนาด flash, chip ID) แล้วโหลดพร้อม verify
- BTN1 คือปุ่ม BOOTSEL: ตอน sketch รันอยู่จะอ่านปุ่มนี้ได้ แต่ถ้ากดค้างตอนจ่ายไฟจะเข้า USB bootloader แทน
- โค้ดเป็นแบบ Arduino (มี `func/` เป็น C++ ของตัวเอง)
- บอร์ดไม่มีปุ่ม reset ถ้าบอร์ดไม่ตอบสนอง: ถอดสาย USB กด BOOTSEL ค้างไว้ เสียบสาย แล้วปล่อย บอร์ดจะเข้า bootloader และ `flash.sh` เขียนใหม่ได้
- `discover.sh` บันทึก USB serial ของบอร์ด (= chip ID) และ COM port ของเครื่องนี้

## อ่านต่อ (ภาษาอังกฤษ)

- [README.md](../../README.md) - แนวคิด บอร์ดทั้งหมด plugin
- [docs/workflow.md](../../docs/workflow.md) - ขั้นตอน gate exit code apps workspace การอัปเดตเครื่องมือ
- [boards/rpi-pico-2w/README.md](../../boards/rpi-pico-2w/README.md) - hardware เวอร์ชันเครื่องมือ verification log
