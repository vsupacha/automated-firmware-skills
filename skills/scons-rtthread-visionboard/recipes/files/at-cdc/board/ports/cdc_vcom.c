/*
 * cdc_vcom.c - port layer (recipe at-cdc): the TinyUSB CDC interface of the user USB port as an
 * RT-Thread character device "cdc0", so RT-Thread components that need an rt_device (the AT server,
 * AT_SERVER_DEVICE) can use it. TinyUSB itself runs in its own thread ("tusb", started by
 * tusb_rt_thread_port.c); this file only bridges reads, writes and the receive callback.
 * Writes are dropped while no terminal has the port open (DTR low) instead of blocking.
 */
#include <rtthread.h>
#include <rtdevice.h>
#include "tusb.h"

#define CDC_VCOM_NAME          "cdc0"
#define CDC_VCOM_WRITE_WAIT_MS 100

static struct rt_device cdc_vcom;

static rt_err_t cdc_vcom_open(rt_device_t dev, rt_uint16_t oflag)
{
    (void)dev;
    (void)oflag;
    return RT_EOK;
}

static rt_ssize_t cdc_vcom_read(rt_device_t dev, rt_off_t pos, void *buffer, rt_size_t size)
{
    (void)dev;
    (void)pos;
    return (rt_ssize_t)tud_cdc_read(buffer, (uint32_t)size);
}

static rt_ssize_t cdc_vcom_write(rt_device_t dev, rt_off_t pos, const void *buffer, rt_size_t size)
{
    const uint8_t *p = buffer;
    rt_size_t      left = size;
    rt_tick_t      start = rt_tick_get();

    (void)dev;
    (void)pos;
    if (!tud_cdc_connected())
    {
        return (rt_ssize_t)size;
    }
    while (left > 0 && rt_tick_get() - start < rt_tick_from_millisecond(CDC_VCOM_WRITE_WAIT_MS))
    {
        uint32_t n = tud_cdc_write(p, (uint32_t)left);
        p += n;
        left -= n;
        tud_cdc_write_flush();
        if (left > 0)
        {
            rt_thread_mdelay(1);
        }
    }
    return (rt_ssize_t)(size - left);
}

/* TinyUSB: data arrived on the CDC interface (called from the tusb thread) */
void tud_cdc_rx_cb(uint8_t itf)
{
    (void)itf;
    if (cdc_vcom.rx_indicate != RT_NULL)
    {
        cdc_vcom.rx_indicate(&cdc_vcom, tud_cdc_available());
    }
}

#ifdef RT_USING_DEVICE_OPS
static const struct rt_device_ops cdc_vcom_ops = {
    RT_NULL, cdc_vcom_open, RT_NULL, cdc_vcom_read, cdc_vcom_write, RT_NULL
};
#endif

static int cdc_vcom_init(void)
{
    cdc_vcom.type = RT_Device_Class_Char;
#ifdef RT_USING_DEVICE_OPS
    cdc_vcom.ops = &cdc_vcom_ops;
#else
    cdc_vcom.open = cdc_vcom_open;
    cdc_vcom.read = cdc_vcom_read;
    cdc_vcom.write = cdc_vcom_write;
#endif
    return rt_device_register(&cdc_vcom, CDC_VCOM_NAME, RT_DEVICE_FLAG_RDWR | RT_DEVICE_FLAG_INT_RX);
}
INIT_DEVICE_EXPORT(cdc_vcom_init);   /* before the AT server (INIT_COMPONENT_EXPORT) looks it up */
