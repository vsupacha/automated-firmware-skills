# NXP FRDM-MCXN947 - วิธีใช้ `mcux-sdk-frdmmcxn947`

คู่มือทีละขั้นสำหรับคน ส่วนคำสั่งสำหรับ agent อยู่ใน [SKILL.md](SKILL.md) และสัญญากลาง (stage,
gate, exit code) อยู่ใน [docs/workflow.md](../../docs/workflow.md) ข้อมูลฮาร์ดแวร์:
[boards/frdm-mcxn947](../../boards/frdm-mcxn947/README.md) สถานะของ skill นี้: **สร้างแอป เปิดใน
VS Code, build, หาบอร์ด, แฟลช และทดสอบได้แล้ว ส่วน debug ยังเป็นแผน** (ทดลองด้วยมือผ่านแล้ว ดู
[docs/related-work.md](../../docs/related-work.md) หัวข้อ "NXP FRDM-MCXN947")

| บนบอร์ด | |
| --- | --- |
| Console | MCU-Link virtual COM port (USB-C J17) 115200 |
| LED1, LED2, LED3 | LED RGB D2: แดง เขียว น้ำเงิน |
| BTN1, BTN2 | SW2 (wakeup), SW3 (ISP - อย่ากดค้างตอนรีเซ็ต) |
| Probe / USB | MCU-Link บนบอร์ด (CMSIS-DAP + VCOM) |

## 1. เตรียมเครื่อง (ครั้งเดียว)

- Windows 10/11, Git for Windows (Git Bash), Python 3
- **MCUXpresso Installer** (nxp.com): Arm GNU Toolchain, Ninja, MCUXpresso SDK Developer (Python
  venv ที่มี west), LinkServer ติดตั้งไว้ที่ `~/.mcuxpressotools` และ `C:/NXP`
- **Kitware CMake 3.30 ขึ้นไป** (cmake.org) skill นี้ไม่ใช้ `cube-cmake` หรือเครื่องมือ
  STM32CubeCLT ของ ST เลย แม้จะอยู่ก่อนใน PATH
- **MCUXpresso SDK 26.09** ในโฟลเดอร์สั้นที่ไม่ sync ขึ้น cloud เช่น ใน Git Bash:
  `~/.mcuxpressotools/.mcux-venv-3.12/Scripts/west.exe init -m https://github.com/nxp-mcuxpresso/mcuxsdk-manifests.git --mr v26.09.00 C:/mcux-26.09`
  แล้วใน `C:/mcux-26.09`: `west update_board --set board frdmmcxn947` (หลาย GB) ถ้าใช้โฟลเดอร์อื่น
  ให้ใส่ `MCUX_SDK_ROOT=<โฟลเดอร์>` ใน `~/.fw-skills.env`
- ทาง IDE (ไม่บังคับ): VS Code + **MCUXpresso for VS Code**

## 2. ติดตั้ง plugin

ใน Claude Code: `/plugin marketplace add vsupacha/automated-firmware-skills` แล้ว
`/plugin install firmware-mcuxpresso@automated-firmware-skills` (หรือ `automated-firmware-skills`
แบบรวมทุกบอร์ด อย่างใดอย่างหนึ่ง)

## 3. สั่ง Claude

