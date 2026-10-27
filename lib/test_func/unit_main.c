/*******************************************************************************
* File Name : unit_main.c
*
* On-target unit test runner: replaces the app's app_main.c in the unit-test
* image (CMake FW_UNIT=ON). Uses the real board layer only for the console;
* the suites test func/ code with fakes of their own. Owns Unity's setUp() /
* tearDown() and calls the running suite's hooks (unit.h).
*
* Start-byte handshake (as the ESP32-S3-BOX unit tests): prints "UNIT-WAIT ..."
* once a second until a byte arrives on the console, so the reader never misses
* the start of the run whenever it opens the port. Then Unity's output, then
* "UNIT-DONE", then the image idles.
*******************************************************************************/
#include <stddef.h>
#include <stdio.h>

#include "unity.h"
#include "app_main.h"
#include "board.h"
#include "unit.h"

void (*unit_setup)(void);
void (*unit_teardown)(void);

void setUp(void)
{
    if (unit_setup != NULL)
    {
        unit_setup();
    }
}

void tearDown(void)
{
    if (unit_teardown != NULL)
    {
        unit_teardown();
    }
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

    UNITY_BEGIN();
    test_gesture_suite();
    test_fxscale_suite();
    (void)UNITY_END();
    printf("UNIT-DONE\r\n");
    for (;;)
    {
    }
}
