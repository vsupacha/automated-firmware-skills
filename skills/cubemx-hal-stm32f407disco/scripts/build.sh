#!/usr/bin/env bash
# Stage 4: build an app's generated CMake project (mx/) with the pinned STM32Cube bundles.
# Usage: build.sh <app-dir> [--clean] [--allow-warnings]
# Gate: "BUILD: PASS" = cmake exit 0, ELF present, 0 warnings in the app's own src/ (exit 2 = fix
# them, or --allow-warnings). Writes <elf>.hex and mx/build/Debug/manifest.txt (tools, firmware
# package, .ioc sha256, ELF/HEX sha256, size) only on PASS - the flash stage will require it.

. "$(dirname "$0")/env.sh"
APPDIR=""; CLEAN=0; ALLOW=0
for a in "$@"; do
  case "$a" in --clean) CLEAN=1;; --allow-warnings) ALLOW=1;; --*) die "unknown option $a";; *) APPDIR="$a";; esac
done
[ -n "$APPDIR" ] && [ -f "$APPDIR/f4-app.env" ] || die "usage: build.sh <app-dir> [--clean] [--allow-warnings]  (an app made by new_app.sh)"
APPDIR="$(cd "$APPDIR" && pwd)"; APP="$(basename "$APPDIR")"
# shellcheck disable=SC1091
. "$APPDIR/f4-app.env"
load_board "$APP_BOARD"
require_safe_path "$APPDIR" "app" 100
[ -f "$APPDIR/mx/CMakeLists.txt" ] || die "no generated project in $APPDIR/mx - run regen.sh"
grep -q "fw-skill overlay" "$APPDIR/mx/CMakeLists.txt" || die "mx/ is not hooked to src/ (regenerated outside the skill?) - run regen.sh"
[ "$APPDIR/$APP.ioc" -nt "$APPDIR/mx/mx.ioc" ] && echo "WARN: $APP.ioc is newer than mx/ - run regen.sh if the hardware configuration changed"
export PATH="$GCC_BIN:$CMAKE_BIN:$NINJA_BIN:$PATH"
mkdir -p "$APPDIR/logs"; LOG="$APPDIR/logs/build-$(ts).log"
OUTDIR="$APPDIR/mx/build/Debug"; ELF="$OUTDIR/mx.elf"

info "cmake --preset Debug + build  (log $LOG)"
start=$(date +%s)
( cd "$APPDIR/mx" && cmake --preset Debug ) >"$LOG" 2>&1; rc=$?
if [ $rc -eq 0 ]; then
  flags=(); [ $CLEAN = 1 ] && flags=(--clean-first)
  ( cd "$APPDIR/mx" && cmake --build --preset Debug "${flags[@]}" ) >>"$LOG" 2>&1; rc=$?
fi
secs=$(( $(date +%s) - start ))
tr -d '\r' <"$LOG" >"$LOG.tmp" && mv "$LOG.tmp" "$LOG"

# warnings in our own sources (<app>/src, also seen as mx/../src) vs generated/HAL code
srcw="$(grep -E "([/\\\\]$APP[/\\\\]|\.\./)src[/\\\\][^:]*:[0-9]+:[0-9]+: warning:" "$LOG" | sort -u)"
nsrc=$(printf '%s' "$srcw" | grep -c .); nall=$(grep -c ': warning:' "$LOG"); errs=$(grep -c ': error:' "$LOG")
echo "cmake exit=$rc  time=${secs}s  warnings(src)=$nsrc  warnings(all)=$nall  errors=$errs"
[ -n "$srcw" ] && echo "$srcw" | head -20
if [ $rc -ne 0 ] || [ ! -f "$ELF" ]; then
  grep -E ': error:|CMake Error|FAILED|undefined reference' "$LOG" | head -20
  echo "BUILD: FAIL  (see $LOG)"; exit 1
fi
if [ "$nsrc" -gt 0 ] && [ $ALLOW = 0 ]; then
  echo "BUILD: WARNINGS ($nsrc in src/) - fix them or re-run with --allow-warnings"; exit 2
fi
arm-none-eabi-objcopy -O ihex "$ELF" "${ELF%.elf}.hex" || die "objcopy failed"
size="$(arm-none-eabi-size "$ELF" | tr -d '\r' | tail -1 | awk '{print $1, $2, $3, $4, $5}')"

{
  echo "# build manifest - written by cubemx-hal-stm32f407disco/build.sh on PASS, $(date '+%Y-%m-%d %H:%M:%S')"
  echo "app        $APP  board=$APP_BOARD  template=$APP_TEMPLATE  sysclk=$SYSCLK_HZ"
  echo "tools      STM32CubeMX $CUBEMX_VERSION, $FW_PACKAGE V$FW_VERSION, gnu-tools-for-stm32 $GCC_VERSION, cmake $CMAKE_VERSION, ninja $NINJA_VERSION"
  echo "gcc        $(arm-none-eabi-gcc --version | head -1 | tr -d '\r')"
  echo "size       (text data bss dec hex) $size"
  echo "sources (sha256  file):"
  echo "$(sha256sum "$APPDIR/$APP.ioc" | cut -d' ' -f1) $APP.ioc"
  echo "artifacts (sha256  bytes  file):"
  for f in "$ELF" "${ELF%.elf}.hex"; do
    echo "$(sha256sum "$f" | cut -d' ' -f1) $(wc -c <"$f" | tr -d ' ') $(basename "$f")"
  done
} >"$OUTDIR/manifest.txt"
echo "  $size"
echo "manifest: $OUTDIR/manifest.txt"
grep -E '^[0-9a-f]{64} [0-9]+ mx.elf$' "$OUTDIR/manifest.txt"
echo "BUILD: PASS"
