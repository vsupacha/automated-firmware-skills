#!/usr/bin/env bash
# Stage 2b: create an RT-Thread app for a board from the SDK's example project + a layered
# template. Needs no hardware and no network (everything comes from RT-Thread Studio's SDK).
# Usage: new_app.sh <board-id> <app-name> [<workspace-dir>] [template] [--no-open]
#   --no-open      stage 2d (open_ide.sh: Studio import) without opening RT-Thread Studio
#   workspace-dir  where apps live (default: $RTT_WS, "" = default)
#   template       a folder under templates/ (default uart-btn-led); see help.sh for the list
# Writes <workspace>/<app>/ - a standalone RT-Thread Studio + scons project:
#   the SDK project BSP_PROJECT (board/, ra/ ra_gen/ ra_cfg/ = FSP, rtconfig.h/.py, SConstruct,
#   .project/.cproject/.settings = Studio project renamed to <app>), rt-thread/ (without docs and
#   examples), libraries/HAL_Drivers + libraries/Kconfig; src/ = templates/_common/src (board/,
#   func/, SConscript) + the template's src (hal_entry.c); tests/; rtt-app.env (record).
#   -DBOARD_<ID> goes into rtconfig.py (scons) and .cproject (Studio's managed build).

. "$(dirname "$0")/env.sh"
OPEN=1; ARGS=()
for a in "$@"; do case "$a" in --no-open) OPEN=0;; --*) die "unknown option $a";; *) ARGS+=("$a");; esac; done
set -- "${ARGS[@]}"
[ $# -ge 2 ] || die "usage: new_app.sh <board-id> <app-name> [<workspace-dir>] [template] [--no-open]"
load_board "$1"; APP="$2"; WS="${3:-$RTT_WS}"; TPL="${4:-uart-btn-led}"
require_vars BOARD_DEFINE BSP_PROJECT
case "$APP" in *[!A-Za-z0-9_-]*|"") die "app name '$APP': use letters, digits, - and _";; esac
[ -d "$SKILL_DIR/templates/$TPL" ] && [ "${TPL#_}" = "$TPL" ] \
  || die "no template '$TPL' (have: $(ls "$SKILL_DIR/templates" | grep -v '^_' | tr '\n' ' '))"
SRC="$BSP_DIR/projects/$BSP_PROJECT"
[ -d "$SRC" ] && [ -d "$BSP_DIR/rt-thread" ] && [ -d "$BSP_DIR/libraries/HAL_Drivers" ] \
  || need_user SETUP "SDK $BSP_NAME $BSP_VERSION not found ($SRC) - install it in RT-Thread Studio (SDK Manager > Board_Support_Packages > $BSP_VENDOR > $BSP_NAME $BSP_VERSION), then re-run"

mkdir -p "$WS" || die "cannot create $WS"; WS="$(cd "$WS" && pwd)"; APPDIR="$WS/$APP"
require_safe_path "$APPDIR" "app" 100
[ -e "$APPDIR" ] && die "$APPDIR already exists - pick another name (or delete it after asking the user)"
write_workspace_gitignore "$WS"
svc="$(path_synced "$WS")"; [ -n "$svc" ] && echo "WARN: $WS is in a $svc folder (about 38 MB per app) - pause sync if a build fails on locked files"

info "Creating $APPDIR (board $BOARD_ID, SDK $BSP_NAME $BSP_VERSION/$BSP_PROJECT, template $TPL)"
mkdir -p "$APPDIR" "$APPDIR/libraries"
# the SDK project without its pictures and Keil files; rt-thread without docs/examples (tar: fast)
( cd "$SRC" && tar cf - --exclude=./docs --exclude='./*.uvprojx' --exclude='./*.uvoptx' --exclude='./mklinks.*' . ) \
  | ( cd "$APPDIR" && tar xf - ) || die "copy of $SRC failed"
( cd "$BSP_DIR" && tar cf - --exclude=rt-thread/documentation --exclude=rt-thread/examples rt-thread ) \
  | ( cd "$APPDIR" && tar xf - ) || die "copy of rt-thread failed"
cp -r "$BSP_DIR/libraries/HAL_Drivers" "$APPDIR/libraries/" && cp "$BSP_DIR/libraries/Kconfig" "$APPDIR/libraries/" \
  || die "copy of libraries failed"

# templates/_common (board + func layers) first, then the app template on top
rm -f "$APPDIR/src/hal_entry.c"
for T in "$SKILL_DIR/templates/_common" "$SKILL_DIR/templates/$TPL"; do
  for part in src tests; do
    [ -d "$T/$part" ] && { mkdir -p "$APPDIR/$part"; cp -r "$T/$part/." "$APPDIR/$part/"; }
  done
done
[ -f "$APPDIR/src/hal_entry.c" ] || die "template $TPL has no src/hal_entry.c"

