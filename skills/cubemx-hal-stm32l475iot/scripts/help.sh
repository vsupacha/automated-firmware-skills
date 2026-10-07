#!/usr/bin/env bash
# Command menu of the cubemx-hal-stm32l475iot skill: what you can ask Claude, with short examples,
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
skill cubemx-hal-stm32l475iot (B-L475E-IOT01A, STM32CubeMX + STM32CubeL4 HAL + CMake) - ask Claude in your own words:
 Set up / check
  "check my tools"                          -> check_tools.sh <board>   (GLOBAL / LOCAL installs, VS Code)
  "find my board"                           -> discover.sh <board>   (read-only; saves ST-LINK serial + COM port)
 Create and build (no board needed)
  "create a hello-world app for the L475"   -> new_app.sh <board> <app> "" hello-world  (CubeMX headless, 30 s - 2 min)
  "write an app: B1 toggles LED2"           -> template + code in src/board, src/func, src/app_main.c
  "I changed the .ioc - regenerate"         -> regen.sh <app>
  "open it in VS Code"                      -> open_ide.sh <app>  (VS Code + STM32CubeIDE extension; new_app does it)
     then choose: code + build/flash/debug yourself in VS Code (IDE path), or let Claude run build/flash/test (script path) - switch any time
  "build it"                                -> build.sh <app>
 Run on hardware (milestone M3; Claude asks before every flash)
  "flash it"                                -> flash.sh <app> --yes   (identity gates: ST-LINK board, device ID)
  "test it" / "test with button presses"    -> serial_test.py auto <spec> <log> --board <b> [--interactive]
 Housekeeping
  "clean the build outputs"                 -> clean.sh [--apps]  (dry run, then --yes; --apps deletes apps)
EOF
else cat <<'EOF'
skill cubemx-hal-stm32l475iot (B-L475E-IOT01A, STM32CubeMX + STM32CubeL4 HAL + CMake) - สั่ง Claude ได้ด้วยภาษาของคุณเอง ตัวอย่าง:
 เตรียม / ตรวจสอบ
  "ตรวจเครื่องมือให้หน่อย"                       -> check_tools.sh <board>   (ติดตั้งแบบ GLOBAL / LOCAL, VS Code)
  "หาบอร์ดที่เสียบอยู่"                           -> discover.sh <board>   (อ่านอย่างเดียว; บันทึก serial ของ ST-LINK + COM port)
 สร้างและ build (ไม่ต้องมีบอร์ด)
  "สร้างแอป hello-world สำหรับบอร์ด L475"       -> new_app.sh <board> <app> "" hello-world  (CubeMX แบบไม่มีหน้าจอ 30 วินาที - 2 นาที)
  "เขียนแอป กด B1 แล้ว LED2 สลับ"               -> template + โค้ดใน src/board, src/func, src/app_main.c
  "แก้ .ioc แล้ว ช่วย generate ใหม่"              -> regen.sh <app>
  "เปิดใน VS Code"                             -> open_ide.sh <app>  (VS Code + STM32CubeIDE extension; new_app เปิดให้เอง)
     จากนั้นเลือกได้: เขียนโค้ด + build/แฟลช/debug เองใน VS Code (ทาง IDE) หรือให้ Claude รัน build/flash/test (ทางสคริปต์) - สลับได้ทุกเมื่อ
  "build ให้หน่อย"                              -> build.sh <app>
 ใช้กับบอร์ดจริง (milestone M3; Claude ถามก่อนแฟลชทุกครั้ง)
  "แฟลชให้หน่อย"                               -> flash.sh <app> --yes   (ตรวจตัวตนบอร์ด: ST-LINK, device ID)
  "ทดสอบ" / "ทดสอบแบบกดปุ่ม"                   -> serial_test.py auto <spec> <log> --board <b> [--interactive]
 งานอื่น
  "clean ให้หน่อย"                              -> clean.sh [--apps]  (ลบผล build; --apps ลบแอปด้วย, แสดงรายการก่อน)
EOF
fi
if [ $LANG_EN = 1 ]; then echo " Active milestones: $(fw_active_milestones)"
else echo " milestone ที่เปิดใช้: $(fw_active_milestones)"; fi
[ $LANG_EN = 1 ] && echo " Boards installed:" || echo " บอร์ดที่มี:"
boards
[ $LANG_EN = 1 ] && echo " App templates:" || echo " template แอป:"
templates
[ $LANG_EN = 1 ] && echo " Apps workspace: $L4_WS" || echo " โฟลเดอร์แอป: $L4_WS"
