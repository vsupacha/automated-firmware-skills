/*
 * board_fake.h - controls of the fake board used by the func/ unit tests (test/test_func).
 * board_fake.cpp implements every function of src/board/board.h, so the tests link src/func/
 * against it instead of src/board/board.cpp: time, button levels and console input are set by the
 * test, LED writes and console output are recorded. Runs on the target (pio test).
 */
#ifndef BOARD_FAKE_H
#define BOARD_FAKE_H

#include <stdbool.h>
#include <stdint.h>

#define FAKE_MAX_IO  4U

void        fake_reset(uint32_t leds, uint32_t buttons);   /* all off/released, time 0, empty console */
void        fake_set_time(uint32_t ms);
void        fake_set_button(uint32_t n, bool pressed);
void        fake_led_fail(uint32_t n, bool fail);           /* board_led_write(n) returns false */
bool        fake_led_level(uint32_t n);                     /* last level written to LED n */
uint32_t    fake_led_writes(void);                          /* number of board_led_write calls */
void        fake_console_input(const char *s);              /* queued for board_console_getc */
const char *fake_console_output(void);                      /* everything printed since the reset */
void        fake_console_clear_output(void);

#endif /* BOARD_FAKE_H */
