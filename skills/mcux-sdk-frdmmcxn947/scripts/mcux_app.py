#!/usr/bin/env python3
"""App helper of the mcux-sdk-frdmmcxn947 skill (called by new_app.sh, open_ide.sh, build.sh).

  mcux_app.py trim <app> <board-dir> <pinmux-dir> <board-define>
      Turn a `west export_app` copy of an SDK example into a layered app: drop the example's
      main file, the SDK board.c/board.h (our src/board replaces them - the SDK board.h also defines
      BOARD_NAME), hardware_init.c / app.h and unused board configs; keep clock_config.* and
      pin_mux.*; build every .c/.h under src/; SDK debug console off (printf goes through the
      board layer's _write); warnings stay warnings (-Wno-error) so build.sh's gate decides.
  mcux_app.py ide <app> --sdk S --board B --core C --device D --gcc G --ninja N --cmake M --venv V [--force]
      Write the MCUXpresso for VS Code project files (content follows extension 26.9.44:
      Import Project keeps existing files): .vscode/mcuxpresso-tools.json (sdk-v2-freestanding),
      .vscode/settings.json, .vscode/launch.json, CMakePresets.json + mcux_include.json (per-PC
      tool paths). Existing files are kept unless --force (launch.json holds the probe choice).
  mcux_app.py sdk-registered <sdk-root>     exit 0 if VS Code's mcuxpresso.sdks lists the SDK
  mcux_app.py register-sdk <sdk-root>       add it to the VS Code user settings (asked first)
"""
import argparse
import json
import os
import re
import shutil
import sys
from pathlib import Path

DROP_FILES = ["readme.md"]
DROP_BOARD = ["board.c", "board.h", "se_board_config.h", "sdmmc_config.h", "wifi_bt_config.h"]
CONSOLE_OFF = ["utility.debug_console_lite", "utility.debug_console", "component.lpuart_adapter",
               "component.serial_manager", "component.serial_manager_uart", "utility.str",
               "utility.assert_lite", "utility.assert"]


def trim(app, board_dir, pinmux_dir, define):
    app = Path(app)
    cm = app / "CMakeLists.txt"
    text = cm.read_text(encoding="utf-8")
    m = re.search(r"mcux_add_source\(\s*SOURCES\s+([\w./-]+\.c)\s*\)", text)
    if not m:
        sys.exit(f"ERROR: {cm}: no single 'mcux_add_source(SOURCES <example>.c)' block - SDK layout changed?")
    example_c = m.group(1)
    text = text.replace(m.group(0), "\n".join([
        "# fw-skill: the layered sources - every .c/.h under src/ (board > func > app)",
        "file(GLOB_RECURSE FW_APP_SOURCES RELATIVE ${CMAKE_CURRENT_LIST_DIR} CONFIGURE_DEPENDS",
        "     src/*.c src/*.h)",
        "mcux_add_source(SOURCES ${FW_APP_SOURCES})",
        "mcux_add_include(INCLUDES src src/board src/func)"]))
    text = re.sub(r"\nmcux_add_include\(\s*INCLUDES\s+\.\s*\)", "", text)
    text = re.sub(r"project\((\w+)\s", "project(app ", text, count=1)
    cm.write_text(text, encoding="utf-8", newline="\n")

    sub = next(p for p in app.iterdir() if p.is_dir() and (p / "board_files.cmake").is_file())
    for f in DROP_FILES + [example_c]:
        (app / f).unlink(missing_ok=True)
    for f in DROP_BOARD:
        (sub / board_dir / f).unlink(missing_ok=True)
    for d in sub.iterdir():
        if d.is_dir() and d.name not in (board_dir, pinmux_dir):
            shutil.rmtree(d)                      # cm33_core0/: hardware_init.c, app.h, image .bin
    for b in sub.rglob("*.bin"):
        b.unlink()
    shutil.rmtree(app / "build_tmp", ignore_errors=True)
    (sub / "board_files.cmake").write_text("\n".join([
        "# Board files of the exported SDK example, trimmed by the mcux-sdk-frdmmcxn947 skill:",
        "# clocks + pin mux only. The SDK board.c/board.h are replaced by src/board (our board API).",
        "mcux_add_configuration(",
        f'    CC "-D{define} -Wno-error"',
        f'    CX "-D{define} -Wno-error"',
        ")",
        "",
        f"mcux_add_source(SOURCES {board_dir}/clock_config.c {board_dir}/clock_config.h)",
        f"mcux_add_include(INCLUDES {board_dir})",
        "",
        f"mcux_add_source(SOURCES {pinmux_dir}/pin_mux.c {pinmux_dir}/pin_mux.h)",
        f"mcux_add_include(INCLUDES {pinmux_dir})",
        ""]), encoding="utf-8", newline="\n")
    for conf in [app / "prj.conf", sub / "prj.conf"]:
        if not conf.is_file():
            continue
        lines = conf.read_text(encoding="utf-8").splitlines()
        out = []
        for ln in lines:
            key = re.match(r"CONFIG_MCUX_COMPONENT_([\w.]+)=y", ln)
            if key and key.group(1) in CONSOLE_OFF:
                ln = f"# CONFIG_MCUX_COMPONENT_{key.group(1)} is not set   # fw-skill: console = src/board"
            out.append(ln)
        conf.write_text("\n".join(out) + "\n", encoding="utf-8", newline="\n")
    print(f"TRIM: PASS ({example_c}, SDK board.c/board.h and debug console removed)")


