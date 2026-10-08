#!/usr/bin/env bash
# Command menu of the scons-rtthread-visionboard skill: what you can ask Claude, with short
# examples, the script behind each request, and the boards/templates installed right now.
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
skill scons-rtthread-visionboard (RT-Thread Vision Board RA8D1, RT-Thread + scons) - ask Claude in your own words:
 Set up / check
  "check my tools"                             -> check_tools.sh <board>
 Create and build (no board needed)
  "create a hello-world app for the Vision Board" -> new_app.sh <board> <app> "" hello-world
  "write an app: KEY0 toggles the blue LED"    -> template + code in src/board, src/func, src/hal_entry.c
  "open it in RT-Thread Studio"                -> open_ide.sh <app>  (import + start Studio; new_app imports it)
     then choose: code + build/download/debug yourself in Studio (IDE path), or let Claude run build/flash/test (script path) - switch any time
  "build it"                                   -> build.sh <app>
 Run on hardware (milestone M1; Claude asks before every flash)
  "find my board"                              -> discover.sh <board>   (pyOCD attach, no halt/reset, writes nothing)
  "flash it"                                   -> flash.sh <app> --yes  (code flash only, read back)
  "test it" / "test with button presses"       -> serial_test.py auto <spec> <log> --board <b> [--interactive]
 Housekeeping
  "clean the build outputs"                    -> clean.sh [--apps]  (dry run, then --yes; --apps deletes apps)
  "add a new board" / "add a template"         -> boards/_template/, SKILL.md "Extending"
EOF
else cat <<'EOF'
skill scons-rtthread-visionboard (RT-Thread Vision Board RA8D1, RT-Thread + scons) - สั่ง Claude ได้ด้วยภาษาของคุณเอง ตัวอย่าง:
 เตรียม / ตรวจสอบ
  "ตรวจเครื่องมือให้หน่อย"                          -> check_tools.sh <board>
 สร้างและ build (ไม่ต้องมีบอร์ด)
  "สร้างแอป hello-world สำหรับ Vision Board"        -> new_app.sh <board> <app> "" hello-world
  "เขียนแอป กด KEY0 แล้วไฟสีฟ้าสลับ"                  -> template + โค้ดใน src/board, src/func, src/hal_entry.c
  "เปิดใน RT-Thread Studio"                        -> open_ide.sh <app>  (import + เปิด Studio; new_app import ให้เอง)
     จากนั้นเลือกได้: เขียนโค้ด + build/download/debug เองใน Studio (ทาง IDE) หรือให้ Claude รัน build/flash/test (ทางสคริปต์) - สลับได้ทุกเมื่อ
  "build ให้หน่อย"                                 -> build.sh <app>
 ใช้กับบอร์ดจริง (milestone M1; Claude จะถามก่อน flash ทุกครั้ง)
  "หาบอร์ดที่ต่ออยู่"                                -> discover.sh <board>   (pyOCD attach ไม่หยุด/ไม่รีเซ็ต ไม่เขียนอะไร)
  "แฟลชเลย"                                       -> flash.sh <app> --yes  (เฉพาะ code flash แล้วอ่านกลับมาตรวจ)
  "ทดสอบ" / "ทดสอบแบบกดปุ่ม"                       -> serial_test.py auto <spec> <log> --board <b> [--interactive]
 งานอื่น
  "clean ให้หน่อย"                                 -> clean.sh [--apps]  (ลบผล build; --apps ลบแอปด้วย, แสดงรายการก่อน)
  "เพิ่มบอร์ดใหม่" / "เพิ่ม template"                -> boards/_template/, SKILL.md หัวข้อ Extending
EOF
fi
if [ $LANG_EN = 1 ]; then echo " Active milestones: $(fw_active_milestones)"
else echo " milestone ที่เปิดใช้: $(fw_active_milestones)"; fi
[ $LANG_EN = 1 ] && echo " Boards installed:" || echo " บอร์ดที่มี:"
boards
[ $LANG_EN = 1 ] && echo " App templates:" || echo " template แอป:"
templates
[ $LANG_EN = 1 ] && echo " Apps workspace: $RTT_WS" || echo " โฟลเดอร์แอป: $RTT_WS"
