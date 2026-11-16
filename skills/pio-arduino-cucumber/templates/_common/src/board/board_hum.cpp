/*
 * board_hum.cpp - Layer 1 driver: HTS221 through Adafruit HTS221 0.1.5 (pinned in the board
 * profile). 1 Hz output data rate - enough for a few-second IoT period.
 */
#include "board_hum.h"

#include <Adafruit_HTS221.h>
#include "board_i2c.h"

static Adafruit_HTS221 hts;
static bool            present;

bool board_hum_begin()
{
    present = board_i2c_begin() && hts.begin_I2C(BOARD_I2C_ADDR_HTS221, &Wire);
    if (present)
    {
        hts.setDataRate(HTS221_RATE_1_HZ);
    }
    return present;
}

bool board_hum_present()
{
    return present;
}

bool board_hum_read(board_hum_t *out)
{
    sensors_event_t h, t;
    if (!present || (out == nullptr) || !hts.getEvent(&h, &t))
    {
        return false;
    }
    out->rh     = h.relative_humidity;
    out->temp_c = t.temperature;
    return true;
}
