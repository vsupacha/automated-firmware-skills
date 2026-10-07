#!/usr/bin/env bash
# Stage 4: build an app with PlatformIO (Arduino) and write the build manifest.
# Usage: build.sh <app-dir> [--clean] [--allow-warnings]
# Gate: "BUILD: PASS" = pio exit 0, firmware.bin/.elf, bootloader, partition table present,
# 0 warnings in the app's own src/ (an incremental build only recompiles changed files; --clean
# re-checks every file). Exit 0 PASS, 1 FAIL, 2 warnings in src/ (fix them, or --allow-warnings).
# The manifest (.pio/build/<env>/manifest.txt: tools, platform, packages, sizes, the flash map
# from `pio project metadata` and the sha256 of every image) is written only on PASS - flash.sh
# programs exactly that map. boot_app0.bin (OTA data, from the framework) is copied next to the
# other images so it is hash-gated too.

. "$(dirname "$0")/env.sh"
APPDIR=""; CLEAN=0; ALLOW=0
for a in "$@"; do
  case "$a" in --clean) CLEAN=1;; --allow-warnings) ALLOW=1;; --*) die "unknown option $a";; *) APPDIR="$a";; esac
done
[ -n "$APPDIR" ] && [ -f "$APPDIR/arduino-app.env" ] || die "usage: build.sh <app-dir> [--clean] [--allow-warnings]  (an app made by new_app.sh)"
APPDIR="$(cd "$APPDIR" && pwd)"
require_safe_path "$APPDIR" "app" 100
[ -n "$PIO" ] || die "PlatformIO not found - run check_tools.sh"
# shellcheck disable=SC1091
. "$APPDIR/arduino-app.env"
ENV="$APP_PIO_ENV"; OUT="$APPDIR/.pio/build/$ENV"
mkdir -p "$APPDIR/logs"; LOG="$APPDIR/logs/build-$(ts).log"

[ $CLEAN = 1 ] && { info "pio run -t clean"; "$PIO" run -d "$APPDIR" -e "$ENV" -t clean >>"$LOG" 2>&1; }
info "pio run -e $ENV  (log $LOG; the first build installs the platform + arduino-esp32 if missing)"
start=$(date +%s); sleep 1
"$PIO" run -d "$APPDIR" -e "$ENV" >>"$LOG" 2>&1; rc=$?
secs=$(( $(date +%s) - start ))
tr -d '\r' <"$LOG" >"$LOG.tmp" && mv "$LOG.tmp" "$LOG"

# warnings in our own sources (<app>/src/) vs the framework (whose libraries have src/ folders too)
srcw="$(grep -E "(^|[/\\\\]$(basename "$APPDIR")[/\\\\])src[/\\\\][^:]*:[0-9]+:[0-9]+: warning:" "$LOG" | sort -u)"
nsrc=$(printf '%s' "$srcw" | grep -c . ); nall=$(grep -c ': warning:' "$LOG")
errs=$(grep -c ': error:' "$LOG")
have=1; fresh=1
for f in firmware.bin firmware.elf bootloader.bin partitions.bin; do
  [ -f "$OUT/$f" ] || have=0
done
[ -f "$OUT/firmware.bin" ] && [ "$(date -r "$OUT/firmware.bin" +%s)" -ge "$start" ] || fresh=0
echo "pio exit=$rc  time=${secs}s  warnings(src)=$nsrc  warnings(all)=$nall  errors=$errs  bin=$([ $fresh = 1 ] && echo rebuilt || echo up-to-date)"
grep -E '^(RAM|Flash):' "$LOG" | sed 's/^/  /'
[ -n "$srcw" ] && echo "$srcw" | head -20

if [ $rc -ne 0 ] || [ $have = 0 ]; then
  grep -E ': error:|Error|error:|FAILED' "$LOG" | head -20
  echo "BUILD: FAIL  (see $LOG)"; exit 1
fi
if [ "$nsrc" -gt 0 ] && [ $ALLOW = 0 ]; then
  echo "BUILD: WARNINGS ($nsrc in src/) - fix them or re-run with --allow-warnings"; exit 2
fi

# flash map: the images and offsets PlatformIO itself would upload ("<offset> <file>" lines)
MAP="$("$PIO" project metadata -d "$APPDIR" -e "$ENV" --json-output 2>/dev/null | "$PYTHON" -c "
import json, sys, os, shutil
e = json.load(sys.stdin)[sys.argv[1]]['extra']; out = sys.argv[2]
for im in e['flash_images']:
    name = os.path.basename(im['path'])
    if os.path.normcase(os.path.dirname(os.path.abspath(im['path']))) != os.path.normcase(os.path.abspath(out)):
        shutil.copyfile(im['path'], os.path.join(out, name))     # e.g. boot_app0.bin from the framework
    print(im['offset'], name)
print(e['application_offset'], 'firmware.bin')" "$ENV" "$(winpath "$OUT")" | tr -d '\r')"
[ -n "$MAP" ] && echo "$MAP" | grep -q ' firmware.bin$' || { echo "BUILD: FAIL (no flash map from pio project metadata)"; exit 1; }
IMAGES="firmware.elf $(echo "$MAP" | awk '{print $2}' | tr '\n' ' ')"

# manifest: what was used, and the sha256 of what flash.sh may program
pname="${APP_PIO_PLATFORM%@*}"; pname="${pname##*/}"
{
  echo "# build manifest - written by pio-arduino-esp32s3box/build.sh on PASS, $(date '+%Y-%m-%d %H:%M:%S')"
  echo "app        $(basename "$APPDIR")  board=$APP_BOARD  template=$APP_TEMPLATE  env=$ENV  target=$APP_IDF_TARGET"
  echo "pio        $("$PIO" --version | tr -d '\r')"
  echo "platform   $APP_PIO_PLATFORM (installed $("$PYTHON" -c "import json,sys;print(json.load(open(sys.argv[1]))['version'])" "$(winpath "$PIO_HOME/platforms/$pname/platform.json")" 2>/dev/null | tr -d '\r'))"
  echo "packages:"
  "$PIO" pkg list -d "$APPDIR" -e "$ENV" 2>/dev/null | tr -d '\r' \
    | grep -E '^(Platform |[│├└─ ]+[a-z])' | sed 's/ (required:.*//; s/^[│├└─ ]*/  /'
  grep -E '^(RAM|Flash):' "$LOG" | sed 's/^/size  /'
  echo "artifacts (sha256  bytes  file):"
  for f in $IMAGES; do
    echo "$(sha256sum "$OUT/$f" | cut -d' ' -f1) $(wc -c <"$OUT/$f" | tr -d ' ') $f"
  done
  echo "flash map (offset file):"
  echo "$MAP" | sed 's/^/flash /'
} >"$OUT/manifest.txt"
echo "manifest: $OUT/manifest.txt"
grep -E '^[0-9a-f]{64} [0-9]+ firmware.bin$' "$OUT/manifest.txt"
echo "BUILD: PASS"
