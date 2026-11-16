#!/usr/bin/env bash
# Command menu of the pio-arduino-cucumber skill: what you can ask Claude, with short examples,
# the script behind each request, and the boards/templates installed right now.
# Usage: help.sh [--en]      (Thai by default)

. "$(dirname "$0")/env.sh"
LANG_EN=0; [ "$1" = "--en" ] && LANG_EN=1

boards() {
  for id in $(known_boards); do
    f="$(board_profile_dir "$id")/board.env"
    name="$(sed -n 's/^BOARD_NAME="\{0,1\}\([^"#]*\)"\{0,1\}.*/\1/p' "$f" | head -1)"
    src=""; case "$f" in "$BOARDS_DIR"/*) ;; *) src="  [project boards/]";; esac
    printf '    %-14s %s%s\n' "$id" "$name" "$src"
  done
}
templates() {
  for d in "$SKILL_DIR"/templates/*/; do
    t="$(basename "$d")"; [ "${t#_}" = "$t" ] || continue
    printf '    %-14s %s\n' "$t" "$(head -1 "$d/description.txt" 2>/dev/null | tr -d '\r')"
  done
}

if [ $LANG_EN = 1 ]; then cat <<'EOF'
skill pio-arduino-cucumber (Gravitech Cucumber S, PlatformIO + Arduino) - ask Claude in your own words:
  (<app> in the later stages = the app folder new_app.sh prints, e.g. apps/my-app or C:/fw-ws/my-app)
 Set up / check
  "check my tools"                            -> check_tools.sh <board>
 Create and build (no board needed)
  "create a hello-world app for the Cucumber" -> new_app.sh <board> <app> "" hello-world
  "create the IoT sensor app"                 -> new_app.sh <board> <app> "" iot-sensor
  "add a driver for a new sensor"             -> src/board/board_<dev>.h/.cpp + tests/<dev>.json (SKILL.md "Extending")
  "open it in VS Code"                        -> open_ide.sh <app>  (VS Code + PlatformIO IDE; new_app does it)
     then choose: code + build/flash/debug yourself in VS Code (IDE path), or let Claude run build/flash/test (script path) - switch any time
  "build it"                                  -> build.sh <app>
 Run on hardware (milestone M1; Claude asks before every flash)
  "find my board"                             -> discover.sh <board> [--port <port>]  (esptool via the USB-UART bridge, writes nothing, resets the chip)
  "back up the factory firmware"              -> backup.sh <board>
  "flash it"                                  -> flash.sh <app> [--yes]
  "test it" / "test with button presses"      -> serial_test.py auto <spec> <log> --board <b> [--interactive]
  "test the sensors one by one"               -> serial_test.py ... tests/i2c_bus.json, mpu6050.json, bmp280.json, hts221.json, rgb_led.json
  "connect it to Wi-Fi / MQTT"                -> you type in a serial monitor: wifi set <ssid> <password>, mqtt set <host> [port] (kept in NVS, never in files)
  "run the unit tests"                        -> unit_test.sh <app> [--yes] [--build-only | --read-only]  (Unity + test log, func/ on the board; asks before flashing)
 Housekeeping
  "clean the build outputs"                   -> clean.sh [--apps]  (dry run, then --yes; --apps deletes apps)
  "add a new board" / "add a template"        -> boards/_template/, SKILL.md "Extending"
EOF
else cat <<'EOF'
skill pio-arduino-cucumber (Gravitech Cucumber S, PlatformIO + Arduino) - สั่ง Claude ได้ด้วยภาษาของคุณเอง ตัวอย่าง:
  (<app> ในขั้นหลัง new_app.sh = โฟลเดอร์แอปที่ new_app.sh พิมพ์ออกมา เช่น apps/my-app หรือ C:/fw-ws/my-app)
 เตรียม / ตรวจสอบ
  "ตรวจเครื่องมือให้หน่อย"                         -> check_tools.sh <board>
 สร้างและ build (ไม่ต้องมีบอร์ด)
  "สร้างแอป hello-world สำหรับ Cucumber"          -> new_app.sh <board> <app> "" hello-world
  "สร้างแอป IoT อ่านเซนเซอร์"                      -> new_app.sh <board> <app> "" iot-sensor
  "เพิ่ม driver เซนเซอร์ตัวใหม่"                    -> src/board/board_<dev>.h/.cpp + tests/<dev>.json (SKILL.md หัวข้อ Extending)
  "เปิดใน VS Code"                                -> open_ide.sh <app>  (VS Code + PlatformIO IDE; new_app เปิดให้เอง)
     จากนั้นเลือกได้: เขียนโค้ด + build/แฟลช/debug เองใน VS Code (ทาง IDE) หรือให้ Claude รัน build/flash/test (ทางสคริปต์) - สลับได้ทุกเมื่อ
  "build ให้หน่อย"                                -> build.sh <app>
 ใช้กับบอร์ดจริง (milestone M1; Claude จะถามก่อน flash ทุกครั้ง)
  "หาบอร์ดที่ต่ออยู่"                               -> discover.sh <board> [--port <port>]  (esptool ผ่าน USB-UART อ่านอย่างเดียว แต่ chip จะรีเซ็ต)
  "สำรอง firmware เดิม"                           -> backup.sh <board>
  "แฟลชเลย"                                      -> flash.sh <app> [--yes]
  "ทดสอบ" / "ทดสอบแบบกดปุ่ม"                      -> serial_test.py auto <spec> <log> --board <b> [--interactive]
  "ทดสอบเซนเซอร์ทีละตัว"                           -> serial_test.py ... tests/i2c_bus.json, mpu6050.json, bmp280.json, hts221.json, rgb_led.json
  "ต่อ Wi-Fi / MQTT"                               -> พิมพ์เองใน serial monitor: wifi set <ssid> <password>, mqtt set <host> [port] (เก็บใน NVS ไม่ลงไฟล์)
  "รัน unit test"                                 -> unit_test.sh <app> [--yes] [--build-only | --read-only]  (Unity + test log ของ func/ บนบอร์ด; ถามก่อน flash)
 งานอื่น
  "clean ให้หน่อย"                                -> clean.sh [--apps]  (ลบผล build; --apps ลบแอปด้วย, แสดงรายการก่อน)
  "เพิ่มบอร์ดใหม่" / "เพิ่ม template"               -> boards/_template/, SKILL.md หัวข้อ Extending
EOF
fi
if [ $LANG_EN = 1 ]; then echo " Active milestones: $(fw_active_milestones)"
else echo " milestone ที่เปิดใช้: $(fw_active_milestones)"; fi
[ $LANG_EN = 1 ] && echo " Boards installed:" || echo " บอร์ดที่มี:"
boards
[ $LANG_EN = 1 ] && echo " App templates:" || echo " template แอป:"
templates
[ $LANG_EN = 1 ] && echo " Apps workspace: $CUKE_WS" || echo " โฟลเดอร์แอป: $CUKE_WS"
