/*
 * board_baro.cpp - Layer 1 driver: BMP280 through Adafruit BMP280 Library 2.6.8 (pinned in the
 * board profile). Normal mode, temperature x2, pressure x16 oversampling, IIR x16, 63 ms standby.
 */
#include "board_baro.h"

#include <Adafruit_BMP280.h>
#include "board_i2c.h"

static Adafruit_BMP280 bmp(&Wire);
static bool            present;

bool board_baro_begin()
{
    present = board_i2c_begin() && bmp.begin(BOARD_I2C_ADDR_BMP280);
    if (present)
    {
        bmp.setSampling(Adafruit_BMP280::MODE_NORMAL, Adafruit_BMP280::SAMPLING_X2,
                        Adafruit_BMP280::SAMPLING_X16, Adafruit_BMP280::FILTER_X16,
                        Adafruit_BMP280::STANDBY_MS_63);
    }
    return present;
}

bool board_baro_present()
{
    return present;
}

bool board_baro_read(board_baro_t *out)
{
    if (!present || (out == nullptr))
    {
        return false;
    }
    out->temp_c      = bmp.readTemperature();
    out->pressure_pa = bmp.readPressure();
    return !isnan(out->temp_c) && !isnan(out->pressure_pa);
}
