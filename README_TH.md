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

1. ติดตั้ง plugin ใน Claude Code:
   `/plugin marketplace add vsupacha/automated-firmware-skills` แล้ว
   `/plugin install automated-firmware-skills@automated-firmware-skills`
2. เลือกบอร์ดใน [boards/README.md](boards/README.md) — README ของแต่ละบอร์ดบอกเครื่องมือที่ต้องติดตั้งและคำสั่ง
3. พิมพ์ถามเป็นภาษาไทยได้เลย เช่น "ขอวิธีใช้หน่อย", "มีคำสั่งอะไรบ้าง", "สร้างแอป blink แล้ว build ให้หน่อย"

## เอกสาร (ภาษาอังกฤษ)

| เอกสาร | เนื้อหา |
| --- | --- |
| [README.md](README.md) | ภาพรวม แนวคิด วิธีใช้ ตาราง skill และ IDE |
| [boards/README.md](boards/README.md) | บอร์ดที่รองรับ, I/O บนบอร์ด, ผลทดสอบ demo |
| [docs/milestones.md](docs/milestones.md) | แผน milestone M1-M5 และสถานะปัจจุบัน |
| [docs/workflow.md](docs/workflow.md) | ข้อตกลงที่ทุก skill ทำตาม: ขั้นตอน, ด่านตรวจ, exit code, ACTION |
| [docs/board-api.md](docs/board-api.md) | API `board.h` และกติกาการแบ่งชั้นโค้ด |
| [docs/walkthrough-edgi-talk-ide.md](docs/walkthrough-edgi-talk-ide.md) | ตัวอย่างการทำงานจริงบนเส้นทาง IDE |
