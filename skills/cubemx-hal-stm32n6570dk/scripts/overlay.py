#!/usr/bin/env python3
"""Hook the layered app (<app>/src) into the STM32CubeMX-generated project (<app>/mx).

Usage: python overlay.py <mx-dir> <BOARD_DEFINE>

Idempotent (re-run after every regeneration). Edits only USER CODE sections of
mx/FSBL/Src/main.c and the user sections of mx/FSBL/CMakeLists.txt (a file CubeMX generates once):
  main.c         #include "board.h" + "app_main.h"; board_early_init() before SystemClock_Config()
                 (USER CODE BEGIN Init); app_main() after the MX_..._Init() calls (USER CODE BEGIN 2)
  CMakeLists.txt every ../../src/**/*.c, include paths src, src/board, src/func, -D<BOARD_DEFINE>,
                 -Wall -Wextra for those sources only
Exit 0 = done, 1 = a marker was not found (a new CubeMX changed the generated files - update this
script, never edit mx/ by hand).
"""
import re
import sys
from pathlib import Path

TAG = "fw-skill overlay"


def fail(msg):
    print(f"OVERLAY: FAIL - {msg}")
    sys.exit(1)


def insert_after(text, marker, block, what):
    if block.strip() in text:
        return text
    if marker not in text:
        fail(f"marker '{marker}' not found ({what})")
    return text.replace(marker, marker + "\n" + block, 1)


def main(argv):
    if len(argv) != 2:
        print(__doc__.strip())
        return 1
    mx, define = Path(argv[0]), argv[1]
    main_c = mx / "FSBL" / "Src" / "main.c"
    cml = mx / "FSBL" / "CMakeLists.txt"
    for f in (main_c, cml):
        if not f.is_file():
            fail(f"{f} missing - generation did not produce the FSBL project")

    raw = main_c.read_bytes().decode("utf-8")
    nl = "\r\n" if "\r\n" in raw else "\n"
    s = raw.replace("\r\n", "\n")
    s = insert_after(s, "/* USER CODE BEGIN Includes */",
                     f'#include "board.h"     /* {TAG} */\n#include "app_main.h"  /* {TAG} */', "main.c includes")
    s = insert_after(s, "/* USER CODE BEGIN Init */",
                     f"  board_early_init();   /* {TAG}: board supply before SystemClock_Config() */", "main.c init")
    s = insert_after(s, "/* USER CODE BEGIN 2 */",
                     f"  app_main();           /* {TAG}: layered app, does not return */", "main.c 2")
    main_c.write_bytes(s.replace("\n", nl).encode("utf-8"))

    raw = cml.read_bytes().decode("utf-8")
    nl = "\r\n" if "\r\n" in raw else "\n"
    s = raw.replace("\r\n", "\n")
    glob = (f"# {TAG}: the layered app sources (<app>/src), warnings on for them only\n"
            "file(GLOB_RECURSE APP_SOURCES CONFIGURE_DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/../../src/*.c)\n"
            "set_source_files_properties(${APP_SOURCES} PROPERTIES COMPILE_OPTIONS \"-Wall;-Wextra\")")
    if glob not in s:
        m = re.search(r"^# Add sources to executable", s, re.M)
        if not m:
            fail("'# Add sources to executable' not found (CMakeLists.txt)")
        s = s[:m.start()] + glob + "\n\n" + s[m.start():]
    s = insert_after(s, "    # Add user defined symbols", f"    {define}  # {TAG}", "CMakeLists symbols")
    s = insert_after(s, "    # Add user defined include paths",
                     f"    ${{CMAKE_CURRENT_SOURCE_DIR}}/../../src  # {TAG}\n"
                     "    ${CMAKE_CURRENT_SOURCE_DIR}/../../src/board\n"
                     "    ${CMAKE_CURRENT_SOURCE_DIR}/../../src/func", "CMakeLists includes")
    s = insert_after(s, "    # Add user sources here", f"    ${{APP_SOURCES}}  # {TAG}", "CMakeLists sources")
    cml.write_bytes(s.replace("\n", nl).encode("utf-8"))
    print("OVERLAY: done (main.c hooks, FSBL/CMakeLists.txt sources/includes/define)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
