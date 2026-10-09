/*
 * hal_entry.c - Layer 3: execution (RT-Thread). hal_entry() runs in RT-Thread's main thread; the
 * msh shell (thread tshell) on the console uart9 runs the commands exported below. No pin numbers
 * here (those belong in board/).
 *
 * push-to-light demo (same console contract as the other skills, as msh commands):
 *   info                   INFO line + READY
 *   led <n> on|off|toggle  drive LEDn -> OK ledN=x / ERR ...
 *   led                    read back all LEDs -> LED led1=x ...   (msh names cannot contain '?')
 *   btn                    button states -> BTN btn1=x
 *   BTNn press toggles LEDn and prints an EVT line (polled every 10 ms in the main thread).
 */
#include <rtthread.h>
#include <stdlib.h>
#include <string.h>

#include "board/board_io.h"
#include "func/button.h"
#include "func/led.h"

#define APP_NAME        "push-to-light"
#define APP_VERSION     "1.0"
#define POLL_PERIOD_MS  10

static void print_info(void)
{
    rt_kprintf("INFO app=%s v=%s board=%s leds=%u btns=%u\n", APP_NAME, APP_VERSION, BOARD_ID_NAME,
               (unsigned)led_count(), (unsigned)button_count());
    rt_kprintf("READY\n");
}

static void print_leds(void)
{
    rt_kprintf("LED");
    for (uint8_t n = 1; n <= led_count(); n++)
    {
        rt_kprintf(" led%u=%d", (unsigned)n, led_get(n) ? 1 : 0);
    }
    rt_kprintf("\n");
}

static void print_buttons(void)
{
    rt_kprintf("BTN");
    for (uint8_t n = 1; n <= button_count(); n++)
    {
        rt_kprintf(" btn%u=%d", (unsigned)n, button_is_pressed(n) ? 1 : 0);
    }
    rt_kprintf("\n");
}

static int cmd_info(int argc, char **argv)
{
    (void)argc;
    (void)argv;
    print_info();
    return 0;
}
MSH_CMD_EXPORT_ALIAS(cmd_info, info, app and board info);

static int cmd_led(int argc, char **argv)
{
    if (argc == 1)
    {
        print_leds();
        return 0;
    }
    if (argc != 3)
    {
        rt_kprintf("ERR usage: led <n> on|off|toggle\n");
        return 0;
    }
    uint8_t n = (uint8_t)atoi(argv[1]);
    bool    ok;
    if (strcmp(argv[2], "on") == 0)          { ok = led_set(n, true); }
    else if (strcmp(argv[2], "off") == 0)    { ok = led_set(n, false); }
    else if (strcmp(argv[2], "toggle") == 0) { ok = led_toggle(n); }
    else
    {
        rt_kprintf("ERR bad action '%s'\n", argv[2]);
        return 0;
    }
    if (ok)
    {
        rt_kprintf("OK led%u=%d\n", (unsigned)n, led_get(n) ? 1 : 0);
    }
    else
    {
        rt_kprintf("ERR no led%s (have %u)\n", argv[1], (unsigned)led_count());
    }
    return 0;
}
MSH_CMD_EXPORT_ALIAS(cmd_led, led, led <n> on|off|toggle - drive LEDn / led - read back the LEDs);

static int cmd_btn(int argc, char **argv)
{
    (void)argc;
    (void)argv;
    print_buttons();
    return 0;
}
MSH_CMD_EXPORT_ALIAS(cmd_btn, btn, btn - button states);

void hal_entry(void)
{
    board_io_init();
    led_init();
    button_init();
    rt_kprintf("\n[APP] %s %s on %s - type 'help'\n", APP_NAME, APP_VERSION, BOARD_ID_NAME);
    print_info();

    while (1)
    {
        uint8_t      num;
        button_evt_t evt = button_poll(&num);

        if (evt == BUTTON_EVT_PRESSED)
        {
            led_toggle(num);   /* BTNn toggles LEDn when it exists */
            rt_kprintf("EVT btn%u=pressed name=%s pin=%s led%u=%d\n", (unsigned)num, button_name(num),
                       button_pin(num), (unsigned)num, led_get(num) ? 1 : 0);
        }
        else if (evt == BUTTON_EVT_RELEASED)
        {
            rt_kprintf("EVT btn%u=released\n", (unsigned)num);
        }
        rt_thread_mdelay(POLL_PERIOD_MS);
    }
}
