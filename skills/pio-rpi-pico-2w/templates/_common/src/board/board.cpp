/*
 * board.cpp - Layer 1: board adaptation for RP2350 boards on the arduino-pico core.
 */
#include "board.h"

void board_init(void)
{
    Serial.begin(115200);               /* USB CDC: the baud rate is ignored, kept for clarity */
    pinMode(LED_BUILTIN, OUTPUT);       /* Pico 2 W: CYW43 WL_GPIO0, driven by the core */
    digitalWrite(LED_BUILTIN, LOW);
}

uint32_t board_millis(void)
{
    return millis();
}

void board_delay_ms(uint32_t ms)
{
    delay(ms);
}

Print &board_console(void)
{
    return Serial;
}

bool board_console_getc(char *c)
{
    if (Serial.available() > 0)
    {
        *c = (char)Serial.read();
        return true;
    }
    return false;
}

uint32_t board_led_count(void)
{
    return BOARD_NUM_LEDS;
}

bool board_led_write(uint32_t n, bool on)
{
    if (n != 1U)
    {
        return false;
    }
    digitalWrite(LED_BUILTIN, on ? HIGH : LOW);
    return true;
}

uint32_t board_button_count(void)
{
    return BOARD_NUM_BUTTONS;
}

bool board_button_read(uint32_t n)
{
    /* BOOTSEL shares the QSPI chip-select line; the core briefly suspends flash access to read
     * it - fine for polling, never call it from an interrupt */
    return (n == 1U) && BOOTSEL;
}

const char *board_button_name(uint32_t n)
{
    return (n == 1U) ? "BOOTSEL" : "?";
}
