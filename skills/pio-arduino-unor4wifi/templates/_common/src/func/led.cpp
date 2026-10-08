/*
 * led.cpp - Layer 2: LED service (uses board.h only).
 */
#include "led.h"

#include "../board/board.h"

void led_init()
{
    for (uint8_t n = 1; n <= led_count(); n++)
    {
        led_set(n, false);
    }
}

uint8_t led_count()
{
    return board_led_count();
}

bool led_set(uint8_t n, bool on)
{
    return board_led_write(n, on);
}

bool led_toggle(uint8_t n)
{
    return (n >= 1) && (n <= led_count()) && led_set(n, !led_get(n));
}

bool led_get(uint8_t n)
{
    return board_led_read(n);
}
