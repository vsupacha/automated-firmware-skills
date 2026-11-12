/*******************************************************************************
* File Name : board.c
*
* Layer 1 - board adaptation for STM32F3 boards on the STM32CubeF3 HAL.
*
* What comes from STM32CubeMX (the app's .ioc, from the CubeMX board
* configuration, regenerated into mx/): clocks, the LED outputs and the B1
* input (MX_GPIO_Init()), SWO on PB3 (SYS: Trace Asynchronous Sw).
* What is done here: the user I/O table, the console glue (_write -> ITM).
*
* STM32F3DISCOVERY (STM32CubeF3 BSP Drivers/BSP/STM32F3-Discovery): eight LEDs
* on PE8..PE15 in a ring (LD3 red PE9, LD4 blue PE8, LD5 orange PE10, LD6 green
* PE15, LD7 green PE11, LD8 orange PE14, LD9 blue PE12, LD10 red PE13), all
* active HIGH; B1 PA0 with a pull-down, pressed = HIGH.
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

#if defined(BOARD_STM32F3_DISCOVERY)
static const board_io_t leds[] =
{
    { GPIOE, GPIO_PIN_9,  true, "LD3",  "PE9"  },      /* red    */
    { GPIOE, GPIO_PIN_8,  true, "LD4",  "PE8"  },      /* blue   */
    { GPIOE, GPIO_PIN_10, true, "LD5",  "PE10" },      /* orange */
    { GPIOE, GPIO_PIN_15, true, "LD6",  "PE15" },      /* green  */
    { GPIOE, GPIO_PIN_11, true, "LD7",  "PE11" },      /* green  */
    { GPIOE, GPIO_PIN_14, true, "LD8",  "PE14" },      /* orange */
    { GPIOE, GPIO_PIN_12, true, "LD9",  "PE12" },      /* blue   */
    { GPIOE, GPIO_PIN_13, true, "LD10", "PE13" },      /* red    */
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
