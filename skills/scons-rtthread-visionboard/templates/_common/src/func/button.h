/*
 * button.h - Layer 2: debounced buttons with press/release events (board_io.h + kernel ticks).
 * Call button_poll() periodically (e.g. every 10 ms from a thread); debouncing is timed with
 * rt_tick_get_millisecond(), so the call rate only bounds the reaction time.
 */
#ifndef BUTTON_H
#define BUTTON_H

#include <stdbool.h>
#include <stdint.h>

#define BUTTON_DEBOUNCE_MS  20U

typedef enum
{
    BUTTON_EVT_NONE = 0,
    BUTTON_EVT_PRESSED,
    BUTTON_EVT_RELEASED
} button_evt_t;

void         button_init(void);
uint8_t      button_count(void);
bool         button_is_pressed(uint8_t n);   /* debounced, 1-based */
const char  *button_name(uint8_t n);
const char  *button_pin(uint8_t n);
button_evt_t button_poll(uint8_t *num);      /* at most one event per call */

#endif /* BUTTON_H */
