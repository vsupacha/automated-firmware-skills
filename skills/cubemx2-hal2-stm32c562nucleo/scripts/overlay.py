#!/usr/bin/env python3
"""Hook the layered application (../src) into a freshly generated STM32CubeMX2 CMake project.

Usage: overlay.py <mx-dir> --define BOARD_<ID>

Edits exactly two generated files, at the markers STM32CubeMX2 leaves for user code (each must be
found exactly once, otherwise the generator changed and this script must be updated):
  CMakeLists.txt  sources = every .c under ../src (glob), include dirs ../src, ../src/board,
                  ../src/func, compile definition BOARD_<ID>, -Wextra for the app sources
  main.c          #include "app_main.h" and app_main() where the template says
                  "You can start your application code here"
Re-run after every generation (regen.sh does); the generated files are overwritten each time.
"""
import argparse
import re
import sys
from pathlib import Path

TAG = "cubemx2-hal2-stm32c562nucleo skill"


def replace_once(text, pattern, repl, what):
    new, n = re.subn(pattern, lambda _m: repl, text, count=0, flags=re.S)
    if n != 1:
        sys.exit(f"overlay: expected one marker for {what}, found {n}")
    return new


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("mx")
    ap.add_argument("--define", required=True)
    a = ap.parse_args()
    mx = Path(a.mx)
    cm, mc = mx / "CMakeLists.txt", mx / "main.c"
    if not cm.is_file() or not mc.is_file():
        sys.exit(f"overlay: {mx} is not a generated CMake project")

    t = cm.read_text(encoding="utf-8")
    if TAG not in t:
        t = replace_once(
            t, r"target_sources\(\$\{CMAKE_PROJECT_NAME\} PRIVATE\s*# Add additional source files here\s*\)",
            "# >>> " + TAG + ": layered application code in ../src (re-applied by regen.sh)\n"
            "file(GLOB_RECURSE APP_SOURCES CONFIGURE_DEPENDS \"${CMAKE_CURRENT_SOURCE_DIR}/../src/*.c\")\n"
            "set_source_files_properties(${APP_SOURCES} PROPERTIES COMPILE_OPTIONS \"-Wextra\")\n"
            "target_sources(${CMAKE_PROJECT_NAME} PRIVATE\n  ${APP_SOURCES}\n)",
            "target_sources")
        t = replace_once(
            t, r"target_include_directories\(\$\{CMAKE_PROJECT_NAME\} PUBLIC\s*# Add additional include directories here\s*\)",
            "target_include_directories(${CMAKE_PROJECT_NAME} PUBLIC\n"
            "  ${CMAKE_CURRENT_SOURCE_DIR}/../src\n"
            "  ${CMAKE_CURRENT_SOURCE_DIR}/../src/board\n"
            "  ${CMAKE_CURRENT_SOURCE_DIR}/../src/func\n)",
            "target_include_directories")
        t = replace_once(
            t, r"target_compile_definitions\(\$\{CMAKE_PROJECT_NAME\} PUBLIC\s*# Add additional defined symbols here\s*\)",
            "target_compile_definitions(${CMAKE_PROJECT_NAME} PUBLIC\n  " + a.define + "\n)\n"
            "# <<< " + TAG,
            "target_compile_definitions")
        cm.write_text(t, encoding="utf-8", newline="\n")

    t = mc.read_text(encoding="utf-8")
    if TAG not in t:
        t = replace_once(t, r'#include "main\.h"', '#include "main.h"\n#include "app_main.h"   /* ' + TAG + " */",
                         "#include main.h")
        t = replace_once(
            t, r"/\*\s*\*\s*You can start your application code here\s*\*/\s*while \(1\) \{\}",
            "/* " + TAG + ": the application lives in src/ (app_main.c); this call is\n"
            "       re-inserted by regen.sh after every generation */\n"
            "    app_main();\n"
            "    while (1) {}",
            "application code marker in main.c")
        mc.write_text(t, encoding="utf-8", newline="\n")
    print(f"overlay: {cm} and {mc} hooked to ../src (define {a.define})")


if __name__ == "__main__":
    main()
