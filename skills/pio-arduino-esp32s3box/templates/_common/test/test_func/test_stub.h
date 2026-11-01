/*
 * test_stub.h - controls of the test stub used by the func/ unit tests (test/test_func).
 * test_stub.cpp implements every function of src/board/board.h, so the tests link src/func/
 * against it instead of src/board/board.cpp: button levels and console input are set by the test,
 * LED levels (read back by led_get) and console output are recorded. Time is the real millis()
 * (func/button.cpp reads it directly). Runs on the target (pio test).
 */
#ifndef TEST_STUB_H
#define TEST_STUB_H

#include <stdbool.h>
#include <stdint.h>

#define TEST_STUB_MAX_IO  4U

void        test_stub_reset(uint8_t leds, uint8_t buttons);   /* all off/released, empty console */
void        test_stub_set_button(uint8_t n, bool pressed);
void        test_stub_led_fail(uint8_t n, bool fail);          /* board_led_write(n) returns false */
bool        test_stub_led_level(uint8_t n);                    /* level of LED n (what led_get reads back) */
uint32_t    test_stub_led_writes(void);                        /* number of board_led_write calls */
void        test_stub_console_input(const char *s);            /* queued for the console Stream */
const char *test_stub_console_output(void);                    /* everything printed since the reset */

#endif /* TEST_STUB_H */
