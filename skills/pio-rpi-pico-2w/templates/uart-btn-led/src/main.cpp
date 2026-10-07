/*
 * main.cpp - Layer 3: application. Wires the function layer together; no pins or core-specific
 * calls here (those belong in board/).
 *
 * uart-btn-led demo (same console contract as the modus-psoc-e84 template):
 *   - console commands over USB CDC (see help)
 *   - BTNn press toggles LEDn and reports an EVT line (Pico 2 W: BOOTSEL -> LED)
 */
#include <stdlib.h>
#include <string.h>

#include "board/board.h"
#include "func/button.h"
#include "func/console.h"
#include "func/led.h"

#define APP_NAME    "uart-btn-led"
#define APP_VERSION "1.0"

static uint32_t next_poll_ms;

static void print_info(void)
{
    console_printf("INFO app=%s v=%s board=%s leds=%lu btns=%lu\r\n", APP_NAME, APP_VERSION,
                   BOARD_ID_NAME, (unsigned long)led_count(), (unsigned long)button_count());
    console_printf("READY\r\n");
}

static void print_leds(void)
{
    console_printf("LED");
    for (uint32_t n = 1U; n <= led_count(); n++)
    {
        console_printf(" led%lu=%d", (unsigned long)n, led_get(n) ? 1 : 0);
    }
    console_printf("\r\n");
}

static void print_buttons(void)
{
    console_printf("BTN");
    for (uint32_t n = 1U; n <= button_count(); n++)
    {
        console_printf(" btn%lu=%d", (unsigned long)n, button_is_pressed(n) ? 1 : 0);
    }
    console_printf("\r\n");
}

/* led <n> on|off|toggle */
static void cmd_led(int argc, char *argv[])
{
    if (argc != 3)
    {
        console_printf("ERR usage: led <n> on|off|toggle\r\n");
        return;
    }
    uint32_t n = (uint32_t)strtoul(argv[1], NULL, 10);
    bool     ok;
    if (strcmp(argv[2], "on") == 0)          { ok = led_set(n, true); }
    else if (strcmp(argv[2], "off") == 0)    { ok = led_set(n, false); }
    else if (strcmp(argv[2], "toggle") == 0) { ok = led_toggle(n); }
    else
    {
        console_printf("ERR bad action '%s'\r\n", argv[2]);
        return;
    }
    if (ok)
    {
        console_printf("OK led%lu=%d\r\n", (unsigned long)n, led_get(n) ? 1 : 0);
    }
    else
    {
        console_printf("ERR no led%s (have %lu)\r\n", argv[1], (unsigned long)led_count());
    }
}

static void cmd_led_q(int argc, char *argv[]) { (void)argc; (void)argv; print_leds(); }
static void cmd_btn_q(int argc, char *argv[]) { (void)argc; (void)argv; print_buttons(); }
static void cmd_info(int argc, char *argv[])  { (void)argc; (void)argv; print_info(); }

static const console_cmd_t commands[] =
{
    { "info", "info                  - app/board info",       cmd_info  },
    { "led",  "led <n> on|off|toggle - drive LEDn",           cmd_led   },
    { "led?", "led?                  - commanded LED states", cmd_led_q },
    { "btn?", "btn?                  - button states",        cmd_btn_q },
};

void setup()
{
    board_init();
    led_init();
    button_init();
    console_init(commands, sizeof(commands) / sizeof(commands[0]));
    console_printf("\r\n[APP] %s %s on %s - type 'help'\r\n", APP_NAME, APP_VERSION, BOARD_ID_NAME);
    print_info();
    next_poll_ms = board_millis();
}

void loop()
{
    if ((int32_t)(board_millis() - next_poll_ms) >= 0)
    {
        uint32_t     num;
        button_evt_t evt;

        next_poll_ms += BUTTON_POLL_MS;
        evt = button_poll(&num);
        if (evt == BUTTON_EVT_PRESSED)
        {
            (void)led_toggle(num);   /* BTNn toggles LEDn when it exists */
            console_printf("EVT btn%lu=pressed name=%s led%lu=%d\r\n", (unsigned long)num,
                           button_name(num), (unsigned long)num, led_get(num) ? 1 : 0);
        }
        else if (evt == BUTTON_EVT_RELEASED)
        {
            console_printf("EVT btn%lu=released\r\n", (unsigned long)num);
        }
    }
    console_poll();
}
