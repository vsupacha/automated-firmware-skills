/*
 * board.h - Layer 1: board adaptation. The ONLY place for pin numbers, BOARD_xxx #ifdefs and
 * core-specific calls (LED_BUILTIN, BOOTSEL). func/ and main.cpp use this API only.
 *
 * The board id reaches C as -DBOARD_<ID> (build_flags, added by new_app.sh); this file maps it to
 * BOARD_ID_NAME (reported in the INFO line - tests check it) and the user I/O counts.
 */
#ifndef BOARD_H
#define BOARD_H

#include <Arduino.h>
#include <stdbool.h>
#include <stdint.h>

#if defined(BOARD_RPI_PICO_2W)
    #define BOARD_ID_NAME       "rpi-pico-2w"
    #define BOARD_NUM_LEDS      1U      /* LED on the CYW43439 Wi-Fi module (LED_BUILTIN = 64) */
    #define BOARD_NUM_BUTTONS   1U      /* BOOTSEL, read through the core's BOOTSEL keyword */
#else
    #define BOARD_ID_NAME       "generic-rp2350"
    #define BOARD_NUM_LEDS      1U
    #define BOARD_NUM_BUTTONS   1U
#endif

void        board_init(void);                 /* console (USB CDC) + user I/O */
uint32_t    board_millis(void);
void        board_delay_ms(uint32_t ms);

/* console = USB CDC of the sketch */
Print      &board_console(void);
bool        board_console_getc(char *c);

/* user I/O, 1-based like the silkscreen */
uint32_t    board_led_count(void);
bool        board_led_write(uint32_t n, bool on);   /* false = no such LED */
uint32_t    board_button_count(void);
bool        board_button_read(uint32_t n);          /* true = pressed */
const char *board_button_name(uint32_t n);

#endif /* BOARD_H */
