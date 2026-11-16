/*
 * board_mqtt.cpp - Layer 1 driver: PubSubClient on a WiFiClient. Buffer 512 bytes (the JSON payload
 * is ~300 bytes; PubSubClient's default 256 would drop it).
 */
#include "board_mqtt.h"

#include <PubSubClient.h>
#include <WiFi.h>

static WiFiClient   tcp;
static PubSubClient mqtt(tcp);
static char         host_buf[64];
static char         inbox[BOARD_MQTT_MAX_PAYLOAD + 1];
static bool         inbox_full;

static void on_message(char *topic, byte *payload, unsigned int length)
{
    (void)topic;
    size_t n = (length < BOARD_MQTT_MAX_PAYLOAD) ? length : BOARD_MQTT_MAX_PAYLOAD;
    memcpy(inbox, payload, n);
    inbox[n]   = '\0';
    inbox_full = true;
}

void board_mqtt_config(const char *host, uint16_t port)
{
    strncpy(host_buf, host, sizeof(host_buf) - 1);
    host_buf[sizeof(host_buf) - 1] = '\0';
    mqtt.setServer(host_buf, port);
    mqtt.setBufferSize(512);
    mqtt.setCallback(on_message);
    mqtt.setSocketTimeout(3);
}

bool board_mqtt_connect(const char *client_id)
{
    tcp.setTimeout(3);                  /* seconds: bounds the blocking connect */
    return mqtt.connect(client_id);
}

bool board_mqtt_connected()                { return mqtt.connected(); }
int  board_mqtt_state()                    { return mqtt.state(); }
void board_mqtt_disconnect()               { mqtt.disconnect(); }
bool board_mqtt_subscribe(const char *t)   { return mqtt.subscribe(t); }
bool board_mqtt_publish(const char *t, const char *p) { return mqtt.publish(t, p); }
void board_mqtt_poll()                     { mqtt.loop(); }

bool board_mqtt_take(char *payload, size_t size)
{
    if (!inbox_full || (payload == nullptr) || (size == 0))
    {
        return false;
    }
    strncpy(payload, inbox, size - 1);
    payload[size - 1] = '\0';
    inbox_full = false;
    return true;
}
