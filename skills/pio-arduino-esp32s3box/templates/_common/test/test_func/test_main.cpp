/*
 * test_main.cpp - Unity unit tests of the func/ layer (led, button, console), on the target.
 * Run with scripts/unit_test.sh <app> (build -> flash.sh, asks first -> read the results).
 * func/ is linked against board_fake.cpp: button levels and console text are set here, LED levels
 * and console output are checked here. button.cpp reads the real millis(), so the debounce tests
 * wait with delay() instead of setting a fake time.
 */
#include <Arduino.h>
#include <string.h>
#include <unity.h>
#include "board_fake.h"
#include "../../src/func/button.h"
#include "../../src/func/console.h"
#include "../../src/func/led.h"

void setUp(void)    { fake_reset(2U, 2U); }
void tearDown(void) {}

/* ---- led ---------------------------------------------------------------------------------- */
static void test_led_init_turns_all_off(void)
{
    led_init();
    TEST_ASSERT_EQUAL_UINT8(2U, led_count());
    TEST_ASSERT_FALSE(led_get(1U));
    TEST_ASSERT_FALSE(fake_led_level(2U));
    TEST_ASSERT_EQUAL_UINT32(2U, fake_led_writes());
}
static void test_led_set_and_toggle_read_back(void)
{
    led_init();
    TEST_ASSERT_TRUE(led_set(1U, true));
    TEST_ASSERT_TRUE(fake_led_level(1U));
    TEST_ASSERT_TRUE(led_get(1U));
    TEST_ASSERT_TRUE(led_toggle(1U));
    TEST_ASSERT_FALSE(fake_led_level(1U));
    TEST_ASSERT_FALSE(led_get(1U));
}
static void test_led_rejects_bad_numbers(void)
{
    led_init();
    TEST_ASSERT_FALSE(led_set(0U, true));
    TEST_ASSERT_FALSE(led_set(3U, true));
    TEST_ASSERT_FALSE(led_toggle(3U));
    TEST_ASSERT_FALSE(led_get(0U));
}
static void test_led_write_failure_is_reported(void)
{
    led_init();
    fake_led_fail(2U, true);
    TEST_ASSERT_FALSE(led_set(2U, true));
    TEST_ASSERT_FALSE(led_get(2U));
}

/* ---- button (real time: BUTTON_DEBOUNCE_MS) ----------------------------------------------- */
static void test_button_press_reported_after_debounce(void)
{
    uint8_t n = 0U;
    button_init();
    fake_set_button(1U, true);
    TEST_ASSERT_EQUAL(BUTTON_EVT_NONE, button_poll(&n));          /* edge seen */
    TEST_ASSERT_EQUAL(BUTTON_EVT_NONE, button_poll(&n));          /* not yet stable */
    delay(BUTTON_DEBOUNCE_MS + 5);
    TEST_ASSERT_EQUAL(BUTTON_EVT_PRESSED, button_poll(&n));
    TEST_ASSERT_EQUAL_UINT8(1U, n);
    TEST_ASSERT_TRUE(button_is_pressed(1U));
    delay(BUTTON_DEBOUNCE_MS + 5);
    TEST_ASSERT_EQUAL(BUTTON_EVT_NONE, button_poll(&n));          /* one event only */
}
static void test_button_bounce_shorter_than_debounce_is_ignored(void)
{
    uint8_t n = 0U;
    button_init();
    fake_set_button(1U, true);
    (void)button_poll(&n);
    delay(BUTTON_DEBOUNCE_MS / 4);
    fake_set_button(1U, false);
    (void)button_poll(&n);
    delay(BUTTON_DEBOUNCE_MS + 5);
    TEST_ASSERT_EQUAL(BUTTON_EVT_NONE, button_poll(&n));
    TEST_ASSERT_FALSE(button_is_pressed(1U));
}
static void test_button_release_and_second_button(void)
{
    uint8_t n = 0U;
    button_init();
    fake_set_button(2U, true);
    (void)button_poll(&n);
    delay(BUTTON_DEBOUNCE_MS + 5);
    TEST_ASSERT_EQUAL(BUTTON_EVT_PRESSED, button_poll(&n));
    TEST_ASSERT_EQUAL_UINT8(2U, n);
    fake_set_button(2U, false);
    (void)button_poll(&n);
    delay(BUTTON_DEBOUNCE_MS + 5);
    TEST_ASSERT_EQUAL(BUTTON_EVT_RELEASED, button_poll(&n));
    TEST_ASSERT_EQUAL_UINT8(2U, n);
    TEST_ASSERT_EQUAL_STRING("BOOT", button_name(1U));
}

