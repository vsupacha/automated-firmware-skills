/*******************************************************************************
* File Name : board.c
*
* Layer 1 - board adaptation for STM32F4 boards on the STM32CubeF4 HAL.
*
* What comes from STM32CubeMX (the app's .ioc, from the CubeMX board
* configuration, regenerated into mx/): clocks, the LED outputs and the B1
* input (MX_GPIO_Init()), SWO on PB3 (SYS: Trace Asynchronous Sw).
* What is done here: the user I/O table, the console glue (_write -> ITM).
*
* STM32F407G-DISC1 (STM32CubeF4 BSP Drivers/BSP/STM32F4-Discovery): LD3 orange
* PD13, LD4 green PD12, LD5 red PD14, LD6 blue PD15, all active HIGH; B1 PA0
* with an external pull-down, pressed = HIGH.
*
* Console: printf() goes to ITM stimulus port 0 = SWO through the ST-LINK. The
* debugger configures SWO (core clock = SYSCLK_HZ of the board profile); with
* no SWO viewer attached, ITM output is discarded - an unattended board never
* blocks. There is no console input (the board's ST-LINK/V2 has no VCP).
*******************************************************************************/
#include "board.h"

#include <stdio.h>

#include "main.h"

typedef struct
{
    GPIO_TypeDef *port;
    uint16_t      pin;
    bool          active_high;
    const char   *name;
    const char   *pin_name;
} board_io_t;

#if defined(BOARD_STM32F407G_DISC1)
static const board_io_t leds[] =
{
    { GPIOD, GPIO_PIN_13, true, "LD3", "PD13" },       /* orange */
    { GPIOD, GPIO_PIN_12, true, "LD4", "PD12" },       /* green  */
    { GPIOD, GPIO_PIN_14, true, "LD5", "PD14" },       /* red    */
    { GPIOD, GPIO_PIN_15, true, "LD6", "PD15" },       /* blue   */
};
static const board_io_t buttons[] =
{
    { GPIOA, GPIO_PIN_0,  true, "B1",  "PA0"  },
};
#else
#error "board.c: no user I/O table for this board - add a BOARD_xxx block"
#endif

#define N_LEDS      ((uint32_t)(sizeof(leds) / sizeof(leds[0])))
#define N_BUTTONS   ((uint32_t)(sizeof(buttons) / sizeof(buttons[0])))

void board_init(void)
{
    /* pins are configured by the generated MX_GPIO_Init(); start with every LED off */
    for (uint32_t i = 0U; i < N_LEDS; i++)
    {
        board_led_write(i, false);
    }
}

void board_delay_ms(uint32_t ms)
{
    HAL_Delay(ms);
}

uint32_t board_millis(void)
{
    return HAL_GetTick();
}

void board_fatal(void)
{
    __disable_irq();
    for (;;)
    {
    }
}

uint32_t board_led_count(void)
{
    return N_LEDS;
}

void board_led_write(uint32_t idx, bool on)
{
    if (idx < N_LEDS)
    {
        bool level = (on == leds[idx].active_high);
        HAL_GPIO_WritePin(leds[idx].port, leds[idx].pin, level ? GPIO_PIN_SET : GPIO_PIN_RESET);
    }
}

bool board_led_read(uint32_t idx)
{
    if (idx >= N_LEDS)
    {
        return false;
    }
    /* read back the output data register: the pin really is driven this way */
    bool level = ((leds[idx].port->ODR & leds[idx].pin) != 0U);
    return level == leds[idx].active_high;
}

const char *board_led_name(uint32_t idx)
{
    return (idx < N_LEDS) ? leds[idx].name : "?";
}

uint32_t board_button_count(void)
{
    return N_BUTTONS;
}

bool board_button_is_pressed(uint32_t idx)
{
    if (idx >= N_BUTTONS)
    {
        return false;
    }
    bool level = (HAL_GPIO_ReadPin(buttons[idx].port, buttons[idx].pin) == GPIO_PIN_SET);
    return level == buttons[idx].active_high;
}

const char *board_button_name(uint32_t idx)
{
    return (idx < N_BUTTONS) ? buttons[idx].name : "?";
}

const char *board_button_pin(uint32_t idx)
{
    return (idx < N_BUTTONS) ? buttons[idx].pin_name : "?";
}

/* ---- console: SWO output only ---- */

bool board_console_getc(char *c)
{
    (void)c;
    return false;
}

void board_console_flush(void)
{
}

/* printf() -> ITM port 0 / SWO (overrides the weak _write of the generated syscalls.c) */
int _write(int file, char *ptr, int len)
{
    (void)file;
    for (int i = 0; i < len; i++)
    {
        (void)ITM_SendChar((uint32_t)(uint8_t)ptr[i]);
    }
    return len;
}
