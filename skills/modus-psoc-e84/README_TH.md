# modus-psoc-e84 — คู่มือภาษาไทย

Skill สำหรับ Claude Code ใช้สร้าง firmware บอร์ดตระกูล **Infineon PSOC Edge E84** ด้วย
ModusToolbox แบบอัตโนมัติ ตั้งแต่ตรวจเครื่องมือจนถึงทดสอบบนบอร์ดจริง
(คำสั่งหลักสำหรับ Claude อยู่ใน `SKILL.md` เป็นภาษาอังกฤษ)

## ⚠️ ก่อนเริ่ม: ชื่อโฟลเดอร์

ModusToolbox (make, configurator, OpenOCD) **ทำงานผิดพลาดถ้า path มีช่องว่าง หรือมีตัวอักษรที่ไม่ใช่ภาษาอังกฤษ (เช่น ภาษาไทย)**
ทั้งโฟลเดอร์ workspace/แอป, โฟลเดอร์ผู้ใช้ Windows (`C:\Users\<ชื่อ>`) และโฟลเดอร์ติดตั้ง ModusToolbox

- ใช้เฉพาะ A-Z, a-z, 0-9, `-`, `_` เช่น `C:\Users\<you>\works\automated-firmware-skills`
- ถ้าชื่อผู้ใช้ Windows เป็นภาษาไทย ให้วาง workspace นอกโฟลเดอร์ผู้ใช้ เช่น `C:\pse84-ws`
- โฟลเดอร์ที่ sync (Dropbox/OneDrive) ใช้ได้ แต่ถ้า build ล้มเพราะไฟล์ถูกล็อก ให้หยุด sync ชั่วคราว
- ขั้นที่ 1 (`check_tools.sh`) ตรวจให้อัตโนมัติ ถ้าขึ้น `BAD` ต้องแก้ก่อน และ `new_app` / `build` / `flash` จะไม่ยอมทำงานบน path ที่ไม่ปลอดภัย

## โครงสร้างโฟลเดอร์ใน repo automated-firmware-skills

```
automated-firmware-skills/              ← เปิด Claude Code ที่นี่
├── skills/modus-psoc-e84/              ← skill นี้
├── boards/<id>/README.md               ← ข้อมูล hardware ของบอร์ด (ใช้ร่วมกันทุก skill)
├── boards/<id>/modus-psoc-e84/         ← profile ของบอร์ดสำหรับ skill นี้: board.env, overlay, log การทดสอบ
└── apps/                               ← แอปที่สร้างขึ้น + mtb_shared (ลบได้ด้วยขั้น clean)
```

แอปตัวอย่างที่ commit ไว้ใน repo มี `APP_PUBLISHED=1` ใน `pse84-app.env` — ขั้น clean จะลบเฉพาะผล build ของแอปเหล่านี้

## ลำดับงาน 6 ขั้น + clean (แต่ละขั้นมี "gate" ต้องผ่านก่อนไปขั้นถัดไป)

| ขั้น | ทำอะไร | สคริปต์ | ผ่านเมื่อ |
| --- | --- | --- | --- |
| 1 | ตรวจชื่อโฟลเดอร์ + dev tools (MTB, ProgTools, GCC, Edge Protect, python/pyserial) | `scripts/check_tools.sh <board>` | `missing/bad=0` |
| 2a | ค้นหาบอร์ดที่ต่อกับเครื่องนี้ (อ่านอย่างเดียว) แล้วบันทึก probe serial + COM port ของเครื่อง | `discover.sh <board>` | `IDENTITY: PASS`, `Saved ...` |
| 2b | สร้าง project ด้วย Project Creator + overlay BSP (ไม่ต้องมีบอร์ด) | `new_app.sh <board> <app>` | `Created ...` |
| 3 | เขียนโค้ดแยก layer: `board/` → `func/` → `main.c` และเขียน test spec จากโจทย์ | `templates/uart-btn-led/` | โค้ดไม่ข้าม layer |
| 4 | build ทั้ง 3 core + sign + combined hex | `build.sh <app>` | `BUILD: PASS`, 0 warning |
| 5 | flash (ต้องขออนุญาตผู้ใช้ก่อนทุกครั้ง) ตรวจ manifest, ตัวตนบอร์ด และ life cycle ก่อนเขียน | `flash.sh <app> --yes` | `FLASH: PASS` (exit 10 + `ACTION: POWER_CYCLE` = ให้ถอดเสียบ USB) |
| 6 | ทดสอบผ่าน UART ตาม spec JSON (รันหลัง flash) | `serial_test.py auto <spec> <log> --board <board>` | `RESULT: PASS` |
| 7 | clean: ลบผล build และ library (source ของแอปยังอยู่) | `clean.sh` (dry run) แล้ว `clean.sh --yes` | `CLEAN: done` |

