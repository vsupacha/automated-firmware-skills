/*
 * board.cpp - Layer 1: board adaptation for ESP32-S3 boards on the arduino-esp32 core.
 *
 * Serial is the ESP32-S3 USB Serial/JTAG (the board json sets USB CDC on boot). While no host has
 * the port open, Serial drops output instead of blocking, so an unattended board never hangs.
 */
#include "board.h"

struct board_pin_t
{
    uint8_t     pin;
    bool        active_high;
    const char *name;
};

#if defined(BOARD_ESP32_S3_BOX)
/* No user LED on the BOX: LED1 = LCD backlight TFT_BL (GPIO45, a strapping pin - driven only
 * after boot). BOOT = GPIO0, active low with an external pull-up. */
static const board_pin_t LEDS[]    = { { TFT_BL, true,  "LCD backlight" } };
static const board_pin_t BUTTONS[] = { { 0,      false, "BOOT" } };
static const uint8_t     NUM_LEDS  = sizeof(LEDS) / sizeof(LEDS[0]);
#else
static const board_pin_t LEDS[]    = { { 0,      true,  "-" } };
static const board_pin_t BUTTONS[] = { { 0,      false, "BOOT" } };
static const uint8_t     NUM_LEDS  = 0;
#endif
static const uint8_t     NUM_BUTTONS = sizeof(BUTTONS) / sizeof(BUTTONS[0]);

void board_init()
{
    Serial.begin(115200);               /* USB: the baud rate is ignored, kept for clarity */
    for (uint8_t i = 0; i < NUM_LEDS; i++)
    {
        pinMode(LEDS[i].pin, OUTPUT);   /* arduino-esp32 OUTPUT keeps the input path: read-back works */
        digitalWrite(LEDS[i].pin, LEDS[i].active_high ? LOW : HIGH);
    }
    for (uint8_t i = 0; i < NUM_BUTTONS; i++)
    {
        pinMode(BUTTONS[i].pin, BUTTONS[i].active_high ? INPUT_PULLDOWN : INPUT_PULLUP);
    }
}

Stream &board_console()
{
    return Serial;
}

uint8_t board_led_count()
{
    return NUM_LEDS;
}

bool board_led_write(uint8_t n, bool on)
{
    if ((n < 1) || (n > NUM_LEDS))
    {
        return false;
    }
    const board_pin_t &led = LEDS[n - 1];
    digitalWrite(led.pin, (on == led.active_high) ? HIGH : LOW);
    return true;
}

bool board_led_read(uint8_t n)
{
    if ((n < 1) || (n > NUM_LEDS))
    {
        return false;
    }
    const board_pin_t &led = LEDS[n - 1];
    return (digitalRead(led.pin) == HIGH) == led.active_high;
}

const char *board_led_name(uint8_t n)
{
    return ((n >= 1) && (n <= NUM_LEDS)) ? LEDS[n - 1].name : "?";
}

uint8_t board_button_count()
{
    return NUM_BUTTONS;
}

bool board_button_read(uint8_t n)
{
    if ((n < 1) || (n > NUM_BUTTONS))
    {
        return false;
    }
    const board_pin_t &btn = BUTTONS[n - 1];
    return (digitalRead(btn.pin) == HIGH) == btn.active_high;
}

const char *board_button_name(uint8_t n)
{
    return ((n >= 1) && (n <= NUM_BUTTONS)) ? BUTTONS[n - 1].name : "?";
}

uint8_t board_button_pin(uint8_t n)
{
    return ((n >= 1) && (n <= NUM_BUTTONS)) ? BUTTONS[n - 1].pin : 0;
}
