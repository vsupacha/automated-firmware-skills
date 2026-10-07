/*******************************************************************************
* File Name : board.h
*
* Layer 1 - board adaptation for ESP32-S3 boards (ESP-IDF drivers).
* The ONLY place for GPIO numbers, ESP-IDF driver calls and BOARD_xxx #ifdefs.
* func/ and app_main.c use this API only (docs/board-api.md - the same API as
* the modus-psoc-e84 and cubemx-stm32c5 skills, so <repo>/lib/func is shared
* unchanged).
*
* The board id reaches C as -DBOARD_<ID> (src/CMakeLists.txt, written by
* new_app.sh); this file maps it to BOARD_NAME and the user I/O.
*******************************************************************************/
#ifndef BOARD_H
#define BOARD_H

#include <stdbool.h>
#include <stdint.h>

#if defined(BOARD_ESP32_S3_BOX)
    #define BOARD_NAME          "esp32-s3-box"
#else
    #define BOARD_NAME          "generic-esp32s3"
#endif

/* Upper bounds for static tables in func/ */
#define BOARD_MAX_LEDS          (4U)
#define BOARD_MAX_BUTTONS       (4U)

/* System */
void     board_init(void);               /* user I/O + USB Serial/JTAG console       */
void     board_delay_ms(uint32_t ms);    /* FreeRTOS delay: yields (>= 1 tick)       */
uint32_t board_millis(void);             /* ms since boot (esp_timer)                */
void     board_fatal(void);              /* stop execution on unrecoverable error    */

/* User LEDs, index 0..board_led_count()-1 (LED1 = index 0) */
uint32_t    board_led_count(void);
void        board_led_write(uint32_t idx, bool on);
bool        board_led_read(uint32_t idx);         /* read back the pin level     */
const char *board_led_name(uint32_t idx);         /* "LCD backlight"             */

/* User buttons, index 0..board_button_count()-1 (BTN1 = index 0) */
uint32_t    board_button_count(void);
bool        board_button_is_pressed(uint32_t idx);  /* raw, not debounced       */
const char *board_button_name(uint32_t idx);        /* silkscreen name, "BOOT"  */
const char *board_button_pin(uint32_t idx);         /* e.g. "GPIO0"             */

/* Console = USB Serial/JTAG of the ESP32-S3. printf() also works. */
bool     board_console_getc(char *c);    /* non-blocking; true if a byte was read */
void     board_console_flush(void);

#endif /* BOARD_H */
