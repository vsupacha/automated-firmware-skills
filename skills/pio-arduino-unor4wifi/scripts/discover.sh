#!/usr/bin/env bash
# Stage 4 (connect): find the connected board and save this PC's bench file (USB serial, COM port).
# Usage: discover.sh <board-id> [--serial <usb-serial>]
# Read-only: a 1200 baud touch starts the loader of the board's ESP32-S3 USB bridge, bossac --info
# reads it and --reset restarts the sketch (the running firmware restarts, nothing is written).
# Gates: USB VID:PID of the UNO R4 WiFi bridge, loader = EXPECTED_LOADER, loader device =
# EXPECTED_LOADER_DEVICE (an emulated placeholder - the RA4M1 itself is identified after flashing
# by the sketch's INFO line), security off, no locked regions. On PASS writes
# <UNO_WS>/.bench/<board-id>.env.

. "$(dirname "$0")/env.sh"
require_milestone M1 "discover.sh (stage 4 connect)"
BOARD=""; WANT=""
while [ $# -gt 0 ]; do
  case "$1" in --serial) WANT="$(norm_serial "$2")"; shift;; --*) die "unknown option $1";; *) BOARD="$1";; esac; shift
done
[ -n "$BOARD" ] || die "usage: discover.sh <board-id> [--serial <usb-serial>]  (boards: $(known_boards))"
load_board "$BOARD"
require_vars USB_VID USB_PIDS_APP EXPECTED_LOADER
bench_lock "$BOARD_ID" discover.sh

info "Arduino USB devices (VID $USB_VID) on this PC"
mapfile -t DEVS < <(usb_devices | tr -d '\r' | grep -v '^$')
[ ${#DEVS[@]} -gt 0 ] || need_user CONNECT "no board found - plug the $BOARD_NAME's USB-C port into this PC with a data cable, then re-run discover.sh"
for d in "${DEVS[@]}"; do echo "    $d"; done

SEL=""
if [ -n "$WANT" ]; then
  for d in "${DEVS[@]}"; do [ "$(echo "$d" | awk '{print $1}')" = "$WANT" ] && SEL="$d"; done
  [ -n "$SEL" ] || die "no device with serial $WANT"
elif [ ${#DEVS[@]} -eq 1 ]; then
  SEL="${DEVS[0]}"
else
  need_user CHOOSE "${#DEVS[@]} Arduino devices connected - ask which one is '$BOARD_ID', then re-run with --serial <usb-serial> (list above)"
fi
read -r SER PORT PID <<<"$SEL"
case " $USB_PIDS_APP " in *" $PID "*) ;; *) die "USB PID $PID is not the $BOARD_NAME's USB bridge ($USB_PIDS_APP)";; esac

info "Identity check of $SER on $PORT (1200 baud touch + bossac --info --reset, read-only - the sketch restarts)"
mkdir -p "$BENCH_DIR"
ID="$(IDENTITY_LOG="$BENCH_DIR/$BOARD_ID.identity.log" identity "$PORT")"
val() { echo "$ID" | sed -n "s/^$1=//p"; }
fail=0
echo "usb serial     $SER  ($USB_VID:$PID, $PORT)"
echo "loader         $(val loader)"
echo "loader device  $(val device)  (emulated by the USB bridge)"
echo "security       $(val security)"
echo "locked         $(val locked)"
case "$(val loader)" in "$EXPECTED_LOADER"*) ;; *) echo "FAIL: loader '$(val loader)' is not '$EXPECTED_LOADER'"; fail=1;; esac
[ -z "$EXPECTED_LOADER_DEVICE" ] || [ "$(val device)" = "$EXPECTED_LOADER_DEVICE" ] \
  || { echo "FAIL: loader device '$(val device)' != $EXPECTED_LOADER_DEVICE"; fail=1; }
[ "$(val security)" = false ] || { echo "FAIL: security is '$(val security)' - stop and ask the user (never change it)"; fail=1; }
[ "$(val locked)" = none ] || { echo "FAIL: locked regions '$(val locked)' - stop and ask the user (never unlock)"; fail=1; }
[ $fail = 0 ] || { echo "IDENTITY: FAIL (bossac output: $BENCH_DIR/$BOARD_ID.identity.log)"; exit 1; }
PORT="$(wait_port "$SER" 15)" || die "board port did not come back after the reset"
echo "IDENTITY: PASS"

KEEP="$(bench_dev_lines "$BENCH_DIR/$BOARD_ID.env")"   # e.g. FLASH_POLICY
cat >"$BENCH_DIR/$BOARD_ID.env" <<EOF
# Bench instance: board '$BOARD_ID' on this PC, written $(date '+%Y-%m-%d %H:%M')
# by pio-arduino-unor4wifi/discover.sh. Re-run discover.sh after changing board or USB port.
USB_SERIAL=$SER
CONSOLE_PORT=$PORT
EOF
[ -z "$KEEP" ] || echo "$KEEP" >>"$BENCH_DIR/$BOARD_ID.env"
info "Saved $BENCH_DIR/$BOARD_ID.env  (USB_SERIAL=$SER CONSOLE_PORT=$PORT)"
