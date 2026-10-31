/*
 * at_cmds.c - Layer 3b: AT command interface (recipe at-cdc). A peer of the msh commands in
 * hal_entry.c: it maps AT commands of RT-Thread's AT server (on the user USB CDC port, device
 * "cdc0") to the function layer. No pin numbers here (those belong in board/), no USB code (that is
 * the port layer, board/ports/cdc_vcom.c).
 *
 *   AT              OK                               (built in: AT, ATE0/ATE1, AT+RST, AT&L ...)
 *   AT+INFO         +INFO: app=...,board=...,leds=n,btns=n   OK
 *   AT+LED?         +LED: <led1>,<led2>,...          OK
 *   AT+LED=<n>,<s>  s = 0 off, 1 on, 2 toggle -> +LED: <n>,<state>  OK | ERROR
 *   AT+BTN?         +BTN: <btn1>,...                 OK
 */
#include <rtthread.h>

#ifdef AT_USING_SERVER
#include <at.h>
#include "board/board_io.h"
#include "func/button.h"
#include "func/led.h"

#define AT_APP_NAME "push-to-light"

static void print_states(const char *tag, uint8_t count, bool (*get)(uint8_t))
{
    char    line[64];
    rt_size_t len = (rt_size_t)rt_snprintf(line, sizeof(line), "+%s: ", tag);

    for (uint8_t n = 1; n <= count && len < sizeof(line) - 3; n++)
    {
        len += (rt_size_t)rt_snprintf(line + len, sizeof(line) - len, n > 1 ? ",%d" : "%d", get(n) ? 1 : 0);
    }
    at_server_printfln("%s", line);
}

static at_result_t at_info_exec(void)
{
    at_server_printfln("+INFO: app=%s,board=%s,leds=%u,btns=%u", AT_APP_NAME, BOARD_ID_NAME,
                       (unsigned)led_count(), (unsigned)button_count());
    return AT_RESULT_OK;
}
AT_CMD_EXPORT("AT+INFO", RT_NULL, RT_NULL, RT_NULL, RT_NULL, at_info_exec);

static at_result_t at_led_query(void)
{
    print_states("LED", led_count(), led_get);
    return AT_RESULT_OK;
}

static at_result_t at_led_setup(const char *args)
{
    int n = 0;
    int s = -1;

    if (at_req_parse_args(args, "=%d,%d", &n, &s) != 2 || n < 1 || n > 255 || s < 0 || s > 2)
    {
        return AT_RESULT_PARSE_FAILE;
    }
    bool ok = (s == 2) ? led_toggle((uint8_t)n) : led_set((uint8_t)n, s == 1);
    if (!ok)
    {
        return AT_RESULT_CHECK_FAILE;
    }
    at_server_printfln("+LED: %d,%d", n, led_get((uint8_t)n) ? 1 : 0);
    return AT_RESULT_OK;
}
AT_CMD_EXPORT("AT+LED", "=<n>,<0|1|2>", RT_NULL, at_led_query, at_led_setup, RT_NULL);

static at_result_t at_btn_query(void)
{
    print_states("BTN", button_count(), button_is_pressed);
    return AT_RESULT_OK;
}
AT_CMD_EXPORT("AT+BTN", RT_NULL, RT_NULL, at_btn_query, RT_NULL, RT_NULL);

#endif /* AT_USING_SERVER */