# rtconfig.py: GCC by default (RT-Thread Studio sets RTT_CC too) + the board define;
# Studio project: renamed to the app, the board define in the managed-build symbols
"$PYTHON" - "$(winpath "$APPDIR")" "$APP" "$BSP_PROJECT" "$BOARD_DEFINE" "$GCC_VERSION" "$(cygpath -w "$GCC_BIN")" <<'EOF' || die "patching the project files failed"
import os, re, sys
app_dir, app, old, define, gcc, gcc_bin = sys.argv[1:7]
def patch(rel, fn):
    p = os.path.join(app_dir, rel)
    s = open(p, encoding="utf-8").read()
    t = fn(s)
    if t == s:
        sys.exit(f"no change in {rel}")
    open(p, "w", encoding="utf-8", newline="").write(t)
patch("rtconfig.py", lambda s: s.replace("CROSS_TOOL='keil'", "CROSS_TOOL='gcc'", 1)
                                 .replace("CFLAGS = DEVICE + ' -Dgcc'", f"CFLAGS = DEVICE + ' -Dgcc -D{define}'", 1))
patch(".project", lambda s: s.replace(f"<name>{old}</name>", f"<name>{app}</name>", 1))
patch(os.path.join(".settings", "projcfg.ini"), lambda s: s.replace(f"project_name={old}", f"project_name={app}"))
sym = (r'\1 valueType="definedSymbols">'
       f'\n                  <listOptionValue builtIn="false" value="{define}" />\n                </option>')
patch(".cproject", lambda s: re.sub(r'(<option id="ilg\.gnuarmeclipse\.managedbuild\.cross\.option\.(?:c|cpp)\.compiler\.defs\.\d+"[^>]*?)\s*/>', sym, s))
# Studio's toolchain = the profile's GCC (the SDK project says 10.2.1, which fails in Studio's build)
patch(os.path.join(".settings", "ilg.gnumcueclipse.managedbuild.cross.arm.prefs"),
      lambda s: re.sub(r"(GNU_Tools_for_ARM_Embedded_Processors/)[^/]+(/bin)", r"\g<1>" + gcc + r"\g<2>", s))
patch(os.path.join(".settings", "local_temp_storage.prefs"),
      lambda s: re.sub(r"(?m)^temp\.toolchain\.exec\.path=.*$",
                       lambda m: "temp.toolchain.exec.path=" + gcc_bin[:-4].replace("\\", "\\\\").replace(":", "\\:") + "/bin", s))
# RT-Thread 5.0.2's eclipse target names the project "project" when Studio regenerates it (scons
# --target=eclipse without --project-name): default it to the app name in the app's copy
patch(os.path.join("rt-thread", "tools", "options.py"),
      lambda s: s.replace("""                      default = "project",""", f"""                      default = "{app}",""", 1))
for f in os.listdir(os.path.join(app_dir, ".settings")):
    if f.startswith(old) and f.endswith(".rttlaunch"):
        os.replace(os.path.join(app_dir, ".settings", f), os.path.join(app_dir, ".settings", app + f[len(old):]))
EOF
grep -q -- "-D$BOARD_DEFINE'" "$APPDIR/rtconfig.py" || die "rtconfig.py: board define not set"

# Studio's "sync scons configuration to project", done before the first open: scons
# --target=eclipse (as Studio's sconscript_update.bat: env-new scons, RTT_CC=gcc, the profile's
# GCC) regenerates .cproject from the SConscripts (include paths such as src/, excluded files) and
# writes rtconfig_preinc.h + makefile.targets - Studio then builds without asking for a sync.
info "Syncing the Studio project with scons (scons --target=eclipse --project-name=$APP)"
ENV_ROOT="$(winpath "$RTT_ENV_NEW")" PKGS_ROOT="$(winpath "$RTT_ENV_NEW/packages")" \
  scons_run "$APPDIR" --target=eclipse --project-name="$APP" >"$APPDIR/scons-sync.log" 2>&1 \
  || { tail -5 "$APPDIR/scons-sync.log"; die "scons --target=eclipse failed (log $APPDIR/scons-sync.log)"; }
mkdir -p "$APPDIR/logs" && mv "$APPDIR/scons-sync.log" "$APPDIR/logs/scons-sync.log"
[ -f "$APPDIR/rtconfig_preinc.h" ] && grep -q '//src}' "$APPDIR/.cproject" && grep -q "<name>$APP</name>" "$APPDIR/.project" \
  && grep -q "/$GCC_VERSION/bin" "$APPDIR/.settings/ilg.gnumcueclipse.managedbuild.cross.arm.prefs" \
  || die "Studio project not in sync after scons --target=eclipse (log $APPDIR/logs/scons-sync.log)"

cat >"$APPDIR/rtt-app.env" <<EOF
# written by scons-rtthread-visionboard/new_app.sh $(date '+%Y-%m-%d %H:%M')
APP_BOARD=$BOARD_ID
APP_BOARD_DEFINE=$BOARD_DEFINE
APP_TEMPLATE=$TPL
APP_SDK=$BSP_VENDOR/$BSP_NAME/$BSP_VERSION/$BSP_PROJECT
APP_GCC=$GCC_VERSION
EOF
info "Created $APPDIR  (board $BOARD_ID, template $TPL, $(du -sh "$APPDIR" | cut -f1))"
info "Next: build.sh $APPDIR"
fw_new_app_ide "$APPDIR" $OPEN     # stage 2d: hand over to RT-Thread Studio
