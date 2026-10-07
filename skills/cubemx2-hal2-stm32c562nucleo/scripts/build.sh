#!/usr/bin/env bash
# Stage 4: build an app's generated CMake project with the pinned GCC/CMake/Ninja.
# Usage: build.sh <app-dir> [--clean] [--allow-warnings]
# Gate: "BUILD: PASS" = cmake configure + build exit 0, ELF present, 0 warnings in src/.
# Exit 0 PASS, 1 FAIL, 2 warnings in src/. Writes .hex next to the ELF and
# mx/build/<preset>/manifest.txt (tools, packs, .ioc2 + artifact sha256) only on PASS -
# flash.sh requires it. Run regen.sh first after changing the .ioc2.

. "$(dirname "$0")/env.sh"
APPDIR=""; CLEAN=0; ALLOW=0
for a in "$@"; do
  case "$a" in --clean) CLEAN=1;; --allow-warnings) ALLOW=1;; --*) die "unknown option $a";; *) APPDIR="$a";; esac
done
[ -n "$APPDIR" ] && [ -f "$APPDIR/cubemx-app.env" ] || die "usage: build.sh <app-dir> [--clean] [--allow-warnings]  (an app made by new_app.sh)"
APPDIR="$(cd "$APPDIR" && pwd)"
# shellcheck disable=SC1091
. "$APPDIR/cubemx-app.env"
load_board "$APP_BOARD"
require_safe_path "$APPDIR" "app" 110
[ -f "$APPDIR/mx/CMakeLists.txt" ] || die "no generated project in $APPDIR/mx - run regen.sh"
grep -q "cubemx2-hal2-stm32c562nucleo skill" "$APPDIR/mx/CMakeLists.txt" || die "mx/ is not hooked to src/ (regenerated outside the skill?) - run regen.sh"
[ "$(sha256sum "$APPDIR/$APP_IOC2" | cut -d' ' -f1)" != "" ] || die "missing $APP_IOC2"
if [ "$APPDIR/$APP_IOC2" -nt "$APPDIR/mx/CMakeLists.txt" ]; then
  echo "WARN: $APP_IOC2 is newer than mx/ - run regen.sh if the hardware configuration changed"
fi
export PATH="$GCC_BIN:$CMAKE_BIN:$NINJA_BIN:$PATH"
mkdir -p "$APPDIR/logs"; LOG="$APPDIR/logs/build-$(ts).log"
OUTDIR="$APPDIR/mx/build/$APP_PRESET"; ELF="$OUTDIR/$APP_SW_PROJECT.elf"

info "cmake --preset $APP_PRESET  (log $LOG)"
start=$(date +%s)
( cd "$APPDIR/mx" && cmake --preset "$APP_PRESET" ) >"$LOG" 2>&1; rc=$?
if [ $rc -eq 0 ]; then
  flags=(); [ $CLEAN = 1 ] && flags=(--clean-first)
  ( cd "$APPDIR/mx" && cmake --build --preset "$APP_PRESET" "${flags[@]}" ) >>"$LOG" 2>&1; rc=$?
fi
secs=$(( $(date +%s) - start ))
tr -d '\r' <"$LOG" >"$LOG.tmp" && mv "$LOG.tmp" "$LOG"

# warnings in our own sources (../src) vs generated/vendor code
srcw="$(grep -E '(\.\./src/|[/\\]src[/\\](board|func)[/\\]|[/\\]src[/\\]app_main\.c).*: warning:' "$LOG" | sort -u)"
nsrc=$(printf '%s' "$srcw" | grep -c .); nall=$(grep -c ': warning:' "$LOG"); errs=$(grep -c ': error:' "$LOG")
echo "cmake exit=$rc  time=${secs}s  warnings(src)=$nsrc  warnings(all)=$nall  errors=$errs"
[ -n "$srcw" ] && echo "$srcw" | head -20
if [ $rc -ne 0 ] || [ ! -f "$ELF" ]; then
  grep -E ': error:|CMake Error|FAILED' "$LOG" | head -20
  echo "BUILD: FAIL  (see $LOG)"; exit 1
fi
if [ "$nsrc" -gt 0 ] && [ $ALLOW = 0 ]; then
  echo "BUILD: WARNINGS ($nsrc in src/) - fix them or re-run with --allow-warnings"; exit 2
fi
arm-none-eabi-objcopy -O ihex "$ELF" "${ELF%.elf}.hex" || die "objcopy failed"
size="$(arm-none-eabi-size "$ELF" | tr -d '\r' | tail -1 | awk '{print $1, $2, $3, $4, $5}')"

{
  echo "# build manifest - written by cubemx2-hal2-stm32c562nucleo/build.sh on PASS, $(date '+%Y-%m-%d %H:%M:%S')"
  echo "app        $(basename "$APPDIR")  board=$APP_BOARD  template=$APP_TEMPLATE  preset=$APP_PRESET"
  echo "tools      STM32CubeMX2 $MX_VERSION, gnu-tools-for-stm32 $GCC_VERSION, cmake $CMAKE_VERSION, ninja $NINJA_VERSION"
  echo "gcc        $(arm-none-eabi-gcc --version | head -1 | tr -d '\r')"
  echo "packs (as linked by the generated project):"
  grep -o 'STMicroelectronics_[A-Za-z0-9_]*_[0-9]*_[0-9]*_[0-9]*' "$APPDIR/mx/cmake/components.cmake" 2>/dev/null | sort -u | sed 's/^/  /'
  echo "size       (text data bss dec hex) $size"
  echo "sources (sha256  file):"
  echo "$(sha256sum "$APPDIR/$APP_IOC2" | cut -d' ' -f1) $APP_IOC2"
  echo "artifacts (sha256  bytes  file):"
  for f in "$ELF" "${ELF%.elf}.hex"; do
    echo "$(sha256sum "$f" | cut -d' ' -f1) $(wc -c <"$f" | tr -d ' ') $(basename "$f")"
  done
} >"$OUTDIR/manifest.txt"
echo "  $size"
echo "manifest: $OUTDIR/manifest.txt"
grep " $APP_SW_PROJECT.elf\$" "$OUTDIR/manifest.txt"
echo "BUILD: PASS"
