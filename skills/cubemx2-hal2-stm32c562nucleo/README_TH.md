# ST NUCLEO-C562RE - วิธีใช้ `cubemx2-hal2-stm32c562nucleo`

firmware สำหรับ ST NUCLEO-C562RE - STM32C562RET6, STM32C5 - ด้วย STM32CubeMX2 + STM32Cube HAL2 + CMake ตั้งแต่ "ติดตั้งเครื่องมือครบหรือยัง" จนถึง
"ทดสอบบนบอร์ดผ่านแล้ว" โดยมีด่านตรวจ (gate) ทุกขั้น สั่ง Claude ด้วยภาษาของคุณเอง หรือรัน script ชุดเดียวกันเองใน
Git Bash ก็ได้ ภาษาอังกฤษ: [README.md](README.md) คำสั่งที่ agent ทำตาม: [SKILL.md](SKILL.md)

ขั้นที่ใช้บอร์ด (connect, flash, test, debug) ผ่านการตรวจบนบอร์ดจริงแล้ว ระดับหลักฐานของแต่ละ template และเวอร์ชันเครื่องมือที่แน่นอน:
[boards/nucleo-c562re/README.md](../../boards/nucleo-c562re/README.md)

| บนบอร์ด | |
| --- | --- |
| Console | ST-LINK virtual COM port |
| LED1 | LD1 (green) |
| BTN1 | B1 (USER) |
| Probe / USB | on-board ST-LINK |

## 1. เตรียมเครื่อง (ทำครั้งเดียว)

- Windows 10/11 พร้อม Git for Windows (Git Bash) และ Python 3 กับ `pyserial`
- STM32CubeMX2 และ pack ของมัน (STM32C5 DFP, HAL drivers, templates, board pack ของ NUCLEO-C562RE)
- STM32Cube bundles: GNU Tools for STM32, CMake, Ninja, STM32CubeProgrammer, ST-LINK GDB server (สำหรับ debug)
- ไม่บังคับ: VS Code และ STM32CubeIDE for VS Code สำหรับทาง IDE; Claude Code สำหรับทาง agent

`check_tools.sh` (ข้อ 3) จะบอกสิ่งที่ขาดพร้อมเวอร์ชันที่ board profile pin ไว้

## 2. ติดตั้ง plugin

ใน Claude Code จากโฟลเดอร์โปรเจกต์ของคุณ:

```
/plugin marketplace add vsupacha/automated-firmware-skills
/plugin install firmware-stm32@automated-firmware-skills
```

จะได้ `firmware-tools` มาด้วย ถ้าใช้ `automated-firmware-skills@automated-firmware-skills` จะได้ทุกบอร์ด
เลือกอย่างใดอย่างหนึ่ง

## 3. สั่ง Claude

| คุณพิมพ์ | Claude รัน | สิ่งที่เห็น |
| --- | --- | --- |
| "ขอวิธีใช้หน่อย" | `help.sh` | เมนูคำสั่ง บอร์ด และ template |
| "ตรวจเครื่องมือสำหรับ ST NUCLEO-C562RE ให้หน่อย" | `check_tools.sh nucleo-c562re` | `missing/bad=0`; แถว BAD บอกว่าต้องติดตั้งอะไร |
| "สร้างแอป push-to-light ชื่อ btn-led" | `new_app.sh nucleo-c562re btn-led "" push-to-light` | `Created <โฟลเดอร์แอป>` (ครั้งแรกบนเครื่อง: ถามที่เก็บแอป) |
| "เปิดใน IDE" | `open_ide.sh <app>` (new_app เปิดให้เอง) | `IDE: OPENED` - STM32CubeIDE for VS Code |
| "build ให้หน่อย" | `build.sh <app>` | `BUILD: PASS` ไม่มี warning + manifest (เวอร์ชันเครื่องมือ, hash ของ image) |
| "หาบอร์ดที่ต่ออยู่" | `discover.sh nucleo-c562re` | `IDENTITY: PASS` - อ่านอย่างเดียว บันทึก probe และ console port ของเครื่องนี้ |
| "แฟลชเลย" | `flash.sh <app> --yes` **หลังคุณตอบ yes** | `FLASH: PASS` |
| "ทดสอบ" | `serial_test.py auto <app>/tests/push_to_light.json ...` | `RESULT: PASS (n/n passed ...)` |
| "ทดสอบแบบกดปุ่ม" | `serial_test.py auto <app>/tests/push_to_light.json ... --interactive` (แอป push-to-light) | กด B1 (USER) เมื่อถูกบอก แล้วดู LD1 (green) |
| "ดูสถานะ MCU" | `debug.sh status nucleo-c562re` | `DEBUG: STATUS running fault=none` - ไม่ reset ไม่ halt |
| "รัน debug scenario" | `debug.sh run <app> .../scenarios/push-to-light.json` | `DEBUG: PASS` - breakpoint / watchpoint; core หยุดระหว่าง attach |
| "clean ให้หน่อย" | `clean.sh` (dry run ก่อน) | แสดงรายการ แล้วลบเมื่อคุณตอบ yes; `--apps` ลบซอร์สของแอปด้วย |

