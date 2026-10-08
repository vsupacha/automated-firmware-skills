#!/usr/bin/env bash
# Stage 2a: find the connected board and save this PC's bench file (USB serial = MAC, COM port).
# Usage: discover.sh <board-id> [--serial <usb-serial>]
# Read-only: esptool reads chip, features, MAC, flash size and the security state through the
# USB Serial/JTAG - it RESETS the chip (the running firmware restarts) but writes nothing.
# Gates: chip = EXPECTED_CHIP, MAC = USB serial, flash size = EXPECTED_FLASH, secure boot and
# flash encryption disabled. On PASS writes <ESP_WS>/.bench/<board-id>.env.

. "$(dirname "$0")/env.sh"
require_milestone M1 "discover.sh (stage 4 connect)"
BOARD=""; WANT=""
while [ $# -gt 0 ]; do
  case "$1" in --serial) WANT="$(norm_mac "$2")"; shift;; --*) die "unknown option $1";; *) BOARD="$1";; esac; shift
done
[ -n "$BOARD" ] || die "usage: discover.sh <board-id> [--serial <usb-serial>]  (boards: $(known_boards))"
load_board "$BOARD"
bench_lock "$BOARD_ID" discover.sh

info "Espressif USB devices (VID $USB_VID) on this PC"
mapfile -t DEVS < <(usb_devices | tr -d '\r' | grep -v '^$')
[ ${#DEVS[@]} -gt 0 ] || need_user CONNECT "no board found - plug the $BOARD_NAME's USB-C port into this PC with a data cable; if it still does not show up: hold BOOT, press RESET, release BOOT; then re-run discover.sh"
for d in "${DEVS[@]}"; do echo "    $d"; done

SEL=""
if [ -n "$WANT" ]; then
  for d in "${DEVS[@]}"; do [ "$(echo "$d" | awk '{print $1}')" = "$WANT" ] && SEL="$d"; done
  [ -n "$SEL" ] || die "no device with serial $WANT"
elif [ ${#DEVS[@]} -eq 1 ]; then
  SEL="${DEVS[0]}"
else
  need_user CHOOSE "${#DEVS[@]} Espressif devices connected - ask which one is '$BOARD_ID', then re-run with --serial <usb-serial> (list above)"
fi
read -r SER PORT PID <<<"$SEL"
case " $USB_PIDS_APP " in *" $PID "*) ;; *) die "USB PID $PID is not the $BOARD_NAME's USB Serial/JTAG ($USB_PIDS_APP)";; esac

info "Identity check of $SER on $PORT (esptool, read-only - the chip restarts)"
mkdir -p "$BENCH_DIR"
ID="$(IDENTITY_LOG="$BENCH_DIR/$BOARD_ID.identity.log" identity "$PORT")"
val() { echo "$ID" | sed -n "s/^$1=//p"; }
fail=0
echo "usb serial     $SER  ($USB_VID:$PID, $PORT)"
echo "chip           $(val chip)"
echo "features       $(val features)"
echo "mac            $(val mac)"
echo "flash size     $(val flash)"
echo "secure boot    $(val secure_boot)"
echo "flash crypt    $(val flash_crypt)"
case "$(val chip)" in "$EXPECTED_CHIP "*|"$EXPECTED_CHIP") ;; *) echo "FAIL: chip '$(val chip)' is not $EXPECTED_CHIP"; fail=1;; esac
[ "$(val mac)" = "$SER" ] || { echo "FAIL: MAC '$(val mac)' != USB serial $SER"; fail=1; }
[ -z "$EXPECTED_FLASH" ] || [ "$(val flash)" = "$EXPECTED_FLASH" ] || { echo "FAIL: flash '$(val flash)' != $EXPECTED_FLASH"; fail=1; }
[ "$(val secure_boot)" = Disabled ] || { echo "FAIL: secure boot is '$(val secure_boot)' - stop and ask the user (never change it)"; fail=1; }
[ "$(val flash_crypt)" = Disabled ] || { echo "FAIL: flash encryption is '$(val flash_crypt)' - stop and ask the user (never change it)"; fail=1; }
[ $fail = 0 ] || { echo "IDENTITY: FAIL (esptool output: $BENCH_DIR/$BOARD_ID.identity.log)"; exit 1; }
echo "IDENTITY: PASS"

KEEP="$(bench_dev_lines "$BENCH_DIR/$BOARD_ID.env")"   # e.g. FLASH_POLICY
cat >"$BENCH_DIR/$BOARD_ID.env" <<EOF
# Bench instance: board '$BOARD_ID' on this PC, written $(date '+%Y-%m-%d %H:%M')
# by pio-arduino-esp32s3box/discover.sh. Re-run discover.sh after changing board or USB port.
USB_SERIAL=$SER
CONSOLE_PORT=$PORT
EOF
[ -z "$KEEP" ] || echo "$KEEP" >>"$BENCH_DIR/$BOARD_ID.env"
info "Saved $BENCH_DIR/$BOARD_ID.env  (USB_SERIAL=$SER CONSOLE_PORT=$PORT)"
