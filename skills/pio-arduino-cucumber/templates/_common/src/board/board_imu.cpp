/*
 * board_imu.cpp - Layer 1 driver: MPU6050 through Adafruit MPU6050 2.2.6 (pinned in the board
 * profile). The library object lives only in this file.
 */
#include "board_imu.h"

#include <Adafruit_MPU6050.h>
#include "board_i2c.h"

static Adafruit_MPU6050 mpu;
static bool             present;

bool board_imu_begin()
{
    present = board_i2c_begin() && mpu.begin(BOARD_I2C_ADDR_MPU6050, &Wire);
    if (present)
    {
        mpu.setAccelerometerRange(MPU6050_RANGE_2_G);
        mpu.setGyroRange(MPU6050_RANGE_250_DEG);
        mpu.setFilterBandwidth(MPU6050_BAND_21_HZ);
    }
    return present;
}

bool board_imu_present()
{
    return present;
}

bool board_imu_read(board_imu_t *out)
{
    sensors_event_t a, g, t;
    if (!present || (out == nullptr) || !mpu.getEvent(&a, &g, &t))
    {
        return false;
    }
    out->ax     = a.acceleration.x;
    out->ay     = a.acceleration.y;
    out->az     = a.acceleration.z;
    out->gx     = g.gyro.x;
    out->gy     = g.gyro.y;
    out->gz     = g.gyro.z;
    out->temp_c = t.temperature;
    return true;
}
