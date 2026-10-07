/*
 * board.h - Layer 1: board adaptation (Arduino API). The ONLY place for pin numbers, the choice
 * of the console port (Serial), pin I/O calls (pinMode, digitalWrite, digitalRead) and
 * BOARD_xxx #ifdefs. func/ and main.cpp use the Arduino API (millis, Print/Stream) + this file.
 *
 * The board id reaches C++ as -DBOARD_<ID> (build_flags, added by new_app.sh); this file maps it
 * to BOARD_ID_NAME (reported in the INFO line - tests check it).
 */
#ifndef BOARD_H
#define BOARD_H

#include <Arduino.h>

#if defined(BOARD_ESP32_S3_BOX)
    #define BOARD_ID_NAME   "esp32-s3-box"
#else
    #define BOARD_ID_NAME   "generic-esp32s3"
#endif

void        board_init();                   /* Serial + user I/O; call first in setup() */
Stream     &board_console();                /* Serial: USB CDC of the ESP32-S3 USB Serial/JTAG */

/* user I/O, 1-based like the silkscreen */
uint8_t     board_led_count();
bool        board_led_write(uint8_t n, bool on);   /* false = no such LED */
bool        board_led_read(uint8_t n);             /* pin level read back */
const char *board_led_name(uint8_t n);
uint8_t     board_button_count();
bool        board_button_read(uint8_t n);          /* raw level, true = pressed */
const char *board_button_name(uint8_t n);
uint8_t     board_button_pin(uint8_t n);

#endif /* BOARD_H */
