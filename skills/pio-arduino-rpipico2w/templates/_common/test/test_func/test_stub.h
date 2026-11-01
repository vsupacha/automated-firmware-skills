/*
 * test_stub.h - controls of the test stub used by the func/ unit tests (test/test_func).
 * test_stub.cpp implements every function of src/board/board.h, so the tests link src/func/
 * against it instead of src/board/board.cpp: time, button levels and console input are set by the
 * test, LED writes and console output are recorded. Runs on the target (pio test).
 */
#ifndef TEST_STUB_H
#define TEST_STUB_H

#include <stdbool.h>
#include <stdint.h>

#define TEST_STUB_MAX_IO  4U

void        test_stub_reset(uint32_t leds, uint32_t buttons);   /* all off/released, time 0, empty console */
void        test_stub_set_time(uint32_t ms);
void        test_stub_set_button(uint32_t n, bool pressed);
void        test_stub_led_fail(uint32_t n, bool fail);           /* board_led_write(n) returns false */
bool        test_stub_led_level(uint32_t n);                     /* last level written to LED n */
uint32_t    test_stub_led_writes(void);                          /* number of board_led_write calls */
void        test_stub_console_input(const char *s);              /* queued for board_console_getc */
const char *test_stub_console_output(void);                      /* everything printed since the reset */
void        test_stub_console_clear_output(void);

#endif /* TEST_STUB_H */
