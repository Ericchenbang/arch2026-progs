#include "gcd.h"

/* Dummy: returns 0 for every input. Replace with the binary GCD. */
uint32_t gcd_u32(uint32_t a, uint32_t b)
{
    if (a == 0) {
        return b;
    }
    if (b == 0) {
        return a;
    }
    uint32_t shared_twos = 0;

    while (((a | b) & 1) == 0) {
        a /= 2;
        b /= 2;
        shared_twos += 1;
    }

    while ((a & 1) == 0) {
        a /= 2;
    }
    do {
        while ((b & 1) == 0) {
            b /= 2;
        }

        if (a > b) {
            uint32_t temp = a;
            a = b;
            b = temp;
        }
        b -= a;
    } while (b != 0);

    return (a << shared_twos);
}
