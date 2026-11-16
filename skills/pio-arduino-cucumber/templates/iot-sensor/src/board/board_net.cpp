/*
 * board_net.cpp - Layer 1 driver: arduino-esp32 WiFi (station) + Preferences (NVS).
 */
#include "board_net.h"

#include <Preferences.h>
#include <WiFi.h>

static const char NVS_NS[] = "cuke";
static bool       wifi_on;

bool board_store_get(const char *key, char *buf, size_t size)
{
    Preferences p;
    if ((buf == nullptr) || (size == 0) || !p.begin(NVS_NS, true))
    {
        return false;
    }
    bool   have = p.isKey(key);
    size_t n    = have ? p.getString(key, buf, size) : 0;
    p.end();
    if (n == 0)
    {
        buf[0] = '\0';
    }
    return have && (n > 0);
}

bool board_store_set(const char *key, const char *value)
{
    Preferences p;
    if (!p.begin(NVS_NS, false))
    {
        return false;
    }
    size_t n = p.putString(key, value);
    p.end();
    return n == strlen(value);
}

void board_store_erase(const char *key)
{
    Preferences p;
    if (p.begin(NVS_NS, false))
    {
        p.remove(key);
        p.end();
    }
}

void board_wifi_begin(const char *ssid, const char *pass)
{
    WiFi.persistent(false);             /* credentials live in our NVS keys, not in the Wi-Fi driver's */
    WiFi.mode(WIFI_STA);
    WiFi.setAutoReconnect(true);
    WiFi.begin(ssid, pass);
    wifi_on = true;
}

void board_wifi_stop()
{
    WiFi.disconnect(true);
    WiFi.mode(WIFI_OFF);
    wifi_on = false;
}

board_wifi_state_t board_wifi_state()
{
    if (!wifi_on)
    {
        return BOARD_WIFI_OFF;
    }
    return (WiFi.status() == WL_CONNECTED) ? BOARD_WIFI_CONNECTED : BOARD_WIFI_CONNECTING;
}

void board_wifi_ip(char *buf, size_t size)
{
    IPAddress ip = (board_wifi_state() == BOARD_WIFI_CONNECTED) ? WiFi.localIP() : IPAddress(0, 0, 0, 0);
    snprintf(buf, size, "%u.%u.%u.%u", ip[0], ip[1], ip[2], ip[3]);
}

int board_wifi_rssi()
{
    return (board_wifi_state() == BOARD_WIFI_CONNECTED) ? WiFi.RSSI() : 0;
}

void board_mac_hex(char *buf, size_t size)
{
    uint8_t m[6];
    WiFi.macAddress(m);
    snprintf(buf, size, "%02x%02x%02x%02x%02x%02x", m[0], m[1], m[2], m[3], m[4], m[5]);
}
