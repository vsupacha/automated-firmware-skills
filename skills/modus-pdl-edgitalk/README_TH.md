# RT-Thread Edgi-Talk - วิธีใช้ `modus-pdl-edgitalk`

firmware สำหรับ RT-Thread Edgi-Talk - PSE846GPS2DBZC4A, Infineon PSOC Edge E84 - ด้วย ModusToolbox 3.9 + PDL ตั้งแต่ "ติดตั้งเครื่องมือครบหรือยัง" จนถึง
"ทดสอบบนบอร์ดผ่านแล้ว" โดยมีด่านตรวจ (gate) ทุกขั้น สั่ง Claude ด้วยภาษาของคุณเอง หรือรัน script ชุดเดียวกันเองใน
Git Bash ก็ได้ ภาษาอังกฤษ: [README.md](README.md) คำสั่งที่ agent ทำตาม: [SKILL.md](SKILL.md)

ขั้นที่ใช้บอร์ด (connect, flash, test) ผ่านการตรวจบนบอร์ดจริงแล้ว ระดับหลักฐานของแต่ละ template และเวอร์ชันเครื่องมือที่แน่นอน:
[boards/edgi-talk/README.md](../../boards/edgi-talk/README.md)

| บนบอร์ด | |
| --- | --- |
| Console | KitProg3 USB-UART |
| LED1 | LED1 (red) |
| BTN1 | SW2 |
| Probe / USB | on-board KitProg3 |

## 1. เตรียมเครื่อง (ทำครั้งเดียว)

- Windows 10/11 พร้อม Git for Windows (Git Bash) และ Python 3 กับ `pyserial`
- ModusToolbox 3.9 tools, ModusToolbox Programming Tools, Arm GCC, Edge Protect Security Suite
- path สั้น ไม่มีช่องว่างหรืออักษรที่ไม่ใช่ภาษาอังกฤษ ทั้ง workspace, โฟลเดอร์ผู้ใช้ Windows และที่ติดตั้ง ModusToolbox
- ไม่บังคับ: VS Code และ Infineon ModusToolbox for VS Code สำหรับทาง IDE; Claude Code สำหรับทาง agent

`check_tools.sh` (ข้อ 3) จะบอกสิ่งที่ขาดพร้อมเวอร์ชันที่ board profile pin ไว้

## 2. ติดตั้ง plugin

ใน Claude Code จากโฟลเดอร์โปรเจกต์ของคุณ:

```
/plugin marketplace add vsupacha/automated-firmware-skills
/plugin install firmware-modustoolbox@automated-firmware-skills
```

จะได้ `firmware-tools` มาด้วย ถ้าใช้ `automated-firmware-skills@automated-firmware-skills` จะได้ทุกบอร์ด
เลือกอย่างใดอย่างหนึ่ง

## 3. สั่ง Claude

| คุณพิมพ์ | Claude รัน | สิ่งที่เห็น |
| --- | --- | --- |
| "ขอวิธีใช้หน่อย" | `help.sh` | เมนูคำสั่ง บอร์ด และ template |
| "ตรวจเครื่องมือสำหรับ RT-Thread Edgi-Talk ให้หน่อย" | `check_tools.sh edgi-talk` | `missing/bad=0`; แถว BAD บอกว่าต้องติดตั้งอะไร |
| "สร้างแอป push-to-light ชื่อ btn-edgi" | `new_app.sh edgi-talk btn-edgi "" push-to-light` | `Created <โฟลเดอร์แอป>` (ครั้งแรกบนเครื่อง: ถามที่เก็บแอป) |
| "เปิดใน IDE" | `open_ide.sh <app>` (new_app เปิดให้เอง) | `IDE: OPENED` - Infineon ModusToolbox for VS Code |
| "build ให้หน่อย" | `build.sh <app>` | `BUILD: PASS` ไม่มี warning + manifest (เวอร์ชันเครื่องมือ, hash ของ image) |
| "สำรองบอร์ดก่อน" | `backup.sh edgi-talk` | เก็บ image จากโรงงานไว้ก่อน flash ครั้งแรก |
| "หาบอร์ดที่ต่ออยู่" | `discover.sh edgi-talk` | `IDENTITY: PASS` - อ่านอย่างเดียว บันทึก probe และ console port ของเครื่องนี้ |
| "แฟลชเลย" | `flash.sh <app> --yes` **หลังคุณตอบ yes** | `FLASH: PASS` |
| "ทดสอบ" | `serial_test.py auto <app>/tests/push_to_light.json ...` | `RESULT: PASS (n/n passed ...)` |
| "ทดสอบแบบกดปุ่ม" | `serial_test.py auto <app>/tests/push_to_light.json ... --interactive` (แอป push-to-light) | กด SW2 เมื่อถูกบอก แล้วดู LED1 (red) |
| "clean ให้หน่อย" | `clean.sh` (dry run ก่อน) | แสดงรายการ แล้วลบเมื่อคุณตอบ yes; `--apps` ลบซอร์สของแอปด้วย |

- **แอปแรกบนเครื่อง:** ถ้า `apps/` อยู่ใน Dropbox/OneDrive หรือ path ยาวเกิน `new_app.sh` จะหยุดด้วย
  `ACTION: CHOOSE` แล้ว Claude จะถามว่าจะเก็บแอปที่ไหน (แนะนำโฟลเดอร์ path สั้นนอกโฟลเดอร์ที่ sync เช่น
  `C:/fw-ws`) แล้วบันทึกด้วย `lib/fw_workspace.sh set <dir>` เครื่องนั้นจะไม่ถามอีก
