/*******************************************************************************
* File Name : gesture.c
*
* Layer 2 - function. See gesture.h.
*
* Two stages per update: debounce the raw level (stable for GESTURE_DEBOUNCE_MS),
* then a state machine on the debounced edges. All time differences are
* unsigned subtractions, so they stay right across the uint32_t wrap-around.
*
*   IDLE --press--> DOWN --held LONG_MS--> (LONG) HELD --release--> IDLE
*                    |
*                 release
*                    v
*                   GAP --gap over--> (SHORT) IDLE
*                    |
*                  press
*                    v
*                  DOWN2 --release--> (DOUBLE) IDLE
*                    |
*                held DOUBLE_GAP_MS --> (SHORT) DOWN   (click, then press-and-hold)
*******************************************************************************/
#include "gesture.h"

enum
{
    PHASE_IDLE = 0U,
    PHASE_DOWN,         /* first press, may become LONG or a click   */
    PHASE_HELD,         /* LONG reported, waiting for the release    */
    PHASE_GAP,          /* one click done, waiting for a second one  */
    PHASE_DOWN2         /* second press of a double click            */
};

void gesture_init(gesture_state_t *g)
{
    g->phase     = PHASE_IDLE;
    g->raw       = false;
    g->stable    = false;
    g->raw_since = 0U;
    g->since     = 0U;
}

/* true when the debounced level changed in this update */
static bool debounce(gesture_state_t *g, bool pressed, uint32_t now_ms)
{
    if (pressed != g->raw)
    {
        g->raw       = pressed;
        g->raw_since = now_ms;
    }
    if ((g->raw != g->stable) && ((uint32_t)(now_ms - g->raw_since) >= GESTURE_DEBOUNCE_MS))
    {
        g->stable = g->raw;
        return true;
    }
    return false;
}

gesture_t gesture_update(gesture_state_t *g, bool pressed, uint32_t now_ms)
{
    bool      edge    = debounce(g, pressed, now_ms);
    uint32_t  elapsed = (uint32_t)(now_ms - g->since);
    gesture_t out     = GESTURE_NONE;

    switch (g->phase)
    {
        case PHASE_IDLE:
            if (edge && g->stable)
            {
                g->phase = PHASE_DOWN;
                g->since = now_ms;
            }
            break;

        case PHASE_DOWN:
            if (edge && !g->stable)
            {
                g->phase = PHASE_GAP;
                g->since = now_ms;
            }
            else if (elapsed >= GESTURE_LONG_MS)
            {
                g->phase = PHASE_HELD;
                out      = GESTURE_LONG;
            }
            break;

        case PHASE_HELD:
            if (edge && !g->stable)
            {
                g->phase = PHASE_IDLE;
            }
            break;

        case PHASE_GAP:
            if (edge && g->stable)
            {
                g->phase = PHASE_DOWN2;
                g->since = now_ms;
            }
            else if (elapsed >= GESTURE_DOUBLE_GAP_MS)
            {
                g->phase = PHASE_IDLE;
                out      = GESTURE_SHORT;
            }
            break;

        case PHASE_DOWN2:
            if (edge && !g->stable)
            {
                g->phase = PHASE_IDLE;
                out      = GESTURE_DOUBLE;
            }
            else if (elapsed >= GESTURE_DOUBLE_GAP_MS)
            {
                /* held too long for a double click: the first click was a
                 * SHORT, this press continues as a first press (LONG timer
                 * runs from when it started) */
                g->phase = PHASE_DOWN;
                out      = GESTURE_SHORT;
            }
            break;

        default:
            gesture_init(g);
            break;
    }
    return out;
}

const char *gesture_name(gesture_t e)
{
    switch (e)
    {
        case GESTURE_SHORT:  return "short";
        case GESTURE_LONG:   return "long";
        case GESTURE_DOUBLE: return "double";
        default:             return "none";
    }
}
