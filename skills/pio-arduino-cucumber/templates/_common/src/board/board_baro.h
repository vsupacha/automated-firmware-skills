/*
 * board_baro.h - Layer 1 driver: BMP280 barometric pressure + temperature on the onboard I2C bus
 * (0x76, chip id 0x58). Units: Pa, degC.
 */
#ifndef BOARD_BARO_H
#define BOARD_BARO_H

#include <Arduino.h>

struct board_baro_t
{
    float pressure_pa;
    float temp_c;
};

bool board_baro_begin();                    /* false = no BMP280 answered */
bool board_baro_present();
bool board_baro_read(board_baro_t *out);    /* false = not present or the reading is not a number */

#endif /* BOARD_BARO_H */
