/*******************************************************************************
* File Name : test_driver_main.c
*
* On-target unit test runner (the test driver's main): replaces the app's
* app_main.c in the unit-test image (CMake FW_UNIT=ON). Uses the real board
* layer only for the console; the suites (test_*.c, the test driver cases)
* test func/ code with test stubs of their own. Owns Unity's setUp() /
* tearDown(), calls the running suite's hooks (test_driver.h) and records every
* case in the test log (test_log.h).
*
* Start-byte handshake (as the ESP32-S3-BOX unit tests): prints "UNIT-WAIT ..."
* once a second until a byte arrives on the console, so the reader never misses
* the start of the run whenever it opens the port. Then Unity's output, then
* the test log line "TESTLOG: ...", then "UNIT-DONE", then the image idles.
*******************************************************************************/
#include <stddef.h>
#include <stdio.h>

#include "unity.h"
#include "app_main.h"
#include "board.h"
#include "test_driver.h"
#include "test_log.h"

void (*test_driver_setup)(void);
void (*test_driver_teardown)(void);

void setUp(void)
{
    test_log_begin(Unity.CurrentTestName);
    if (test_driver_setup != NULL)
    {
        test_driver_setup();
    }
}

void tearDown(void)
{
    if (test_driver_teardown != NULL)
    {
        test_driver_teardown();
    }
    test_log_end(Unity.CurrentTestName, Unity.CurrentTestFailed == 0U);
}

void app_main(void)
{
    char     c;
    uint32_t next = 0U;

    board_init();
    while (!board_console_getc(&c))
    {
        if ((int32_t)(board_millis() - next) >= 0)
        {
            printf("UNIT-WAIT send any byte to start (board=%s)\r\n", BOARD_NAME);
            next = board_millis() + 1000U;
        }
    }
    board_delay_ms(50U);
    while (board_console_getc(&c))
    {
    }

    test_log_clear();
    UNITY_BEGIN();
    test_gesture_suite();
    test_fxscale_suite();
    (void)UNITY_END();
    printf("%s\r\n", test_log_line());
    printf("UNIT-DONE\r\n");
    for (;;)
    {
    }
}
