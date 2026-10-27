# ST STM32N6570-DK - วิธีใช้ `cubemx-hal-stm32n6570dk`

firmware สำหรับ ST STM32N6570-DK - STM32N657X0H3Q, STM32N6 - ด้วย STM32CubeMX 6.18 + STM32CubeN6 HAL + CMake ตั้งแต่ "ติดตั้งเครื่องมือครบหรือยัง" จนถึง
"ทดสอบบนบอร์ดผ่านแล้ว" โดยมีด่านตรวจ (gate) ทุกขั้น สั่ง Claude ด้วยภาษาของคุณเอง หรือรัน script ชุดเดียวกันเองใน
Git Bash ก็ได้ ภาษาอังกฤษ: [README.md](README.md) คำสั่งที่ agent ทำตาม: [SKILL.md](SKILL.md)

ทำได้ถึงขั้น build - ขั้นที่ใช้บอร์ดยังอยู่ในแผน ระดับหลักฐานของแต่ละ template และเวอร์ชันเครื่องมือที่แน่นอน:
[boards/stm32n6570-dk/README.md](../../boards/stm32n6570-dk/README.md)

| บนบอร์ด | |
| --- | --- |
| Console | ST-LINK virtual COM port |
| LED1 | LED1 (green) |
| BTN1 | USER1 |
| Probe / USB | on-board ST-LINK |

## 1. เตรียมเครื่อง (ทำครั้งเดียว)

- Windows 10/11 พร้อม Git for Windows (Git Bash) และ Python 3 กับ `pyserial`
- STM32CubeMX 6.18 (รุ่น classic) พร้อม package STM32Cube_FW_N6
- STM32Cube bundles: GNU Tools for STM32, CMake, Ninja
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
| "ตรวจเครื่องมือสำหรับ ST STM32N6570-DK ให้หน่อย" | `check_tools.sh stm32n6570-dk` | `missing/bad=0`; แถว BAD บอกว่าต้องติดตั้งอะไร |
| "เครื่องมือยังเป็นเวอร์ชันที่ pin ไว้ไหม" | `update_tools.sh stm32n6570-dk` | `UPDATE: NONE` หรือคำถามก่อนแก้ pin |
| "สร้างแอป hello-world ชื่อ hello-n6" | `new_app.sh stm32n6570-dk hello-n6 "" hello-world` | `Created <โฟลเดอร์แอป>` (ครั้งแรกบนเครื่อง: ถามที่เก็บแอป) |
| "เปิดใน IDE" | `open_ide.sh <app>` (new_app เปิดให้เอง) | `IDE: OPENED` - STM32CubeIDE for VS Code |
| "build ให้หน่อย" | `build.sh <app>` | `BUILD: PASS` ไม่มี warning + manifest (เวอร์ชันเครื่องมือ, hash ของ image) |
| "clean ให้หน่อย" | `clean.sh` (dry run ก่อน) | แสดงรายการ แล้วลบเมื่อคุณตอบ yes; `--apps` ลบซอร์สของแอปด้วย |

- **แอปแรกบนเครื่อง:** ถ้า `apps/` อยู่ใน Dropbox/OneDrive หรือ path ยาวเกิน `new_app.sh` จะหยุดด้วย
  `ACTION: CHOOSE` แล้ว Claude จะถามว่าจะเก็บแอปที่ไหน (แนะนำโฟลเดอร์ path สั้นนอกโฟลเดอร์ที่ sync เช่น
  `C:/fw-ws`) แล้วบันทึกด้วย `lib/fw_workspace.sh set <dir>` เครื่องนั้นจะไม่ถามอีก
- **สองทาง:** หลังสร้างแอปแล้ว คุณเขียนโค้ด, build และ debug เองใน STM32CubeIDE for VS Code ได้
  (ทาง IDE) หรือให้ Claude รันขั้นที่มี gate ให้ (ทาง script) ใช้โฟลเดอร์แอปเดียวกัน สลับได้ทุกเมื่อ
- **โค้ดของคุณ** อยู่ใน `src/` แบ่งเป็น layer: `board/` (ขาและ peripheral), `func/` (logic ที่ย้ายบอร์ดได้),
  `app_main` (ตัวเชื่อม) - ดู [docs/board-api.md](../../docs/board-api.md)

## 4. ใช้แบบไม่มี Claude (Git Bash จาก root ของ repo)

```bash
S=skills/cubemx-hal-stm32n6570dk/scripts
bash $S/check_tools.sh stm32n6570-dk
bash $S/new_app.sh stm32n6570-dk hello-n6 "" hello-world   # พิมพ์: Created <โฟลเดอร์แอป>
bash $S/build.sh <โฟลเดอร์แอป>
```

`<โฟลเดอร์แอป>` คือที่ `new_app.sh` พิมพ์ออกมา - `apps/hello-n6` หรือเช่น `C:/fw-ws/hello-n6` ถ้าเครื่องตั้ง
workspace ไว้ exit code: 0 ผ่าน, 1 ล้มเหลว, 2 มี warning ที่กั้น gate, **10 = ทำตามบรรทัด `ACTION:` แล้วรันซ้ำ**
(SETUP, CONNECT, APPROVE, CHOOSE)

## 5. หมายเหตุของบอร์ดนี้

- ขั้นที่ใช้บอร์ด (connect, flash, test) ยัง**อยู่ในแผน** เพราะ N6 boot จาก flash ภายนอก การโหลดแอปต้องใช้ development boot mode (สวิตช์ BOOT1) และ "connect under reset" ระหว่างนี้ skill ทำได้ถึงสร้างแอป เปิดใน IDE และ build
- ไฟล์ `<app>.ioc` ของทุกแอปเริ่มจาก template แบบ FSBL-only ของ ST ใน STM32CubeN6 บวก UART ของ console ห้ามแก้ `mx/` ด้วยมือ

## อ่านต่อ (ภาษาอังกฤษ)

- [README.md](../../README.md) - แนวคิด บอร์ดทั้งหมด plugin
- [docs/workflow.md](../../docs/workflow.md) - ขั้นตอน gate exit code apps workspace การอัปเดตเครื่องมือ
- [boards/stm32n6570-dk/README.md](../../boards/stm32n6570-dk/README.md) - hardware เวอร์ชันเครื่องมือ verification log
