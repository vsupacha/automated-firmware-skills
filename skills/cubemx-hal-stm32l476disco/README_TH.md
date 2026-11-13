# ST STM32L476G-DISCO (32L476GDISCOVERY) - วิธีใช้ `cubemx-hal-stm32l476disco`

firmware สำหรับ ST STM32L476G-DISCO (32L476GDISCOVERY) - STM32L476VGT6, STM32L4 - ด้วย STM32CubeMX 6.18 + STM32CubeL4 HAL + CMake ตั้งแต่ "ติดตั้งเครื่องมือครบหรือยัง" จนถึง
"ทดสอบบนบอร์ดผ่านแล้ว" โดยมีด่านตรวจ (gate) ทุกขั้น สั่ง Claude ด้วยภาษาของคุณเอง หรือรัน script ชุดเดียวกันเองใน
Git Bash ก็ได้ ภาษาอังกฤษ: [README.md](README.md) คำสั่งที่ agent ทำตาม: [SKILL.md](SKILL.md)

ขั้นที่ใช้บอร์ด (connect, flash, test, debug) ผ่านการตรวจบนบอร์ดจริงแล้ว ระดับหลักฐานของแต่ละ template และเวอร์ชันเครื่องมือที่แน่นอน:
[boards/stm32l476g-disco/README.md](../../boards/stm32l476g-disco/README.md)

| บนบอร์ด | |
| --- | --- |
| Console | ST-LINK virtual COM port |
| LED1, LED2 | LD4 (red), LD5 (green) |
| BTN1..BTN5 | joystick center, left, right, up, down |
| Probe / USB | on-board ST-LINK/V2-1 |

## 1. เตรียมเครื่อง (ทำครั้งเดียว)

- Windows 10/11 พร้อม Git for Windows (Git Bash) และ Python 3 กับ `pyserial`
- STM32CubeMX 6.18 (รุ่น classic) พร้อม package STM32Cube_FW_L4
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
| "ตรวจเครื่องมือสำหรับ ST STM32L476G-DISCO ให้หน่อย" | `check_tools.sh stm32l476g-disco` | `missing/bad=0`; แถว BAD บอกว่าต้องติดตั้งอะไร |
| "เครื่องมือยังเป็นเวอร์ชันที่ pin ไว้ไหม" | `update_tools.sh stm32l476g-disco` | `UPDATE: NONE` หรือคำถามก่อนแก้ pin |
| "สร้างแอป push-to-light ชื่อ btn-led" | `new_app.sh stm32l476g-disco btn-led "" push-to-light` | `Created <โฟลเดอร์แอป>` (ครั้งแรกบนเครื่อง: ถามที่เก็บแอป) |
| "เปิดใน IDE" | `open_ide.sh <app>` (new_app เปิดให้เอง) | `IDE: OPENED` - STM32CubeIDE for VS Code |
| "build ให้หน่อย" | `build.sh <app>` | `BUILD: PASS` ไม่มี warning + manifest (เวอร์ชันเครื่องมือ, hash ของ image) |
| "หาบอร์ดที่ต่ออยู่" | `discover.sh stm32l476g-disco` | `IDENTITY: PASS` - อ่านอย่างเดียว บันทึก probe และ console port ของเครื่องนี้ |
| "แฟลชเลย" | `flash.sh <app> --yes` **หลังคุณตอบ yes** | `FLASH: PASS` |
| "ทดสอบ" | `serial_test.py auto <app>/tests/push_to_light.json ...` | `RESULT: PASS (n/n passed ...)` |
| "ทดสอบแบบกดปุ่ม" | `serial_test.py auto <app>/tests/push_to_light.json ... --interactive` (แอป push-to-light) | กด joystick ตรงกลาง แล้วกดซ้าย เมื่อถูกบอก แล้วดู LD4 (สีแดง) |
| "ดูสถานะ MCU" | `debug.sh status stm32l476g-disco` | `DEBUG: STATUS running fault=none` - ไม่ reset ไม่ halt |
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
S=skills/cubemx-hal-stm32l476disco/scripts
bash $S/check_tools.sh stm32l476g-disco
bash $S/new_app.sh stm32l476g-disco btn-led "" push-to-light   # พิมพ์: Created <โฟลเดอร์แอป>
bash $S/build.sh <โฟลเดอร์แอป>
bash $S/discover.sh stm32l476g-disco
bash $S/flash.sh <โฟลเดอร์แอป> --yes          # เมื่อตัดสินใจ flash แล้วเท่านั้น
python $S/serial_test.py auto <โฟลเดอร์แอป>/tests/push_to_light.json <โฟลเดอร์แอป>/logs/test.log --board stm32l476g-disco --interactive
```

`<โฟลเดอร์แอป>` คือที่ `new_app.sh` พิมพ์ออกมา - `apps/btn-led` หรือเช่น `C:/fw-ws/btn-led` ถ้าเครื่องตั้ง
workspace ไว้ exit code: 0 ผ่าน, 1 ล้มเหลว, 2 มี warning ที่กั้น gate, **10 = ทำตามบรรทัด `ACTION:` แล้วรันซ้ำ**
(SETUP, CONNECT, APPROVE, CHOOSE)

## 5. หมายเหตุของบอร์ดนี้

- **การ flash:** STM32CubeProgrammer ผ่าน ST-LINK (ตรวจตัวตน: ชื่อบอร์ดของ ST-LINK, device ID; verify หลังเขียน)
- ทุกแอปมีไฟล์ `<app>.ioc` ที่เริ่มจาก board configuration ของ CubeMX บวก USART2 บน virtual COM port ของ ST-LINK ถ้าจะเปลี่ยน hardware ให้แก้ไฟล์นี้ใน STM32CubeMX แล้วสั่ง "generate ใหม่" (`regen.sh`) ห้ามแก้ `mx/` ด้วยมือ
- console รับข้อมูลด้วย interrupt ลง ring buffer (USART ของ L4 ไม่มี RX FIFO)

## อ่านต่อ (ภาษาอังกฤษ)

- [README.md](../../README.md) - แนวคิด บอร์ดทั้งหมด plugin
- [docs/workflow.md](../../docs/workflow.md) - ขั้นตอน gate exit code apps workspace การอัปเดตเครื่องมือ
- [boards/stm32l476g-disco/README.md](../../boards/stm32l476g-disco/README.md) - hardware เวอร์ชันเครื่องมือ verification log
