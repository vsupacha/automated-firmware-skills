# RT-Thread Vision Board - วิธีใช้ `scons-rtthread-visionboard`

firmware สำหรับ RT-Thread Vision Board - R7FA8D1BH, Renesas RA8D1, Cortex-M85 - ด้วย RT-Thread 5.0.2 + scons (RT-Thread Studio SDK) ตั้งแต่ "ติดตั้งเครื่องมือครบหรือยัง" จนถึง
"ทดสอบบนบอร์ดผ่านแล้ว" โดยมีด่านตรวจ (gate) ทุกขั้น สั่ง Claude ด้วยภาษาของคุณเอง หรือรัน script ชุดเดียวกันเองใน
Git Bash ก็ได้ ภาษาอังกฤษ: [README.md](README.md) คำสั่งที่ agent ทำตาม: [SKILL.md](SKILL.md)

ขั้นที่ใช้บอร์ด: hello-world ทดสอบบนบอร์ดจริงแล้ว ระดับหลักฐานของแต่ละ template และเวอร์ชันเครื่องมือที่แน่นอน:
[boards/vision-board/README.md](../../boards/vision-board/README.md)

| บนบอร์ด | |
| --- | --- |
| Console | ART-Link virtual COM port (msh shell) |
| LED1 | blue LED (P102) |
| BTN1 | KEY0 |
| Probe / USB | on-board ART-Link (pyOCD) |

## 1. เตรียมเครื่อง (ทำครั้งเดียว)

- Windows 10/11 พร้อม Git for Windows (Git Bash) และ Python 3 กับ `pyserial`
- RT-Thread Studio พร้อมของจาก SDK Manager: support package ของ VISION-BOARD, GNU_Tools_for_ARM_Embedded_Processors 13.3 และ RealThread PyOCD (Studio มี scons มาให้)
- แต่ละแอปเป็นสำเนาแยกขนาดประมาณ 38 MB
- ไม่บังคับ: VS Code และ RT-Thread Studio สำหรับทาง IDE (RT-Thread Studio เป็น IDE แยกของตัวเอง); Claude Code สำหรับทาง agent

`check_tools.sh` (ข้อ 3) จะบอกสิ่งที่ขาดพร้อมเวอร์ชันที่ board profile pin ไว้

## 2. ติดตั้ง plugin

ใน Claude Code จากโฟลเดอร์โปรเจกต์ของคุณ:

```
/plugin marketplace add vsupacha/automated-firmware-skills
/plugin install firmware-rtthread@automated-firmware-skills
```

จะได้ `firmware-tools` มาด้วย ถ้าใช้ `automated-firmware-skills@automated-firmware-skills` จะได้ทุกบอร์ด
เลือกอย่างใดอย่างหนึ่ง

## 3. สั่ง Claude

| คุณพิมพ์ | Claude รัน | สิ่งที่เห็น |
| --- | --- | --- |
| "ขอวิธีใช้หน่อย" | `help.sh` | เมนูคำสั่ง บอร์ด และ template |
| "ตรวจเครื่องมือสำหรับ RT-Thread Vision Board ให้หน่อย" | `check_tools.sh vision-board` | `missing/bad=0`; แถว BAD บอกว่าต้องติดตั้งอะไร |
| "สร้างแอป hello-world ชื่อ hello" | `new_app.sh vision-board hello "" hello-world` | `Created <โฟลเดอร์แอป>` (ครั้งแรกบนเครื่อง: ถามที่เก็บแอป) |
| "เปิดใน IDE" | `open_ide.sh <app>` (new_app เปิดให้เอง) | `IDE: OPENED` - RT-Thread Studio |
| "build ให้หน่อย" | `build.sh <app>` | `BUILD: PASS` ไม่มี warning + manifest (เวอร์ชันเครื่องมือ, hash ของ image) |
| "หาบอร์ดที่ต่ออยู่" | `discover.sh vision-board` | `IDENTITY: PASS` - อ่านอย่างเดียว บันทึก probe และ console port ของเครื่องนี้ |
| "แฟลชเลย" | `flash.sh <app> --yes` **หลังคุณตอบ yes** | `FLASH: PASS` |
| "ทดสอบ" | `serial_test.py auto <app>/tests/hello_world.json ...` | `RESULT: PASS (n/n passed ...)` |
| "ทดสอบแบบกดปุ่ม" | `serial_test.py auto <app>/tests/push_to_light.json ... --interactive` (แอป push-to-light) | กด KEY0 เมื่อถูกบอก แล้วดู blue LED (P102) |
| "clean ให้หน่อย" | `clean.sh` (dry run ก่อน) | แสดงรายการ แล้วลบเมื่อคุณตอบ yes; `--apps` ลบซอร์สของแอปด้วย |

