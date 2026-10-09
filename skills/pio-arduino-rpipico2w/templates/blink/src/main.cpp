/*
 * main.cpp - Layer 3: application. Wires the function layer together; no pins or core-specific
 * calls here (those belong in board/).
 *
 * blink: LED1 toggles, "BLINK led1=x" on the USB console every 0.5 s, timed by the board's 1 ms
 * tick (no drift from the loop body). The console stays active so tests can sync with "info".
 */
#include "board/board.h"
#include "func/console.h"
#include "func/led.h"

#define APP_NAME        "blink"
#define APP_VERSION     "1.0"
#define BLINK_PERIOD_MS (500U)

static uint32_t next_ms;

static void print_info(void)
{
    console_printf("INFO app=%s v=%s board=%s period_ms=%u\r\n", APP_NAME, APP_VERSION,
                   BOARD_ID_NAME, (unsigned)BLINK_PERIOD_MS);
    console_printf("READY\r\n");
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

void setup()
{
    board_init();
    led_init();
    console_init(commands, sizeof(commands) / sizeof(commands[0]));
    console_printf("\r\n[APP] %s %s on %s\r\n", APP_NAME, APP_VERSION, BOARD_ID_NAME);
    print_info();
    next_ms = board_millis() + BLINK_PERIOD_MS;
}

void loop()
{
    /* signed difference handles the 32-bit tick wrap-around (~49 days) */
    if ((int32_t)(board_millis() - next_ms) >= 0)
    {
        next_ms += BLINK_PERIOD_MS;
        led_toggle(1);
        console_printf("BLINK led1=%d\r\n", led_get(1) ? 1 : 0);
    }
    console_poll();
}
