#!/usr/bin/env bash
# Command menu of the pio-espidf-esp32s3box skill: what you can ask Claude, with short examples,
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
skill pio-espidf-esp32s3box (ESP32-S3-BOX, PlatformIO + ESP-IDF) - ask Claude in your own words:
 Set up / check
  "check my tools"                            -> check_tools.sh <board>
 Create and build (no board needed)
  "create a hello-world app for the BOX"      -> new_app.sh <board> <app> "" hello-world
  "write an app: BOOT toggles the backlight"  -> template + code in src/board, src/func, src/app_main.c
  "build it"                                  -> build.sh <app>
 Run on hardware (milestone M3; Claude asks before every flash)
  "find my board"                             -> discover.sh <board>   (esptool, writes nothing, resets the chip)
  "back up the factory firmware"              -> backup.sh <board>
  "flash it"                                  -> flash.sh <app> --yes
  "test it" / "test with button presses"      -> serial_test.py auto <spec> <log> --board <b> [--interactive]
 Housekeeping
  "clean the build outputs"                   -> clean.sh [--apps]  (dry run, then --yes; --apps deletes apps)
  "add a new board" / "add a template"        -> boards/_template/, SKILL.md "Extending"
EOF
else cat <<'EOF'
skill pio-espidf-esp32s3box (ESP32-S3-BOX, PlatformIO + ESP-IDF) - สั่ง Claude ได้ด้วยภาษาของคุณเอง ตัวอย่าง:
 เตรียม / ตรวจสอบ
  "ตรวจเครื่องมือให้หน่อย"                         -> check_tools.sh <board>
 สร้างและ build (ไม่ต้องมีบอร์ด)
  "สร้างแอป hello-world สำหรับ BOX"               -> new_app.sh <board> <app> "" hello-world
  "เขียนแอป กด BOOT แล้วไฟจอสลับ"                  -> template + โค้ดใน src/board, src/func, src/app_main.c
  "build ให้หน่อย"                                -> build.sh <app>
 ใช้กับบอร์ดจริง (milestone M3; Claude จะถามก่อน flash ทุกครั้ง)
  "หาบอร์ดที่ต่ออยู่"                               -> discover.sh <board>   (esptool อ่านอย่างเดียว แต่ chip จะรีเซ็ต)
  "สำรอง firmware เดิม"                           -> backup.sh <board>
  "แฟลชเลย"                                      -> flash.sh <app> --yes
  "ทดสอบ" / "ทดสอบแบบกดปุ่ม"                      -> serial_test.py auto <spec> <log> --board <b> [--interactive]
 งานอื่น
  "clean ให้หน่อย"                                -> clean.sh [--apps]  (ลบผล build; --apps ลบแอปด้วย, แสดงรายการก่อน)
  "เพิ่มบอร์ดใหม่" / "เพิ่ม template"               -> boards/_template/, SKILL.md หัวข้อ Extending
EOF
fi
if [ $LANG_EN = 1 ]; then echo " Active milestones: $(fw_active_milestones)  (hardware commands = M3; enable in milestones.env)"
else echo " milestone ที่เปิดใช้: $(fw_active_milestones)  (คำสั่งกับบอร์ดจริง = M3 เปิดใช้ใน milestones.env)"; fi
[ $LANG_EN = 1 ] && echo " Boards installed:" || echo " บอร์ดที่มี:"
boards
[ $LANG_EN = 1 ] && echo " App templates:" || echo " template แอป:"
templates
[ $LANG_EN = 1 ] && echo " Apps workspace: $ESP_WS" || echo " โฟลเดอร์แอป: $ESP_WS"
