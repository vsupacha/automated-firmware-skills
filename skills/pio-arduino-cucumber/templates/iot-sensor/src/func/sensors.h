/*
 * sensors.h - Layer 2: the onboard sensors as one service (Arduino API + the board drivers
 * board_imu.h / board_baro.h / board_hum.h). Starts the drivers, takes a snapshot of all of them and
 * formats it as console report lines and as a JSON payload (no JSON library: snprintf). A sensor
 * that is missing or fails a read is reported as ok=0 / null - the other sensors still report.
 */
#ifndef SENSORS_H
#define SENSORS_H

#include <Arduino.h>

#include "../board/board_baro.h"
#include "../board/board_hum.h"
#include "../board/board_imu.h"

struct sensors_t
{
    bool         imu_ok;
    bool         baro_ok;
    bool         hum_ok;
    board_imu_t  imu;
    board_baro_t baro;
    board_hum_t  hum;
};

uint8_t sensors_init();                         /* begins every driver; returns how many answered */
bool    sensors_imu_present();
bool    sensors_baro_present();
bool    sensors_hum_present();
void    sensors_read(sensors_t *s);             /* one snapshot of all sensors */

/* report lines (test contract, CR LF):
 *   IMU ok=1 ax=0.12 ay=-0.05 az=9.79 gx=0.001 gy=-0.002 gz=0.000 t=29.4
 *   BARO ok=1 p=100912.4 t=30.1
 *   HUM ok=1 rh=55.3 t=29.8
 *   SENS seq=12 t=29.8 rh=55.3 p=100912.4 ax=0.12 ay=-0.05 az=9.79 gx=0.001 gy=-0.002 gz=0.000 */
void   sensors_print_imu(Print &out, const sensors_t &s);
void   sensors_print_baro(Print &out, const sensors_t &s);
void   sensors_print_hum(Print &out, const sensors_t &s);
void   sensors_print_line(Print &out, const sensors_t &s, uint32_t seq);

/* JSON payload, field names as the LE380 POC dashboard expects (type, temperature, humidity,
 * pressure, acceleration_x/y/z) + seq, board and gyro_x/y/z. Returns the length (0 = buffer too small). */
size_t sensors_json(char *buf, size_t size, const sensors_t &s, uint32_t seq, const char *board);

#endif /* SENSORS_H */
