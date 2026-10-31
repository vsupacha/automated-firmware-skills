/*
 * button.c - Layer 2: debounce by time; a level must be stable BUTTON_DEBOUNCE_MS before it
 * counts (board_io.h + the kernel tick).
 */
#include "button.h"

#include <rtthread.h>

#include "../board/board_io.h"

#define BUTTON_MAX 8U

static bool      stable[BUTTON_MAX + 1];
static bool      last_raw[BUTTON_MAX + 1];
static rt_tick_t since[BUTTON_MAX + 1];

uint8_t button_count(void)
{
    uint8_t n = board_button_count();
    return (n > BUTTON_MAX) ? (uint8_t)BUTTON_MAX : n;
}

void button_init(void)
{
    for (uint8_t n = 1; n <= button_count(); n++)
    {
        stable[n]   = board_button_read(n);
        last_raw[n] = stable[n];
        since[n]    = rt_tick_get_millisecond();
    }
}

bool button_is_pressed(uint8_t n)
{
    return (n >= 1) && (n <= button_count()) && stable[n];
}

const char *button_name(uint8_t n)
{
    return board_button_name(n);
}

const char *button_pin(uint8_t n)
{
    return board_button_pin(n);
}

button_evt_t button_poll(uint8_t *num)
{
    rt_tick_t now = rt_tick_get_millisecond();

    for (uint8_t n = 1; n <= button_count(); n++)
    {
        bool raw = board_button_read(n);
        if (raw != last_raw[n])
        {
            last_raw[n] = raw;
            since[n]    = now;
        }
        else if ((raw != stable[n]) && ((rt_tick_t)(now - since[n]) >= BUTTON_DEBOUNCE_MS))
        {
            stable[n] = raw;
            *num      = n;
            return raw ? BUTTON_EVT_PRESSED : BUTTON_EVT_RELEASED;
        }
    }
    return BUTTON_EVT_NONE;
}
