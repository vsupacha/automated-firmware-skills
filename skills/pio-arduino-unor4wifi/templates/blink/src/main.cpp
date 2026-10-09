/*
 * main.cpp - Layer 3: application (Arduino sketch). Wires the function layer together; no pin
 * numbers or Serial here (those belong in board/).
 *
 * blink: LED1 toggles, "BLINK led1=x" on the UART console (USB bridge) every 0.5 s, timed by
 * millis() (no drift from the loop body). The console stays active so tests can sync with "info".
 */
#include <Arduino.h>

#include "board/board.h"
#include "func/console.h"
#include "func/led.h"

static const char          APP_NAME[]      = "blink";
static const char          APP_VERSION[]   = "1.0";
static const unsigned long BLINK_PERIOD_MS = 500;

static unsigned long next_ms;

static void print_info()
{
    console_printf("INFO app=%s v=%s board=%s period_ms=%lu\r\n", APP_NAME, APP_VERSION,
                   BOARD_ID_NAME, BLINK_PERIOD_MS);
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
    led_init();
    console_init(commands, sizeof(commands) / sizeof(commands[0]));
    console_out().println();
    console_printf("[APP] %s %s on %s\r\n", APP_NAME, APP_VERSION, BOARD_ID_NAME);
    print_info();
    next_ms = millis() + BLINK_PERIOD_MS;
}

void loop()
{
    /* signed difference handles the millis() wrap-around (~49 days) */
    if ((long)(millis() - next_ms) >= 0)
    {
        next_ms += BLINK_PERIOD_MS;
        led_toggle(1);
        console_printf("BLINK led1=%d\r\n", led_get(1) ? 1 : 0);
    }
    console_poll();
}
