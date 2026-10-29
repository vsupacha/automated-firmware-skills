#!/usr/bin/env bash
# Command menu of the mcux-sdk-frdmmcxn947 skill: what you can ask Claude, with short examples,
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
skill mcux-sdk-frdmmcxn947 (NXP FRDM-MCXN947, MCUXpresso SDK + CMake) - ask Claude in your own words:
  (<app> in the later stages = the app folder new_app.sh prints, e.g. C:/fw-ws/my-app)
 Set up / check
  "check my tools"                          -> check_tools.sh <board>   (SDK, NXP tools, Kitware CMake, VS Code)
 Create and build (no board needed)
  "create a hello-world app for the MCXN947" -> new_app.sh <board> <app> "" hello-world  (west export_app, ~20 s)
  "write an app: SW2 toggles the green LED" -> template + code in src/board, src/func, src/app_main.c
  "open it in VS Code"                      -> open_ide.sh <app>  (MCUXpresso for VS Code; new_app does it)
     then choose: code + build/flash/debug yourself in VS Code (IDE path), or let Claude run build/flash/test (script path) - switch any time
  "build it"                                -> build.sh <app>   (NXP / Kitware tools only, never ST's)
 Run on hardware (milestone M1; Claude asks before every flash)
  "find my board"                           -> discover.sh <board>   (read-only; saves MCU-Link serial + COM port)
  "flash it"                                -> flash.sh <app> --yes   (identity + internal-flash gates, LinkServer -u none)
  "test it" / "test with button presses"    -> serial_test.py auto <spec> <log> --board <b> [--interactive]
 Housekeeping
  "clean the build outputs"                 -> clean.sh [--apps]  (dry run, then --yes; --apps deletes apps)
EOF
else cat <<'EOF'
skill mcux-sdk-frdmmcxn947 (NXP FRDM-MCXN947, MCUXpresso SDK + CMake) - สั่ง Claude ได้ด้วยภาษาของคุณเอง ตัวอย่าง:
  (<app> ในขั้นหลัง new_app.sh = โฟลเดอร์แอปที่ new_app.sh พิมพ์ออกมา เช่น C:/fw-ws/my-app)
 เตรียม / ตรวจสอบ
  "ตรวจเครื่องมือให้หน่อย"                       -> check_tools.sh <board>   (SDK, เครื่องมือ NXP, Kitware CMake, VS Code)
 สร้างและ build (ไม่ต้องมีบอร์ด)
  "สร้างแอป hello-world สำหรับบอร์ด MCXN947"     -> new_app.sh <board> <app> "" hello-world  (west export_app ประมาณ 20 วินาที)
  "เขียนแอป กด SW2 แล้ว LED เขียวสลับ"          -> template + โค้ดใน src/board, src/func, src/app_main.c
  "เปิดใน VS Code"                             -> open_ide.sh <app>  (MCUXpresso for VS Code; new_app เปิดให้เอง)
     จากนั้นเลือกได้: เขียนโค้ด + build/แฟลช/debug เองใน VS Code (ทาง IDE) หรือให้ Claude รัน build/flash/test (ทางสคริปต์) - สลับได้ทุกเมื่อ
  "build ให้หน่อย"                              -> build.sh <app>   (ใช้เครื่องมือ NXP / Kitware เท่านั้น ไม่ใช้ของ ST)
 ใช้กับบอร์ดจริง (milestone M1; Claude ถามก่อนแฟลชทุกครั้ง)
  "หาบอร์ดที่เสียบอยู่"                           -> discover.sh <board>   (อ่านอย่างเดียว; บันทึก serial ของ MCU-Link + COM port)
  "แฟลชให้หน่อย"                               -> flash.sh <app> --yes   (ตรวจตัวตนบอร์ด + เขียนเฉพาะ internal flash, LinkServer -u none)
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
[ $LANG_EN = 1 ] && echo " Apps workspace: $MCX_WS" || echo " โฟลเดอร์แอป: $MCX_WS"
