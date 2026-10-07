#!/usr/bin/env bash
# Command menu of the modus-pdl-edgitalk skill: what you can ask Claude, with short examples,
# the script behind each request, and the boards/templates installed right now.
# Usage: help.sh [--en]      (Thai by default)

. "$(dirname "$0")/env.sh"
LANG_EN=0; [ "$1" = "--en" ] && LANG_EN=1

boards() {
  for id in $(known_boards); do
    f="$(board_profile_dir "$id")/board.env"
    name="$(sed -n 's/^BOARD_NAME="\{0,1\}\([^"#]*\)"\{0,1\}.*/\1/p' "$f" | head -1)"
    ext="$(sed -n 's/^BOARD_EXTENDS=\([A-Za-z0-9_-]*\).*/\1/p' "$f")"
    src=""; case "$f" in "$BOARDS_DIR"/*) ;; *) src="  [project boards/]";; esac
    printf '    %-14s %s%s%s\n' "$id" "$name" "${ext:+  (= $ext + extras)}" "$src"
  done
}
templates() {
  for d in "$SKILL_DIR"/templates/*/; do
    t="$(basename "$d")"; [ "${t#_}" = "$t" ] || continue
    desc="$(head -1 "$d/description.txt" 2>/dev/null | tr -d '\r')"
    printf '    %-14s %s\n' "$t" "$desc"
  done
}

if [ $LANG_EN = 1 ]; then cat <<'EOF'
PSOC Edge E84 firmware skill - what you can ask (say it in your own words)

 Setup
  "check my tools"                         -> check_tools.sh <board>
  "find the board(s) I plugged in"         -> discover.sh <board> [--serial <probe>]
 Explore
  "list ModusToolbox examples for tesaiot" -> examples.sh <board> [words]
  "examples about bluetooth / wifi / ml"   -> examples.sh <board> ble | --category Wi-Fi
  "tell me about btstack-findme"           -> examples.sh <board> --detail <id>
 Create + build
  "create a hello-world app for edgi-talk" -> new_app.sh <board> <app> "" hello-world
  "start from the BLE Find Me example"     -> new_app.sh <board> <app> --example btstack-findme
  "write an app: press SW1, LED1 lights"   -> template + code in board/ func/ main.c layers
  "open it in VS Code"                     -> open_ide.sh <app>  (VS Code + ModusToolbox extension; new_app does it)
     then choose: code + build/flash/debug yourself in VS Code (IDE path), or let Claude run build/flash/test (script path) - switch any time
  "build it"                               -> build.sh <app>
 Run on hardware (Claude asks before every flash)
  "back up the board first"                -> backup.sh <board>
  "flash it" / "restore the backup"        -> flash.sh <app> --yes [--hex <file>]
  "test it" / "test with button presses"   -> serial_test.py auto <spec> <log> --board <b> [--interactive]
 Housekeeping
  "clean the build outputs"                -> clean.sh [--apps]  (dry run, then --yes; --apps deletes apps)
  "add a new board" / "add a template"     -> boards/_template/README.md, SKILL.md "Extending"
EOF
else cat <<'EOF'
skill modus-pdl-edgitalk (PSOC Edge E84) - สั่ง Claude ได้ด้วยภาษาของคุณเอง ตัวอย่าง:

 เตรียมเครื่อง
  "ตรวจเครื่องมือให้หน่อย"                  -> check_tools.sh <board>
  "หาบอร์ดที่เสียบอยู่"                       -> discover.sh <board> [--serial <probe>]
 ดูตัวอย่างของ ModusToolbox
  "ขอรายการ example ของ tesaiot"            -> examples.sh <board> [คำค้น]
  "มี example เกี่ยวกับ bluetooth ไหม"       -> examples.sh <board> ble   หรือ --category Wi-Fi
  "อธิบาย btstack-findme หน่อย"              -> examples.sh <board> --detail <id>
 สร้างแอป + build
  "สร้างแอป hello world ให้ edgi-talk"        -> new_app.sh <board> <app> "" hello-world
  "เริ่มจาก example BLE Find Me"             -> new_app.sh <board> <app> --example btstack-findme
  "เขียนแอป กด SW1 แล้ว LED1 ติด"             -> template + โค้ดแบ่ง layer board/ func/ main.c
  "เปิดใน VS Code"                           -> open_ide.sh <app>  (VS Code + ModusToolbox extension; new_app เปิดให้เอง)
     จากนั้นเลือกได้: เขียนโค้ด + build/แฟลช/debug เองใน VS Code (ทาง IDE) หรือให้ Claude รัน build/flash/test (ทางสคริปต์) - สลับได้ทุกเมื่อ
  "build ให้หน่อย"                           -> build.sh <app>
 ใช้กับบอร์ดจริง (Claude จะขออนุญาตก่อน flash ทุกครั้ง)
  "สำรอง firmware เดิมก่อน"                   -> backup.sh <board>
  "flash เลย" / "คืน firmware เดิม"           -> flash.sh <app> --yes [--hex <file>]
  "ทดสอบ" / "ทดสอบแบบกดปุ่มด้วย"             -> serial_test.py auto <spec> <log> --board <b> [--interactive]
 ดูแลโฟลเดอร์
  "clean ให้หน่อย"                            -> clean.sh [--apps]  (ลบผล build; --apps ลบแอปด้วย, แสดงรายการก่อน)
  "เพิ่มบอร์ดใหม่" / "เพิ่ม template"           -> boards/_template/README.md, SKILL.md หัวข้อ Extending
EOF
fi
echo
if [ $LANG_EN = 1 ]; then echo " Active milestones: $(fw_active_milestones)  (hardware commands = M3; enable in milestones.env)"
else echo " milestone ที่เปิดใช้: $(fw_active_milestones)  (คำสั่งกับบอร์ดจริง = M3 เปิดใช้ใน milestones.env)"; fi
[ $LANG_EN = 1 ] && echo " Boards installed:" || echo " บอร์ดที่มี profile:"
boards
[ $LANG_EN = 1 ] && echo " App templates:" || echo " template แอป:"
templates
[ $LANG_EN = 1 ] && echo " Apps workspace: $PSE84_WS" || echo " โฟลเดอร์แอป: $PSE84_WS"
