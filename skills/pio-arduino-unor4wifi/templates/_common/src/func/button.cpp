/*
 * button.cpp - Layer 2: debounce by time; a level must be stable BUTTON_DEBOUNCE_MS before it
 * counts (uses board.h only).
 */
#include "button.h"

#include "../board/board.h"

#define BUTTON_MAX 8

static bool          stable[BUTTON_MAX + 1];
static bool          last_raw[BUTTON_MAX + 1];
static unsigned long since[BUTTON_MAX + 1];

uint8_t button_count()
{
    uint8_t n = board_button_count();
    return (n > BUTTON_MAX) ? BUTTON_MAX : n;
}

void button_init()
{
    for (uint8_t n = 1; n <= button_count(); n++)
    {
        stable[n]   = board_button_read(n);
        last_raw[n] = stable[n];
        since[n]    = millis();
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

button_evt_t button_poll(uint8_t *num)
{
    unsigned long now = millis();

    for (uint8_t n = 1; n <= button_count(); n++)
    {
        bool raw = board_button_read(n);
        if (raw != last_raw[n])
        {
            last_raw[n] = raw;
            since[n]    = now;
        }
        else if ((raw != stable[n]) && ((now - since[n]) >= BUTTON_DEBOUNCE_MS))
        {
            stable[n] = raw;
            *num      = n;
            return raw ? BUTTON_EVT_PRESSED : BUTTON_EVT_RELEASED;
        }
    }
    return BUTTON_EVT_NONE;
}