- **แอปแรกบนเครื่อง:** ถ้า `apps/` อยู่ใน Dropbox/OneDrive หรือ path ยาวเกิน `new_app.sh` จะหยุดด้วย
  `ACTION: CHOOSE` แล้ว Claude จะถามว่าจะเก็บแอปที่ไหน (แนะนำโฟลเดอร์ path สั้นนอกโฟลเดอร์ที่ sync เช่น
  `C:/fw-ws`) แล้วบันทึกด้วย `lib/fw_workspace.sh set <dir>` เครื่องนั้นจะไม่ถามอีก
- **สองทาง:** หลังสร้างแอปแล้ว คุณเขียนโค้ด, build, flash และ debug เองใน STM32CubeIDE for VS Code ได้
  (ทาง IDE) หรือให้ Claude รันขั้นที่มี gate ให้ (ทาง script) ใช้โฟลเดอร์แอปเดียวกัน สลับได้ทุกเมื่อ
- **โค้ดของคุณ** อยู่ใน `src/` แบ่งเป็น layer: `board/` (ขาและ peripheral), `func/` (logic ที่ย้ายบอร์ดได้),
  `app_main` (ตัวเชื่อม) - ดู [docs/board-api.md](../../docs/board-api.md)
- **ไม่มีการ flash จนกว่าคุณจะตอบ yes** Claude จะแสดงบอร์ด แอป และ hash ของ image แล้วรอ
  `flash.sh` ตรวจตัวตนบอร์ดอีกครั้งก่อนเขียน

## 4. ใช้แบบไม่มี Claude (Git Bash จาก root ของ repo)

```bash
S=skills/cubemx2-hal2-stm32c562nucleo/scripts
bash $S/check_tools.sh nucleo-c562re
bash $S/new_app.sh nucleo-c562re btn-led "" push-to-light   # พิมพ์: Created <โฟลเดอร์แอป>
bash $S/build.sh <โฟลเดอร์แอป>
bash $S/discover.sh nucleo-c562re
bash $S/flash.sh <โฟลเดอร์แอป> --yes          # เมื่อตัดสินใจ flash แล้วเท่านั้น
python $S/serial_test.py auto <โฟลเดอร์แอป>/tests/push_to_light.json <โฟลเดอร์แอป>/logs/test.log --board nucleo-c562re --interactive
```

`<โฟลเดอร์แอป>` คือที่ `new_app.sh` พิมพ์ออกมา - `apps/btn-led` หรือเช่น `C:/fw-ws/btn-led` ถ้าเครื่องตั้ง
workspace ไว้ exit code: 0 ผ่าน, 1 ล้มเหลว, 2 มี warning ที่กั้น gate, **10 = ทำตามบรรทัด `ACTION:` แล้วรันซ้ำ**
(SETUP, CONNECT, APPROVE, CHOOSE)

## 5. หมายเหตุของบอร์ดนี้

- **การ flash:** STM32CubeProgrammer ผ่าน ST-LINK (ตรวจตัวตน: ชื่อบอร์ดของ ST-LINK, ชื่อและ ID ของชิป; verify หลังเขียน)
- ทุกแอปมีไฟล์ `<app>.ioc2` (การตั้งค่า hardware ของ STM32CubeMX2) ที่สร้างจาก board pack หรือ copy มาด้วย `--ioc2 <file>` ถ้าจะเปลี่ยน hardware ให้แก้ที่ไฟล์นี้ (CubeMX2 GUI หรือ CLI) แล้วสั่ง "generate ใหม่" (`regen.sh`) ห้ามแก้ `mx/` ด้วยมือ
- core ของ C5 อยู่ที่ debug access port 1 (`DEBUG_APID=1` ใน profile) `debug.sh` จัดการให้เอง
- ขา: LD1 = PA5 (high = ติด), B1 = PC13 (กดแล้วเป็น high), B2 = RESET; console = USART2 (PA2/PA3) ออก virtual COM port ของ ST-LINK ที่ 115200 - รายละเอียดใน board README

## อ่านต่อ (ภาษาอังกฤษ)

- [README.md](../../README.md) - แนวคิด บอร์ดทั้งหมด plugin
- [docs/workflow.md](../../docs/workflow.md) - ขั้นตอน gate exit code apps workspace การอัปเดตเครื่องมือ
- [boards/nucleo-c562re/README.md](../../boards/nucleo-c562re/README.md) - hardware เวอร์ชันเครื่องมือ verification log
