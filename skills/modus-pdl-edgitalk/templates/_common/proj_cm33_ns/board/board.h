/*******************************************************************************
* File Name : board.h
*
* Layer 1 - BSP adaptation (board layer).
* The ONLY layer that may use CYBSP_* aliases, PDL (Cy_*) pin/SCB calls or
* board-specific #ifdefs. Everything above (func/, main.c) uses this API only,
* so porting to another PSOC Edge E84 board touches this folder (plus the BSP).
*
* Board selection: the build passes -DBOARD_<ID> (set by new_app.sh from the
* board profile): BOARD_EDGI_TALK.
* Names are the SILKSCREEN names users see, not the BSP macro names.
*******************************************************************************/
#ifndef BOARD_H
#define BOARD_H

#include <stdbool.h>
#include <stdint.h>

#if defined(BOARD_EDGI_TALK)
    #define BOARD_NAME          "edgi-talk"
    /* Only SW2 (P8[3]) is populated. The BSP still defines CYBSP_USER_BTN2
     * (SW4, P8[7]) inherited from the EPC2 eval kit - it is not a button here. */
    #define BOARD_BSP_BUTTONS   (1U)
    #define BOARD_BTN_NAMES     "SW2"
    #define BOARD_LED_NAMES     "LED1", "LED2", "LED3"

#else
    #define BOARD_NAME          "generic-pse84"
#endif

/* BOARD_BSP_BUTTONS caps how many CYBSP_USER_BTNx aliases are real buttons
 * (a BSP may declare I/O the board does not populate). Default: all of them. */
#ifndef BOARD_BSP_BUTTONS
    #define BOARD_BSP_BUTTONS   (2U)
#endif

/* Upper bounds for static tables in func/ */
#define BOARD_MAX_LEDS          (5U)
#define BOARD_MAX_BUTTONS       (4U)

/* System */
void     board_init(void);               /* cybsp_init, IRQs, console UART      */
void     board_start_cm55(void);         /* boot the CM55 core (boot chain)     */
void     board_delay_ms(uint32_t ms);
uint32_t board_millis(void);             /* ms since board_init (SysTick 1 kHz) */
void     board_fatal(void);              /* stop execution on unrecoverable err */

/* User LEDs, index 0..board_led_count()-1 (LED1 = index 0) */
uint32_t    board_led_count(void);
void        board_led_write(uint32_t idx, bool on);
bool        board_led_read(uint32_t idx);         /* read back the pin output   */
const char *board_led_name(uint32_t idx);         /* silkscreen / user name     */

/* User buttons, index 0..board_button_count()-1 (BTN1 = index 0) */
uint32_t    board_button_count(void);
bool        board_button_is_pressed(uint32_t idx);  /* raw, not debounced      */
const char *board_button_name(uint32_t idx);        /* silkscreen name, "SW2"  */
const char *board_button_pin(uint32_t idx);         /* e.g. "P17.5"            */
/* Diagnostics: "drive=<dm> hsiom=<n> in=<0|1> out=<0|1>" of the button pin */
const char *board_button_diag(uint32_t idx);

/* Console UART (debug UART routed to the probe's USB-UART). printf() also works. */
bool     board_console_getc(char *c);    /* non-blocking; true if a byte read   */
void     board_console_flush(void);      /* wait until TX FIFO is empty         */

#endif /* BOARD_H */