- **สองทาง:** หลังสร้างแอปแล้ว คุณเขียนโค้ด, build, flash และ debug เองใน Infineon ModusToolbox for VS Code ได้
  (ทาง IDE) หรือให้ Claude รันขั้นที่มี gate ให้ (ทาง script) ใช้โฟลเดอร์แอปเดียวกัน สลับได้ทุกเมื่อ
- **โค้ดของคุณ** อยู่ใน `src/` แบ่งเป็น layer: `board/` (ขาและ peripheral), `func/` (logic ที่ย้ายบอร์ดได้),
  `app_main` (ตัวเชื่อม) - ดู [docs/board-api.md](../../docs/board-api.md)
- **ไม่มีการ flash จนกว่าคุณจะตอบ yes** Claude จะแสดงบอร์ด แอป และ hash ของ image แล้วรอ
  `flash.sh` ตรวจตัวตนบอร์ดอีกครั้งก่อนเขียน

## 4. ใช้แบบไม่มี Claude (Git Bash จาก root ของ repo)

```bash
S=skills/modus-pdl-edgitalk/scripts
bash $S/check_tools.sh edgi-talk
bash $S/new_app.sh edgi-talk btn-edgi "" push-to-light   # พิมพ์: Created <โฟลเดอร์แอป>
bash $S/build.sh <โฟลเดอร์แอป>
bash $S/discover.sh edgi-talk
bash $S/flash.sh <โฟลเดอร์แอป> --yes          # เมื่อตัดสินใจ flash แล้วเท่านั้น
python $S/serial_test.py auto <โฟลเดอร์แอป>/tests/push_to_light.json <โฟลเดอร์แอป>/logs/test.log --board edgi-talk --interactive
```

`<โฟลเดอร์แอป>` คือที่ `new_app.sh` พิมพ์ออกมา - `apps/btn-edgi` หรือเช่น `C:/fw-ws/btn-edgi` ถ้าเครื่องตั้ง
workspace ไว้ exit code: 0 ผ่าน, 1 ล้มเหลว, 2 มี warning ที่กั้น gate, **10 = ทำตามบรรทัด `ACTION:` แล้วรันซ้ำ**
(SETUP, CONNECT, APPROVE, CHOOSE)

## 5. หมายเหตุของบอร์ดนี้

- **การ flash:** OpenOCD (ModusToolbox Programming Tools) ผ่าน KitProg3 (ตรวจตัวตน: serial ของ probe, ชิป, ตรวจ life cycle ก่อนเขียน; verify)
- การสร้างแอปจะรัน ModusToolbox Project Creator (ใช้เวลาไม่กี่นาที และโหลด `mtb_shared` ครั้งแรก) ถ้า Dropbox หรือ OneDrive lock ไฟล์ จะล้มโดยไม่บอกสาเหตุชัดเจน ให้เก็บ apps workspace ไว้นอกโฟลเดอร์ที่ sync (`new_app.sh` ถามครั้งเดียวต่อเครื่อง)
- มี template เพิ่ม: `button-led`, `dual-core-ipc` (CM33 + CM55) การส่งต่อให้ IDE จะรัน `make vscode` ของ ModusToolbox แล้วทำ "Fix Tasks / Fix Settings" ของ extension ให้ล่วงหน้า (`vscode_fix.py`)
- "สำรองบอร์ด" (`backup.sh edgi-talk`) ก่อน flash ครั้งแรก เพื่อเก็บ firmware จากโรงงานไว้
- ถ้าชื่อผู้ใช้ Windows เป็นภาษาไทยหรือมีอักษรที่ไม่ใช่ภาษาอังกฤษ ให้เก็บ apps workspace ไว้นอกโฟลเดอร์ผู้ใช้ (เช่น `C:/fw-ws`)
- `flash.sh` อาจหยุดด้วย `ACTION: POWER_CYCLE`: ถอดแล้วเสียบ USB ใหม่ แล้วรันซ้ำ ส่วน `clean.sh` จะขึ้น `CLEAN: INCOMPLETE` ถ้าโปรแกรม sync lock ไฟล์อยู่ ให้หยุด sync ชั่วคราวแล้วรันซ้ำ
- code example ของ Infineon: "ขอรายการ example ของ edgi-talk" (`examples.sh`), "เริ่มจาก example <id>" (`new_app.sh ... --example <id>` ล็อกเวอร์ชันทั้ง example และ BSP) example ที่ปรับ BSP เอง (เช่น Bluetooth) ต้องรวมการตั้งค่าเข้ากับ overlay ของ Edgi-Talk เอง
- หลายบอร์ดในเครื่องเดียว: รัน `discover.sh edgi-talk --serial <probe>` แยกทีละบอร์ด เพราะทุกบอร์ดใช้ชิปรุ่นเดียวกัน แยกกันได้ด้วย serial ของ probe เท่านั้น

## อ่านต่อ (ภาษาอังกฤษ)

- [README.md](../../README.md) - แนวคิด บอร์ดทั้งหมด plugin
- [docs/workflow.md](../../docs/workflow.md) - ขั้นตอน gate exit code apps workspace การอัปเดตเครื่องมือ
- [boards/edgi-talk/README.md](../../boards/edgi-talk/README.md) - hardware เวอร์ชันเครื่องมือ verification log
