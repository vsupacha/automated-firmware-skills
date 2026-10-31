/*
 * led.c - Layer 2: LED service on the board layer.
 */
#include "led.h"

#include "../board/board_io.h"

void led_init(void)
{
    for (uint8_t n = 1; n <= board_led_count(); n++)
    {
        board_led_write(n, false);
    }
}

uint8_t led_count(void)
{
    return board_led_count();
}

bool led_set(uint8_t n, bool on)
{
    return board_led_write(n, on);
}

bool led_toggle(uint8_t n)
{
    return board_led_write(n, !board_led_read(n));
}

bool led_get(uint8_t n)
{
    return board_led_read(n);
}

const char *led_name(uint8_t n)
{
    return board_led_name(n);
}
