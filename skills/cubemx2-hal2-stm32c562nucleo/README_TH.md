# cubemx2-hal2-stm32c562nucleo — คู่มือภาษาไทย

Skill สำหรับ Claude Code ใช้สร้าง firmware บอร์ด **STM32C5 (NUCLEO-C562RE)** ด้วย STM32CubeMX2
แบบ command line (ไม่ต้องเปิด GUI) + CMake + STM32CubeProgrammer ตั้งแต่ตรวจเครื่องมือจนถึงทดสอบบนบอร์ดจริง
(คำสั่งหลักสำหรับ Claude อยู่ใน `SKILL.md` เป็นภาษาอังกฤษ)

## ก่อนเริ่ม (ผู้พัฒนาต้องทำเอง)

- ติดตั้ง STM32CubeMX2 / STM32Cube for VS Code แล้วติดตั้ง bundle และ pack ตามเวอร์ชันใน `boards/nucleo-c562re/cubemx2-hal2-stm32c562nucleo/board.env`
  (`check_tools.sh` จะบอกว่าขาดอะไร — การยอมรับ license ของ pack เป็นหน้าที่ผู้พัฒนา)
- ใช้ Git Bash และโฟลเดอร์ที่ path สั้น ไม่มีช่องว่าง ไม่มีภาษาไทย
- ต่อบอร์ดผ่านช่อง USB ของ ST-LINK บนบอร์ด

## ต้องมีไฟล์ .ioc2 ไหม?

ต้องมี แต่ไม่ต้องเตรียมเอง: `new_app.sh` สร้าง `<app>.ioc2` จากบอร์ดให้ (create-from-board + เปิด USART2)
ถ้ามี .ioc2 ของตัวเองให้ใช้ `--ioc2 <file>` — เมื่อแก้ .ioc2 (GUI หรือ CLI) ให้รัน `regen.sh <app>`
ห้ามแก้ไฟล์ใน `mx/` เพราะถูกสร้างใหม่ทุกครั้ง โค้ดของเราอยู่ใน `src/` เท่านั้น

## ลำดับงาน (หมายเลขตาม docs/workflow.md)

| ขั้น | ทำอะไร | สคริปต์ | ผ่านเมื่อ |
| --- | --- | --- | --- |
| 1 setup | ตรวจ path, bundle/pack ตามเวอร์ชันที่ล็อกไว้, python/pyserial, ST-LINK | `check_tools.sh <board>` | `missing/bad=0` |
| 6 connect | หา ST-LINK (อ่านอย่างเดียว) ตรวจชื่อบอร์ด/ชิป/Device ID บันทึก serial + COM | `discover.sh <board>` | `IDENTITY: PASS` |
| 2 create | สร้าง .ioc2 จากบอร์ด + generate โปรเจกต์ CMake + เชื่อม src/ | `new_app.sh <board> <app> "" hello-world` | `REGEN: PASS` |
| 3 build | build ด้วย GCC/CMake/Ninja ที่ล็อกเวอร์ชัน + manifest | `build.sh <app>` | `BUILD: PASS`, 0 warning ใน src/ |
| 7 flash | (ขออนุญาตก่อนทุกครั้ง) ตรวจตัวตนแล้วเขียน + verify | `flash.sh <app> --yes` | `FLASH: PASS` |
| 8 test | ทดสอบผ่าน virtual COM port ของ ST-LINK | `serial_test.py auto <spec> <log> --board <board>` | `RESULT: PASS` |
| 11 clean | ลบผล build (`--apps` ลบทั้งแอป) | `clean.sh` แล้ว `clean.sh --yes` | `CLEAN: done` |

ถ้าสคริปต์จบด้วย exit 10 และบรรทัด `ACTION: ...` แปลว่าต้องให้ผู้พัฒนาทำบางอย่าง (เสียบบอร์ด, อนุมัติการ flash, ติดตั้งเครื่องมือ) แล้วรันคำสั่งเดิมซ้ำ

## บอร์ด NUCLEO-C562RE

- LD1 (เขียว) = PA5 ติดเมื่อ high · B1 (USER, ปุ่มสีน้ำเงิน) = PC13 กดแล้วเป็น high · B2 = RESET
- Console: USART2 (PA2/PA3) → virtual COM port ของ ST-LINK, 115200
