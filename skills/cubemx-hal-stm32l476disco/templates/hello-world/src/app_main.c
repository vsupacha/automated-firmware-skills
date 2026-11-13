/*******************************************************************************
* File Name : app_main.c
*
* Layer 3 - application. Wires the function layer together; no HAL/LL calls or
* pins here (those belong in board/).
*
* hello-world: prints "hello, world" on the ST-LINK virtual COM port every 1 s,
* timed by the 1 ms HAL tick (no drift from the loop body). The console stays
* active so tests can sync with "info".
*******************************************************************************/
#include <stdio.h>

#include "app_main.h"
#include "board.h"
#include "console.h"

#define APP_NAME            "hello-world"
#define APP_VERSION         "1.0"
#define HELLO_PERIOD_MS     (1000U)

static void print_info(void)
{
    printf("INFO app=%s v=%s board=%s period_ms=%u\r\n", APP_NAME, APP_VERSION,
           BOARD_NAME, (unsigned)HELLO_PERIOD_MS);
    printf("READY\r\n");
}

static void cmd_info(int argc, char *argv[])
{
    (void)argc;
    (void)argv;
    print_info();
}

static const console_cmd_t commands[] =
{
    { "info", "info                  - app/board info", cmd_info },
};

void app_main(void)
{
    board_init();
    console_init(commands, sizeof(commands) / sizeof(commands[0]));

    printf("\r\n[APP] %s %s on %s\r\n", APP_NAME, APP_VERSION, BOARD_NAME);
    print_info();

    uint32_t next = board_millis() + HELLO_PERIOD_MS;
    for (;;)
    {
        /* signed difference handles the 32-bit tick wrap-around (~49 days) */
        if ((int32_t)(board_millis() - next) >= 0)
        {
            next += HELLO_PERIOD_MS;
            printf("hello, world\r\n");
        }
        console_poll();
    }
}
