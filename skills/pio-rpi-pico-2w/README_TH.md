# pio-rpi-pico-2w — คู่มือภาษาไทย

Skill สำหรับ Claude Code ใช้สร้าง firmware บอร์ด **Raspberry Pi Pico 2 W (RP2350)** ด้วย
PlatformIO + arduino-pico แบบอัตโนมัติ ตั้งแต่ตรวจเครื่องมือจนถึงทดสอบบนบอร์ดจริง
(คำสั่งหลักสำหรับ Claude อยู่ใน `SKILL.md` เป็นภาษาอังกฤษ)

## ก่อนเริ่ม

- ติดตั้ง PlatformIO (`python -m pip install -U platformio` หรือ extension ใน VS Code) และ Git, Python + pyserial
- build ครั้งแรกจะดาวน์โหลด platform + arduino-pico (~1.5 GB) ครั้งเดียว
- Windows: ควรตั้ง `git config --global core.longpaths true` และใช้โฟลเดอร์ที่ path สั้น ไม่มีภาษาไทย
- บอร์ดไม่มีปุ่ม reset — ถ้าบอร์ดไม่ขึ้น ให้ถอดสาย กด BOOTSEL ค้างแล้วเสียบ แล้วปล่อย

## ลำดับงาน 6 ขั้น + clean

| ขั้น | ทำอะไร | สคริปต์ | ผ่านเมื่อ |
| --- | --- | --- | --- |
| 1 | ตรวจ path + PlatformIO, platform, picotool, git, python/pyserial | `check_tools.sh <board>` | `missing/bad=0` |
| 2a | ค้นหาบอร์ด (อ่านอย่างเดียว) บันทึก USB serial (= chip ID) + COM port | `discover.sh <board>` | `IDENTITY: PASS` |
| 2b | สร้างแอป PlatformIO จาก template (platform ล็อกที่ commit) | `new_app.sh <board> <app> "" hello-world` | `Created ...` |
| 3 | เขียนโค้ดแยก layer: `src/board` → `src/func` → `src/main.cpp` + test spec | template | ไม่ข้าม layer |
| 4 | build + manifest (sha256, เวอร์ชันทุก package) | `build.sh <app>` | `BUILD: PASS`, 0 warning ใน src/ |
| 5 | flash (ขออนุญาตก่อนทุกครั้ง): สั่งเข้า BOOTSEL เอง ตรวจชิป/flash/chip ID แล้ว load + verify | `flash.sh <app> --yes` | `FLASH: PASS` |
| 6 | ทดสอบผ่าน USB serial ตาม spec JSON | `serial_test.py auto <spec> <log> --board <board>` | `RESULT: PASS` |
| 7 | clean: ลบผล build (`.pio`) — `--apps` ลบทั้งแอป | `clean.sh` แล้ว `clean.sh --yes` | `CLEAN: done` |

## โครงสร้าง

```
skills/pio-rpi-pico-2w/          skill นี้ (SKILL.md, scripts/, reference/, templates/)
boards/rpi-pico-2w/README.md     ข้อมูล hardware ของบอร์ด
boards/rpi-pico-2w/pio-rpi-pico-2w/   profile สำหรับ skill นี้ + log การทดสอบ
apps/<app>/                      แอปที่สร้าง (platformio.ini, src/, tests/, pico-app.env)
```

บอร์ดของตัวเอง: วาง profile ไว้ในโปรเจกต์ `boards/<id>/pio-rpi-pico-2w/board.env` (skill หาที่นี่ก่อน)
