/*
 * board_rgb.cpp - Layer 1 driver: RGB pixel on GPIO18 with arduino-esp32's neopixelWrite() (RMT;
 * the core sends the WS2812 GRB order). No library needed.
 */
#include "board_rgb.h"

#define BOARD_RGB_PIN   18

static uint8_t last_r, last_g, last_b;

void board_rgb_begin()
{
    board_rgb_set(0, 0, 0);
}

void board_rgb_set(uint8_t r, uint8_t g, uint8_t b)
{
    last_r = r;
    last_g = g;
    last_b = b;
    neopixelWrite(BOARD_RGB_PIN, r, g, b);
}

void board_rgb_get(uint8_t *r, uint8_t *g, uint8_t *b)
{
    if (r != nullptr) { *r = last_r; }
    if (g != nullptr) { *g = last_g; }
    if (b != nullptr) { *b = last_b; }
}
