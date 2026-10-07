/*
 * button.h - Layer 2: debounced buttons with press/release events (uses board.h only).
 * Call button_poll() every BUTTON_POLL_MS.
 */
#ifndef BUTTON_H
#define BUTTON_H

#include <stdbool.h>
#include <stdint.h>

#define BUTTON_POLL_MS      10U
#define BUTTON_DEBOUNCE_MS  50U

typedef enum
{
    BUTTON_EVT_NONE = 0,
    BUTTON_EVT_PRESSED,
    BUTTON_EVT_RELEASED
} button_evt_t;

void         button_init(void);
uint32_t     button_count(void);
bool         button_is_pressed(uint32_t n);
const char  *button_name(uint32_t n);
button_evt_t button_poll(uint32_t *num);   /* at most one event per call */

#endif /* BUTTON_H */
