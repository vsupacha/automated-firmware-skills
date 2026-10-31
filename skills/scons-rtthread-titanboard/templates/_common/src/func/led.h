/*
 * led.h - Layer 2: LED service, 1-based like the silkscreen (board_io.h only).
 * led_get() reads the pin back through the board layer.
 */
#ifndef LED_H
#define LED_H

#include <stdbool.h>
#include <stdint.h>

void        led_init(void);                 /* all off */
uint8_t     led_count(void);
bool        led_set(uint8_t n, bool on);    /* false = no such LED */
bool        led_toggle(uint8_t n);
bool        led_get(uint8_t n);
const char *led_name(uint8_t n);

#endif /* LED_H */
