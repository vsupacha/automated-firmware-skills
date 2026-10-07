/*
 * led.h - Layer 2: LED service, 1-based like the silkscreen (Arduino API, board.h only).
 * led_get() reads the pin back through the board layer.
 */
#ifndef LED_H
#define LED_H

#include <Arduino.h>

void    led_init();                     /* all off */
uint8_t led_count();
bool    led_set(uint8_t n, bool on);    /* false = no such LED */
bool    led_toggle(uint8_t n);
bool    led_get(uint8_t n);

#endif /* LED_H */
