/*
 * main.cpp - Layer 3: application (Arduino sketch). Wires the function layer together; no pin
 * numbers or Serial here (those belong in board/).
 *
 * hello-world: prints "hello, world" on the UART console (USB bridge) every 1 s, timed by
 * millis() (no drift from the loop body). The console stays active so tests can sync with "info".
 */
#include <Arduino.h>

#include "board/board.h"
#include "func/console.h"

static const char          APP_NAME[]      = "hello-world";
static const char          APP_VERSION[]   = "1.0";
static const unsigned long HELLO_PERIOD_MS = 1000;

static unsigned long next_ms;

static void print_info()
{
    console_printf("INFO app=%s v=%s board=%s period_ms=%lu\r\n", APP_NAME, APP_VERSION,
                   BOARD_ID_NAME, HELLO_PERIOD_MS);
    console_out().println("READY");
}

static void cmd_info(int, char *[])
{
    print_info();
}

static const console_cmd_t commands[] =
{
    { "info", "info                  - app/board info", cmd_info },
};

void setup()
{
    board_init();
    console_init(commands, sizeof(commands) / sizeof(commands[0]));
    console_out().println();
    console_printf("[APP] %s %s on %s\r\n", APP_NAME, APP_VERSION, BOARD_ID_NAME);
    print_info();
    next_ms = millis() + HELLO_PERIOD_MS;
}

void loop()
{
    /* signed difference handles the millis() wrap-around (~49 days) */
    if ((long)(millis() - next_ms) >= 0)
    {
        next_ms += HELLO_PERIOD_MS;
        console_out().println("hello, world");
    }
    console_poll();
}
