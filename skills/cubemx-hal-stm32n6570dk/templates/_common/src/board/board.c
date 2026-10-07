/*******************************************************************************
* File Name : board.c
*
* Layer 1 - board adaptation for STM32N6 boards on the STM32CubeN6 HAL.
*
* What comes from STM32CubeMX (the app's .ioc, regenerated into mx/): clocks
* (800 MHz CPU), caches, USART1 + its pins (huart1, MX_USART1_UART_Init()).
* What is configured here at run time: the SMPS overdrive pin (before the
* clock is raised, from board_early_init()), user LEDs and buttons (HAL GPIO),
* the console glue (_write for printf, polled RX).
*
* STM32N6570-DK (values from the STM32CubeN6 BSP Drivers/BSP/STM32N6570-DK):
*   LED1 green PO1 active HIGH, LED2 red PG10 active LOW (mixed polarity),
*   USER1 button PC13 pull-down, pressed = HIGH, SMPS control PF4 (HIGH =
*   overdrive voltage, required for the 800 MHz CPU clock).
*******************************************************************************/
#include "board.h"

#include <stdio.h>

#include "main.h"

extern UART_HandleTypeDef huart1;           /* generated in mx/FSBL/Src/main.c */

typedef struct
{
    GPIO_TypeDef *port;
    uint16_t      pin;
    bool          active_high;
    const char   *name;
    const char   *pin_name;
} board_io_t;

#if defined(BOARD_STM32N6570_DK)
static const board_io_t leds[] =
{
    { GPIOO, GPIO_PIN_1,  true,  "LED1", "PO1"  },     /* green */
    { GPIOG, GPIO_PIN_10, false, "LED2", "PG10" },     /* red   */
};
static const board_io_t buttons[] =
{
    { GPIOC, GPIO_PIN_13, true,  "USER1", "PC13" },
};
#else
#error "board.c: no user I/O table for this board - add a BOARD_xxx block"
#endif

#define N_LEDS      ((uint32_t)(sizeof(leds) / sizeof(leds[0])))
#define N_BUTTONS   ((uint32_t)(sizeof(buttons) / sizeof(buttons[0])))

static void gpio_clock_enable(GPIO_TypeDef *port)
{
    if (port == GPIOC)      { __HAL_RCC_GPIOC_CLK_ENABLE(); }
    else if (port == GPIOF) { __HAL_RCC_GPIOF_CLK_ENABLE(); }
    else if (port == GPIOG) { __HAL_RCC_GPIOG_CLK_ENABLE(); }
    else if (port == GPIOO) { __HAL_RCC_GPIOO_CLK_ENABLE(); }
    else                    { board_fatal(); }
}

void board_early_init(void)
{
#if defined(BOARD_STM32N6570_DK)
    /* external SMPS to overdrive voltage before SystemClock_Config() sets 800 MHz (as ST's
     * Template does with BSP_SMPS_Init(SMPS_VOLTAGE_OVERDRIVE)) */
    GPIO_InitTypeDef gpio = {0};
    gpio_clock_enable(GPIOF);
    gpio.Pin   = GPIO_PIN_4;
    gpio.Mode  = GPIO_MODE_OUTPUT_PP;
    gpio.Pull  = GPIO_NOPULL;
    gpio.Speed = GPIO_SPEED_FREQ_VERY_HIGH;
    HAL_GPIO_Init(GPIOF, &gpio);
    HAL_GPIO_WritePin(GPIOF, GPIO_PIN_4, GPIO_PIN_SET);
#endif
}

void board_init(void)
{
    GPIO_InitTypeDef gpio = {0};

    for (uint32_t i = 0U; i < N_LEDS; i++)
    {
        gpio_clock_enable(leds[i].port);
        board_led_write(i, false);                      /* level before the pin drives */
        gpio.Pin   = leds[i].pin;
        gpio.Mode  = GPIO_MODE_OUTPUT_PP;
        gpio.Pull  = GPIO_NOPULL;
        gpio.Speed = GPIO_SPEED_FREQ_LOW;
        HAL_GPIO_Init(leds[i].port, &gpio);
    }
    for (uint32_t i = 0U; i < N_BUTTONS; i++)
    {
        gpio_clock_enable(buttons[i].port);
        gpio.Pin   = buttons[i].pin;
        gpio.Mode  = GPIO_MODE_INPUT;
        gpio.Pull  = buttons[i].active_high ? GPIO_PULLDOWN : GPIO_PULLUP;
        gpio.Speed = GPIO_SPEED_FREQ_LOW;
        HAL_GPIO_Init(buttons[i].port, &gpio);
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

/* ---- console: USART1 polled (no RX interrupt in the generated project) ---- */

bool board_console_getc(char *c)
{
    if (__HAL_UART_GET_FLAG(&huart1, UART_FLAG_ORE))
    {
        __HAL_UART_CLEAR_OREFLAG(&huart1);              /* drop an overrun, keep receiving */
    }
    if (__HAL_UART_GET_FLAG(&huart1, UART_FLAG_RXNE))
    {
        *c = (char)(huart1.Instance->RDR & 0xFFU);
        return true;
    }
    return false;
}

void board_console_flush(void)
{
    while (!__HAL_UART_GET_FLAG(&huart1, UART_FLAG_TC))
    {
    }
}

/* printf() -> USART1 (overrides the weak _write of the generated syscalls.c) */
int _write(int file, char *ptr, int len)
{
    (void)file;
    if (len > 0)
    {
        (void)HAL_UART_Transmit(&huart1, (uint8_t *)ptr, (uint16_t)len, 100U);
    }
    return len;
}
