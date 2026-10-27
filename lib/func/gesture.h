/*******************************************************************************
* File Name : gesture.h
*
* Layer 2 - function. Turns one button's raw level into gestures: a short click,
* a long press (reported while still held) and a double click. Pure logic: the
* caller passes the raw level and the time, so it needs no board.h and is unit
* tested with a fake clock (lib/test_func/test_gesture.c).
*
* Call gesture_update() often (every 1 ms is fine) with the raw, undebounced
* level; it returns at most one gesture per call. Times are uint32_t ms and may
* wrap around (board_millis() wraps after ~49 days).
*******************************************************************************/
#ifndef GESTURE_H
#define GESTURE_H

#include <stdbool.h>
#include <stdint.h>

#define GESTURE_DEBOUNCE_MS     (20U)   /* level must be stable this long        */
#define GESTURE_LONG_MS         (800U)  /* held this long = LONG (while held)    */
#define GESTURE_DOUBLE_GAP_MS   (250U)  /* max release-to-press gap for DOUBLE   */

typedef enum
{
    GESTURE_NONE = 0,
    GESTURE_SHORT,      /* one click; reported once the double-click gap expired */
    GESTURE_LONG,       /* reported once, while the button is still held         */
    GESTURE_DOUBLE      /* two clicks within GESTURE_DOUBLE_GAP_MS               */
} gesture_t;

typedef struct
{
    uint8_t  phase;         /* private: state machine phase                      */
    bool     raw;           /* private: last raw level                           */
    bool     stable;        /* private: debounced level                          */
    uint32_t raw_since;     /* private: when raw last changed                    */
    uint32_t since;         /* private: when the current phase started           */
} gesture_state_t;

void      gesture_init(gesture_state_t *g);
gesture_t gesture_update(gesture_state_t *g, bool pressed, uint32_t now_ms);
const char *gesture_name(gesture_t e);  /* "short", "long", "double", "none" */

#endif /* GESTURE_H */
