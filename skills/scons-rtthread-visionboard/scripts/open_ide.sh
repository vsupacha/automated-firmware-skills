#!/usr/bin/env bash
# Stage 2d: hand an app over to the IDE - RT-Thread Studio (Eclipse-based, standalone) - so the
# developer can edit, configure (RT-Thread Settings), build, download and debug it with Studio's own
# buttons. The app is already a Studio project (new_app.sh copies the SDK project's .project /
# .cproject / .settings and renames it to the app); this script imports it into the Studio
# workspace <apps>/.rtstudio (headless Eclipse import, ~1 min, only once) and starts Studio on it.
# new_app.sh runs this after creating the app (--no-open there: import only, no window).
# Usage: open_ide.sh <app-dir> [--no-open]
# Gate: "IDE: READY <workspace>" (+ "IDE: OPENED"). Exit 10 ACTION: SETUP = Studio is missing, or it is
# already running on another workspace (import by hand) - installing/closing it is the developer's.
#
# The IDE works on the same folder as the scripts: the project files live in <app>/ (the Studio
# workspace only holds metadata, git-ignored), and Studio builds the same sources and rtconfig.h.

. "$(dirname "$0")/env.sh"
APPDIR=""; OPEN=1
for a in "$@"; do case "$a" in --no-open) OPEN=0;; --*) die "unknown option $a";; *) APPDIR="$a";; esac; done
[ -n "$APPDIR" ] && [ -f "$APPDIR/rtt-app.env" ] && [ -f "$APPDIR/.project" ] || die "usage: open_ide.sh <app-dir> [--no-open]  (an app made by new_app.sh)"
APPDIR="$(cd "$APPDIR" && pwd)"; APP="$(sed -n 's:.*<name>\(.*\)</name>.*:\1:p' "$APPDIR/.project" | head -1)"
[ -x "$STUDIO_EXE" ] && [ -x "$STUDIO_CLI" ] \
  || need_user SETUP "install RT-Thread Studio (www.rt-thread.io/studio.html) with the $BSP_NAME SDK - or build with build.sh (script path)"
mkdir -p "$STUDIO_WS"
running="$(tasklist //FI "IMAGENAME eq studio.exe" 2>/dev/null | grep -ci '^studio.exe')"
if [ ! -d "$STUDIO_WS/.metadata/.plugins/org.eclipse.core.resources/.projects/$APP" ]; then
  if [ "$running" -gt 0 ]; then
    need_user SETUP "RT-Thread Studio is running, so the app cannot be imported in the background - in Studio: File > Import > General > Existing Projects into Workspace > $(winpath "$APPDIR") (or close Studio and re-run open_ide.sh)"
  fi
  info "Importing $APP into the Studio workspace $(winpath "$STUDIO_WS") (headless, about a minute)"
  # Windows backslash paths: Eclipse reads "C:/..." as a URI scheme ("No file system ... scheme: C")
  "$STUDIO_CLI" -nosplash --launcher.suppressErrors -application org.eclipse.cdt.managedbuilder.core.headlessbuild \
    -data "$(cygpath -w "$STUDIO_WS")" -import "$(cygpath -w "$APPDIR")" >"$APPDIR/logs-studio-import.txt" 2>&1
  mkdir -p "$APPDIR/logs" && mv "$APPDIR/logs-studio-import.txt" "$APPDIR/logs/studio-import.log"
  [ -d "$STUDIO_WS/.metadata/.plugins/org.eclipse.core.resources/.projects/$APP" ] \
    || need_user SETUP "the Studio import failed (log $APPDIR/logs/studio-import.log) - import it by hand: File > Import > Existing Projects into Workspace > $(winpath "$APPDIR")"
fi
echo "IDE: READY $(winpath "$STUDIO_WS")  ($IDE_NAME, project $APP)"
if [ "$OPEN" = 1 ]; then
  if [ "$running" -gt 0 ]; then
    echo "IDE: OPENED (RT-Thread Studio is already running - switch to it; File > Switch Workspace > $(winpath "$STUDIO_WS") if it shows another workspace)"
  else
    cmd //c start "" "$(cygpath -w "$STUDIO_EXE")" -data "$(cygpath -w "$STUDIO_WS")" >/dev/null 2>&1 \
      || need_user SETUP "RT-Thread Studio did not start - open it yourself with the workspace $(winpath "$STUDIO_WS")"
    echo "IDE: OPENED in RT-Thread Studio (workspace $(winpath "$STUDIO_WS"))"
  fi
else
  echo "IDE: not opened (--no-open)"
fi
cat <<'TXT'
  In RT-Thread Studio (Project Explorer: the app):
    build         Build (hammer) - the same sources, rtconfig.h and GCC 10.2.1 as build.sh
    settings      RT-Thread Settings - components/drivers (rewrites rtconfig.h); re-run build.sh after
    flash         Download (pyOCD, DAP-Link) - NOTE: Studio downloads rtthread.hex, which contains
                  the FSP option-setting sections (OFS/security); flash.sh programs app.hex without them
    monitor       Terminal on the ART-Link COM port, 115200 - msh: info, led, btn, help
    debug         Debug (pyOCD, DAP-Link, stops at main)
    code          src/ (board -> func -> hal_entry.c)
TXT
