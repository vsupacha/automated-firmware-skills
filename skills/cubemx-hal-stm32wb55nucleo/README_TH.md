# ST NUCLEO-WB55RG - วิธีใช้ `cubemx-hal-stm32wb55nucleo`

firmware สำหรับ ST NUCLEO-WB55RG - STM32WB55RGV6 (core Cortex-M4 ฝั่งแอป), STM32WB - ด้วย STM32CubeMX 6.18 + STM32CubeWB HAL + CMake ตั้งแต่ "ติดตั้งเครื่องมือครบหรือยัง" จนถึง
"ทดสอบบนบอร์ดผ่านแล้ว" โดยมีด่านตรวจ (gate) ทุกขั้น สั่ง Claude ด้วยภาษาของคุณเอง หรือรัน script ชุดเดียวกันเองใน
Git Bash ก็ได้ ภาษาอังกฤษ: [README.md](README.md) คำสั่งที่ agent ทำตาม: [SKILL.md](SKILL.md)

ขั้นที่ใช้บอร์ดมี connect, flash และ test ส่วน debug (stage 7) ยังอยู่ในแผน ระดับหลักฐานของแต่ละ template และเวอร์ชันเครื่องมือที่แน่นอน:
[boards/nucleo-wb55rg/README.md](../../boards/nucleo-wb55rg/README.md)

| บนบอร์ด | |
| --- | --- |
| Console | ST-LINK virtual COM port |
| LED1, LED2, LED3 | LED1 (blue), LED2 (green), LED3 (red) |
| BTN1, BTN2, BTN3 | SW1, SW2, SW3 |
| Probe / USB | on-board ST-LINK/V2-1 |

## 1. เตรียมเครื่อง (ทำครั้งเดียว)

