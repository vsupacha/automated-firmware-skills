# RT-Thread Titan Board - วิธีใช้ `scons-rtthread-titanboard`

firmware สำหรับ RT-Thread Titan Board - R7KA8P1KF, Renesas RA8P1, Cortex-M85 - ด้วย RT-Thread 5.1.0 + scons (RT-Thread Studio SDK) ตั้งแต่ "ติดตั้งเครื่องมือครบหรือยัง" จนถึง
"ทดสอบบนบอร์ดผ่านแล้ว" โดยมีด่านตรวจ (gate) ทุกขั้น สั่ง Claude ด้วยภาษาของคุณเอง หรือรัน script ชุดเดียวกันเองใน
Git Bash ก็ได้ ภาษาอังกฤษ: [README.md](README.md) คำสั่งที่ agent ทำตาม: [SKILL.md](SKILL.md)

ขั้นที่ใช้บอร์ด: hello-world ทดสอบบนบอร์ดจริงแล้ว ระดับหลักฐานของแต่ละ template และเวอร์ชันเครื่องมือที่แน่นอน:
[boards/titan-board/README.md](../../boards/titan-board/README.md)

| บนบอร์ด | |
| --- | --- |
| Console | RA4M2-VCOM virtual COM port (msh shell on uart8) |
| LED1 | red LED (P013) |
| BTN1 | KEY (P110) |
| Probe / USB | RA4M2 CMSIS-DAP บนบอร์ด (CMSIS-DAP v2, pyOCD) - Windows: ต้องใช้ WinUSB ที่มี GUID บน Interface 2 (Zadig) |

## 1. เตรียมเครื่อง (ทำครั้งเดียว)

- Windows 10/11 พร้อม Git for Windows (Git Bash) และ Python 3 กับ `pyserial`
- RT-Thread Studio พร้อมของจาก SDK Manager: support package ของ Titan-Board, GNU_Tools_for_ARM_Embedded_Processors 13.3 และ RealThread PyOCD (Studio มี scons มาให้)
- แต่ละแอปเป็นสำเนาแยกขนาดประมาณ 88 MB
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
| "ตรวจเครื่องมือสำหรับ RT-Thread Titan Board ให้หน่อย" | `check_tools.sh titan-board` | `missing/bad=0`; แถว BAD บอกว่าต้องติดตั้งอะไร |
| "เครื่องมือยังเป็นเวอร์ชันที่ pin ไว้ไหม" | `update_tools.sh titan-board` | `UPDATE: NONE` หรือคำถามก่อนแก้ pin |
| "สร้างแอป hello-world ชื่อ hello" | `new_app.sh titan-board hello "" hello-world` | `Created <โฟลเดอร์แอป>` (ครั้งแรกบนเครื่อง: ถามที่เก็บแอป) |
| "เปิดใน IDE" | `open_ide.sh <app>` (new_app เปิดให้เอง) | `IDE: OPENED` - RT-Thread Studio |
| "แอปนี้ใช้ Wi-Fi กับ SD card ได้ไหม" | `recipe.sh check <app> wifi sdcard` | `RECIPE: READY` หรือบรรทัด `ACTION:` บอกสิ่งที่ต้องเพิ่มก่อน: บล็อกใน board/Kconfig, FSP instance, board port, package ([recipes](recipes/README.md)) |
| "เพิ่ม SD card และ RTC ให้แอป" | `recipe.sh apply <app> sdcard rtc` แล้ว `--yes` **หลังคุณตอบ yes** | `APPLY: DONE` - ไฟล์จาก SDK/skill, `.config` + `rtconfig.h`, สำรองไฟล์ที่ถูกแทนไว้ใน `<app>/logs/` |
| "build ให้หน่อย" | `build.sh <app>` | `BUILD: PASS` ไม่มี warning + manifest (เวอร์ชันเครื่องมือ, hash ของ image) |
| "หาบอร์ดที่ต่ออยู่" | `discover.sh titan-board` | `IDENTITY: PASS` - อ่านอย่างเดียว บันทึก probe และ console port ของเครื่องนี้ |
| "แฟลชเลย" | `flash.sh <app> --yes` **หลังคุณตอบ yes** | `FLASH: PASS` |
| "ทดสอบ" | `serial_test.py auto <app>/tests/hello_world.json ...` | `RESULT: PASS (n/n passed ...)` |
| "บนบอร์ดรันอะไรอยู่" | `msh_status.py auto --board titan-board` | `MSH: PASS` - เวอร์ชัน RT-Thread, คำสั่ง msh ทั้งหมดพร้อมคำอธิบาย, thread และการใช้ stack, heap, device (อ่านอย่างเดียว ไม่ใช้ probe) |
| "ทดสอบแบบกดปุ่ม" | `serial_test.py auto <app>/tests/push_to_light.json ... --interactive` (แอป push-to-light) | กด KEY เมื่อถูกบอก แล้วดู red LED (P013) |
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
S=skills/scons-rtthread-titanboard/scripts
bash $S/check_tools.sh titan-board
bash $S/new_app.sh titan-board hello "" hello-world   # พิมพ์: Created <โฟลเดอร์แอป>
bash $S/build.sh <โฟลเดอร์แอป>
bash $S/discover.sh titan-board
bash $S/flash.sh <โฟลเดอร์แอป> --yes          # เมื่อตัดสินใจ flash แล้วเท่านั้น
python $S/serial_test.py auto <โฟลเดอร์แอป>/tests/hello_world.json <โฟลเดอร์แอป>/logs/test.log --board titan-board
```

`<โฟลเดอร์แอป>` คือที่ `new_app.sh` พิมพ์ออกมา - `apps/hello` หรือเช่น `C:/fw-ws/hello` ถ้าเครื่องตั้ง
workspace ไว้ exit code: 0 ผ่าน, 1 ล้มเหลว, 2 มี warning ที่กั้น gate, **10 = ทำตามบรรทัด `ACTION:` แล้วรันซ้ำ**
(SETUP, CONNECT, APPROVE, CHOOSE)

## 5. หมายเหตุของบอร์ดนี้

- **การ flash:** pyOCD ผ่าน RA4M2 CMSIS-DAP เขียนเฉพาะ code MRAM (ไม่แตะ option-setting memory ของ FSP) และอ่านกลับทุก byte
- console คือ msh ของ RT-Thread: คำสั่ง `info`, `led`, `btn` (ชื่อคำสั่ง msh ใส่ `?` ไม่ได้)
- IDE คือ RT-Thread Studio ไม่ใช่ VS Code **ปุ่ม Download ของ Studio จะเขียน `rtthread.hex` รวมส่วน option-setting (security) ไปด้วย** ควรใช้ "แฟลชเลย" (`flash.sh`) ซึ่งเขียนเฉพาะ code MRAM
- ทดสอบบนบอร์ดแล้ว (2026-10-31): blink (เห็นไฟแดงกะพริบ) และ push-to-light 17/17; hello-world build อย่างเดียว; ขั้นกดปุ่ม KEY และดูสี LED ยังไม่ได้รัน recipe ของ driver build ผ่านแต่ยังไม่ได้รันบนบอร์ด

## อ่านต่อ (ภาษาอังกฤษ)

- [README.md](../../README.md) - แนวคิด บอร์ดทั้งหมด plugin
- [docs/workflow.md](../../docs/workflow.md) - ขั้นตอน gate exit code apps workspace การอัปเดตเครื่องมือ
- [boards/titan-board/README.md](../../boards/titan-board/README.md) - hardware เวอร์ชันเครื่องมือ verification log
