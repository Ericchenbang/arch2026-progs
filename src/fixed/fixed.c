#include "fixed.h"

/* Dummies: every function returns 0. Replace with the real routines. */
uint32_t op1(uint32_t a, uint32_t b, int *n)
{
    *n = 0;
    while (b) {
        unsigned c = (a & b) << 1;
        a = a ^ b;
        b = c;
        ++*n;
    }
    return a;
}

uint32_t op2(uint32_t a, uint32_t b)
{
    uint32_t c = a - b;
    return c;
}

uint32_t op3(uint32_t a, uint32_t b)
{
    uint32_t c = a & b & 1;
    a >>= 1;
    b >>= 1;
    c += a + b;
    return c;
}

int32_t q_mul(int32_t a, int32_t b)
{
    /*
     * int32_t a high[31:16], low[15:0]
     * middle[23:8], middle_high[23:16], middle_low[15:8]
     */
    uint32_t abs_a, abs_b, sign = 0;
    if (a < 0) {
        abs_a = 0u - (uint32_t) a;
        sign ^= 1;
    } else {
        abs_a = (uint32_t) a;
    }
    if (b < 0) {
        abs_b = 0u - (uint32_t) b;
        sign ^= 1;
    } else {
        abs_b = (uint32_t) b;
    }

    // uint32_t abs_a = a, abs_b = b, sign_a = 0, sign_b = 0;
    // if (a < 0) sign_a = 1;
    // if (b < 0) sign_b = 1;

    uint32_t a_low = abs_a & 0xFFFF;
    uint32_t b_low = abs_b & 0xFFFF;
    uint32_t a_high = (abs_a >> 16) & 0xFFFF;
    uint32_t b_high = (abs_b >> 16) & 0xFFFF;

    uint32_t a_low_times_b_low = a_low * b_low;
    uint32_t a_high_times_b_low = a_high * b_low;
    uint32_t a_low_times_b_high = a_low * b_high;
    uint32_t a_high_times_b_high = a_high * b_high;

    uint32_t result_low = a_low_times_b_low;
    uint32_t result_high = a_high_times_b_high;

    // uint32_t temp = a_high_times_b_low << 16;
    // uint32_t old = result_low;
    // result_low += temp;
    // result_high += (a_high_times_b_low >> 16) + (result_low < old);

    // temp = a_low_times_b_high << 16;
    // old = result_low;
    // result_low += temp;
    // result_high += (a_low_times_b_high >> 16) + (result_low < old);

    if (0xFFFFFFFF - result_low < (a_high_times_b_low << 16)) {
        result_high += 1;
    }
    result_low += (a_high_times_b_low << 16);
    result_high += a_high_times_b_low >> 16;

    if (0xFFFFFFFF - result_low < (a_low_times_b_high << 16)) {
        result_high += 1;
    }
    result_low += a_low_times_b_high << 16;
    result_high += a_low_times_b_high >> 16;

    if (sign) {
        result_low = result_low ^ 0xFFFFFFFF;
        result_high = result_high ^ 0xFFFFFFFF;
        // old = result_low;
        // result_low += 1;
        // result_high += (result_low < old);

        if (result_low == 0xFFFFFFFF)
            result_high += 1;
        result_low += 1;
    }

    // if (sign_a){
    //     result_high -= b;
    // }
    // if (sign_b){
    //     result_high -= a;
    // }

    // old = result_low;
    // result_low += 0x00080000u;
    // result_high += (result_low < old);

    if (0xFFFFFFFF - result_low < 0x00080000u)
        result_high += 1;
    result_low += 0x00080000u;

    result_low >>= 20;
    int32_t result = (result_high << 12) | (result_low);

    return result;
}
