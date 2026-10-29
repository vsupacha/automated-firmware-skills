/*******************************************************************************
* File Name : board.c
*
* Layer 1 - board adaptation for NXP MCX N boards (MCUXpresso SDK drivers).
* Clocks and console pins come from the SDK's clock_config.c / pin_mux.c
* (BOARD_InitBootClocks, BOARD_InitPins); user LEDs and buttons are set up here
* with fsl_port / fsl_gpio. Console = LP_FLEXCOMM4 LPUART -> MCU-Link VCOM,
* TX blocking, RX by interrupt into a ring buffer. printf() goes through _write.
*
* FRDM-MCXN947 (SDK board.h): RGB LED D2 active low - red P0_10, green P0_27,
* blue P1_2; SW2 (wakeup) P0_23, SW3 (ISP) P0_6, pressed = low.
*******************************************************************************/
#include "board.h"

#include "clock_config.h"
#include "fsl_clock.h"
#include "fsl_gpio.h"
#include "fsl_lpflexcomm.h"
#include "fsl_lpuart.h"
#include "fsl_port.h"
#include "fsl_reset.h"
#include "pin_mux.h"

#include <stdio.h>

#define CONSOLE_UART        LPUART4
#define CONSOLE_INSTANCE    (4U)
#define CONSOLE_CLK_HZ      (12000000U)       /* FRO 12 MHz -> FLEXCOMM4 */
#define CONSOLE_BAUD        (115200U)
#define RX_BUF_SIZE         (256U)            /* power of two */

typedef struct
{
    GPIO_Type  *gpio;
    PORT_Type  *port;
    uint32_t    pin;
    const char *name;
    const char *pin_name;
} board_io_t;

#if defined(BOARD_FRDM_MCXN947)
static const board_io_t leds[] =
{
    { GPIO0, PORT0, 10U, "LED_RED",   "P0_10" },
    { GPIO0, PORT0, 27U, "LED_GREEN", "P0_27" },
    { GPIO1, PORT1,  2U, "LED_BLUE",  "P1_2"  },
};
static const board_io_t buttons[] =
{
    { GPIO0, PORT0, 23U, "SW2", "P0_23" },
    { GPIO0, PORT0,  6U, "SW3", "P0_6"  },   /* ISP button: held at reset = ROM bootloader */
};
#define LED_ON_LEVEL        (0U)             /* active low */
#define BUTTON_PRESSED      (0U)
#else
#error "board.c: unknown board - add its user I/O"
#endif

#define NUM_LEDS        (sizeof(leds) / sizeof(leds[0]))
#define NUM_BUTTONS     (sizeof(buttons) / sizeof(buttons[0]))

static volatile uint32_t ticks_ms;
static volatile uint8_t  rx_buf[RX_BUF_SIZE];
static volatile uint32_t rx_head;
static volatile uint32_t rx_tail;

void SysTick_Handler(void)
{
    ticks_ms++;
}

static void console_irq(uint32_t instance, void *handle)
{
    (void)instance;
    (void)handle;
    uint32_t flags = LPUART_GetStatusFlags(CONSOLE_UART);

    if ((flags & (uint32_t)kLPUART_RxOverrunFlag) != 0U)
    {
        (void)LPUART_ClearStatusFlags(CONSOLE_UART, (uint32_t)kLPUART_RxOverrunFlag);
    }
    while ((LPUART_GetStatusFlags(CONSOLE_UART) & (uint32_t)kLPUART_RxDataRegFullFlag) != 0U)
    {
        uint8_t  b    = LPUART_ReadByte(CONSOLE_UART);
        uint32_t next = (rx_head + 1U) & (RX_BUF_SIZE - 1U);
        if (next != rx_tail)             /* drop the byte when the buffer is full */
        {
            rx_buf[rx_head] = b;
            rx_head         = next;
        }
    }
}

static void pin_gpio(const board_io_t *io, bool pull_up)
{
    const port_pin_config_t cfg = {
        .pullSelect          = pull_up ? kPORT_PullUp : kPORT_PullDisable,
        .pullValueSelect     = kPORT_LowPullResistor,
        .slewRate            = kPORT_FastSlewRate,
        .passiveFilterEnable = kPORT_PassiveFilterDisable,
        .openDrainEnable     = kPORT_OpenDrainDisable,
        .driveStrength       = kPORT_LowDriveStrength,
        .mux                 = kPORT_MuxAlt0,
        .inputBuffer         = kPORT_InputBufferEnable,
        .invertInput         = kPORT_InputNormal,
        .lockRegister        = kPORT_UnlockRegister,
    };
    PORT_SetPinConfig(io->port, io->pin, &cfg);
}

