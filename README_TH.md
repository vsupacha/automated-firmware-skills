# automated-firmware-skills (ภาษาไทย)

ชุด skill สำหรับ AI agent (Claude Code) ที่พาโปรเจกต์ firmware ของไมโครคอนโทรลเลอร์ตั้งแต่ "ติดตั้งเครื่องมือครบหรือยัง"
ไปจนถึง "ทดสอบบนบอร์ดจริงผ่านแล้ว" โดยมีด่านตรวจ (gate) ทุกขั้น สคริปต์ทั้งหมดเป็น bash/Python ธรรมดา
นักพัฒนาจึงรันเองทีละขั้นได้โดยไม่ต้องใช้ agent

เอกสารหลักเป็นภาษาอังกฤษ หน้านี้สรุปแนวคิดสั้น ๆ และชี้ไปยังเอกสารแต่ละส่วน

## แนวคิดหลัก

- **skill = toolchain + framework + บอร์ด** เช่น `cubemx-hal-stm32l475iot`, `pio-arduino-unor4wifi`
- **ขั้นตอนมีด่านตรวจ** ทุก skill มีขั้นและชื่อสคริปต์เหมือนกัน (ตรวจเครื่องมือ → สร้างโปรเจกต์ → เปิดใน IDE →
  build → เชื่อมบอร์ด → flash → ทดสอบ → clean) ไปขั้นถัดไปได้เมื่อขึ้น PASS เท่านั้น
- **นักพัฒนาเป็นผู้ตัดสินใจ** งานที่คนต้องทำเอง (ติดตั้งเครื่องมือ, เสียบบอร์ด, กดปุ่ม, **อนุมัติการ flash**) สคริปต์จะหยุดพร้อมบรรทัด
  `ACTION: ...` แล้วรอคำยืนยัน — ไม่มีการ flash โดยไม่ได้รับอนุญาต
- **สองเส้นทาง สลับได้ทุกเมื่อ** เขียนโค้ด/build/flash/debug เองใน IDE หรือให้ agent รันขั้นตอนที่มีด่านตรวจให้
- **demo สำหรับเริ่มต้นบอร์ด** hello-world (UART), blink (LED), push-to-light (กดปุ่มแล้วไฟติด)

## เริ่มใช้งาน

1. เตรียมเครื่อง: Windows 10/11 + Git for Windows (Git Bash), Python 3 + `pyserial` และเครื่องมือของผู้ผลิตบอร์ด
   (README ของแต่ละบอร์ดบอกเวอร์ชันที่ต้องใช้ - `check_tools.sh` จะบอกว่าขาดอะไร)
2. ติดตั้ง plugin ใน Claude Code ตามค่ายของบอร์ด (จะได้ `firmware-tools` มาด้วย):
   `/plugin marketplace add vsupacha/automated-firmware-skills` แล้ว
   `/plugin install firmware-stm32@automated-firmware-skills` (หรือ `firmware-platformio`,
   `firmware-modustoolbox`, `firmware-rtthread`) - ถ้าต้องการทุกบอร์ดใช้
   `automated-firmware-skills@automated-firmware-skills` แทน เลือกอย่างใดอย่างหนึ่ง
3. พิมพ์ถามเป็นภาษาไทยได้เลย เช่น "ขอวิธีใช้หน่อย", "ตรวจเครื่องมือให้หน่อย", "สร้างแอป blink แล้ว build ให้หน่อย",
   "แฟลชเลย" (Claude ถามก่อน flash ทุกครั้ง), "ทดสอบ"
4. แอปแรกบนเครื่อง: ถ้าโฟลเดอร์ `apps/` อยู่ใน Dropbox/OneDrive หรือ path ยาวเกิน ระบบจะถามว่าจะเก็บแอปที่ไหน
   (แนะนำโฟลเดอร์ path สั้นนอก Dropbox เช่น `C:/fw-ws`) ถามครั้งเดียวต่อเครื่อง

## คู่มือภาษาไทยของแต่ละบอร์ด

ตั้งแต่เตรียมเครื่องจนถึงทดสอบบนบอร์ด พร้อมประโยคที่ใช้สั่ง Claude และคำสั่ง Git Bash:

| บอร์ด | คู่มือ |
| --- | --- |
| ST NUCLEO-C562RE | [skills/cubemx2-hal2-stm32c562nucleo/README_TH.md](skills/cubemx2-hal2-stm32c562nucleo/README_TH.md) |
| ST B-L475E-IOT01A | [skills/cubemx-hal-stm32l475iot/README_TH.md](skills/cubemx-hal-stm32l475iot/README_TH.md) |
| ST STM32N6570-DK (build เท่านั้น) | [skills/cubemx-hal-stm32n6570dk/README_TH.md](skills/cubemx-hal-stm32n6570dk/README_TH.md) |
| ST STM32F407G-DISC1 (build เท่านั้น) | [skills/cubemx-hal-stm32f407disco/README_TH.md](skills/cubemx-hal-stm32f407disco/README_TH.md) |
| RT-Thread Edgi-Talk | [skills/modus-pdl-edgitalk/README_TH.md](skills/modus-pdl-edgitalk/README_TH.md) |
| Raspberry Pi Pico 2 W | [skills/pio-arduino-rpipico2w/README_TH.md](skills/pio-arduino-rpipico2w/README_TH.md) |
| ESP32-S3-BOX (ESP-IDF) | [skills/pio-espidf-esp32s3box/README_TH.md](skills/pio-espidf-esp32s3box/README_TH.md) |
| ESP32-S3-BOX (Arduino) | [skills/pio-arduino-esp32s3box/README_TH.md](skills/pio-arduino-esp32s3box/README_TH.md) |
| Arduino UNO R4 WiFi | [skills/pio-arduino-unor4wifi/README_TH.md](skills/pio-arduino-unor4wifi/README_TH.md) |
| RT-Thread Vision Board | [skills/scons-rtthread-visionboard/README_TH.md](skills/scons-rtthread-visionboard/README_TH.md) |

## เอกสาร (ภาษาอังกฤษ)

| เอกสาร | เนื้อหา |
| --- | --- |
| [README.md](README.md) | ภาพรวม แนวคิด วิธีใช้ ตาราง skill และ IDE |
| [boards/README.md](boards/README.md) | บอร์ดที่รองรับ, I/O บนบอร์ด, ผลทดสอบ demo |
| [docs/milestones.md](docs/milestones.md) | แผน milestone M1-M5 และสถานะปัจจุบัน |
| [docs/workflow.md](docs/workflow.md) | ข้อตกลงที่ทุก skill ทำตาม: ขั้นตอน, ด่านตรวจ, exit code, ACTION |
| [docs/board-api.md](docs/board-api.md) | API `board.h` และกติกาการแบ่งชั้นโค้ด |
| [docs/walkthrough-edgi-talk-ide.md](docs/walkthrough-edgi-talk-ide.md) | ตัวอย่างการทำงานจริงบนเส้นทาง IDE |
