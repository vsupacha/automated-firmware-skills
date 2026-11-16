/*
 * board_i2c.h - Layer 1 driver: the onboard I2C bus of the Cucumber S (Wire, SDA GPIO41, SCL
 * GPIO40, 100 kHz - pins from the Gravitech pinout and cucumber-library). The sensor drivers call
 * board_i2c_begin() themselves; func/ uses probe/scan for the "i2c?" report.
 */
#ifndef BOARD_I2C_H
#define BOARD_I2C_H

#include <Arduino.h>

#define BOARD_I2C_ADDR_HTS221   0x5F
#define BOARD_I2C_ADDR_MPU6050  0x68
#define BOARD_I2C_ADDR_BMP280   0x76

bool    board_i2c_begin();                              /* idempotent; false = bus init failed */
bool    board_i2c_probe(uint8_t addr);                  /* true = a device ACKs this address */
uint8_t board_i2c_scan(uint8_t *addrs, uint8_t max);    /* 0x08..0x77, ascending; returns count */

#endif /* BOARD_I2C_H */
