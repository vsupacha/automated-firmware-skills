#!/usr/bin/env bash
# Stage 2 (compose): HW driver and software-component recipes at Kconfig level - recipes/drivers/<name>.json.
# Usage: recipe.sh list
#        recipe.sh check <app-dir> <recipe> [<recipe> ...] [--show]   (read-only)
#        recipe.sh apply <app-dir> <recipe> [<recipe> ...] [--yes]    (without --yes: what it would write)
#        recipe.sh derive <recipe> [--write]   (maintainer: Kconfig values from the recipe's SDK project)
# check resolves the recipes on the app's Kconfig tree (kconfiglib, as menuconfig) and reports what
# must exist first. apply writes it (never FSP: that is the developer's FSP configurator step), backs
# up what it replaces, re-checks, then re-syncs the RT-Thread Studio project (scons --target=eclipse).
# Gates: "RECIPE: READY" (0) | "RECIPE: ACTION n" (10) | "RECIPE: FAIL" (1);
#        apply: "ACTION: APPROVE" (10, dry run) | "APPLY: DONE" (0) | "APPLY: NOT DONE" (10 FSP, 1 other).

. "$(dirname "$0")/env.sh"
CMD="$1"; APPDIR="$2"; BOARD=vision-board
case "$CMD" in check|apply) [ -f "$APPDIR/rtt-app.env" ] && BOARD="$(sed -n 's/^APP_BOARD=//p' "$APPDIR/rtt-app.env")";; esac
load_board "${BOARD:-vision-board}"
export RTT_SDK_BSP_DIR="$(winpath "$BSP_DIR")" RTT_ENV_NEW="$(winpath "$RTT_ENV_NEW")"
"$PYTHON" "$(winpath "$(dirname "$0")/recipe.py")" "$@"; rc=$?

# after a real apply: Studio's "sync scons configuration to project", as new_app.sh does
if [ "$CMD" = apply ] && [ $rc -eq 0 ] && printf '%s\n' "$@" | grep -qx -- --yes; then
  APP="$(basename "$(cd "$APPDIR" && pwd)")"
  info "Syncing the Studio project with scons (scons --target=eclipse --project-name=$APP)"
  ENV_ROOT="$(winpath "$RTT_ENV_NEW")" PKGS_ROOT="$(winpath "$RTT_ENV_NEW/packages")" \
    scons_run "$APPDIR" --target=eclipse --project-name="$APP" >"$APPDIR/logs/scons-sync.log" 2>&1 \
    || { tail -5 "$APPDIR/logs/scons-sync.log"; echo "ERROR: scons --target=eclipse failed (log $APPDIR/logs/scons-sync.log) - build.sh still works; Studio needs a sync"; exit 1; }
fi
exit $rc
