/*
 * board.cpp - Layer 1: board adaptation for RA4M1 boards on the Arduino UNO R4 core (Renesas).
 *
 * UNO R4 WiFi: Serial is a RA4M1 UART wired to the ESP32-S3 module, whose firmware bridges it to
 * the USB-C port (USB CDC, the board's COM port). It is a real UART: prints never wait for a host,
 * and the baud rate set here must match the host (115200).
 */
#include "board.h"

struct board_pin_t
{
    uint8_t     pin;
    bool        active_high;
    const char *name;
};

#if defined(BOARD_UNO_R4_WIFI)
/* LED1 = the yellow "L" LED on D13 (LED_BUILTIN, RA4M1 P102), active high. No user button: the
 * only button is RESET. The 12x8 LED matrix and the TX/RX LEDs are not user LEDs here. */
static const board_pin_t LEDS[]      = { { LED_BUILTIN, true, "L" } };
static const uint8_t     NUM_LEDS    = sizeof(LEDS) / sizeof(LEDS[0]);
#else
static const board_pin_t LEDS[]      = { { 0, true, "-" } };
static const uint8_t     NUM_LEDS    = 0;
#endif
static const board_pin_t BUTTONS[]   = { { 0, false, "-" } };   /* placeholder: no user button */
static const uint8_t     NUM_BUTTONS = 0;

void board_init()
{
    Serial.begin(115200);               /* UART to the USB bridge: the host uses 115200 too */
    for (uint8_t i = 0; i < NUM_LEDS; i++)
    {
        pinMode(LEDS[i].pin, OUTPUT);   /* digitalRead of an output reads the port pin: read-back works */
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