def ide(a):
    app = Path(a.app)
    tools = {"version": "25.3", "toolchainPath": a.gcc, "linkedProjects": [], "trustZoneType": "none",
             "multicoreType": "none", "projectType": "sdk-v2-freestanding",
             "sdk": {"path": a.sdk, "version": "", "boardId": a.board, "deviceId": a.device, "coreId": a.core}}
    settings = {"cmake.configureOnOpen": False, "C_Cpp.errorSquiggles": "disabled",
                "C_Cpp.files.exclude": {"**/.vscode": True, "**/__repo__": True},
                "C_Cpp.exclusionPolicy": "checkFolders",
                "C_Cpp.default.configurationProvider": "ms-vscode.cmake-tools",
                "cmake.useCMakePresets": "always", "cmake.buildTask": True,
                "cmake.skipConfigureIfCachePresent": True, "cmake.sourceDirectory": "${workspaceFolder}",
                "cmake.cmakePath": a.cmake}          # per app: never a user-wide ST cube-cmake
    launch = {"configurations": [{
        "type": "mcuxpresso-debug", "name": "Debug", "request": "launch", "cwd": "${workspaceFolder}",
        "executable": {"elf": ""}, "stopAtSymbol": "main", "probeSerialNumber": "", "isAttach": False,
        "skipBuildBeforeDebug": False,
        "gdbInitCommands": ["set remotetimeout 600", "set debug-file-directory", "set non-stop off"],
        "gdbServerConfigs": {"linkserver": {}, "segger": {}, "pemicro": {}}, "showDevDebugOutput": "none"}]}
    types = ["debug", "release"]

    def cfg(n):
        return {"name": n, "displayName": n, "generator": "Ninja", "binaryDir": "${fileDir}/${presetName}",
                "toolchainFile": "$env{SdkRootDirPath}/mcuxsdk/cmake/toolchain/armgcc.cmake",
                "inherits": n + "-env",
                "cacheVariables": {"APP_DIR": {"type": "PATH", "value": "${fileDir}"}, "CMAKE_BUILD_TYPE": n,
                                   "SdkRootDirPath": "$env{SdkRootDirPath}/mcuxsdk", "CONFIG_TOOLCHAIN": "armgcc",
                                   "CMAKE_RUNTIME_OUTPUT_DIRECTORY": "$env{binaryDir}",
                                   "CMAKE_LIBRARY_OUTPUT_DIRECTORY": "$env{binaryDir}",
                                   "CMAKE_ARCHIVE_OUTPUT_DIRECTORY": "$env{binaryDir}",
                                   "WEST": "TRUE", "board": a.board, "core_id": a.core}}

    def env(n):
        return {"name": n + "-env", "displayName": n + "-env", "hidden": True,
                "environment": {"ARMGCC_DIR": a.gcc, "SdkRootDirPath": a.sdk, "MCUX_VENV_PATH": a.venv,
                                "PATH": "$env{MCUX_VENV_PATH}${pathListSep}$penv{PATH}"},
                "cacheVariables": {"CMAKE_MAKE_PROGRAM": a.ninja}}

    presets = {"version": 7, "cmakeMinimumRequired": {"major": 3},
               "configurePresets": [cfg(t) for t in types],
               "buildPresets": [{"name": t, "displayName": t, "configurePreset": t} for t in types],
               "include": ["mcux_include.json"]}
    include = {"version": 7, "cmakeMinimumRequired": {"major": 3},
               "configurePresets": [env(t) for t in types], "buildPresets": []}
    (app / ".vscode").mkdir(exist_ok=True)
    wrote, kept = [], []
    for rel, data, per_pc in ((".vscode/mcuxpresso-tools.json", tools, True), (".vscode/settings.json", settings, True),
                              (".vscode/launch.json", launch, False), ("CMakePresets.json", presets, False),
                              ("mcux_include.json", include, True)):
        f = app / rel
        if f.exists() and not a.force and not (per_pc and a.refresh):
            kept.append(rel)
            continue
        f.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8", newline="\n")
        wrote.append(rel)
    print(f"IDE FILES: written {', '.join(wrote) or '-'}; kept {', '.join(kept) or '-'}")


