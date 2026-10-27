/*******************************************************************************
* File Name : test_gesture.c
*
* Unity tests of func/gesture with a fake clock: the test owns "now" and steps
* it 1 ms per gesture_update() call, so every timing edge case runs in
* milliseconds on the board, including the 32-bit tick wrap-around.
*******************************************************************************/
#include <string.h>

#include "unity.h"
#include "unit.h"
#include "gesture.h"

static gesture_state_t g;
static uint32_t        now;
static uint32_t        seen[4];         /* count per gesture_t      */
static uint32_t        at[4];           /* time of the last of each */

/* hold the raw level for ms milliseconds, one update per ms */
static void hold(bool pressed, uint32_t ms)
{
    for (uint32_t i = 0U; i < ms; i++)
    {
        gesture_t e = gesture_update(&g, pressed, now);
        if (e != GESTURE_NONE)
        {
            seen[e]++;
            at[e] = now;
        }
        now++;
    }
}

static void click(uint32_t down_ms, uint32_t up_ms)
{
    hold(true, down_ms);
    hold(false, up_ms);
}

static void suite_setup(void)
{
    now = 1000U;
    memset(seen, 0, sizeof(seen));
    memset(at, 0, sizeof(at));
    gesture_init(&g);
}

static void test_idle_gives_no_event(void)
{
    hold(false, 2000U);
    TEST_ASSERT_EQUAL_UINT32(0U, seen[GESTURE_SHORT] + seen[GESTURE_LONG] + seen[GESTURE_DOUBLE]);
}

static void test_short_click(void)
{
    click(100U, 400U);
    TEST_ASSERT_EQUAL_UINT32(1U, seen[GESTURE_SHORT]);
    TEST_ASSERT_EQUAL_UINT32(0U, seen[GESTURE_LONG]);
    TEST_ASSERT_EQUAL_UINT32(0U, seen[GESTURE_DOUBLE]);
}

static void test_short_waits_for_the_double_click_gap(void)
{
    click(80U, 200U);                     /* still inside the gap: maybe a double */
    TEST_ASSERT_EQUAL_UINT32(0U, seen[GESTURE_SHORT]);
    hold(false, 200U);
    TEST_ASSERT_EQUAL_UINT32(1U, seen[GESTURE_SHORT]);
}

static void test_bounce_is_ignored(void)
{
    for (uint32_t i = 0U; i < 5U; i++)    /* 3 ms pulses, shorter than the debounce */
    {
        click(3U, 3U);
    }
    hold(false, 600U);
    TEST_ASSERT_EQUAL_UINT32(0U, seen[GESTURE_SHORT] + seen[GESTURE_LONG] + seen[GESTURE_DOUBLE]);
}

static void test_bouncy_press_is_one_click(void)
{
    click(3U, 2U);                         /* contact bounce, then a clean press */
    click(3U, 2U);
    click(100U, 400U);
    TEST_ASSERT_EQUAL_UINT32(1U, seen[GESTURE_SHORT]);
    TEST_ASSERT_EQUAL_UINT32(0U, seen[GESTURE_DOUBLE]);
}

static void test_long_fires_while_held(void)
{
    uint32_t t0 = now;
    hold(true, 900U);
    TEST_ASSERT_EQUAL_UINT32(1U, seen[GESTURE_LONG]);
    /* debounce + long time, within a few ms */
    TEST_ASSERT_UINT32_WITHIN(5U, t0 + GESTURE_DEBOUNCE_MS + GESTURE_LONG_MS, at[GESTURE_LONG]);
    hold(false, 500U);
    TEST_ASSERT_EQUAL_UINT32(1U, seen[GESTURE_LONG]);
    TEST_ASSERT_EQUAL_UINT32(0U, seen[GESTURE_SHORT]);
}

static void test_long_fires_once_however_long_held(void)
{
    hold(true, 5000U);
    hold(false, 500U);
    TEST_ASSERT_EQUAL_UINT32(1U, seen[GESTURE_LONG]);
    TEST_ASSERT_EQUAL_UINT32(0U, seen[GESTURE_SHORT] + seen[GESTURE_DOUBLE]);
}

static void test_double_click(void)
{
    click(80U, 100U);
    click(80U, 400U);
    TEST_ASSERT_EQUAL_UINT32(1U, seen[GESTURE_DOUBLE]);
    TEST_ASSERT_EQUAL_UINT32(0U, seen[GESTURE_SHORT]);
}

static void test_click_then_hold_is_short_then_long(void)
{
    click(80U, 100U);                      /* second press inside the gap ...  */
    hold(true, 900U);                      /* ... but held: not a double click */
    TEST_ASSERT_EQUAL_UINT32(1U, seen[GESTURE_SHORT]);
    TEST_ASSERT_EQUAL_UINT32(1U, seen[GESTURE_LONG]);
    TEST_ASSERT_EQUAL_UINT32(0U, seen[GESTURE_DOUBLE]);
    TEST_ASSERT_TRUE(at[GESTURE_SHORT] < at[GESTURE_LONG]);
    hold(false, 500U);
    TEST_ASSERT_EQUAL_UINT32(0U, seen[GESTURE_DOUBLE]);
}

static void test_two_slow_clicks_are_two_shorts(void)
{
    click(80U, 400U);
    click(80U, 400U);
    TEST_ASSERT_EQUAL_UINT32(2U, seen[GESTURE_SHORT]);
    TEST_ASSERT_EQUAL_UINT32(0U, seen[GESTURE_DOUBLE]);
}

static void test_click_across_tick_wrap(void)
{
    now = 0xFFFFFF80U;                     /* the press starts 128 ms before the wrap */
    gesture_init(&g);
    click(100U, 400U);
    TEST_ASSERT_EQUAL_UINT32(1U, seen[GESTURE_SHORT]);
    TEST_ASSERT_EQUAL_UINT32(0U, seen[GESTURE_LONG]);
}

static void test_long_across_tick_wrap(void)
{
    now = 0xFFFFFE00U;                     /* 512 ms before the wrap */
    gesture_init(&g);
    hold(true, 900U);
    TEST_ASSERT_EQUAL_UINT32(1U, seen[GESTURE_LONG]);
}

static void test_names(void)
{
    TEST_ASSERT_EQUAL_STRING("short", gesture_name(GESTURE_SHORT));
    TEST_ASSERT_EQUAL_STRING("long", gesture_name(GESTURE_LONG));
    TEST_ASSERT_EQUAL_STRING("double", gesture_name(GESTURE_DOUBLE));
    TEST_ASSERT_EQUAL_STRING("none", gesture_name(GESTURE_NONE));
}

void test_gesture_suite(void)
{
    unit_setup    = suite_setup;
    unit_teardown = NULL;
    UnitySetTestFile(__FILE__);           /* Unity's FAIL lines name this file */
    RUN_TEST(test_idle_gives_no_event);
    RUN_TEST(test_short_click);
    RUN_TEST(test_short_waits_for_the_double_click_gap);
    RUN_TEST(test_bounce_is_ignored);
    RUN_TEST(test_bouncy_press_is_one_click);
    RUN_TEST(test_long_fires_while_held);
    RUN_TEST(test_long_fires_once_however_long_held);
    RUN_TEST(test_double_click);
    RUN_TEST(test_click_then_hold_is_short_then_long);
    RUN_TEST(test_two_slow_clicks_are_two_shorts);
    RUN_TEST(test_click_across_tick_wrap);
    RUN_TEST(test_long_across_tick_wrap);
    RUN_TEST(test_names);
}
