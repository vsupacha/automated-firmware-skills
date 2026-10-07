/*
 * main.cpp - Layer 3: application (Arduino sketch). Wires the function layer together; no pin
 * numbers or Serial here (those belong in board/).
 *
 * uart-btn-led demo (same console contract as the other skills' template):
 *   - console commands over the USB console (see help)
 *   - BTNn press toggles LEDn and reports an EVT line (ESP32-S3-BOX: BOOT -> LCD backlight)
 * loop() polls the console and the buttons (debounced with millis()) and never blocks.
 */
#include <Arduino.h>

#include "board/board.h"
#include "func/button.h"
#include "func/console.h"
#include "func/led.h"

static const char APP_NAME[]    = "uart-btn-led";
static const char APP_VERSION[] = "1.0";

static void print_info()
{
    console_out().printf("INFO app=%s v=%s board=%s leds=%u btns=%u\r\n", APP_NAME, APP_VERSION,
                         BOARD_ID_NAME, led_count(), button_count());
    console_out().println("READY");
}

static void print_leds()
{
    console_out().print("LED");
    for (uint8_t n = 1; n <= led_count(); n++)
    {
        console_out().printf(" led%u=%d", n, led_get(n) ? 1 : 0);
    }
    console_out().println();
}

static void print_buttons()
{
    console_out().print("BTN");
    for (uint8_t n = 1; n <= button_count(); n++)
    {
        console_out().printf(" btn%u=%d", n, button_is_pressed(n) ? 1 : 0);
    }
    console_out().println();
}

/* led <n> on|off|toggle */
static void cmd_led(int argc, char *argv[])
{
    if (argc != 3)
    {
        console_out().println("ERR usage: led <n> on|off|toggle");
        return;
    }
    uint8_t n = (uint8_t)atoi(argv[1]);
    bool    ok;
    if (strcmp(argv[2], "on") == 0)          { ok = led_set(n, true); }
    else if (strcmp(argv[2], "off") == 0)    { ok = led_set(n, false); }
    else if (strcmp(argv[2], "toggle") == 0) { ok = led_toggle(n); }
    else
    {
        console_out().printf("ERR bad action '%s'\r\n", argv[2]);
        return;
    }
    if (ok)
    {
        console_out().printf("OK led%u=%d\r\n", n, led_get(n) ? 1 : 0);
    }
    else
    {
        console_out().printf("ERR no led%s (have %u)\r\n", argv[1], led_count());
    }
}

static void cmd_led_q(int, char *[]) { print_leds(); }
static void cmd_btn_q(int, char *[]) { print_buttons(); }
static void cmd_info(int, char *[])  { print_info(); }

static const console_cmd_t commands[] =
{
    { "info", "info                  - app/board info", cmd_info  },
    { "led",  "led <n> on|off|toggle - drive LEDn",     cmd_led   },
    { "led?", "led?                  - read back LEDs", cmd_led_q },
    { "btn?", "btn?                  - button states",  cmd_btn_q },
};

void setup()
{
    board_init();
    led_init();
    button_init();
    console_init(commands, sizeof(commands) / sizeof(commands[0]));
    console_out().println();
    console_out().printf("[APP] %s %s on %s - type 'help'\r\n", APP_NAME, APP_VERSION, BOARD_ID_NAME);
    print_info();
}

void loop()
{
    uint8_t      num;
    button_evt_t evt = button_poll(&num);

    if (evt == BUTTON_EVT_PRESSED)
    {
        led_toggle(num);   /* BTNn toggles LEDn when it exists */
        console_out().printf("EVT btn%u=pressed name=%s pin=GPIO%u led%u=%d\r\n", num,
                             button_name(num), board_button_pin(num), num, led_get(num) ? 1 : 0);
    }
    else if (evt == BUTTON_EVT_RELEASED)
    {
        console_out().printf("EVT btn%u=released\r\n", num);
    }
    console_poll();
}
