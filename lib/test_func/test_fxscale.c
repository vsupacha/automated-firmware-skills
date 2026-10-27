/*******************************************************************************
* File Name : test_fxscale.c
*
* Unity tests of func/fxscale: the fixed-point result must stay within 1 %
* (relative) of the float product over the whole range x 0.01..100, gain
* 0.01..10 - checked at the corners, on a log-spaced grid and on pseudo-random
* pairs. The reference product is computed in double. The worst error found is
* printed, so the margin to the 1 % bound is visible in every run.
*******************************************************************************/
#include <math.h>
#include <stdio.h>

#include "unity.h"
#include "unit.h"
#include "fxscale.h"

static double worst;            /* worst relative error of the current test */
static float  worst_x, worst_g;

static void check(float x, float g)
{
    double ref = (double)x * (double)g;
    double got = (double)fxscale(x, g);
    double rel = fabs(got - ref) / ref;
    if (rel > worst)
    {
        worst   = rel;
        worst_x = x;
        worst_g = g;
    }
}

static void report(const char *what)
{
    char msg[96];
    (void)snprintf(msg, sizeof(msg), "%s: worst rel error %.6f %% at x=%g gain=%g",
                   what, worst * 100.0, (double)worst_x, (double)worst_g);
    TEST_MESSAGE(msg);
    TEST_ASSERT_TRUE_MESSAGE(worst < (double)FXSCALE_MAX_REL_ERR, msg);
}

/* log-spaced value i of n in [lo, hi] (both ends included) */
static float logspace(float lo, float hi, uint32_t i, uint32_t n)
{
    double t = (double)i / (double)(n - 1U);
    return (float)exp(log((double)lo) + t * (log((double)hi) - log((double)lo)));
}

static void suite_setup(void)
{
    worst = 0.0;
    worst_x = 0.0f;
    worst_g = 0.0f;
}

static void test_examples(void)
{
    TEST_ASSERT_FLOAT_WITHIN(0.01f, 1.0f, fxscale(1.0f, 1.0f));
    TEST_ASSERT_FLOAT_WITHIN(0.25f, 25.0f, fxscale(50.0f, 0.5f));
    TEST_ASSERT_FLOAT_WITHIN(0.09f, 8.91f, fxscale(3.3f, 2.7f));
}

static void test_corners(void)
{
    check(FXSCALE_X_MIN, FXSCALE_G_MIN);   /* 0.0001: smallest result */
    check(FXSCALE_X_MIN, FXSCALE_G_MAX);
    check(FXSCALE_X_MAX, FXSCALE_G_MIN);
    check(FXSCALE_X_MAX, FXSCALE_G_MAX);   /* 1000: largest result */
    report("corners");
}

static void test_log_grid(void)
{
    for (uint32_t i = 0U; i < 41U; i++)    /* 10 points per decade */
    {
        for (uint32_t j = 0U; j < 31U; j++)
        {
            check(logspace(FXSCALE_X_MIN, FXSCALE_X_MAX, i, 41U),
                  logspace(FXSCALE_G_MIN, FXSCALE_G_MAX, j, 31U));
        }
    }
    report("log grid 41x31");
}

static void test_random_pairs(void)
{
    uint32_t s = 12345U;                   /* fixed seed: the same pairs every run */
    for (uint32_t k = 0U; k < 5000U; k++)
    {
        s = s * 1664525U + 1013904223U;
        float u = (float)(s >> 8) / 16777216.0f;
        s = s * 1664525U + 1013904223U;
        float v = (float)(s >> 8) / 16777216.0f;
        check(FXSCALE_X_MIN * powf(FXSCALE_X_MAX / FXSCALE_X_MIN, u),
              FXSCALE_G_MIN * powf(FXSCALE_G_MAX / FXSCALE_G_MIN, v));
    }
    report("5000 random pairs");
}

void test_fxscale_suite(void)
{
    unit_setup    = suite_setup;
    unit_teardown = NULL;
    UnitySetTestFile(__FILE__);           /* Unity's FAIL lines name this file */
    RUN_TEST(test_examples);
    RUN_TEST(test_corners);
    RUN_TEST(test_log_grid);
    RUN_TEST(test_random_pairs);
}
