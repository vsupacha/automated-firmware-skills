#!/usr/bin/env bash
# Stage 2a: find the connected board and save this PC's bench file (USB serial = chip ID, COM port).
# Usage: discover.sh <board-id> [--serial <usb-serial>]
# Read-only: never reboots or writes the board. A board running a sketch is identified by its USB
# IDs + serial; a board in BOOTSEL (blank or held at power-up) is also checked with picotool
# (chip type, flash size). flash.sh re-checks the chip in BOOTSEL before every write.
# On PASS writes <PICO_WS>/.bench/<board-id>.env.

. "$(dirname "$0")/env.sh"
require_milestone M3 "discover.sh (stage 6 connect)"
BOARD=""; WANT=""
while [ $# -gt 0 ]; do
  case "$1" in --serial) WANT="$(echo "$2" | tr a-z A-Z)"; shift;; --*) die "unknown option $1";; *) BOARD="$1";; esac; shift
done
[ -n "$BOARD" ] || die "usage: discover.sh <board-id> [--serial <usb-serial>]  (boards: $(known_boards))"
load_board "$BOARD"

info "RP2 USB devices (VID $USB_VID) on this PC"
mapfile -t DEVS < <(usb_devices | tr -d '\r' | grep -E '^(app|bootsel) ')
[ ${#DEVS[@]} -gt 0 ] || need_user CONNECT "no board found - plug the Pico 2 W in with a data cable; if it still does not show up: unplug, hold BOOTSEL, plug in, release; then re-run discover.sh"
for d in "${DEVS[@]}"; do echo "    $d"; done

SEL=""
if [ -n "$WANT" ]; then
  for d in "${DEVS[@]}"; do [ "$(echo "$d" | awk '{print $2}')" = "$WANT" ] && SEL="$d"; done
  [ -n "$SEL" ] || die "no device with serial $WANT"
elif [ ${#DEVS[@]} -eq 1 ]; then
  SEL="${DEVS[0]}"
else
  need_user CHOOSE "${#DEVS[@]} boards connected - ask which one is '$BOARD_ID', then re-run with --serial <usb-serial> (list above)"
fi
read -r MODE SER PORT PID <<<"$SEL"

info "Identity check of $SER ($MODE)"
fail=0
echo "usb serial     $SER"
echo "usb id         $USB_VID:$PID ($MODE)"
if [ "$MODE" = bootsel ]; then
  out="$(picotool_info "$SER")"
  chip="$(echo "$out" | sed -n 's/^ *type: *//p' | head -1)"
  flash="$(echo "$out" | sed -n 's/^ *flash size: *//p' | head -1)"
  chipid="$(echo "$out" | sed -n 's/^ *chipid: *0x//p' | head -1 | tr a-z A-Z)"
  echo "chip           ${chip:-?}"; echo "flash          ${flash:-?}"; echo "chip id        ${chipid:-?}"
  [ "$chip" = "$EXPECTED_CHIP" ] || { echo "FAIL: chip '${chip:-none}' != $EXPECTED_CHIP"; fail=1; }
  [ -z "$EXPECTED_FLASH" ] || [ "$flash" = "$EXPECTED_FLASH" ] || { echo "FAIL: flash '${flash:-?}' != $EXPECTED_FLASH"; fail=1; }
  [ "$chipid" = "$SER" ] || { echo "FAIL: chip id '${chipid:-?}' != USB serial $SER"; fail=1; }
  echo "console port   - (BOOTSEL: no sketch running; flash.sh finds the port after flashing)"
  PORT=""
else
  echo "console port   $PORT"
  case " $USB_PIDS_APP " in *" $PID "*) ;; *) echo "FAIL: USB PID $PID is not a $BOARD_NAME sketch ($USB_PIDS_APP)"; fail=1;; esac
  echo "NOTE: chip type/flash size are read in BOOTSEL - flash.sh checks them before programming"
fi
[ $fail = 0 ] || { echo "IDENTITY: FAIL"; exit 1; }
echo "IDENTITY: PASS"

mkdir -p "$BENCH_DIR"
cat >"$BENCH_DIR/$BOARD_ID.env" <<EOF
# Bench instance: board '$BOARD_ID' on this PC, written $(date '+%Y-%m-%d %H:%M')
# by pio-rpi-pico-2w/discover.sh. Re-run discover.sh after changing board or USB port.
USB_SERIAL=$SER
CONSOLE_PORT=$PORT
EOF
info "Saved $BENCH_DIR/$BOARD_ID.env  (USB_SERIAL=$SER CONSOLE_PORT=${PORT:--})"
