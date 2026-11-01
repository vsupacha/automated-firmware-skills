/*******************************************************************************
* File Name : board.h  (host test stub)
*
* Test stub of the board for host tests (lib/host_test.sh): the board.h API of
* docs/board-api.md backed by plain variables, plus test_stub_* controls the tests
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

/* Console: input from test_stub_console_input(), output = stdout */
bool     board_console_getc(char *c);
void     board_console_flush(void);

/* ---- test controls (host only) ---- */
#define TEST_STUB_MAX_IO             (8U)

void     test_stub_reset(uint32_t leds, uint32_t buttons);    /* counts up to TEST_STUB_MAX_IO */
void     test_stub_advance_ms(uint32_t ms);
void     test_stub_button_set(uint32_t idx, bool pressed);    /* raw level */
bool     test_stub_led_get(uint32_t idx);                     /* what the pin shows */
void     test_stub_led_force(uint32_t idx, bool on);          /* change it behind func's back */
uint32_t test_stub_led_writes(void);                          /* board_led_write calls since reset */
void     test_stub_console_input(const char *s);
uint32_t test_stub_fatal_calls(void);

#endif /* BOARD_H */
