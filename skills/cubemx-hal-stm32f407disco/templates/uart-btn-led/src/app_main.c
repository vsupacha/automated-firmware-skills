/*******************************************************************************
* File Name : app_main.c
*
* Layer 3 - application. Wires the function layer together; no HAL calls or pins
* here (those belong in board/).
*
* uart-btn-led demo (same console contract as the other skills' template):
*   - console commands (see help) - only where the board has console input;
*     on the F4 Discovery the console is SWO output only
*   - BTNn press toggles LEDn and reports an EVT line (F4 Discovery: B1 -> LD3)
* The console is polled continuously (the UART has no RX interrupt); buttons are
* debounced every BUTTON_POLL_MS from the 1 ms tick.
*******************************************************************************/
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "app_main.h"
#include "board.h"
#include "button.h"
#include "console.h"
#include "led.h"

#define APP_NAME        "uart-btn-led"
#define APP_VERSION     "1.0"

static void print_info(void)
{
    printf("INFO app=%s v=%s board=%s leds=%lu btns=%lu\r\n", APP_NAME, APP_VERSION,
           BOARD_NAME, (unsigned long)led_count(), (unsigned long)button_count());
    printf("READY\r\n");
}

static void print_leds(void)
{
    printf("LED");
    for (uint32_t n = 1U; n <= led_count(); n++)
    {
        printf(" led%lu=%d", (unsigned long)n, led_get(n) ? 1 : 0);
    }
    printf("\r\n");
}

static void print_buttons(void)
{
    printf("BTN");
    for (uint32_t n = 1U; n <= button_count(); n++)
    {
        printf(" btn%lu=%d", (unsigned long)n, button_is_pressed(n) ? 1 : 0);
    }
    printf("\r\n");
}

/* led <n> on|off|toggle */
static void cmd_led(int argc, char *argv[])
{
    if (argc != 3)
    {
        printf("ERR usage: led <n> on|off|toggle\r\n");
        return;
    }
    uint32_t n  = (uint32_t)strtoul(argv[1], NULL, 10);
    bool     ok;
    if (strcmp(argv[2], "on") == 0)          { ok = led_set(n, true); }
    else if (strcmp(argv[2], "off") == 0)    { ok = led_set(n, false); }
    else if (strcmp(argv[2], "toggle") == 0) { ok = led_toggle(n); }
    else
    {
        printf("ERR bad action '%s'\r\n", argv[2]);
        return;
    }
    if (ok)
    {
        printf("OK led%lu=%d\r\n", (unsigned long)n, led_get(n) ? 1 : 0);
    }
    else
    {
        printf("ERR no led%s (have %lu)\r\n", argv[1], (unsigned long)led_count());
    }
}

static void cmd_led_q(int argc, char *argv[])  { (void)argc; (void)argv; print_leds(); }
static void cmd_btn_q(int argc, char *argv[])  { (void)argc; (void)argv; print_buttons(); }
static void cmd_info(int argc, char *argv[])   { (void)argc; (void)argv; print_info(); }

static const console_cmd_t commands[] =
{
    { "info", "info                  - app/board info", cmd_info  },
    { "led",  "led <n> on|off|toggle - drive LEDn",     cmd_led   },
    { "led?", "led?                  - read back LEDs", cmd_led_q },
    { "btn?", "btn?                  - button states",  cmd_btn_q },
};

void app_main(void)
{
    board_init();
    led_init();
    button_init();
    console_init(commands, sizeof(commands) / sizeof(commands[0]));

    printf("\r\n[APP] %s %s on %s - type 'help'\r\n", APP_NAME, APP_VERSION, BOARD_NAME);
    print_info();

    uint32_t next_poll = board_millis();
    for (;;)
    {
        if ((int32_t)(board_millis() - next_poll) >= 0)
        {
            uint32_t     num;
            button_evt_t evt;

            next_poll += BUTTON_POLL_MS;
            evt = button_poll(&num);
            if (evt == BUTTON_EVT_PRESSED)
            {
                (void)led_toggle(num);   /* BTNn toggles LEDn when it exists */
                printf("EVT btn%lu=pressed name=%s pin=%s led%lu=%d\r\n", (unsigned long)num,
                       board_button_name(num - 1U), board_button_pin(num - 1U),
                       (unsigned long)num, led_get(num) ? 1 : 0);
            }
            else if (evt == BUTTON_EVT_RELEASED)
            {
                printf("EVT btn%lu=released\r\n", (unsigned long)num);
            }
        }
        console_poll();
    }
}
