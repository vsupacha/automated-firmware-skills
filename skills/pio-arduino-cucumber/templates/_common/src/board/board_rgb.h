/*
 * board_rgb.h - Layer 1 driver: the RGB LED on GPIO18 ("RGB LED" on the Gravitech pinout; one
 * WS2812-type pixel, like the Saola-1 the board json comes from - UNVERIFIED until seen on the
 * board). The pixel cannot be read back: board_rgb_get() returns the last colour written.
 */
#ifndef BOARD_RGB_H
#define BOARD_RGB_H

#include <Arduino.h>

void board_rgb_begin();                                     /* pixel off */
void board_rgb_set(uint8_t r, uint8_t g, uint8_t b);
void board_rgb_get(uint8_t *r, uint8_t *g, uint8_t *b);     /* last written colour */

#endif /* BOARD_RGB_H */
