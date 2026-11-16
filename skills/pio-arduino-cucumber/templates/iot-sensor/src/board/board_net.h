/*
 * board_net.h - Layer 1 driver: Wi-Fi station + settings in NVS (iot-sensor template).
 * Wi-Fi credentials and the MQTT broker are typed by the developer at run time (console
 * "wifi set ..." / "mqtt set ...") and kept in the chip's NVS (Preferences namespace "cuke") -
 * never in source files or git. board_net_*() never print the password.
 */
#ifndef BOARD_NET_H
#define BOARD_NET_H

#include <Arduino.h>

enum board_wifi_state_t
{
    BOARD_WIFI_OFF = 0,
    BOARD_WIFI_CONNECTING,
    BOARD_WIFI_CONNECTED
};

/* settings (NVS strings); get returns false when the key is not set */
bool board_store_get(const char *key, char *buf, size_t size);
bool board_store_set(const char *key, const char *value);
void board_store_erase(const char *key);

/* Wi-Fi station (non-blocking: begin starts the association, state() reports progress) */
void               board_wifi_begin(const char *ssid, const char *pass);
void               board_wifi_stop();
board_wifi_state_t board_wifi_state();
void               board_wifi_ip(char *buf, size_t size);     /* "0.0.0.0" when not connected */
int                board_wifi_rssi();                         /* dBm, 0 when not connected */
void               board_mac_hex(char *buf, size_t size);     /* station MAC, 12 lower-case hex digits */

#endif /* BOARD_NET_H */
