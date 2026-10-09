/*
 * hal_entry.c - Layer 3: execution (RT-Thread). hal_entry() runs in RT-Thread's main thread; the
 * msh shell (thread tshell) on the console uart9 stays active so tests can sync with "info".
 *
 * blink: LED1 toggles, "BLINK led1=x" every 0.5 s, timed with rt_thread_delay_until() (no drift
 * from the loop body).
 */
#include <rtthread.h>

#include "board/board_io.h"
#include "func/led.h"

#define APP_NAME        "blink"
#define APP_VERSION     "1.0"
#define BLINK_PERIOD_MS 500

static void print_info(void)
{
    rt_kprintf("INFO app=%s v=%s board=%s period_ms=%d\n", APP_NAME, APP_VERSION, BOARD_ID_NAME,
               BLINK_PERIOD_MS);
    rt_kprintf("READY\n");
}

static int cmd_info(int argc, char **argv)
{
    (void)argc;
    (void)argv;
    print_info();
    return 0;
}
MSH_CMD_EXPORT_ALIAS(cmd_info, info, app and board info);

void hal_entry(void)
{
    board_io_init();
    led_init();
    rt_kprintf("\n[APP] %s %s on %s\n", APP_NAME, APP_VERSION, BOARD_ID_NAME);
    print_info();

    rt_tick_t tick = rt_tick_get();
    while (1)
    {
        rt_thread_delay_until(&tick, rt_tick_from_millisecond(BLINK_PERIOD_MS));
        led_toggle(1);
        rt_kprintf("BLINK led1=%d\n", led_get(1) ? 1 : 0);
    }
}
