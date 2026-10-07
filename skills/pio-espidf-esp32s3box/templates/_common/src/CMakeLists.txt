# Component of the app's own sources (layered: board/, func/, app_main.c). Written by the
# pio-espidf-esp32s3box skill; new_app.sh fills in the board define. Every .c under src/ is built.
FILE(GLOB_RECURSE app_sources ${CMAKE_CURRENT_SOURCE_DIR}/*.c)

idf_component_register(SRCS ${app_sources}
                       INCLUDE_DIRS "." "board" "func"
                       PRIV_REQUIRES esp_driver_gpio esp_driver_usb_serial_jtag esp_timer)

# our code only: board define + extra warnings (build.sh allows 0 warnings in src/)
target_compile_definitions(${COMPONENT_LIB} PRIVATE @BOARD_DEFINE@)
target_compile_options(${COMPONENT_LIB} PRIVATE -Wall -Wextra)
