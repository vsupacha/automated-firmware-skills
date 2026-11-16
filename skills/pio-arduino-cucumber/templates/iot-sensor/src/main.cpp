/*
 * main.cpp - Layer 3: application (Arduino sketch). IoT sensor node on the Gravitech Cucumber S.
 *
 *   - sensors (func/sensors over the board drivers MPU6050, BMP280, HTS221): one SENS line every
 *     period (stream on), per-sensor commands imu? baro? hum?, the I2C scan i2c?, a JSON payload
 *   - LED1 (GPIO2) and the RGB LED (GPIO18): led / rgb commands, BOOT toggles LED1
 *   - optional network: Wi-Fi station + MQTT publish of the JSON payload to
 *     <MQTT_TOPIC_BASE>/<id>; <MQTT_TOPIC_BASE>/<id>/cmd accepts {"led":0|1} and {"rgb":[r,g,b]}.
 *     Defaults (broker, topic base, node id) are in app_config.h, the Wi-Fi credentials in the
 *     git-ignored src/secrets.h; values typed at run time ("wifi set", "mqtt set") are kept in NVS
 *     and win. The node runs fine with no network at all.
 *
 * loop() never blocks, except board_mqtt_connect() (TCP connect, a few seconds at most, retried
 * every 10 s while the broker is unreachable).
 */
#include <Arduino.h>

#include "app_config.h"
#include "board/board.h"
#include "board/board_i2c.h"
#include "board/board_mqtt.h"
#include "board/board_net.h"
#include "board/board_rgb.h"
#include "func/button.h"
#include "func/console.h"
#include "func/led.h"
#include "func/sensors.h"

static const char          APP_NAME[]        = "iot-sensor";
static const char          APP_VERSION[]     = "1.0";
static const unsigned long PERIOD_DEFAULT_MS = 5000;
static const unsigned long PERIOD_MIN_MS     = 500;
static const unsigned long NET_TICK_MS       = 1000;
static const unsigned long MQTT_RETRY_MS     = 10000;

static unsigned long period_ms = PERIOD_DEFAULT_MS;
static bool          stream_on = true;
static unsigned long next_sample_ms;
static unsigned long next_net_ms;
static unsigned long next_mqtt_try_ms;
static uint32_t      seq;
static sensors_t     last;

static char               mac_hex[13];
static char               node_id[32];
static char               mqtt_host[64];
static char               topic_sensor[96];
static char               topic_cmd[100];
static bool               mqtt_enabled;
static board_wifi_state_t wifi_prev = BOARD_WIFI_OFF;
static bool               mqtt_prev;
static uint32_t           published;

/* ---- reports ------------------------------------------------------------------------------ */
static void print_info()
{
    console_out().printf("INFO app=%s v=%s board=%s leds=%u btns=%u imu=%d baro=%d hum=%d period_ms=%lu\r\n",
                         APP_NAME, APP_VERSION, BOARD_ID_NAME, led_count(), button_count(),
                         sensors_imu_present() ? 1 : 0, sensors_baro_present() ? 1 : 0,
                         sensors_hum_present() ? 1 : 0, period_ms);
    console_out().println("READY");
}

static void print_leds()
{
    console_out().print("LED");
    for (uint8_t n = 1; n <= led_count(); n++)
    {
        console_out().printf(" led%u=%d", n, led_get(n) ? 1 : 0);
    }
    console_out().println();
}

static void print_rgb()
{
    uint8_t r, g, b;
    board_rgb_get(&r, &g, &b);
    console_out().printf("RGB r=%u g=%u b=%u\r\n", r, g, b);
}

static void print_wifi()
{
    static const char *const NAMES[] = { "off", "connecting", "connected" };
    char ssid[33];
    char ip[16];
    bool have = board_store_get("ssid", ssid, sizeof(ssid)) || (WIFI_SSID_DEFAULT[0] != '\0');
    board_wifi_ip(ip, sizeof(ip));
    console_out().printf("WIFI state=%s saved=%d ip=%s rssi=%d mac=%s\r\n", NAMES[board_wifi_state()],
                         have ? 1 : 0, ip, board_wifi_rssi(), mac_hex);
}

