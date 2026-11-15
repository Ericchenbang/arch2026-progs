#include "bf16.h"

#define POS_ZERO 0x0000U
#define POS_INF 0x7F80U
#define NAN 0x7FC0U

#define EXP_BIAS 127

/* Dummies: every function returns 0. Replace with the real routines. */
uint16_t bf16_from_f32(uint32_t f32bits)
{
    int16_t exp = (f32bits >> 23) & 0xFF;
    uint16_t bit16 = (f32bits >> 16) & 1;
    if (exp == 0xFF) {
        return ((f32bits >> 16) & 0xFFFF);
    } else {
        // uint16_t bit16 = (f32bits >> 16) & 1;
        f32bits += 0x7FFF + bit16;
        return ((f32bits >> 16) & 0xFFFF);
    }
}

uint16_t bf16_mul(uint16_t a, uint16_t b)
{
    uint16_t sign_a = (a >> 15) & 1;
    uint16_t sign_b = (b >> 15) & 1;
    int16_t exp_a = ((a >> 7) & 0xFF);
    int16_t exp_b = ((b >> 7) & 0xFF);
    uint16_t mant_a = a & 0x7F;
    uint16_t mant_b = b & 0x7F;

    uint16_t result_sign = sign_a ^ sign_b;

    /** Handle special cases */
    // if a is Inf or NaN
    if (exp_a == 0xFF) {
        // a is NaN
        if (mant_a)
            return a;
        // a is Inf and b is zero
        if (!exp_b && !mant_b)
            return NAN;
        // a is Inf and b is non-zero
        return (result_sign << 15) | 0x7F80;
    }
    // if b is Inf or NaN
    if (exp_b == 0xFF) {
        // b is NaN
        if (mant_b)
            return b;
        // b is Inf and a is zero
        if (!exp_a && !mant_a)
            return NAN;
        // b is Inf and a is non-zero
        return (result_sign << 15) | 0x7F80;
    }
    // a is zero or b is zero
    if ((!exp_a && !mant_a) || (!exp_b && !mant_b))
        return (result_sign << 15);

    // Normalize denormal number
    int16_t exp_adjust = 0;
    if (!exp_a) {
        while (!(mant_a & 0x80)) {
            mant_a <<= 1;
            exp_adjust--;
        }
        exp_a = 1;
    } else
        mant_a |= 0x80;
    if (!exp_b) {
        while (!(mant_b & 0x80)) {
            mant_b <<= 1;
            exp_adjust--;
        }
        exp_b = 1;
    } else
        mant_b |= 0x80;

    uint32_t result_mant = (uint32_t) mant_a * mant_b;
    int32_t result_exp = (int32_t) exp_a + exp_b - EXP_BIAS + exp_adjust;

    // check if mant has carry, and truncate toward zero stated by bf16.h
    if (result_mant & 0x8000) {
        result_mant = (result_mant >> 8) & 0x7F;
        result_exp++;
    } else
        result_mant = (result_mant >> 7) & 0x7F;

    // check if it's Inf
    if (result_exp >= 0xFF)
        return (result_sign << 15) | 0x7F80;
    // check if it's subnormal
    if (result_exp <= 0) {
        // when the exponent is below -6, the result is zero with the product
        // sign
        if (result_exp < -6)
            return result_sign << 15;
        result_mant >>= (1 - result_exp);
        result_exp = 0;
    }

    return (result_sign << 15) | ((result_exp & 0xFF) << 7) |
           (result_mant & 0x7F);
}

uint16_t bf16_sqrt(uint16_t a)
{
    uint16_t sign_a = (a >> 15) & 1;
    int16_t exp_a = ((a >> 7) & 0xFF);
    uint16_t mant_a = a & 0x7F;

    if (exp_a == 0xFF) {
        // a is NaN
        if (mant_a)
            return a;
        // a is +Inf
        if (!sign_a)
            return a;
        // a is -Inf
        else
            return NAN;
    }
    // a is negative and not -0
    if (sign_a && (exp_a || mant_a))
        return NAN;
    // a is +0, -0 or denormal
    if (exp_a == 0)
        return POS_ZERO;

    exp_a -= EXP_BIAS;
    mant_a |= 0x80;

    // halve exp
    int16_t new_exp;
    // if exp is odd, left shift mant and then halve it
    if (exp_a & 1) {
        mant_a <<= 1;
        new_exp = ((exp_a - 1) >> 1) + EXP_BIAS;
    } else {
        new_exp = (exp_a >> 1) + EXP_BIAS;
    }

    uint32_t low = 90, high = 256, result = 128;

    while (low <= high) {
        uint32_t mid = (low + high) >> 1;
        uint32_t sq = (mid * mid) / 128;

        if (sq <= mant_a) {
            result = mid;
            low = mid + 1;
        } else {
            high = mid - 1;
        }
    }

    if (result & 0x100) {
        new_exp++;
        result >>= 1;
    }
    while (!(result & 0x80)) {
        new_exp--;
        result <<= 1;
    }

    if (new_exp == 0xFF) {
        return POS_INF;
    }
    if (new_exp <= 0) {
        return POS_ZERO;
    }
    return (sign_a << 15) | ((new_exp & 0xFF) << 7) | (result & 0x7F);
}
