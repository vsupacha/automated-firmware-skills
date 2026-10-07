/*
 * led.cpp - Layer 2: LED service (uses board.h only).
 */
#include "led.h"

#include "../board/board.h"

#define LED_MAX 8U

static bool state[LED_MAX + 1U];

void led_init(void)
{
    for (uint32_t n = 1U; n <= led_count(); n++)
    {
        (void)led_set(n, false);
    }
}

uint32_t led_count(void)
{
    uint32_t n = board_led_count();
    return (n > LED_MAX) ? LED_MAX : n;
}

bool led_set(uint32_t n, bool on)
{
    if ((n < 1U) || (n > led_count()) || !board_led_write(n, on))
    {
        return false;
    }
    state[n] = on;
    return true;
}

bool led_toggle(uint32_t n)
{
    return (n >= 1U) && (n <= led_count()) && led_set(n, !state[n]);
}

bool led_get(uint32_t n)
{
    return (n >= 1U) && (n <= led_count()) && state[n];
}