static void print_mqtt()
{
    console_out().printf("MQTT state=%s host=%s topic=%s published=%lu\r\n",
                         board_mqtt_connected() ? "connected" : (mqtt_enabled ? "waiting" : "off"),
                         mqtt_enabled ? mqtt_host : "-", topic_sensor, (unsigned long)published);
}

/* ---- network ------------------------------------------------------------------------------ */
/* NVS first, then the compiled default (src/secrets.h); false = no network known */
static bool wifi_start_saved()
{
    char ssid[33];
    char pass[65];
    if (board_store_get("ssid", ssid, sizeof(ssid)))
    {
        if (!board_store_get("pass", pass, sizeof(pass)))
        {
            pass[0] = '\0';
        }
    }
    else if (WIFI_SSID_DEFAULT[0] != '\0')
    {
        snprintf(ssid, sizeof(ssid), "%s", WIFI_SSID_DEFAULT);
        snprintf(pass, sizeof(pass), "%s", WIFI_PASS_DEFAULT);
    }
    else
    {
        return false;
    }
    board_wifi_begin(ssid, pass);
    memset(pass, 0, sizeof(pass));
    return true;
}

/* NVS "mqtt_host" wins ("off" there = disabled); else MQTT_HOST_DEFAULT ("" = disabled) */
static void mqtt_load()
{
    char     port[8];
    uint16_t p = 0;
    if (board_store_get("mqtt_host", mqtt_host, sizeof(mqtt_host)))
    {
        p = board_store_get("mqtt_port", port, sizeof(port)) ? (uint16_t)atoi(port) : 0;
    }
    else
    {
        snprintf(mqtt_host, sizeof(mqtt_host), "%s", MQTT_HOST_DEFAULT);
    }
    mqtt_enabled = (mqtt_host[0] != '\0') && (strcmp(mqtt_host, "off") != 0);
    if (mqtt_enabled)
    {
        board_mqtt_config(mqtt_host, (p != 0) ? p : (uint16_t)MQTT_PORT_DEFAULT);
    }
}

static bool publish_snapshot(const sensors_t &s)
{
    char payload[BOARD_MQTT_MAX_PAYLOAD];
    if (!board_mqtt_connected() || (sensors_json(payload, sizeof(payload), s, seq, BOARD_ID_NAME) == 0))
    {
        return false;
    }
    if (!board_mqtt_publish(topic_sensor, payload))
    {
        console_out().println("EVT mqtt=publish-failed");
        return false;
    }
    published++;
    console_out().printf("EVT mqtt=published seq=%lu bytes=%u\r\n", (unsigned long)seq, (unsigned)strlen(payload));
    return true;
}

/* {"led":0|1} / {"rgb":[r,g,b]} - a tiny matcher, enough for the two commands */
static void handle_cmd(const char *msg)
{
    const char *p;
    console_out().printf("EVT mqtt=cmd payload=%s\r\n", msg);
    if ((p = strstr(msg, "\"led\":")) != nullptr)
    {
        led_set(1, atoi(p + 6) != 0);
        print_leds();
    }
    if ((p = strstr(msg, "\"rgb\":[")) != nullptr)
    {
        int r = 0, g = 0, b = 0;
        if (sscanf(p + 7, "%d,%d,%d", &r, &g, &b) == 3)
        {
            board_rgb_set((uint8_t)constrain(r, 0, 255), (uint8_t)constrain(g, 0, 255), (uint8_t)constrain(b, 0, 255));
            print_rgb();
        }
    }
}

