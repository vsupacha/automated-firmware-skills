/*
 * board_imu.h - Layer 1 driver: MPU6050 accelerometer + gyroscope + die temperature on the onboard
 * I2C bus (0x68, WHO_AM_I 0x68). Units: m/s^2, rad/s, degC. begin() sets +-2 g, +-250 deg/s and a
 * 21 Hz low-pass filter (quiet readings for a resting board).
 */
#ifndef BOARD_IMU_H
#define BOARD_IMU_H

#include <Arduino.h>

struct board_imu_t
{
    float ax, ay, az;       /* m/s^2 */
    float gx, gy, gz;       /* rad/s */
    float temp_c;           /* MPU6050 die temperature */
};

bool board_imu_begin();                 /* false = no MPU6050 answered */
bool board_imu_present();               /* result of the last begin */
bool board_imu_read(board_imu_t *out);  /* false = not present or bus error */

#endif /* BOARD_IMU_H */
