/*
 * board_i2c.cpp - Layer 1 driver: onboard I2C bus (Wire). Pins come from platformio.ini
 * (-DBOARD_I2C_SDA/-DBOARD_I2C_SCL, written by new_app.sh from the board profile); the variant's
 * SDA/SCL (GPIO8/9 on the Saola-1 variant) are NOT the Cucumber's sensor bus.
 */
#include "board_i2c.h"

#include <Wire.h>

#ifndef BOARD_I2C_SDA
    #define BOARD_I2C_SDA   41
#endif
#ifndef BOARD_I2C_SCL
    #define BOARD_I2C_SCL   40
#endif
#define BOARD_I2C_HZ        100000UL

static bool started;

bool board_i2c_begin()
{
    if (!started)
    {
        started = Wire.begin(BOARD_I2C_SDA, BOARD_I2C_SCL, BOARD_I2C_HZ);
    }
    return started;
}

bool board_i2c_probe(uint8_t addr)
{
    if (!board_i2c_begin())
    {
        return false;
    }
    Wire.beginTransmission(addr);
    return Wire.endTransmission() == 0;
}

uint8_t board_i2c_scan(uint8_t *addrs, uint8_t max)
{
    uint8_t n = 0;
    for (uint8_t a = 0x08; a <= 0x77; a++)
    {
        if (board_i2c_probe(a))
        {
            if (n < max)
            {
                addrs[n] = a;
            }
            n++;
        }
    }
    return n;
}
