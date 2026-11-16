/*
 * test_stub.cpp - the board.h API for the func/ unit tests (see test_stub.h). Not linked into
 * the app: the unit-test environment builds only src/func/ (build_src_filter = +<func/>).
 */
#include "test_stub.h"
#include <string.h>
#include "../../src/board/board.h"
#include "../../src/board/board_baro.h"
#include "../../src/board/board_hum.h"
#include "../../src/board/board_i2c.h"
#include "../../src/board/board_imu.h"
#include "../../src/board/board_rgb.h"

namespace
{
class StubStream : public Stream
{
public:
    int available() override { return (int)(in_len_ - in_pos_); }
    int read() override { return (in_pos_ < in_len_) ? (unsigned char)in_[in_pos_++] : -1; }
    int peek() override { return (in_pos_ < in_len_) ? (unsigned char)in_[in_pos_] : -1; }
    void flush() override {}
    size_t write(uint8_t c) override
    {
        if (out_len_ < sizeof(out_) - 1U)
        {
            out_[out_len_++] = (char)c;
            out_[out_len_]   = '\0';
        }
        return 1U;
    }
    void reset() { in_len_ = in_pos_ = out_len_ = 0U; out_[0] = '\0'; }
    void feed(const char *s)
    {
        size_t n = strlen(s);
        if (in_len_ + n < sizeof(in_))
        {
            memcpy(&in_[in_len_], s, n);
            in_len_ += n;
        }
    }
    const char *text() const { return out_; }
private:
    char   in_[256]   = {0};
    size_t in_len_    = 0U;
    size_t in_pos_    = 0U;
    char   out_[1024] = {0};
    size_t out_len_   = 0U;
};

StubStream io;
uint8_t    n_leds;
uint8_t    n_buttons;
bool       led_level[TEST_STUB_MAX_IO + 1U];
bool       led_fails[TEST_STUB_MAX_IO + 1U];
bool       button_level[TEST_STUB_MAX_IO + 1U];
uint32_t   led_write_count;

bool valid(uint8_t n, uint8_t count) { return (n >= 1U) && (n <= count) && (n <= TEST_STUB_MAX_IO); }
}

void test_stub_reset(uint8_t leds, uint8_t buttons)
{
    n_leds = leds; n_buttons = buttons; led_write_count = 0U;
    memset(led_level, 0, sizeof(led_level));
    memset(led_fails, 0, sizeof(led_fails));
    memset(button_level, 0, sizeof(button_level));
    io.reset();
}
void        test_stub_set_button(uint8_t n, bool p)   { if (n <= TEST_STUB_MAX_IO) { button_level[n] = p; } }
void        test_stub_led_fail(uint8_t n, bool fail)  { if (n <= TEST_STUB_MAX_IO) { led_fails[n] = fail; } }
bool        test_stub_led_level(uint8_t n)            { return (n <= TEST_STUB_MAX_IO) && led_level[n]; }
uint32_t    test_stub_led_writes(void)                { return led_write_count; }
void        test_stub_console_input(const char *s)    { io.feed(s); }
const char *test_stub_console_output(void)            { return io.text(); }

/* ---- board.h ------------------------------------------------------------------------------ */
void    board_init() {}
Stream &board_console() { return io; }
uint8_t board_led_count() { return n_leds; }
bool board_led_write(uint8_t n, bool on)
{
    led_write_count++;
    if (!valid(n, n_leds) || led_fails[n])
    {
        return false;
    }
    led_level[n] = on;
    return true;
}
bool        board_led_read(uint8_t n)     { return valid(n, n_leds) && led_level[n]; }
const char *board_led_name(uint8_t n)     { return (n == 1U) ? "LED" : "LED2"; }
uint8_t     board_button_count()          { return n_buttons; }
bool        board_button_read(uint8_t n)  { return valid(n, n_buttons) && button_level[n]; }
const char *board_button_name(uint8_t n)  { return (n == 1U) ? "BOOT" : "BTN"; }
uint8_t     board_button_pin(uint8_t n)   { return n; }

/* ---- board drivers of the Cucumber S (board_imu/baro/hum/rgb/i2c.h) -------------------------
 * Linked so that func/ modules over the drivers (iot-sensor: func/sensors.cpp) build in the unit
 * image. The stub has no sensors: begin/read report "not present"; the RGB pixel keeps its value. */
bool board_imu_begin()                  { return false; }
bool board_imu_present()                { return false; }
bool board_imu_read(board_imu_t *)      { return false; }
bool board_baro_begin()                 { return false; }
bool board_baro_present()               { return false; }
bool board_baro_read(board_baro_t *)    { return false; }
bool board_hum_begin()                  { return false; }
bool board_hum_present()                { return false; }
bool board_hum_read(board_hum_t *)      { return false; }
bool    board_i2c_begin()               { return true; }
bool    board_i2c_probe(uint8_t)        { return false; }
uint8_t board_i2c_scan(uint8_t *, uint8_t) { return 0U; }
static uint8_t rgb_stub[3];
void board_rgb_begin()                              { rgb_stub[0] = rgb_stub[1] = rgb_stub[2] = 0U; }
void board_rgb_set(uint8_t r, uint8_t g, uint8_t b) { rgb_stub[0] = r; rgb_stub[1] = g; rgb_stub[2] = b; }
void board_rgb_get(uint8_t *r, uint8_t *g, uint8_t *b)
{
    if (r != nullptr) { *r = rgb_stub[0]; }
    if (g != nullptr) { *g = rgb_stub[1]; }
    if (b != nullptr) { *b = rgb_stub[2]; }
}
