/*
 * button.h - Layer 2: debounced buttons with press/release events (Arduino API, board.h only).
 * Call button_poll() from loop(); debouncing is timed with millis(), so the call rate does not
 * matter as long as loop() does not block.
 */
#ifndef BUTTON_H
#define BUTTON_H

#include <Arduino.h>

#define BUTTON_DEBOUNCE_MS  20

enum button_evt_t
{
    BUTTON_EVT_NONE = 0,
    BUTTON_EVT_PRESSED,
    BUTTON_EVT_RELEASED
};

void         button_init();
uint8_t      button_count();
bool         button_is_pressed(uint8_t n);   /* debounced, 1-based */
const char  *button_name(uint8_t n);
button_evt_t button_poll(uint8_t *num);      /* at most one event per call */

#endif /* BUTTON_H */
