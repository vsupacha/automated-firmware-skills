/*******************************************************************************
* File Name : board.h  (host fake)
*
* Fake board for host tests (lib/host_test.sh): the board.h API of
* docs/board-api.md backed by plain variables, plus fake_* controls the tests
* use to press buttons, feed console input and advance time.
* BOARD_MAX_* are small on purpose so the tests can exceed them.
*******************************************************************************/
#ifndef BOARD_H
#define BOARD_H

#include <stdbool.h>
#include <stdint.h>

#define BOARD_NAME              "host"

/* Upper bounds for static tables in func/ */
#define BOARD_MAX_LEDS          (4U)
#define BOARD_MAX_BUTTONS       (4U)

/* System */
void     board_init(void);
void     board_delay_ms(uint32_t ms);
uint32_t board_millis(void);
void     board_fatal(void);

/* User LEDs, index 0..board_led_count()-1 */
uint32_t    board_led_count(void);
void        board_led_write(uint32_t idx, bool on);
bool        board_led_read(uint32_t idx);
const char *board_led_name(uint32_t idx);

/* User buttons, index 0..board_button_count()-1 */
uint32_t    board_button_count(void);
bool        board_button_is_pressed(uint32_t idx);
const char *board_button_name(uint32_t idx);
const char *board_button_pin(uint32_t idx);

/* Console: input from fake_console_input(), output = stdout */
bool     board_console_getc(char *c);
void     board_console_flush(void);

/* ---- test controls (host only) ---- */
#define FAKE_MAX_IO             (8U)

void     fake_reset(uint32_t leds, uint32_t buttons);    /* counts up to FAKE_MAX_IO */
void     fake_advance_ms(uint32_t ms);
void     fake_button_set(uint32_t idx, bool pressed);    /* raw level */
bool     fake_led_get(uint32_t idx);                     /* what the pin shows */
void     fake_led_force(uint32_t idx, bool on);          /* change it behind func's back */
uint32_t fake_led_writes(void);                          /* board_led_write calls since reset */
void     fake_console_input(const char *s);
uint32_t fake_fatal_calls(void);

#endif /* BOARD_H */
