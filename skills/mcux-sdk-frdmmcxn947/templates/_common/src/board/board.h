/*******************************************************************************
* File Name : board.h
*
* Layer 1 - board adaptation for NXP MCX N boards (MCUXpresso SDK drivers).
* The ONLY place for GPIO ports/pins, fsl_ driver calls and BOARD_xxx #ifdefs.
* func/ and app_main.c use this API only (same API as the other skills, so
* func/ is shared unchanged).
*
* Replaces the SDK board.h (new_app.sh removes it from the exported example):
* pins and clocks come from the SDK pin_mux.c / clock_config.c.
*******************************************************************************/
#ifndef BOARD_H
#define BOARD_H

#include <stdbool.h>
#include <stdint.h>

#if defined(BOARD_FRDM_MCXN947)
    #define BOARD_NAME          "frdm-mcxn947"
#else
    #define BOARD_NAME          "generic-mcxn"
#endif

/* Upper bounds for static tables in func/ */
#define BOARD_MAX_LEDS          (4U)
#define BOARD_MAX_BUTTONS       (4U)

/* System */
void     board_init(void);               /* clocks, pins, user I/O, console, 1 ms tick */
void     board_delay_ms(uint32_t ms);
uint32_t board_millis(void);             /* ms since reset (SysTick)                   */
void     board_fatal(void);              /* stop execution on unrecoverable error      */

/* User LEDs, index 0..board_led_count()-1 (LED1 = index 0) */
uint32_t    board_led_count(void);
void        board_led_write(uint32_t idx, bool on);
bool        board_led_read(uint32_t idx);         /* read back the pin output    */
const char *board_led_name(uint32_t idx);         /* silkscreen name             */

/* User buttons, index 0..board_button_count()-1 (BTN1 = index 0) */
uint32_t    board_button_count(void);
bool        board_button_is_pressed(uint32_t idx);  /* raw, not debounced       */
const char *board_button_name(uint32_t idx);        /* silkscreen name, "SW2"   */
const char *board_button_pin(uint32_t idx);         /* e.g. "P0_23"             */

/* Console UART (routed to the MCU-Link virtual COM port). printf() also works. */
bool     board_console_getc(char *c);    /* non-blocking; true if a byte was read */
void     board_console_flush(void);

#endif /* BOARD_H */