static void net_tick(unsigned long now)
{
    board_wifi_state_t w = board_wifi_state();
    if (w != wifi_prev)
    {
        char ip[16];
        board_wifi_ip(ip, sizeof(ip));
        if (w == BOARD_WIFI_CONNECTED)       { console_out().printf("EVT wifi=connected ip=%s\r\n", ip); }
        else if (w == BOARD_WIFI_CONNECTING) { console_out().println("EVT wifi=connecting"); }
        else                                 { console_out().println("EVT wifi=off"); }
        wifi_prev = w;
    }
    if ((w == BOARD_WIFI_CONNECTED) && mqtt_enabled && !board_mqtt_connected()
        && ((long)(now - next_mqtt_try_ms) >= 0))
    {
        char id[24];
        snprintf(id, sizeof(id), "cucumber-%s", mac_hex);
        if (board_mqtt_connect(id))
        {
            board_mqtt_subscribe(topic_cmd);
        }
        else
        {
            console_out().printf("EVT mqtt=failed state=%d\r\n", board_mqtt_state());
            next_mqtt_try_ms = now + MQTT_RETRY_MS;
        }
    }
    bool m = board_mqtt_connected();
    if (m != mqtt_prev)
    {
        console_out().printf("EVT mqtt=%s\r\n", m ? "connected" : "disconnected");
        mqtt_prev = m;
    }
}

/* ---- commands ----------------------------------------------------------------------------- */
static void cmd_info(int, char *[]) { print_info(); }
static void cmd_led_q(int, char *[]) { print_leds(); }
static void cmd_rgb_q(int, char *[]) { print_rgb(); }
static void cmd_wifi_q(int, char *[]) { print_wifi(); }
static void cmd_mqtt_q(int, char *[]) { print_mqtt(); }

static void cmd_btn_q(int, char *[])
{
    console_out().print("BTN");
    for (uint8_t n = 1; n <= button_count(); n++)
    {
        console_out().printf(" btn%u=%d", n, button_is_pressed(n) ? 1 : 0);
    }
    console_out().println();
}

/* led <n> on|off|toggle */
static void cmd_led(int argc, char *argv[])
{
    if (argc != 3)
    {
        console_out().println("ERR usage: led <n> on|off|toggle");
        return;
    }
    uint8_t n = (uint8_t)atoi(argv[1]);
    bool    ok;
    if (strcmp(argv[2], "on") == 0)          { ok = led_set(n, true); }
    else if (strcmp(argv[2], "off") == 0)    { ok = led_set(n, false); }
    else if (strcmp(argv[2], "toggle") == 0) { ok = led_toggle(n); }
    else
    {
        console_out().printf("ERR bad action '%s'\r\n", argv[2]);
        return;
    }
    if (ok) { console_out().printf("OK led%u=%d\r\n", n, led_get(n) ? 1 : 0); }
    else    { console_out().printf("ERR no led%s (have %u)\r\n", argv[1], led_count()); }
}

/* rgb <r> <g> <b>   (0..255 each) */
static void cmd_rgb(int argc, char *argv[])
{
    if (argc != 4)
    {
        console_out().println("ERR usage: rgb <r> <g> <b>");
        return;
    }
    int v[3];
    for (int i = 0; i < 3; i++)
    {
        char *end = nullptr;
        long  x   = strtol(argv[i + 1], &end, 10);
        if ((end == argv[i + 1]) || (*end != '\0') || (x < 0) || (x > 255))
        {
            console_out().printf("ERR bad value '%s' (0..255)\r\n", argv[i + 1]);
            return;
        }
        v[i] = (int)x;
    }
    board_rgb_set((uint8_t)v[0], (uint8_t)v[1], (uint8_t)v[2]);
    console_out().printf("OK rgb=%d,%d,%d\r\n", v[0], v[1], v[2]);
}

static void cmd_i2c_q(int, char *[])
{
    uint8_t addrs[16];
    uint8_t n = board_i2c_scan(addrs, sizeof(addrs));
    console_out().printf("I2C n=%u addrs=", n);
    for (uint8_t i = 0; (i < n) && (i < sizeof(addrs)); i++)
    {
        console_out().printf("%s0x%02X", (i > 0) ? "," : "", addrs[i]);
    }
    console_out().println();
}

static void cmd_imu_q(int, char *[])  { sensors_read(&last); sensors_print_imu(console_out(), last); }
static void cmd_baro_q(int, char *[]) { sensors_read(&last); sensors_print_baro(console_out(), last); }
static void cmd_hum_q(int, char *[])  { sensors_read(&last); sensors_print_hum(console_out(), last); }
static void cmd_read(int, char *[])   { sensors_read(&last); sensors_print_line(console_out(), last, ++seq); }