ขั้น clean มี 2 แบบ:
- **ค่าปกติ:** ลบเฉพาะผล build และ library (`build/`, `libs/`, `mtb_shared`, cache) — source/test/log และ `.bench` ยังอยู่ (ดึงใหม่ได้ด้วย `build.sh <app> --getlibs`)
- **`--apps`:** ลบทั้งแอปที่สร้างด้วย `new_app.sh` (โฟลเดอร์ที่มี `pse84-app.env`) **รวม source code** + `apps/.bench` — ใช้เมื่อผู้ใช้สั่งลบแอปเท่านั้น (แอปที่มี `APP_PUBLISHED=1` ลบเฉพาะผล build)

บอร์ดของตัวเอง (ติดตั้ง skill เป็น plugin): วาง profile ไว้ในโปรเจกต์ที่ `boards/<id>/modus-psoc-e84/board.env` (ข้าง `apps/`) — skill จะหาที่นี่ก่อน และไม่หายเมื่ออัปเดต plugin
`new_app.sh` สร้าง `apps/.gitignore` ให้ถ้ายังไม่มี และ `backup.sh` ทำให้โฟลเดอร์ `backup/` ไม่ถูก commit

ถ้าไม่ใส่ `--yes` จะแสดงรายการที่จะลบเท่านั้น ควรสำรอง log หรือโค้ดที่ต้องการเก็บก่อนลบจริง
ถ้าขึ้น `CLEAN: INCOMPLETE` แปลว่า Dropbox/OneDrive ล็อกไฟล์อยู่ ให้หยุด sync ชั่วคราวแล้วรันซ้ำ

## ข้อมูลบอร์ด 2 ระดับ

- **ชนิดบอร์ด** (`boards/<id>/modus-psoc-e84/board.env` ใน repo) — เหมือนกันทุกบอร์ดรุ่นเดียวกัน: BSP, overlay, ชิปที่คาดหวัง, ชื่อปุ่ม
- **บอร์ดที่ต่อกับเครื่องนี้** (`apps/.bench/<id>.env`) — probe serial และ COM port ซึ่งต่างกันทุกเครื่อง
  นักศึกษาแต่ละคนรัน `discover.sh <board>` ครั้งแรกครั้งเดียว ห้ามแก้ค่าเหล่านี้ใน `boards/`

## โครงสร้างโฟลเดอร์ skill

```
SKILL.md                 คำสั่งสำหรับ Claude (อังกฤษ)
(ข้อมูลบอร์ดย้ายไปอยู่ที่ <repo>/boards/<id>/ แล้ว)
reference/               รายละเอียดแต่ละขั้น, ปัญหาที่เคยเจอและวิธีแก้
scripts/                 สคริปต์ทุกขั้น (รันด้วย Git Bash)
templates/<ชื่อ>/        template แอปแบบแบ่ง layer พร้อม test spec: uart-btn-led, button-led,
                         hello-world, dual-core-ipc (CM33 console + CM55 ทำงานผ่าน mailbox)
```

## เมนูวิธีใช้ และ example ของ ModusToolbox

- พิมพ์ **"ขอวิธีใช้หน่อย"** หรือ "มีคำสั่งอะไรบ้าง" — Claude จะแสดงรายการคำสั่งพร้อมตัวอย่าง (มาจาก `scripts/help.sh`)
- **"ขอรายการ example ของ tesaiot"** / **"มี example bluetooth ไหม"** — ดึงรายการ code example ของ Infineon ที่รองรับบอร์ดนั้น (`examples.sh`)
- **"เริ่มจาก example btstack-findme"** — สร้างแอปจาก example โดยล็อกเวอร์ชันทั้ง example และ BSP (`new_app.sh ... --example <id>`)
  example ที่ปรับ BSP เอง (เช่น Bluetooth) ใช้กับ Edgi-Talk ที่มี overlay ไม่ได้โดยตรง ต้องรวมการตั้งค่าเอง

## ใช้หลายบอร์ดในเครื่องเดียว

เสียบหลายบอร์ดได้ แต่ต้องรัน `discover.sh <board> --serial <probe>` แยกให้แต่ละบอร์ด (สคริปต์จะไม่เดาให้)
เพราะทุกบอร์ดใช้ชิปรุ่นเดียวกัน สิ่งเดียวที่แยกบอร์ดได้คือ serial ของ probe — serial หนึ่งผูกได้กับบอร์ดเดียว

## ก่อน commit / ส่งต่อ

1. ข้อมูลเฉพาะเครื่อง (`apps/.bench`, `apps/mtb_shared`, `build/`, `logs/`) และ `backup/` ถูก `.gitignore` ไว้แล้ว — ห้ามบังคับ add
2. skill ต้องอยู่คู่กับ `boards/` เสมอ (ส่งทั้ง repo ไม่ใช่เฉพาะโฟลเดอร์ skill)
3. ผู้รับเปิด Claude Code ใน repo แล้วเริ่มจากขั้นที่ 1 (`check_tools.sh`) และ `discover.sh`
