/*******************************************************************************
* File Name : board_fake.c
*
* Fake board for host tests: board.h backed by variables (see board.h).
*******************************************************************************/
#include "board.h"

#include <stdio.h>
#include <string.h>

static uint32_t n_leds;
static uint32_t n_buttons;
static bool     led[FAKE_MAX_IO];
static bool     button[FAKE_MAX_IO];
static uint32_t led_writes;
static uint32_t now_ms;
static uint32_t fatal_calls;
static char     rx[512];
static size_t   rx_len;
static size_t   rx_pos;

static const char *const led_names[FAKE_MAX_IO] =
    { "LED1", "LED2", "LED3", "LED4", "LED5", "LED6", "LED7", "LED8" };
static const char *const button_names[FAKE_MAX_IO] =
    { "SW1", "SW2", "SW3", "SW4", "SW5", "SW6", "SW7", "SW8" };
static const char *const button_pins[FAKE_MAX_IO] =
    { "P0.0", "P0.1", "P0.2", "P0.3", "P0.4", "P0.5", "P0.6", "P0.7" };

void fake_reset(uint32_t leds, uint32_t buttons)
{
    n_leds      = (leds > FAKE_MAX_IO) ? FAKE_MAX_IO : leds;
    n_buttons   = (buttons > FAKE_MAX_IO) ? FAKE_MAX_IO : buttons;
    memset(led, 0, sizeof(led));
    memset(button, 0, sizeof(button));
    led_writes  = 0U;
    now_ms      = 0U;
    fatal_calls = 0U;
    rx_len      = 0U;
    rx_pos      = 0U;
}

void fake_advance_ms(uint32_t ms)       { now_ms += ms; }
bool fake_led_get(uint32_t idx)         { return (idx < FAKE_MAX_IO) && led[idx]; }
uint32_t fake_led_writes(void)          { return led_writes; }
uint32_t fake_fatal_calls(void)         { return fatal_calls; }

void fake_button_set(uint32_t idx, bool pressed)
{
    if (idx < FAKE_MAX_IO)
    {
        button[idx] = pressed;
    }
}

void fake_led_force(uint32_t idx, bool on)
{
    if (idx < FAKE_MAX_IO)
    {
        led[idx] = on;
    }
}

void fake_console_input(const char *s)
{
    size_t n = strlen(s);

    if (rx_pos == rx_len)
    {
        rx_pos = 0U;
        rx_len = 0U;
    }
    if (n > (sizeof(rx) - rx_len))
    {
        n = sizeof(rx) - rx_len;
    }
    memcpy(&rx[rx_len], s, n);
    rx_len += n;
}

/* ---- board.h ---- */

void     board_init(void)               { }
void     board_delay_ms(uint32_t ms)    { now_ms += ms; }
uint32_t board_millis(void)             { return now_ms; }
void     board_fatal(void)              { fatal_calls++; }

uint32_t board_led_count(void)          { return n_leds; }

void board_led_write(uint32_t idx, bool on)
{
    if (idx < n_leds)
    {
        led[idx] = on;
        led_writes++;
    }
}

bool board_led_read(uint32_t idx)
{
    return (idx < n_leds) && led[idx];
}

const char *board_led_name(uint32_t idx)
{
    return (idx < n_leds) ? led_names[idx] : "?";
}

uint32_t board_button_count(void)       { return n_buttons; }

bool board_button_is_pressed(uint32_t idx)
{
    return (idx < n_buttons) && button[idx];
}

const char *board_button_name(uint32_t idx)
{
    return (idx < n_buttons) ? button_names[idx] : "?";
}

const char *board_button_pin(uint32_t idx)
{
    return (idx < n_buttons) ? button_pins[idx] : "?";
}

bool board_console_getc(char *c)
{
    if (rx_pos < rx_len)
    {
        *c = rx[rx_pos++];
        return true;
    }
    return false;
}

void board_console_flush(void)
{
    fflush(stdout);
}
