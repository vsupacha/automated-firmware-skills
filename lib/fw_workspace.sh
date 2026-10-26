#!/usr/bin/env bash
# Apps workspace of this PC (docs/workflow.md "Apps workspace"): where new_app.sh creates apps and
# where .bench/ (this PC's probes and console ports) lives. The choice is saved per PC in
# ~/.fw-skills.env (FW_SETTINGS names another file) - never in git and never synced.
# Usage: fw_workspace.sh [show]      the workspace the scripts use now, and where it comes from
#        fw_workspace.sh set <dir>   save <dir> for this PC (created if missing)
#        fw_workspace.sh unset       remove the saved choice: back to <project>/apps
# new_app.sh stops with ACTION: CHOOSE until a workspace is saved when <project>/apps is in a synced
# folder or too long for the toolchain. Per-skill <PREFIX>_WS and new_app.sh's workspace argument
# still override this setting.
# Gate: "WORKSPACE: <dir> (<source>)"; exit 0, 1 = bad path or usage.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
. "$REPO_ROOT/lib/common.sh"

show() {
  local src
  if [ -n "$FW_WS" ]; then src="FW_WS in the environment"
  elif [ -n "$(fw_saved_ws)" ]; then src="saved for this PC in $(winpath "$FW_SETTINGS")"
  else src="default <project>/apps - nothing saved for this PC"; fi
  echo "WORKSPACE: $(winpath "$(fw_default_ws)") ($src)"
  local svc; svc="$(path_synced "$(fw_default_ws)")"
  [ -n "$svc" ] && echo "NOTE: in a $svc folder - generate/build may hit locked files; a folder outside it avoids that"
  return 0
}

case "${1:-show}" in
  show) show;;
  set)
    [ -n "$2" ] || die "usage: fw_workspace.sh set <dir>"
    why="$(path_problem "$2")"
    [ -z "$why" ] || die "workspace '$2' $why. Use a short folder with only English letters, digits, - and _ (e.g. $(fw_ws_suggest))"
    mkdir -p "$2" || die "cannot create $2"
    dir="$(winpath "$(cd "$2" && pwd)")"
    { grep -v '^FW_WS=' "$FW_SETTINGS" 2>/dev/null; echo "FW_WS=$dir"; } >"$FW_SETTINGS.tmp" \
      && mv "$FW_SETTINGS.tmp" "$FW_SETTINGS" || die "cannot write $FW_SETTINGS"
    [ -n "$FW_WS" ] && echo "NOTE: FW_WS=$FW_WS in the environment still overrides the saved choice"
    show
    echo "NOTE: board files (.bench/) are per workspace - run discover.sh <board> again before flashing"
    ;;
  unset)
    if [ -f "$FW_SETTINGS" ]; then
      grep -v '^FW_WS=' "$FW_SETTINGS" >"$FW_SETTINGS.tmp"; mv "$FW_SETTINGS.tmp" "$FW_SETTINGS"
      [ -s "$FW_SETTINGS" ] || rm -f "$FW_SETTINGS"
    fi
    show
    ;;
  -h|--help) sed -n '2,11p' "$0";;
  *) die "usage: fw_workspace.sh [show | set <dir> | unset]";;
esac