- Windows 10/11 พร้อม Git for Windows (Git Bash) และ Python 3 กับ `pyserial`
- STM32CubeMX 6.18 (รุ่น classic) พร้อม package STM32Cube_FW_WB
- STM32Cube bundles: GNU Tools for STM32, CMake, Ninja, STM32CubeProgrammer, ST-LINK GDB server (สำหรับ debug ใน VS Code)
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
| "ตรวจเครื่องมือสำหรับ ST NUCLEO-WB55RG ให้หน่อย" | `check_tools.sh nucleo-wb55rg` | `missing/bad=0`; แถว BAD บอกว่าต้องติดตั้งอะไร |
| "เครื่องมือยังเป็นเวอร์ชันที่ pin ไว้ไหม" | `update_tools.sh nucleo-wb55rg` | `UPDATE: NONE` หรือคำถามก่อนแก้ pin |
| "สร้างแอป push-to-light ชื่อ btn-led" | `new_app.sh nucleo-wb55rg btn-led "" push-to-light` | `Created <โฟลเดอร์แอป>` (ครั้งแรกบนเครื่อง: ถามที่เก็บแอป) |
| "เปิดใน IDE" | `open_ide.sh <app>` (new_app เปิดให้เอง) | `IDE: OPENED` - STM32CubeIDE for VS Code |
| "build ให้หน่อย" | `build.sh <app>` | `BUILD: PASS` ไม่มี warning + manifest (เวอร์ชันเครื่องมือ, hash ของ image) |
| "หาบอร์ดที่ต่ออยู่" | `discover.sh nucleo-wb55rg` | `IDENTITY: PASS` - อ่านอย่างเดียว บันทึก probe และ console port ของเครื่องนี้ |
| "แฟลชเลย" | `flash.sh <app> --yes` **หลังคุณตอบ yes** | `FLASH: PASS` |
| "ทดสอบ" | `serial_test.py auto <app>/tests/push_to_light.json ...` | `RESULT: PASS (n/n passed ...)` |
| "ทดสอบแบบกดปุ่ม" | `serial_test.py auto <app>/tests/push_to_light.json ... --interactive` (แอป push-to-light) | กด SW1 / SW2 เมื่อถูกบอก แล้วดู LED1 (สีน้ำเงิน) |
| "รัน unit test บนบอร์ด" | `unit_test.sh <app> --yes` **หลังจากคุณตอบตกลง** (หรือตั้ง `FLASH_POLICY=auto`) | `UNIT: PASS (n/n, test log agrees)` - Unity test ของโค้ดใน `func/` บอร์ดจะรัน image ทดสอบค้างไว้จนกว่าจะ flash แอปกลับ |
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
S=skills/cubemx-hal-stm32wb55nucleo/scripts
bash $S/check_tools.sh nucleo-wb55rg
bash $S/new_app.sh nucleo-wb55rg btn-led "" push-to-light   # พิมพ์: Created <โฟลเดอร์แอป>
bash $S/build.sh <โฟลเดอร์แอป>
bash $S/discover.sh nucleo-wb55rg
bash $S/flash.sh <โฟลเดอร์แอป> --yes          # เมื่อตัดสินใจ flash แล้วเท่านั้น
python $S/serial_test.py auto <โฟลเดอร์แอป>/tests/push_to_light.json <โฟลเดอร์แอป>/logs/test.log --board nucleo-wb55rg --interactive
```

`<โฟลเดอร์แอป>` คือที่ `new_app.sh` พิมพ์ออกมา - `apps/btn-led` หรือเช่น `C:/fw-ws/btn-led` ถ้าเครื่องตั้ง
workspace ไว้ exit code: 0 ผ่าน, 1 ล้มเหลว, 2 มี warning ที่กั้น gate, **10 = ทำตามบรรทัด `ACTION:` แล้วรันซ้ำ**
(SETUP, CONNECT, APPROVE, CHOOSE)

## 5. หมายเหตุของบอร์ดนี้

- **การ flash:** STM32CubeProgrammer ผ่าน ST-LINK (ตรวจตัวตน: ชื่อบอร์ดของ ST-LINK, device ID; verify หลังเขียน)
- ทุกแอปมีไฟล์ `<app>.ioc` ที่เริ่มจาก board configuration ของ CubeMX บวก USART1 บน virtual COM port ของ ST-LINK ถ้าจะเปลี่ยน hardware ให้แก้ไฟล์นี้ใน STM32CubeMX แล้วสั่ง "generate ใหม่" (`regen.sh`) ห้ามแก้ `mx/` ด้วยมือ
- console รับข้อมูลด้วย interrupt ลง ring buffer (ไม่ได้เปิด RX FIFO ของ USART1)
- `.ioc` เริ่มด้วย `clearpinout` เพราะหลัง `loadboard` ของบอร์ดนี้ CubeMX ไม่ยอมตั้ง USART1 จนกว่าจะล้าง pin ที่บอร์ดล็อกไว้ ส่วน LED และปุ่มตั้งค่าใน `src/board/board.c`
- **Wireless stack:** stack BLE/802.15.4 ของ CM0+ และ FUS อยู่ปลาย flash (เป็นพื้นที่ secure เหนือ `SFSA`) skill นี้เขียนเฉพาะแอปของ CM4 ที่ 0x08000000 ไม่ลบและไม่อัปเดต stack แต่ BLE demo ที่มากับบอร์ดจะถูกเขียนทับตั้งแต่การ flash ครั้งแรก
- STM32CubeMX2 1.1.2 มีบอร์ดนี้ในรายการแต่สร้างโปรเจกต์ไม่ได้ (pack ของ WB ขึ้นว่า incompatible) skill นี้จึงใช้ STM32CubeMX แบบ classic

## อ่านต่อ (ภาษาอังกฤษ)

- [README.md](../../README.md) - แนวคิด บอร์ดทั้งหมด plugin
- [docs/workflow.md](../../docs/workflow.md) - ขั้นตอน gate exit code apps workspace การอัปเดตเครื่องมือ
- [boards/nucleo-wb55rg/README.md](../../boards/nucleo-wb55rg/README.md) - hardware เวอร์ชันเครื่องมือ verification log
