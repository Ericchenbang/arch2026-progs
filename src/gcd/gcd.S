# gcd_u32_asm: binary GCD, hand-written RV32I.
#
# uint32_t gcd_u32_asm(uint32_t a, uint32_t b)   a in a0, b in a1, result in a0
#
# RV32I and Zicsr only: no mul, div, rem, no floating point, no compressed
# instructions. Tests: tests/tgcd.c.

    .text

    .globl  gcd_u32_asm
    .type   gcd_u32_asm, @function
    .align  2
gcd_u32_asm:
    beq a0, x0, pa_alt
check_b_zero:
    beq a1, x0, pa_end
cal_shared_twos:
    addi a2, x0, 0          # a2: shared_twos
shared_twos_loop:
    andi a3, a0, 1          # a3: a & 1
    bne a3, x0, check_divide_b
    andi a4, a1, 1          # a4: b & 1
    bne a4, x0, divide_a
    srli a0, a0, 1
    srli a1, a1, 1
    addi a2, a2, 1
    jal x0, shared_twos_loop
divide_a:
    srli a0, a0, 1
    andi a3, a0, 1
    beq a3, x0, divide_a  
check_divide_b:
    andi a4, a1, 1
    bne a4, x0, check_swap
divide_b: 
    srli a1, a1, 1
    andi a4, a1, 1
    beq a4, x0, divide_b
check_swap:
    bgeu a1, a0, minus
    addi t0, a0, 0
    addi a0, a1, 0
    addi a1, t0, 0
minus:
    sub a1, a1, a0
    bne a1, x0, check_divide_b

    sll a0, a0, a2
    jalr x0, ra, 0
pa_alt:
    addi a0, a1, 0
pa_end:
    jalr x0, ra, 0
    .size   gcd_u32_asm, .-gcd_u32_asm
