/*******************************************************************************
* File Name : board.h
*
* Layer 1 - board adaptation for STM32C5 boards (HAL2 + LL from STM32CubeMX2).
* The ONLY place for GPIO ports/pins, HAL/LL calls and BOARD_xxx #ifdefs.
* func/ and app_main.c use this API only (same API as the modus-pdl-edgitalk skill,
* so func/ is shared unchanged).
*
* The board id reaches C as -DBOARD_<ID> (added to the generated CMakeLists by
* regen.sh); this file maps it to BOARD_NAME and the user I/O.
*******************************************************************************/
#ifndef BOARD_H
#define BOARD_H

#include <stdbool.h>
#include <stdint.h>

#if defined(BOARD_NUCLEO_C562RE)
    #define BOARD_NAME          "nucleo-c562re"
#else
    #define BOARD_NAME          "generic-stm32c5"
#endif

/* Upper bounds for static tables in func/ */
#define BOARD_MAX_LEDS          (4U)
#define BOARD_MAX_BUTTONS       (4U)

/* System */
void     board_init(void);               /* user I/O + console; after mx_system_init() */
void     board_delay_ms(uint32_t ms);
uint32_t board_millis(void);             /* ms since reset (HAL tick)                  */
void     board_fatal(void);              /* stop execution on unrecoverable error      */

/* User LEDs, index 0..board_led_count()-1 (LED1 = index 0) */
uint32_t    board_led_count(void);
void        board_led_write(uint32_t idx, bool on);
bool        board_led_read(uint32_t idx);         /* read back the pin output    */
const char *board_led_name(uint32_t idx);         /* silkscreen name, "LD1"      */

/* User buttons, index 0..board_button_count()-1 (BTN1 = index 0) */
uint32_t    board_button_count(void);
bool        board_button_is_pressed(uint32_t idx);  /* raw, not debounced       */
const char *board_button_name(uint32_t idx);        /* silkscreen name, "B1"    */
const char *board_button_pin(uint32_t idx);         /* e.g. "PC13"              */

/* Console UART (routed to the ST-LINK virtual COM port). printf() also works. */
bool     board_console_getc(char *c);    /* non-blocking; true if a byte was read */
void     board_console_flush(void);

#endif /* BOARD_H */
