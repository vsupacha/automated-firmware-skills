/*******************************************************************************
* File Name : board.c
*
* Layer 1 - board adaptation for ESP32-S3 boards on ESP-IDF 5.x.
*
* Console: the ESP32-S3 USB Serial/JTAG through its IDF driver. The driver
* buffers input (non-blocking reads, nothing lost while the superloop sleeps
* 1 ms) and drops output after 50 ms when no host reads it, so an unattended
* board never hangs in printf(). TX line endings stay as written ("\r\n").
*
* User I/O per board: an #if table of GPIOs. The ESP32-S3-BOX has no user LED;
* LED1 is the LCD backlight (visible without an LCD driver).
*******************************************************************************/
#include "board.h"

#include <stdio.h>

#include "driver/gpio.h"
#include "driver/usb_serial_jtag.h"
#include "driver/usb_serial_jtag_vfs.h"
#include "esp_timer.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"

typedef struct
{
    gpio_num_t  pin;
    bool        active_high;
    const char *name;
    const char *pin_name;
} board_io_t;

#if defined(BOARD_ESP32_S3_BOX)
/* ESP32-S3-BOX (2021): LCD backlight GPIO45 (strapping pin - driven only after
 * boot); BOOT button GPIO0, active low with an external pull-up. */
static const board_io_t leds[]    = { { GPIO_NUM_45, true,  "LCD backlight", "GPIO45" } };
static const board_io_t buttons[] = { { GPIO_NUM_0,  false, "BOOT",          "GPIO0"  } };
#else
/* generic ESP32-S3 module: BOOT button only */
static const board_io_t leds[]    = { { GPIO_NUM_NC, true,  "-",    "-"     } };
static const board_io_t buttons[] = { { GPIO_NUM_0,  false, "BOOT", "GPIO0" } };
#endif

#define N_LEDS      ((leds[0].pin == GPIO_NUM_NC) ? 0U : (uint32_t)(sizeof(leds) / sizeof(leds[0])))
#define N_BUTTONS   ((uint32_t)(sizeof(buttons) / sizeof(buttons[0])))

void board_init(void)
{
    /* console: driver-based USB Serial/JTAG for stdin/stdout */
    usb_serial_jtag_driver_config_t usj = USB_SERIAL_JTAG_DRIVER_CONFIG_DEFAULT();
    if (usb_serial_jtag_driver_install(&usj) == ESP_OK)
    {
        usb_serial_jtag_vfs_use_driver();
    }
    usb_serial_jtag_vfs_set_tx_line_endings(ESP_LINE_ENDINGS_LF);
    setvbuf(stdout, NULL, _IOLBF, 0);

    for (uint32_t i = 0U; i < N_LEDS; i++)
    {
        /* input+output so board_led_read() reads the pin level back */
        gpio_reset_pin(leds[i].pin);
        gpio_set_direction(leds[i].pin, GPIO_MODE_INPUT_OUTPUT);
        board_led_write(i, false);
    }
    for (uint32_t i = 0U; i < N_BUTTONS; i++)
    {
        gpio_reset_pin(buttons[i].pin);
        gpio_set_direction(buttons[i].pin, GPIO_MODE_INPUT);
        gpio_set_pull_mode(buttons[i].pin, buttons[i].active_high ? GPIO_PULLDOWN_ONLY : GPIO_PULLUP_ONLY);
    }
}

void board_delay_ms(uint32_t ms)
{
    TickType_t t = pdMS_TO_TICKS(ms);
    vTaskDelay((t == 0U) ? 1U : t);     /* always yield: the idle task must run */
}

uint32_t board_millis(void)
{
    return (uint32_t)(esp_timer_get_time() / 1000);
}

void board_fatal(void)
{
    printf("ERR fatal - halted\r\n");
    for (;;)
    {
        vTaskDelay(portMAX_DELAY);
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
        gpio_set_level(leds[idx].pin, (on == leds[idx].active_high) ? 1U : 0U);
    }
}

bool board_led_read(uint32_t idx)
{
    return (idx < N_LEDS) && ((gpio_get_level(leds[idx].pin) != 0) == leds[idx].active_high);
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
    return (idx < N_BUTTONS) && ((gpio_get_level(buttons[idx].pin) != 0) == buttons[idx].active_high);
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
    return usb_serial_jtag_read_bytes((uint8_t *)c, 1U, 0) > 0;
}

void board_console_flush(void)
{
    fflush(stdout);
}