/* ---- console ------------------------------------------------------------------------------ */
static int  seen_argc;
static char seen_args[CONSOLE_ARGS_MAX][CONSOLE_LINE_MAX];
static void cmd_led(int argc, char *argv[])
{
    seen_argc = argc;
    for (int i = 0; (i < argc) && (i < CONSOLE_ARGS_MAX); i++)
    {
        strncpy(seen_args[i], argv[i], CONSOLE_LINE_MAX - 1);
        seen_args[i][CONSOLE_LINE_MAX - 1] = '\0';
    }
}
static const console_cmd_t CMDS[] = { { "led", "led <n> on|off|toggle", cmd_led } };

static void console_feed(const char *text)
{
    seen_argc = -1;
    console_init(CMDS, 1U);
    fake_console_input(text);
    console_poll();
}
static void test_console_splits_a_command_line(void)
{
    console_feed("led 1  on\r");
    TEST_ASSERT_EQUAL_INT(3, seen_argc);
    TEST_ASSERT_EQUAL_STRING("led", seen_args[0]);
    TEST_ASSERT_EQUAL_STRING("1", seen_args[1]);
    TEST_ASSERT_EQUAL_STRING("on", seen_args[2]);
    TEST_ASSERT_NOT_NULL(strstr(fake_console_output(), "led 1  on"));     /* echoed */
}
static void test_console_help_lists_the_commands(void)
{
    console_feed("help\n");
    TEST_ASSERT_NOT_NULL(strstr(fake_console_output(), "OK commands:"));
    TEST_ASSERT_NOT_NULL(strstr(fake_console_output(), "led <n> on|off|toggle"));
}
static void test_console_unknown_command(void)
{
    console_feed("foo\r");
    TEST_ASSERT_EQUAL_INT(-1, seen_argc);
    TEST_ASSERT_NOT_NULL(strstr(fake_console_output(), "ERR unknown command 'foo'"));
}
static void test_console_backspace_and_empty_lines(void)
{
    console_feed("\r\nlex\b\bed 2\r");
    TEST_ASSERT_EQUAL_INT(2, seen_argc);
    TEST_ASSERT_EQUAL_STRING("led", seen_args[0]);
    TEST_ASSERT_EQUAL_STRING("2", seen_args[1]);
}
static void test_console_long_line_is_cut_not_overflowed(void)
{
    char longline[CONSOLE_LINE_MAX * 2];
    memset(longline, 'x', sizeof(longline) - 2);
    longline[sizeof(longline) - 2] = '\r';
    longline[sizeof(longline) - 1] = '\0';
    console_feed(longline);
    TEST_ASSERT_NOT_NULL(strstr(fake_console_output(), "ERR unknown command"));
    TEST_ASSERT_EQUAL_INT(-1, seen_argc);
}

void setup()
{
    /* USB Serial/JTAG drops output while no host reads the port, and a host cannot reset this chip
       through it reliably: wait until the reader (scripts/unit_test.sh) sends a byte, announcing
       ourselves once a second, then run the suite once. */
    Serial.begin(115200);
    while (Serial.available() == 0)
    {
        Serial.println("UNIT-WAIT send any byte to start");
        delay(1000);
    }
    while (Serial.available() > 0) { (void)Serial.read(); }
    UNITY_BEGIN();
    RUN_TEST(test_led_init_turns_all_off);
    RUN_TEST(test_led_set_and_toggle_read_back);
    RUN_TEST(test_led_rejects_bad_numbers);
    RUN_TEST(test_led_write_failure_is_reported);
    RUN_TEST(test_button_press_reported_after_debounce);
    RUN_TEST(test_button_bounce_shorter_than_debounce_is_ignored);
    RUN_TEST(test_button_release_and_second_button);
    RUN_TEST(test_console_splits_a_command_line);
    RUN_TEST(test_console_help_lists_the_commands);
    RUN_TEST(test_console_unknown_command);
    RUN_TEST(test_console_backspace_and_empty_lines);
    RUN_TEST(test_console_long_line_is_cut_not_overflowed);
    UNITY_END();
}

void loop() {}
