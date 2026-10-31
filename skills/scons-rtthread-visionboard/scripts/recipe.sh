#!/usr/bin/env bash
# Stage 2 (compose, read-only): HW driver recipes at Kconfig level - recipes/drivers/<name>.json.
# Usage: recipe.sh list
#        recipe.sh check <app-dir> <recipe> [<recipe> ...] [--show]
#        recipe.sh derive <recipe> [--write]   (maintainer: Kconfig values from the recipe's SDK project)
# check resolves the recipes on the app's Kconfig tree (kconfiglib, as menuconfig) and reports what
# must exist first: FSP instances in ra_gen/ (FSP configurator), package folders, board/Kconfig blocks.
# Nothing is written. Gate: "RECIPE: READY" (exit 0) | "RECIPE: ACTION n" (exit 10) | "RECIPE: FAIL" (1).

. "$(dirname "$0")/env.sh"
BOARD=vision-board
[ "$1" = check ] && [ -f "$2/rtt-app.env" ] && BOARD="$(sed -n 's/^APP_BOARD=//p' "$2/rtt-app.env")"
load_board "${BOARD:-vision-board}"
export RTT_SDK_BSP_DIR="$(winpath "$BSP_DIR")" RTT_ENV_NEW="$(winpath "$RTT_ENV_NEW")"
exec "$PYTHON" "$(winpath "$(dirname "$0")/recipe.py")" "$@"
