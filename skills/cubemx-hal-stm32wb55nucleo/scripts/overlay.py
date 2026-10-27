#!/usr/bin/env python3
"""Hook the layered app (<app>/src) into the STM32CubeMX-generated project (<app>/mx).

Usage: python overlay.py <mx-dir> <BOARD_DEFINE>

Idempotent (re-run after every regeneration). Edits only USER CODE sections of mx/Src/main.c and
the user sections of mx/CMakeLists.txt (a file CubeMX generates once):
  main.c         #include "board.h" + "app_main.h"; app_main() after the MX_..._Init() calls
                 (USER CODE BEGIN 2)
  CMakeLists.txt every ../src/**/*.c, include paths src, src/board, src/func, -D<BOARD_DEFINE>,
                 -Wall -Wextra for those sources only; the FW_UNIT switch (unit_test.sh: test/*.c
                 replace src/app_main.c, Unity, float printf, libm); CMSIS-DSP BasicMath + Support
                 from mx/Drivers/CMSIS/DSP for func/ modules
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


def edit(path, fn):
    raw = path.read_bytes().decode("utf-8")
    nl = "\r\n" if "\r\n" in raw else "\n"
    path.write_bytes(fn(raw.replace("\r\n", "\n")).replace("\n", nl).encode("utf-8"))


def main(argv):
    if len(argv) != 2:
        print(__doc__.strip())
        return 1
    mx, define = Path(argv[0]), argv[1]
    main_c, cml = mx / "Src" / "main.c", mx / "CMakeLists.txt"
    for f in (main_c, cml):
        if not f.is_file():
            fail(f"{f} missing - generation did not produce the project")

    def main_hooks(s):
        s = insert_after(s, "/* USER CODE BEGIN Includes */",
                         f'#include "board.h"     /* {TAG} */\n#include "app_main.h"  /* {TAG} */', "main.c includes")
        return insert_after(s, "/* USER CODE BEGIN 2 */",
                            f"  app_main();           /* {TAG}: layered app, does not return */", "main.c 2")

    def cmake_hooks(s):
        glob = (f"# {TAG}: the layered app sources (<app>/src), warnings on for them only\n"
                "file(GLOB_RECURSE APP_SOURCES CONFIGURE_DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/../src/*.c)\n"
                "set_source_files_properties(${APP_SOURCES} PROPERTIES COMPILE_OPTIONS \"-Wall;-Wextra\")")
        if glob not in s:
            m = re.search(r"^# Add sources to executable", s, re.M)
            if not m:
                fail("'# Add sources to executable' not found (CMakeLists.txt)")
            s = s[:m.start()] + glob + "\n\n" + s[m.start():]
        unit = (f"# {TAG}: FW_UNIT=ON builds the on-target unit-test image (unit_test.sh): <app>/test\n"
                "# (test runner + suites + Unity) replaces src/app_main.c; the rest of src/ stays\n"
                "option(FW_UNIT \"on-target unit-test image\" OFF)\n"
                "if(FW_UNIT)\n"
                "    list(FILTER APP_SOURCES EXCLUDE REGEX \"/src/app_main\\\\.c$\")\n"
                "    file(GLOB UNIT_SOURCES CONFIGURE_DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/../test/*.c)\n"
                "    set_source_files_properties(${UNIT_SOURCES} PROPERTIES COMPILE_OPTIONS \"-Wall;-Wextra\")\n"
                "    list(APPEND APP_SOURCES ${UNIT_SOURCES} ${CMAKE_CURRENT_SOURCE_DIR}/../test/unity/unity.c)\n"
                "    target_include_directories(${CMAKE_PROJECT_NAME} PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/../test/unity)\n"
                "    target_link_options(${CMAKE_PROJECT_NAME} PRIVATE -u _printf_float)  # suites print floats\n"
                "    target_link_libraries(${CMAKE_PROJECT_NAME} m)\n"
                "endif()")
        dsp = (f"# {TAG}: CMSIS-DSP (Arm, Apache-2.0; the copy CubeMX puts in mx/Drivers) for func/ modules\n"
               "# such as fxscale - BasicMath + Support compiled from source (the copied prebuilt lib is\n"
               "# soft-float only); --gc-sections drops what no module calls\n"
               "set(FW_DSP ${CMAKE_CURRENT_SOURCE_DIR}/Drivers/CMSIS/DSP)\n"
               "if(EXISTS ${FW_DSP}/Source/BasicMathFunctions/BasicMathFunctions.c)\n"
               "    target_sources(${CMAKE_PROJECT_NAME} PRIVATE\n"
               "        ${FW_DSP}/Source/BasicMathFunctions/BasicMathFunctions.c\n"
               "        ${FW_DSP}/Source/SupportFunctions/SupportFunctions.c)\n"
               "    target_include_directories(${CMAKE_PROJECT_NAME} PRIVATE ${FW_DSP}/Include)\n"
               "    target_compile_definitions(${CMAKE_PROJECT_NAME} PRIVATE ARM_MATH_CM4)\n"
               "endif()")
        old_unit_inc = "    target_include_directories(${CMAKE_PROJECT_NAME} PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/../test/unity)\n"
        if "option(FW_UNIT" not in s:
            m = re.search(r"^# Add sources to executable", s, re.M)
            s = s[:m.start()] + unit + "\n\n" + s[m.start():]
        elif "_printf_float" not in s:           # an app from before the float / libm lines
            s = s.replace(old_unit_inc, old_unit_inc
                          + "    target_link_options(${CMAKE_PROJECT_NAME} PRIVATE -u _printf_float)  # suites print floats\n"
                          + "    target_link_libraries(${CMAKE_PROJECT_NAME} m)\n", 1)
        if "set(FW_DSP" not in s:
            m = re.search(r"^# Add sources to executable", s, re.M)
            s = s[:m.start()] + dsp + "\n\n" + s[m.start():]
        s = insert_after(s, "    # Add user defined symbols", f"    {define}  # {TAG}", "CMakeLists symbols")
        s = insert_after(s, "    # Add user defined include paths",
                         f"    ${{CMAKE_CURRENT_SOURCE_DIR}}/../src  # {TAG}\n"
                         "    ${CMAKE_CURRENT_SOURCE_DIR}/../src/board\n"
                         "    ${CMAKE_CURRENT_SOURCE_DIR}/../src/func", "CMakeLists includes")
        return insert_after(s, "    # Add user sources here", f"    ${{APP_SOURCES}}  # {TAG}", "CMakeLists sources")

    edit(main_c, main_hooks)
    edit(cml, cmake_hooks)
    print("OVERLAY: done (main.c hooks, CMakeLists.txt sources/includes/define)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