static void cmd_json(int, char *[])
{
    char payload[BOARD_MQTT_MAX_PAYLOAD];
    sensors_read(&last);
    if (sensors_json(payload, sizeof(payload), last, ++seq, BOARD_ID_NAME) == 0)
    {
        console_out().println("ERR json buffer too small");
        return;
    }
    console_out().printf("JSON %s\r\n", payload);
}

/* period <ms> */
static void cmd_period(int argc, char *argv[])
{
    long ms = (argc == 2) ? atol(argv[1]) : 0;
    if (ms < (long)PERIOD_MIN_MS)
    {
        console_out().printf("ERR usage: period <ms>  (>= %lu)\r\n", PERIOD_MIN_MS);
        return;
    }
    period_ms      = (unsigned long)ms;
    next_sample_ms = millis() + period_ms;
    console_out().printf("OK period_ms=%lu\r\n", period_ms);
}

/* stream on|off */
static void cmd_stream(int argc, char *argv[])
{
    if ((argc == 2) && ((strcmp(argv[1], "on") == 0) || (strcmp(argv[1], "off") == 0)))
    {
        stream_on      = (strcmp(argv[1], "on") == 0);
        next_sample_ms = millis() + period_ms;
        console_out().printf("OK stream=%s\r\n", stream_on ? "on" : "off");
        return;
    }
    console_out().println("ERR usage: stream on|off");
}

/* wifi set <ssid> <password> | wifi join | wifi off | wifi forget   (SSIDs with spaces: not supported) */
static void cmd_wifi(int argc, char *argv[])
{
    if ((argc == 4) && (strcmp(argv[1], "set") == 0))
    {
        bool ok = board_store_set("ssid", argv[2]) && board_store_set("pass", argv[3]);
        memset(argv[3], 0, strlen(argv[3]));
        if (!ok)
        {
            console_out().println("ERR could not save to NVS");
            return;
        }
        console_out().println("OK wifi=saved");          /* never echo the password back */
        wifi_start_saved();
        return;
    }
    if ((argc == 2) && (strcmp(argv[1], "join") == 0))
    {
        if (!wifi_start_saved())
        {
            console_out().println("ERR no saved wifi (wifi set <ssid> <password>)");
            return;
        }
        console_out().println("OK wifi=joining");
        return;
    }
    if ((argc == 2) && (strcmp(argv[1], "off") == 0))
    {
        board_mqtt_disconnect();
        board_wifi_stop();
        console_out().println("OK wifi=off");
        return;
    }
    if ((argc == 2) && (strcmp(argv[1], "forget") == 0))
    {
        board_mqtt_disconnect();
        board_wifi_stop();
        board_store_erase("ssid");
        board_store_erase("pass");
        console_out().println("OK wifi=forgotten");
        return;
    }
    console_out().println("ERR usage: wifi set <ssid> <password> | join | off | forget");
}

/* mqtt set <host> [port] | mqtt off */
static void cmd_mqtt(int argc, char *argv[])
{
    if (((argc == 3) || (argc == 4)) && (strcmp(argv[1], "set") == 0))
    {
        bool ok = board_store_set("mqtt_host", argv[2]);
        if (argc == 4)
        {
            ok = ok && board_store_set("mqtt_port", argv[3]);
        }
        else
        {
            board_store_erase("mqtt_port");
        }
        if (!ok)
        {
            console_out().println("ERR could not save to NVS");
            return;
        }
        board_mqtt_disconnect();
        mqtt_load();
        next_mqtt_try_ms = millis();
        console_out().printf("OK mqtt=%s\r\n", argv[2]);
        return;
    }
    if ((argc == 2) && (strcmp(argv[1], "off") == 0))
    {
        board_mqtt_disconnect();
        board_store_set("mqtt_host", "off");     /* survives a reset; "mqtt set" turns it on again */
        board_store_erase("mqtt_port");
        mqtt_enabled = false;
        console_out().println("OK mqtt=off");
        return;
    }
    console_out().println("ERR usage: mqtt set <host> [port] | off");
}

