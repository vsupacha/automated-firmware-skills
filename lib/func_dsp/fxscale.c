/*******************************************************************************
* File Name : fxscale.c
*
* Layer 2 - function. See fxscale.h.
*
* Block floating point: each operand is split into a mantissa in [0.5, 1) and a
* power of two (frexpf), the mantissas are multiplied in q31 by CMSIS-DSP
* (arm_float_to_q31 -> arm_scale_q31 -> arm_q31_to_float; the product is in
* [0.25, 1), so about 30 bits of it survive), and the exponents are added back
* (ldexpf). The q31 product keeps ~30 bits, so the error is set by rounding the
* result to float32: worst 6e-8 relative on the board (0.000006 %), whatever the
* magnitude.
*
* Found by the unit tests (2026-10-27, NUCLEO-WB55RG): one fixed Q format for the
* whole range (x / 2^7, gain / 2^4) leaves only ~100 q31 counts for the smallest
* products - 1.31 % error at x 0.012, gain 0.011 (5000 random pairs), although the
* corners and a log grid stayed under 1 %.
*******************************************************************************/
#include "fxscale.h"

#include <math.h>

#include "arm_math.h"

float fxscale(float x, float gain)
{
    int       ex, eg;
    float32_t xm = frexpf(x, &ex);           /* x    = xm * 2^ex, xm in [0.5, 1) */
    float32_t gm = frexpf(gain, &eg);        /* gain = gm * 2^eg                 */
    q31_t     xq, gq, yq;
    float32_t y;

    arm_float_to_q31(&xm, &xq, 1U);
    arm_float_to_q31(&gm, &gq, 1U);
    arm_scale_q31(&xq, gq, 0, &yq, 1U);       /* yq = xq * gq, in [0.25, 1)       */
    arm_q31_to_float(&yq, &y, 1U);
    return ldexpf(y, ex + eg);
}
