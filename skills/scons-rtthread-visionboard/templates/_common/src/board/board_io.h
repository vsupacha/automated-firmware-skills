/*
 * board_io.h - Layer 1: board adaptation (RT-Thread pin device). The ONLY place for pin numbers
 * (BSP_IO_PORT_xx_PIN_yy), rt_pin_* calls and BOARD_xxx #ifdefs. func/ and hal_entry.c use the
 * RT-Thread kernel API (rtthread.h: ticks, threads, rt_kprintf) + this file.
 *
 * Named board_io.h, not board.h: the BSP's own board/board.h is on the include path.
 * The board id reaches C as -DBOARD_<ID> (rtconfig.py CFLAGS, added by new_app.sh); this file maps
 * it to BOARD_ID_NAME (reported in the INFO line - tests check it).
 */
#ifndef BOARD_IO_H
#define BOARD_IO_H

#include <rtthread.h>
#include <stdbool.h>
#include <stdint.h>

#if defined(BOARD_VISION_BOARD)
    #define BOARD_ID_NAME   "vision-board"
#else
    #define BOARD_ID_NAME   "generic-ra8d1"
#endif

void        board_io_init(void);                /* LED outputs (off) + button inputs */

/* user I/O, 1-based like the silkscreen */
uint8_t     board_led_count(void);
bool        board_led_write(uint8_t n, bool on);   /* false = no such LED */
bool        board_led_read(uint8_t n);             /* pin level read back */
const char *board_led_name(uint8_t n);
uint8_t     board_button_count(void);
bool        board_button_read(uint8_t n);          /* raw level, true = pressed */
const char *board_button_name(uint8_t n);
const char *board_button_pin(uint8_t n);           /* port pin name, e.g. "P907" */

#endif /* BOARD_IO_H */