static void cmd_publish(int, char *[])
{
    sensors_read(&last);
    seq++;
    if (!publish_snapshot(last))
    {
        console_out().println("ERR mqtt not connected (wifi? mqtt?)");
    }
}

static const console_cmd_t commands[] =
{
    { "info",    "info                    - app/board info",                cmd_info    },
    { "led",     "led <n> on|off|toggle   - drive LEDn",                    cmd_led     },
    { "led?",    "led?                    - read back LEDs",                cmd_led_q   },
    { "btn?",    "btn?                    - button states",                 cmd_btn_q   },
    { "rgb",     "rgb <r> <g> <b>         - RGB LED colour 0..255",         cmd_rgb     },
    { "rgb?",    "rgb?                    - last RGB colour",               cmd_rgb_q   },
    { "i2c?",    "i2c?                    - scan the onboard I2C bus",      cmd_i2c_q   },
    { "imu?",    "imu?                    - MPU6050 accel/gyro/temp",       cmd_imu_q   },
    { "baro?",   "baro?                   - BMP280 pressure/temp",          cmd_baro_q  },
    { "hum?",    "hum?                    - HTS221 humidity/temp",          cmd_hum_q   },
    { "read",    "read                    - one SENS line now",             cmd_read    },
    { "json",    "json                    - the MQTT payload now",          cmd_json    },
    { "period",  "period <ms>             - SENS/publish period",           cmd_period  },
    { "stream",  "stream on|off           - periodic SENS lines",           cmd_stream  },
    { "wifi",    "wifi set <ssid> <pw>|join|off|forget - Wi-Fi in NVS",     cmd_wifi    },
    { "wifi?",   "wifi?                   - Wi-Fi state",                   cmd_wifi_q  },
    { "mqtt",    "mqtt set <host> [port]|off - broker in NVS",              cmd_mqtt    },
    { "mqtt?",   "mqtt?                   - MQTT state",                    cmd_mqtt_q  },
    { "publish", "publish                 - publish one payload now",       cmd_publish },
};

void setup()
{
    board_init();
    led_init();
    button_init();
    board_rgb_begin();
    sensors_init();
    board_mac_hex(mac_hex, sizeof(mac_hex));
    snprintf(node_id, sizeof(node_id), "%s", (APP_NODE_ID[0] != '\0') ? APP_NODE_ID : mac_hex);
    snprintf(topic_sensor, sizeof(topic_sensor), "%s/%s", MQTT_TOPIC_BASE, node_id);
    snprintf(topic_cmd, sizeof(topic_cmd), "%s/cmd", topic_sensor);
    mqtt_load();
    console_init(commands, sizeof(commands) / sizeof(commands[0]));
    console_out().println();
    console_out().printf("[APP] %s %s on %s - type 'help'\r\n", APP_NAME, APP_VERSION, BOARD_ID_NAME);
    print_info();
    wifi_start_saved();                 /* NVS or src/secrets.h; nothing known = stays off */
    next_sample_ms = millis() + period_ms;
    next_net_ms    = millis();
}

void loop()
{
    unsigned long now = millis();
    uint8_t       num;
    button_evt_t  evt = button_poll(&num);

    if (evt == BUTTON_EVT_PRESSED)
    {
        led_toggle(num);
        console_out().printf("EVT btn%u=pressed name=%s pin=GPIO%u led%u=%d\r\n", num,
                             button_name(num), board_button_pin(num), num, led_get(num) ? 1 : 0);
    }
    else if (evt == BUTTON_EVT_RELEASED)
    {
        console_out().printf("EVT btn%u=released\r\n", num);
    }

    if (stream_on && ((long)(now - next_sample_ms) >= 0))
    {
        next_sample_ms += period_ms;
        sensors_read(&last);
        sensors_print_line(console_out(), last, ++seq);
        publish_snapshot(last);
    }
    if ((long)(now - next_net_ms) >= 0)
    {
        next_net_ms = now + NET_TICK_MS;
        net_tick(now);
    }
    board_mqtt_poll();
    char msg[BOARD_MQTT_MAX_PAYLOAD + 1];
    if (board_mqtt_take(msg, sizeof(msg)))
    {
        handle_cmd(msg);
    }
    console_poll();
}
