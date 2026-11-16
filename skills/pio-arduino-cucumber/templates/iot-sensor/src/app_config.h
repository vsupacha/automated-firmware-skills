/*
 * app_config.h - Layer 3: compile-time defaults of the iot-sensor app (edit here).
 *
 * Values typed at run time ("wifi set", "mqtt set") are kept in NVS and win over these defaults.
 * Topics: <MQTT_TOPIC_BASE>/<id> (JSON payload) and <MQTT_TOPIC_BASE>/<id>/cmd (commands);
 * <id> = APP_NODE_ID, or the station MAC (12 hex digits) when APP_NODE_ID is "".
 *
 * Wi-Fi credentials are NOT here: put them in src/secrets.h (copy secrets.example.h). That file
 * is git-ignored - never commit a password. Without it the node waits for "wifi set".
 */
#ifndef APP_CONFIG_H
#define APP_CONFIG_H

#define APP_NODE_ID        ""                          /* "" = use the MAC; max 31 chars, no '/' '+' '#' */
#define MQTT_HOST_DEFAULT  "broker.emqx.io"            /* public test broker: every reader sees the payloads */
#define MQTT_PORT_DEFAULT  1883
#define MQTT_TOPIC_BASE    "tu/tse/le380/iot_sensor"

#if defined(__has_include)
#if __has_include("secrets.h")
#include "secrets.h"
#endif
#endif
#ifndef WIFI_SSID_DEFAULT
#define WIFI_SSID_DEFAULT  ""                          /* "" = no default network */
#endif
#ifndef WIFI_PASS_DEFAULT
#define WIFI_PASS_DEFAULT  ""
#endif

#endif /* APP_CONFIG_H */
