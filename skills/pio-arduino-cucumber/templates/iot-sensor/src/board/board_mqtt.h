/*
 * board_mqtt.h - Layer 1 driver: MQTT 3.1.1 client over the Wi-Fi station (PubSubClient 2.8, pinned
 * in the board profile, PIO_LIB_DEPS_NET). Plain TCP (port 1883 by default), no TLS, no
 * user/password: use a test broker or one on your own network - every reader of the broker sees
 * the payloads. Incoming messages on subscribed topics are kept in a one-message mailbox.
 */
#ifndef BOARD_MQTT_H
#define BOARD_MQTT_H

#include <Arduino.h>

#define BOARD_MQTT_MAX_PAYLOAD  384

void board_mqtt_config(const char *host, uint16_t port);
bool board_mqtt_connect(const char *client_id);     /* BLOCKS up to a few seconds (TCP connect) */
bool board_mqtt_connected();
int  board_mqtt_state();                            /* PubSubClient state code (0 = connected) */
void board_mqtt_disconnect();
bool board_mqtt_subscribe(const char *topic);
bool board_mqtt_publish(const char *topic, const char *payload);
void board_mqtt_poll();                             /* keep-alive + receive; call from loop() */
bool board_mqtt_take(char *payload, size_t size);   /* true = a message was waiting (copied, then cleared) */

#endif /* BOARD_MQTT_H */
