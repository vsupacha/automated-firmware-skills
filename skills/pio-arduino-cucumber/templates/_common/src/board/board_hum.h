/*
 * board_hum.h - Layer 1 driver: HTS221 relative humidity + temperature on the onboard I2C bus
 * (0x5F, WHO_AM_I 0xBC). Units: %RH, degC.
 */
#ifndef BOARD_HUM_H
#define BOARD_HUM_H

#include <Arduino.h>

struct board_hum_t
{
    float rh;               /* % relative humidity */
    float temp_c;
};

bool board_hum_begin();                     /* false = no HTS221 answered */
bool board_hum_present();
bool board_hum_read(board_hum_t *out);

#endif /* BOARD_HUM_H */
