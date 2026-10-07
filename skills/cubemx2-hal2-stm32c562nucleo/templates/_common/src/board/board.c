/*******************************************************************************
* File Name : board.c
*
* Layer 1 - board adaptation for STM32C5 boards.
*   - clocks, USART2 and its pins are initialised by the generated mx_system_init()
*     (called by the generated main.c before app_main())
*   - user LED/button pins are configured here at run time with HAL2 GPIO, so the
*     board-default .ioc2 needs no GPIO setup
*   - console RX polls the USART receive flag (LL): the board-default project has
*     no USART interrupt, so interrupt-driven HAL receive would never complete
*   - printf() goes to the console through _write() (overrides the weak syscall)
*******************************************************************************/
#include "board.h"

#include <stdio.h>

#include "stm32c5xx_hal.h"
#include "stm32c5xx_ll_usart.h"
#include "mx_usart2.h"

typedef struct
{
    hal_gpio_t  port;
    uint32_t    pin;
    bool        active_high;
    const char *name;
    const char *pin_name;
} board_io_t;

/* User I/O per board - add an #elif block for another board (names from boards/<id>/README.md) */
#if defined(BOARD_NUCLEO_C562RE)
/* NUCLEO-C562RE (MB2213), from the board pack: LD1 green on PA5 (via Q1), active high;
 * B1 USER on PC13 with pull-down R13, active high. Console: USART2 -> ST-LINK VCP. */
static const board_io_t leds[] =
{
    { HAL_GPIOA, HAL_GPIO_PIN_5,  true, "LD1", "PA5"  },
};
static const board_io_t buttons[] =
{
    { HAL_GPIOC, HAL_GPIO_PIN_13, true, "B1",  "PC13" },
};
#define BOARD_CONSOLE_USART     USART2
#else
#error "board.c: no user I/O table for this board - add an #elif block for its BOARD_<ID>"
#endif

#define N_LEDS      (sizeof(leds) / sizeof(leds[0]))
#define N_BUTTONS   (sizeof(buttons) / sizeof(buttons[0]))

static hal_uart_handle_t *console;

static void enable_port_clock(hal_gpio_t port)
{
    if (port == HAL_GPIOA)      { HAL_RCC_GPIOA_EnableClock(); }
    else if (port == HAL_GPIOB) { HAL_RCC_GPIOB_EnableClock(); }
    else if (port == HAL_GPIOC) { HAL_RCC_GPIOC_EnableClock(); }
    else                        { /* add ports used by other boards here */ }
}

void board_init(void)
{
    hal_gpio_config_t cfg =
    {
        .mode        = HAL_GPIO_MODE_OUTPUT,
        .pull        = HAL_GPIO_PULL_NO,
        .speed       = HAL_GPIO_SPEED_FREQ_LOW,
        .output_type = HAL_GPIO_OUTPUT_PUSHPULL,
        .alternate   = HAL_GPIO_AF_0,
        .init_state  = HAL_GPIO_PIN_RESET,
    };

    for (uint32_t i = 0U; i < N_LEDS; i++)
    {
        enable_port_clock(leds[i].port);
        cfg.init_state = leds[i].active_high ? HAL_GPIO_PIN_RESET : HAL_GPIO_PIN_SET;  /* off */
        if (HAL_GPIO_Init(leds[i].port, leds[i].pin, &cfg) != HAL_OK)
        {
            board_fatal();
        }
    }
    cfg.mode = HAL_GPIO_MODE_INPUT;
    for (uint32_t i = 0U; i < N_BUTTONS; i++)
    {
        enable_port_clock(buttons[i].port);
        cfg.pull = HAL_GPIO_PULL_NO;    /* external pull resistor on the board */
        if (HAL_GPIO_Init(buttons[i].port, buttons[i].pin, &cfg) != HAL_OK)
        {
            board_fatal();
        }
    }

    console = mx_usart2_uart_gethandle();
    if (console == NULL)
    {
        board_fatal();
    }
    (void)setvbuf(stdout, NULL, _IONBF, 0);   /* every printf goes out immediately */
}

void board_delay_ms(uint32_t ms)
{
    uint32_t start = HAL_GetTick();
    while ((HAL_GetTick() - start) < ms)
    {
    }
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
    return (uint32_t)N_LEDS;
}

void board_led_write(uint32_t idx, bool on)
{
    if (idx < N_LEDS)
    {
        bool level = (on == leds[idx].active_high);
        HAL_GPIO_WritePin(leds[idx].port, leds[idx].pin, level ? HAL_GPIO_PIN_SET : HAL_GPIO_PIN_RESET);
    }
}

bool board_led_read(uint32_t idx)
{
    if (idx >= N_LEDS)
    {
        return false;
    }
    /* read back the output data register: the pin really is driven this way */
    bool level = ((LL_GPIO_ReadOutputPort((GPIO_TypeDef *)leds[idx].port) & leds[idx].pin) != 0U);
    return level == leds[idx].active_high;
}

const char *board_led_name(uint32_t idx)
{
    return (idx < N_LEDS) ? leds[idx].name : "?";
}

uint32_t board_button_count(void)
{
    return (uint32_t)N_BUTTONS;
}

bool board_button_is_pressed(uint32_t idx)
{
    if (idx >= N_BUTTONS)
    {
        return false;
    }
    bool level = (HAL_GPIO_ReadPin(buttons[idx].port, buttons[idx].pin) == HAL_GPIO_PIN_SET);
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

bool board_console_getc(char *c)
{
    USART_TypeDef *u = BOARD_CONSOLE_USART;

    if (LL_USART_IsActiveFlag_ORE(u) != 0U)
    {
        LL_USART_ClearFlag_ORE(u);      /* overrun: drop it, keep receiving */
    }
    if (LL_USART_IsActiveFlag_RXNE_RXFNE(u) != 0U)
    {
        *c = (char)LL_USART_ReceiveData8(u);
        return true;
    }
    return false;
}

void board_console_flush(void)
{
    /* HAL_UART_Transmit() in _write() blocks until the data is sent */
}

/* newlib: printf/putchar end here (strong definition overrides the weak syscall) */
int _write(int file, char *ptr, int len)
{
    (void)file;
    if ((console != NULL) && (len > 0))
    {
        (void)HAL_UART_Transmit(console, ptr, (uint32_t)len, 100U);
    }
    return len;
}