def settings_path():
    return Path(os.environ.get("APPDATA", str(Path.home() / "AppData/Roaming"))) / "Code/User/settings.json"


def loads_jsonc(text):
    text = re.sub(r'("(?:\\.|[^"\\])*")|//[^\n]*|/\*.*?\*/', lambda m: m.group(1) or "", text, flags=re.S)
    return json.loads(re.sub(r",(\s*[}\]])", r"\1", text) or "{}")


def same(p, q):
    return os.path.normcase(os.path.normpath(p)) == os.path.normcase(os.path.normpath(q))


def sdk_registered(root):
    try:
        sdks = loads_jsonc(settings_path().read_text(encoding="utf-8")).get("mcuxpresso.sdks", [])
    except (OSError, ValueError):
        return False
    return any(same(s.get("path", ""), root) for s in sdks if isinstance(s, dict))


def register_sdk(root):
    p = settings_path()
    if sdk_registered(root):
        print(f"SDK: REGISTERED already ({root})")
        return 0
    text = p.read_text(encoding="utf-8") if p.is_file() else "{\n}\n"
    loads_jsonc(text)                                     # refuse to touch a file we cannot read
    win = os.path.normpath(root)
    entry = {"type": "git-repositoryv2", "path": win, "basePath": os.path.join(win, "mcuxsdk"), "fromAch": False}
    body = json.dumps(entry, indent=4).replace("\n", "\n        ")
    m = re.search(r'"mcuxpresso\.sdks"\s*:\s*\[', text)
    if m:
        rest = text[m.end():]
        empty = re.match(r"\s*\]", rest) is not None
        text = text[:m.end()] + "\n        " + body + ("" if empty else ",") + rest
    else:
        i = text.rstrip().rfind("}")
        head = text[:i].rstrip()
        sep = "" if head.endswith("{") else ","
        text = head + sep + '\n    "mcuxpresso.sdks": [\n        ' + body + "\n    ]\n}\n"
    loads_jsonc(text)                                     # still valid
    shutil.copyfile(p, str(p) + ".fw-bak") if p.is_file() else None
    p.write_text(text, encoding="utf-8")
    print(f"SDK: REGISTERED {win} in {p} (backup: settings.json.fw-bak)")
    return 0


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    t = sub.add_parser("trim")
    for k in ("app", "board_dir", "pinmux_dir", "define"):
        t.add_argument(k)
    i = sub.add_parser("ide")
    i.add_argument("app")
    for k in ("sdk", "board", "core", "device", "gcc", "ninja", "cmake", "venv"):
        i.add_argument(f"--{k}", required=True)
    i.add_argument("--force", action="store_true", help="rewrite every file")
    i.add_argument("--refresh", action="store_true", help="rewrite the per-PC files only")
    r = sub.add_parser("sdk-registered")
    r.add_argument("root")
    g = sub.add_parser("register-sdk")
    g.add_argument("root")
    a = ap.parse_args()
    if a.cmd == "trim":
        trim(a.app, a.board_dir, a.pinmux_dir, a.define)
    elif a.cmd == "ide":
        ide(a)
    elif a.cmd == "sdk-registered":
        return 0 if sdk_registered(a.root) else 1
    else:
        return register_sdk(a.root)
    return 0


if __name__ == "__main__":
    sys.exit(main())
