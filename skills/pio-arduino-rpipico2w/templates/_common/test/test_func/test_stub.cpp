/*
 * test_stub.cpp - the board.h API for the func/ unit tests (see test_stub.h). Not linked into
 * the app: the unit-test environment builds only src/func/ (build_src_filter = +<func/>).
 */
#include "test_stub.h"
#include <string.h>
#include "../../src/board/board.h"

namespace
{
class CapturePrint : public Print
{
public:
    size_t write(uint8_t c) override
    {
        if (len_ < sizeof(buf_) - 1U)
        {
            buf_[len_++] = (char)c;
            buf_[len_]   = '\0';
        }
        return 1U;
    }
    void clear() { len_ = 0U; buf_[0] = '\0'; }
    const char *text() const { return buf_; }
private:
    char   buf_[1024] = {0};
    size_t len_       = 0U;
};

CapturePrint out;
uint32_t     now_ms;
uint32_t     n_leds;
uint32_t     n_buttons;
bool         led_level[TEST_STUB_MAX_IO + 1U];
bool         led_fails[TEST_STUB_MAX_IO + 1U];
bool         button_level[TEST_STUB_MAX_IO + 1U];
uint32_t     led_write_count;
char         in_buf[256];
size_t       in_len;
size_t       in_pos;
}

void test_stub_reset(uint32_t leds, uint32_t buttons)
{
    now_ms = 0U; n_leds = leds; n_buttons = buttons; led_write_count = 0U;
    memset(led_level, 0, sizeof(led_level));
    memset(led_fails, 0, sizeof(led_fails));
    memset(button_level, 0, sizeof(button_level));
    in_len = 0U; in_pos = 0U;
    out.clear();
}
void        test_stub_set_time(uint32_t ms)              { now_ms = ms; }
void        test_stub_set_button(uint32_t n, bool p)     { if (n <= TEST_STUB_MAX_IO) { button_level[n] = p; } }
void        test_stub_led_fail(uint32_t n, bool fail)    { if (n <= TEST_STUB_MAX_IO) { led_fails[n] = fail; } }
bool        test_stub_led_level(uint32_t n)              { return (n <= TEST_STUB_MAX_IO) && led_level[n]; }
uint32_t    test_stub_led_writes(void)                   { return led_write_count; }
const char *test_stub_console_output(void)               { return out.text(); }
void        test_stub_console_clear_output(void)         { out.clear(); }
void test_stub_console_input(const char *s)
{
    size_t n = strlen(s);
    if (in_len + n < sizeof(in_buf))
    {
        memcpy(&in_buf[in_len], s, n);
        in_len += n;
    }
}

/* ---- board.h ------------------------------------------------------------------------------ */
void     board_init(void)           {}
uint32_t board_millis(void)         { return now_ms; }
void     board_delay_ms(uint32_t ms) { now_ms += ms; }
Print   &board_console(void)        { return out; }
bool board_console_getc(char *c)
{
    if (in_pos >= in_len)
    {
        return false;
    }
    *c = in_buf[in_pos++];
    return true;
}
uint32_t board_led_count(void) { return n_leds; }
bool board_led_write(uint32_t n, bool on)
{
    led_write_count++;
    if ((n < 1U) || (n > n_leds) || (n > TEST_STUB_MAX_IO) || led_fails[n])
    {
        return false;
    }
    led_level[n] = on;
    return true;
}
uint32_t    board_button_count(void)        { return n_buttons; }
bool        board_button_read(uint32_t n)   { return (n >= 1U) && (n <= n_buttons) && (n <= TEST_STUB_MAX_IO) && button_level[n]; }
const char *board_button_name(uint32_t n)   { return (n == 1U) ? "BOOTSEL" : "BTN"; }
