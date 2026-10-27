/*******************************************************************************
* File Name : fxscale.h
*
* Layer 2 - function. Scale a value by a gain in fixed point with CMSIS-DSP:
* float -> q31 -> arm_scale_q31() -> q31 -> float.
* Contract: x in [FXSCALE_X_MIN, FXSCALE_X_MAX], gain in [FXSCALE_G_MIN,
* FXSCALE_G_MAX]; the result is within FXSCALE_MAX_REL_ERR of the float
* product x * gain (relative). Outside the range the result is undefined.
*
* Uses CMSIS-DSP (Arm, Apache-2.0): Cortex-M only - func/ may include arm_math.h
* on Cortex-M boards (docs/board-api.md); the skill's build must compile CMSIS-DSP
* (the CubeMX skills do).
*******************************************************************************/
#ifndef FXSCALE_H
#define FXSCALE_H

#define FXSCALE_X_MIN           (0.01f)
#define FXSCALE_X_MAX           (100.0f)
#define FXSCALE_G_MIN           (0.01f)
#define FXSCALE_G_MAX           (10.0f)
#define FXSCALE_MAX_REL_ERR     (0.01f)     /* 1 % */

float fxscale(float x, float gain);

#endif /* FXSCALE_H */