static void console_init(void)
{
    lpuart_config_t cfg;

    CLOCK_SetClkDiv(kCLOCK_DivFlexcom4Clk, 1U);
    CLOCK_AttachClk(kFRO12M_to_FLEXCOMM4);
    RESET_ClearPeripheralReset(kFC4_RST_SHIFT_RSTn);
#if defined(LPFLEXCOMM_INIT_NOT_USED_IN_DRIVER) && LPFLEXCOMM_INIT_NOT_USED_IN_DRIVER
    (void)LP_FLEXCOMM_Init(CONSOLE_INSTANCE, LP_FLEXCOMM_PERIPH_LPUART);
#endif
    LPUART_GetDefaultConfig(&cfg);
    cfg.baudRate_Bps = CONSOLE_BAUD;
    cfg.enableTx     = true;
    cfg.enableRx     = true;
    if (LPUART_Init(CONSOLE_UART, &cfg, CONSOLE_CLK_HZ) != kStatus_Success)
    {
        board_fatal();
    }
    LP_FLEXCOMM_SetIRQHandler(CONSOLE_INSTANCE, console_irq, NULL, LP_FLEXCOMM_PERIPH_LPUART);
    LPUART_EnableInterrupts(CONSOLE_UART, (uint32_t)kLPUART_RxDataRegFullInterruptEnable);
    (void)EnableIRQ(LP_FLEXCOMM4_IRQn);
    (void)setvbuf(stdout, NULL, _IONBF, 0);   /* every printf goes out immediately */
}

void board_init(void)
{
    BOARD_InitPins();                          /* SDK pin_mux.c: console + SWO pins */
    BOARD_InitBootClocks();                    /* SDK clock_config.c                */
    (void)SysTick_Config(SystemCoreClock / 1000U);

    CLOCK_EnableClock(kCLOCK_Port0);
    CLOCK_EnableClock(kCLOCK_Port1);
    CLOCK_EnableClock(kCLOCK_Gpio0);
    CLOCK_EnableClock(kCLOCK_Gpio1);

    for (uint32_t i = 0U; i < NUM_LEDS; i++)
    {
        const gpio_pin_config_t out = { kGPIO_DigitalOutput, (uint8_t)(LED_ON_LEVEL ^ 1U) };
        GPIO_PinInit(leds[i].gpio, leds[i].pin, &out);   /* level before the pin drives */
        pin_gpio(&leds[i], false);
    }
    for (uint32_t i = 0U; i < NUM_BUTTONS; i++)
    {
        const gpio_pin_config_t in = { kGPIO_DigitalInput, 0U };
        pin_gpio(&buttons[i], true);
        GPIO_PinInit(buttons[i].gpio, buttons[i].pin, &in);
    }
    console_init();
}

void board_delay_ms(uint32_t ms)
{
    uint32_t start = ticks_ms;
    while ((ticks_ms - start) < ms)
    {
    }
}

uint32_t board_millis(void)
{
    return ticks_ms;
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
    return (uint32_t)NUM_LEDS;
}

void board_led_write(uint32_t idx, bool on)
{
    if (idx < NUM_LEDS)
    {
        GPIO_PinWrite(leds[idx].gpio, leds[idx].pin, on ? LED_ON_LEVEL : (uint8_t)(LED_ON_LEVEL ^ 1U));
    }
}

bool board_led_read(uint32_t idx)
{
    if (idx >= NUM_LEDS)
    {
        return false;
    }
    uint32_t level = (leds[idx].gpio->PDOR >> leds[idx].pin) & 1U;   /* output latch */
    return level == LED_ON_LEVEL;
}

const char *board_led_name(uint32_t idx)
{
    return (idx < NUM_LEDS) ? leds[idx].name : "?";
}

uint32_t board_button_count(void)
{
    return (uint32_t)NUM_BUTTONS;
}

bool board_button_is_pressed(uint32_t idx)
{
    if (idx >= NUM_BUTTONS)
    {
        return false;
    }
    return GPIO_PinRead(buttons[idx].gpio, buttons[idx].pin) == BUTTON_PRESSED;
}

const char *board_button_name(uint32_t idx)
{
    return (idx < NUM_BUTTONS) ? buttons[idx].name : "?";
}

const char *board_button_pin(uint32_t idx)
{
    return (idx < NUM_BUTTONS) ? buttons[idx].pin_name : "?";
}

bool board_console_getc(char *c)
{
    if (rx_tail == rx_head)
    {
        return false;
    }
    *c      = (char)rx_buf[rx_tail];
    rx_tail = (rx_tail + 1U) & (RX_BUF_SIZE - 1U);
    return true;
}

void board_console_flush(void)
{
    while ((LPUART_GetStatusFlags(CONSOLE_UART) & (uint32_t)kLPUART_TransmissionCompleteFlag) == 0U)
    {
    }
}

/* printf() -> LPUART4 (newlib _write) */
int _write(int file, char *ptr, int len);
int _write(int file, char *ptr, int len)
{
    (void)file;
    if (len > 0)
    {
        (void)LPUART_WriteBlocking(CONSOLE_UART, (const uint8_t *)ptr, (size_t)len);
    }
    return len;
}
