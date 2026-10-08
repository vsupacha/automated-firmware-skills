/*
 * board_io.c - Layer 1: board adaptation for RA8D1 boards on RT-Thread (pin device of the RA BSP:
 * the pin number is the FSP's BSP_IO_PORT_xx_PIN_yy value).
 */
#include "board_io.h"

#include <rtdevice.h>
#include "hal_data.h"

typedef struct
{
    rt_base_t   pin;
    bool        active_high;
    const char *name;
    const char *pin_name;
} board_pin_t;

#if defined(BOARD_VISION_BOARD)
/* RGB LED, common anode: a colour lights when its pin is LOW. P102 = blue (BSP blink example);
 * P106 and PA07 are the other two colours (OpenMV port of the Vision Board) - which is red and
 * which is green: see boards/vision-board/README.md. KEY0 = P907, input (external pull),
 * pressed = LOW. */
static const board_pin_t LEDS[] =
{
    { BSP_IO_PORT_01_PIN_02, false, "LED P102", "P102" },
    { BSP_IO_PORT_01_PIN_06, false, "LED P106", "P106" },
    { BSP_IO_PORT_10_PIN_07, false, "LED PA07", "PA07" },
};
static const board_pin_t BUTTONS[] =
{
    { BSP_IO_PORT_09_PIN_07, false, "KEY0", "P907" },
};
#define NUM_LEDS    (sizeof(LEDS) / sizeof(LEDS[0]))
#define NUM_BUTTONS (sizeof(BUTTONS) / sizeof(BUTTONS[0]))
#else
static const board_pin_t LEDS[]    = { { 0, false, "-", "-" } };
static const board_pin_t BUTTONS[] = { { 0, false, "-", "-" } };
#define NUM_LEDS    0U
#define NUM_BUTTONS 0U
#endif

void board_io_init(void)
{
    for (uint8_t i = 0; i < NUM_LEDS; i++)
    {
        rt_pin_mode(LEDS[i].pin, PIN_MODE_OUTPUT);
        rt_pin_write(LEDS[i].pin, LEDS[i].active_high ? PIN_LOW : PIN_HIGH);
    }
    for (uint8_t i = 0; i < NUM_BUTTONS; i++)
    {
        rt_pin_mode(BUTTONS[i].pin, PIN_MODE_INPUT);
    }
}

uint8_t board_led_count(void)
{
    return (uint8_t)NUM_LEDS;
}

bool board_led_write(uint8_t n, bool on)
{
    if ((n < 1) || (n > NUM_LEDS))
    {
        return false;
    }
    const board_pin_t *led = &LEDS[n - 1];
    rt_pin_write(led->pin, (on == led->active_high) ? PIN_HIGH : PIN_LOW);
    return true;
}

bool board_led_read(uint8_t n)
{
    if ((n < 1) || (n > NUM_LEDS))
    {
        return false;
    }
    const board_pin_t *led = &LEDS[n - 1];
    return (rt_pin_read(led->pin) == PIN_HIGH) == led->active_high;
}

const char *board_led_name(uint8_t n)
{
    return ((n >= 1) && (n <= NUM_LEDS)) ? LEDS[n - 1].name : "?";
}

uint8_t board_button_count(void)
{
    return (uint8_t)NUM_BUTTONS;
}

bool board_button_read(uint8_t n)
{
    if ((n < 1) || (n > NUM_BUTTONS))
    {
        return false;
    }
    const board_pin_t *btn = &BUTTONS[n - 1];
    return (rt_pin_read(btn->pin) == PIN_HIGH) == btn->active_high;
}

const char *board_button_name(uint8_t n)
{
    return ((n >= 1) && (n <= NUM_BUTTONS)) ? BUTTONS[n - 1].name : "?";
}

const char *board_button_pin(uint8_t n)
{
    return ((n >= 1) && (n <= NUM_BUTTONS)) ? BUTTONS[n - 1].pin_name : "?";
}
