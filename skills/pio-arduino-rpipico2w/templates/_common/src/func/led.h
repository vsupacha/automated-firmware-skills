/*
 * led.h - Layer 2: LED service, 1-based like the silkscreen (uses board.h only).
 * led_get() returns the commanded state: the Pico 2 W LED sits on the Wi-Fi module and has no
 * read-back path - a human confirms what it shows.
 */
#ifndef LED_H
#define LED_H

#include <stdbool.h>
#include <stdint.h>

void     led_init(void);
uint32_t led_count(void);
bool     led_set(uint32_t n, bool on);     /* false = no such LED */
bool     led_toggle(uint32_t n);
bool     led_get(uint32_t n);

#endif /* LED_H */