- **แอปแรกบนเครื่อง:** ถ้า `apps/` อยู่ใน Dropbox/OneDrive หรือ path ยาวเกิน `new_app.sh` จะหยุดด้วย
  `ACTION: CHOOSE` แล้ว Claude จะถามว่าจะเก็บแอปที่ไหน (แนะนำโฟลเดอร์ path สั้นนอกโฟลเดอร์ที่ sync เช่น
  `C:/fw-ws`) แล้วบันทึกด้วย `lib/fw_workspace.sh set <dir>` เครื่องนั้นจะไม่ถามอีก
- **สองทาง:** หลังสร้างแอปแล้ว คุณเขียนโค้ด, build, flash และ debug เองใน RT-Thread Studio ได้
  (ทาง IDE) หรือให้ Claude รันขั้นที่มี gate ให้ (ทาง script) ใช้โฟลเดอร์แอปเดียวกัน สลับได้ทุกเมื่อ
- **โค้ดของคุณ** อยู่ใน `src/` แบ่งเป็น layer: `board/` (ขาและ peripheral), `func/` (logic ที่ย้ายบอร์ดได้),
  `app_main` (ตัวเชื่อม) - ดู [docs/board-api.md](../../docs/board-api.md)
- **ไม่มีการ flash จนกว่าคุณจะตอบ yes** Claude จะแสดงบอร์ด แอป และ hash ของ image แล้วรอ
  `flash.sh` ตรวจตัวตนบอร์ดอีกครั้งก่อนเขียน

## 4. ใช้แบบไม่มี Claude (Git Bash จาก root ของ repo)

```bash
S=skills/scons-rtthread-visionboard/scripts
bash $S/check_tools.sh vision-board
bash $S/new_app.sh vision-board hello "" hello-world   # พิมพ์: Created <โฟลเดอร์แอป>
bash $S/build.sh <โฟลเดอร์แอป>
bash $S/discover.sh vision-board
bash $S/flash.sh <โฟลเดอร์แอป> --yes          # เมื่อตัดสินใจ flash แล้วเท่านั้น
python $S/serial_test.py auto <โฟลเดอร์แอป>/tests/hello_world.json <โฟลเดอร์แอป>/logs/test.log --board vision-board
```

`<โฟลเดอร์แอป>` คือที่ `new_app.sh` พิมพ์ออกมา - `apps/hello` หรือเช่น `C:/fw-ws/hello` ถ้าเครื่องตั้ง
workspace ไว้ exit code: 0 ผ่าน, 1 ล้มเหลว, 2 มี warning ที่กั้น gate, **10 = ทำตามบรรทัด `ACTION:` แล้วรันซ้ำ**
(SETUP, CONNECT, APPROVE, CHOOSE)

## 5. หมายเหตุของบอร์ดนี้

- **การ flash:** pyOCD ผ่าน ART-Link เขียนเฉพาะ code flash (ไม่แตะ option-setting memory ของ FSP) และอ่านกลับทุก byte
- console คือ msh ของ RT-Thread: คำสั่ง `info`, `led`, `btn` (ชื่อคำสั่ง msh ใส่ `?` ไม่ได้)
- IDE คือ RT-Thread Studio ไม่ใช่ VS Code **ปุ่ม Download ของ Studio จะเขียน `rtthread.hex` รวมส่วน option-setting (security) ไปด้วย** ควรใช้ "แฟลชเลย" (`flash.sh`) ซึ่งเขียนเฉพาะ code flash
- ตอนนี้ทดสอบบนบอร์ดแล้วเฉพาะ hello-world; สีของ LED และระดับของปุ่ม KEY0 ใน push-to-light ยังไม่ได้ยืนยัน

## อ่านต่อ (ภาษาอังกฤษ)

- [README.md](../../README.md) - แนวคิด บอร์ดทั้งหมด plugin
- [docs/workflow.md](../../docs/workflow.md) - ขั้นตอน gate exit code apps workspace การอัปเดตเครื่องมือ
- [boards/vision-board/README.md](../../boards/vision-board/README.md) - hardware เวอร์ชันเครื่องมือ verification log