| คุณพูด | Claude รัน | คุณจะเห็น |
| --- | --- | --- |
| "ใช้ยังไง" | `help.sh` | เมนูคำสั่ง บอร์ด และ template |
| "ตรวจเครื่องมือสำหรับ FRDM-MCXN947" | `check_tools.sh frdm-mcxn947` | `missing/bad=0` แถว BAD บอกว่าต้องติดตั้งอะไร |
| "สร้างแอป push-to-light ชื่อ btn-led" | `new_app.sh frdm-mcxn947 btn-led "" push-to-light` | `Created <โฟลเดอร์แอป>` (ครั้งแรกบนเครื่องจะถามโฟลเดอร์ workspace) |
| "เปิดใน IDE" | `open_ide.sh <app>` (new_app ทำให้แล้ว) | `IDE: OPENED` - MCUXpresso for VS Code แสดงแอปใน Projects view |
| "ลงทะเบียน SDK ใน VS Code" | `open_ide.sh <app> --register-sdk` **หลังคุณตกลง** | `SDK: REGISTERED` - เพิ่ม 1 รายการใน VS Code user settings |
| "build ให้หน่อย" | `build.sh <app>` | `BUILD: PASS` ไม่มี warning + manifest (เวอร์ชันเครื่องมือ, hash ของ image) |
| "หาบอร์ดที่เสียบอยู่" | `discover.sh frdm-mcxn947` | `IDENTITY: PASS` - อ่านอย่างเดียว; บันทึก serial ของ MCU-Link และ VCOM ของเครื่องนี้ |
| "แฟลชให้หน่อย" | `flash.sh <app> --yes` **หลังคุณตกลง** | `FLASH: PASS` (เขียน + ตรวจกลับ + รีเซ็ต) |
| "ทดสอบ" | `serial_test.py auto <app>/tests/push_to_light.json ...` | `RESULT: PASS (n/n passed ...)` |
| "ทดสอบแบบกดปุ่ม" | `serial_test.py auto <app>/tests/push_to_light.json ... --interactive` | กด SW2 / SW3 ตามที่ Claude บอก แล้วดู LED แดง / เขียว |
| "clean ให้หน่อย" | `clean.sh` (dry run ก่อน) | รายการ แล้วลบเมื่อคุณตกลงเท่านั้น; `--apps` ลบซอร์สของแอปด้วย |

skill นี้ยัง debug (breakpoint, watchpoint) ไม่ได้

## 4. ทำเองโดยไม่ผ่าน Claude (Git Bash ที่ root ของ repo)

```bash
S=skills/mcux-sdk-frdmmcxn947/scripts
bash $S/check_tools.sh frdm-mcxn947
bash $S/new_app.sh frdm-mcxn947 btn-led "" push-to-light     # พิมพ์: Created C:/fw-ws/btn-led
bash $S/build.sh C:/fw-ws/btn-led
bash $S/discover.sh frdm-mcxn947
bash $S/flash.sh C:/fw-ws/btn-led --yes
python $S/serial_test.py auto C:/fw-ws/btn-led/tests/push_to_light.json C:/fw-ws/btn-led/logs/test.log --board frdm-mcxn947 --sync
```

ปุ่ม Build ใน VS Code ใช้ preset เดียวกัน (`debug`) และโฟลเดอร์ `debug/` เดียวกัน

## 5. หมายเหตุของบอร์ดนี้

- แอปมาจากตัวอย่าง `hello_world` ของ SDK ที่ export ด้วย `west export_app` แล้วตัดบางส่วน:
  เอา `board.c/board.h` และ debug console ของ SDK ออก เก็บ `clock_config` (150 MHz) กับ
  `pin_mux` ไว้ แล้วใส่ `src/` แบบแบ่งชั้นของเรา ขาและสัญญาณนาฬิกาแก้ด้วย MCUXpresso Config
  Tools ที่ไฟล์ `.mex` ในโฟลเดอร์บอร์ด
- SDK คอมไพล์ด้วย `-Werror` แต่ skill ปิดไว้ เพื่อให้ `build.sh` รายงาน warning เอง (exit 2)
  ควรแก้ก่อนทำต่อ
- SW3 คือปุ่ม ISP ถ้ากดค้างตอนบอร์ดรีเซ็ต จะเข้า ROM bootloader แทนแอปของคุณ
- `flash.sh` เขียนเฉพาะ internal flash (ไม่เขียน protected flash หรือ FlexSPI) และไม่อัปเดต
  firmware ของ MCU-Link (`LinkServer -u none`)

## เพิ่มเติม

- คู่มือภาษาอังกฤษ: [README.md](README.md)
- board profile และบันทึกการตรวจสอบ: [boards/frdm-mcxn947/mcux-sdk-frdmmcxn947/README.md](../../boards/frdm-mcxn947/mcux-sdk-frdmmcxn947/README.md)
