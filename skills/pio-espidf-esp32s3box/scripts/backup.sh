#!/usr/bin/env bash
# Stage 7 (before the first flash): read the whole flash of this PC's board into a file, so the
# factory firmware can be restored. Read-only for the board (esptool read_flash; the chip resets).
# Usage: backup.sh <board-id> [--out <dir>]
#   --out  default $ESP_BACKUP_DIR = <workspace>/../backup (outside apps/, so clean.sh keeps it;
#          git-ignored - flash dumps never go to git)
# Restore (developer decision, writes the board): esptool.py --chip esp32s3 --port <port>
#   write_flash 0x0 <file.bin>

. "$(dirname "$0")/env.sh"
require_milestone M1 "backup.sh (stage 5 backup)"
BOARD=""; OUT="${ESP_BACKUP_DIR:-$(dirname "$ESP_WS")/backup}"
while [ $# -gt 0 ]; do
  case "$1" in --out) OUT="$2"; shift;; --*) die "unknown option $1";; *) BOARD="$1";; esac; shift
done
[ -n "$BOARD" ] || die "usage: backup.sh <board-id> [--out <dir>]"
load_board "$BOARD"
bench_lock "$BOARD_ID" backup.sh
require_vars USB_SERIAL
PORT="$(find_port "$USB_SERIAL")"
[ -n "$PORT" ] || need_user CONNECT "board '$BOARD_ID' ($USB_SERIAL) not found - plug it in (or run discover.sh after changing board), then re-run"
size="$(echo "${EXPECTED_FLASH:-16MB}" | sed 's/MB$//')"; bytes=$((size * 1024 * 1024))
mkdir -p "$OUT"; OUT="$(cd "$OUT" && pwd)"
FILE="$OUT/$BOARD_ID-flash-$(ts).bin"; LOG="$FILE.log"
info "esptool read_flash 0x0 $bytes bytes from $PORT -> $FILE (several minutes)"
esptool_run "$PORT" --baud 921600 --before default_reset --after hard_reset \
  read_flash 0x0 "$bytes" "$(winpath "$FILE")" >"$LOG"; rc=$?
tail -3 "$LOG" | sed 's/^/  /'
if [ $rc -ne 0 ] || [ ! -f "$FILE" ] || [ "$(wc -c <"$FILE" | tr -d ' ')" -ne "$bytes" ]; then
  echo "BACKUP: FAIL (see $LOG)"; exit 1
fi
echo "$(sha256sum "$FILE" | cut -d' ' -f1)  $(basename "$FILE")" >"$FILE.sha256"
echo "sha256 $(cut -d' ' -f1 "$FILE.sha256")"
echo "BACKUP: PASS ($FILE)"
