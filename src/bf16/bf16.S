# BFloat16 routines: hand-written RV32I.
#
# uint16_t bf16_from_f32_asm(uint32_t f32bits)   a0 -> a0
# uint16_t bf16_mul_asm(uint16_t a, uint16_t b)  a0, a1 -> a0
# uint16_t bf16_sqrt_asm(uint16_t a)             a0 -> a0
#
# RV32I and Zicsr only: no mul, div, rem, no floating point, no compressed
# instructions. Tests: tests/tbf16.c.

    .equ POS_ZERO, 0x0000
    .equ POS_INF,  0x7F80
    .equ NAN,      0x7FC0
    .equ EXP_BIAS, 127

    .globl  bf16_from_f32_asm
    .type   bf16_from_f32_asm, @function
    .align  2
bf16_from_f32_asm:
    srli t0, a0, 23
    andi t0, t0, 0xFF       # t0 = exp
    addi t1, x0, 0xFF
    beq t0, t1, bf16_from_f32_return
    srli t0, a0, 16
    andi t0, t0, 1          # t0 = bit16
    li t1, 0x7FFF           # t1 = 0x7FFF
    add a0, a0, t1
    add a0, a0, t0
bf16_from_f32_return:
    srli a0, a0, 16
    # li t0, 0xFFFF
    # and a0, a0, t0
    jalr x0, ra, 0
    .size   bf16_from_f32_asm, .-bf16_from_f32_asm

    .globl  bf16_mul_asm
    .type   bf16_mul_asm, @function
    .align  2
bf16_mul_asm:
    srli t0, a0, 15
    andi t0, t0, 1
    srli t1, a1, 15
    andi t1, t1, 1
    xor a4, t0, t1          # a4: result_sign    
    slli a5, a4, 15         # a5: (result_sign << 15)

    srli a7, a0, 7
    andi a7, a7, 0xFF       # a7: exp_a
    srli a6, a1, 7
    andi a6, a6, 0xFF       # a6: exp_b
    
    andi a2, a0, 0x7F       # a2: mant_a
    andi a3, a1, 0x7F       # a3: mant_b

    addi t3, x0, 0          # t3: (!exp_a && !mant_a)
    addi t4, x0, 0          # t4: (!exp_b && !mant_b)
    addi t6, x0, 1          # t6: 1
a_zero:
    bne a7, x0, b_zero
    bne a2, x0, b_zero
    addi t3, x0, 1 
b_zero:
    bne a6, x0, special
    bne a3, x0, special
    addi t4, x0, 1          
special:
    addi t5, x0, 0xFF       # t5: 0xFF
check_a:
    bne a7, t5, check_b
    beq a2, x0, a_not_NaN
    jalr x0, ra, 0          # return a
a_not_NaN:
    beq t4, t6, return_NaN
    jal x0, return_sign_INF
check_b:
    bne a6, t5, check_ab_zero
    beq a3, x0, b_not_NaN
    addi a0, a1, 0
    jalr x0, ra, 0          # return b
b_not_NaN: 
    beq t3, t6, return_NaN
return_sign_INF:
    li t0, POS_INF
    or a0, a5, t0
    jalr x0, ra, 0
return_NaN:
    li a0, NAN
    jalr x0, ra, 0

check_ab_zero:
    beq t3, t6, a_b_is_zero
    bne t4, t6, a_normalize_denormal
a_b_is_zero:
    addi a0, a5, 0
    jalr x0, ra, 0          # return (result_sign << 15)

a_normalize_denormal:
    addi t3, x0, 0          # t3: exp_adjust
    bne a7, x0, a_add_implict_one 
    addi a7, x0, 1          # exp_a = 1
norm_a_loop:
    andi t0, a2, 0x80
    bne t0, x0, b_normalize_denormal
    slli a2, a2, 1
    addi t3, t3, -1
    jal x0, norm_a_loop
a_add_implict_one:
    ori a2, a2, 0x80
b_normalize_denormal:
    bne a6, x0,  b_add_implict_one
    addi a6, x0, 1          # exp_b = 1
norm_b_loop:
    andi t0, a3, 0x80
    bne t0, x0, multiplication
    slli a3, a3, 1
    addi t3, t3, -1
    jal x0, norm_b_loop
b_add_implict_one:
    ori a3, a3, 0x80
multiplication:
    addi a0, x0, 0          # a0: result_mant
while_loop: 
    beq a3, x0, umul_finish
    andi t1, a3, 1
    beq t1, x0, next_digit 
    add a0, a0, a2
next_digit:
    slli a2, a2, 1
    srli a3, a3, 1
    jal x0, while_loop
umul_finish:
    add a1, a7, a6
    addi a1, a1, -127
    add a1, a1, t3          # a1: result_exp
    
    li t0, 0x8000
    and t1, a0, t0
    beq t1, x0, no_carry
    srli a0, a0, 8
    addi a1, a1, 1
    jal x0, check_result_exp
no_carry:
    srli a0, a0, 7
check_result_exp:
    andi a0, a0, 0x7F
    blt a1, t5, check_subnormal
    li t0, POS_INF
    or a0, a5, t0
    jalr x0, ra, 0
check_subnormal:
    blt a1, x0, check_neg6
    bne a1, x0, mul_return
check_neg6:
    addi t0, x0, -6
    bge a1, t0, subnormal_right_shift_result_mant
    addi a0, a5, 0
    jalr x0, ra, 0
subnormal_right_shift_result_mant:
    sub t0, t6, a1
    srl a0, a0, t0          # result_mant >>= (1 - result_exp);
    addi a1, x0, 0
mul_return:
    andi t1, a1, 0xFF
    slli t1, t1, 7
    andi t2, a0, 0x7F
    or a0, a5, t1
    or a0, a0, t2
    jalr x0, ra, 0

    .size   bf16_mul_asm, .-bf16_mul_asm

    .globl  bf16_sqrt_asm
    .type   bf16_sqrt_asm, @function
    .align  2
bf16_sqrt_asm:
    srli a1, a0, 15
    andi a1, a1, 1          # a1: sign_a
    srli a2, a0, 7
    andi a2, a2, 0xFF       # a2: exp_a
    andi a3, a0, 0x7F       # a3: mant_a

    addi a4, x0, 0xFF       # a4: 0xFF
    bne a2, a4, sqrt_check_neg
    beq a3, x0, sqrt_a_isnot_NAN
sqrt_return_a:
    jalr x0, ra, 0          # a is NaN, return a
sqrt_a_isnot_NAN:
    beq a1, x0, sqrt_return_a
sqrt_return_NAN:
    li a0, NAN
    jalr x0, ra, 0          # return NaN

sqrt_check_neg:
    beq a1, x0, sqrt_check_exp
    bne a2, x0, sqrt_return_NAN
    bne a3, x0, sqrt_return_NAN
sqrt_check_exp:
    bne a2, x0, sqrt_adjust_exp
    li a0, POS_ZERO
    jalr x0, ra, 0          # return POS_ZERO
sqrt_adjust_exp:
    addi a2, a2, -127
    ori a3, a3, 0x80
    addi a5, x0, 127        # a5: new_exp
    andi t0, a2, 1          # t0: exp_a & 1
    beq t0, x0, sqrt_exp_even
    slli a3, a3, 1
    addi a2, a2, -1
sqrt_exp_even:
    srai a2, a2, 1
    add a5, a5, a2

    addi t0, x0, 90         # t0: low
    addi t1, x0, 256        # t1: high
    addi a6, x0, 128        # a6: result
sqrt_binary_search:
    blt t0, t1, sqrt_cal_mid        # low < high
    bne t0, t1, sqrt_check_result   # low != high
sqrt_cal_mid:
    add t3, t0, t1
    srli t3, t3, 1          # t3: mid
    add t4, t3, x0          # t4: mid
    add t5, t3, x0          # t5: mid
    
    addi t6, x0, 0          # t6: sq
sq_mul_while_loop: 
    beq t5, x0, sq_mul_finish
    andi t2, t5, 1         
    beq t2, x0, sq_next_digit 
    add t6, t6, t4
sq_next_digit:
    slli t4, t4, 1
    srli t5, t5, 1
    jal x0, sq_mul_while_loop
sq_mul_finish:
    srli t6, t6, 7          # sq / 128
    blt t6, a3, sq_less_equal
    bne t6, a3, sq_bigger
sq_less_equal:
    addi a6, t3, 0          # result = mid
    addi t0, t3, 1          # low = mid + 1
    jal x0, sqrt_binary_search
sq_bigger:
    addi t1, t3, -1
    jal x0, sqrt_binary_search

sqrt_check_result:
    andi t0, a6, 0x100
    beq t0, x0, sqrt_check_subnormal
    addi a5, a5, 1          # new_exp++
    srli a6, a6, 1
sqrt_check_subnormal:
    andi t1, a6, 0x80
    bne t1, x0, sqrt_exp_Inf
    addi a5, a5, -1
    slli a6, a6, 1
    jal x0, sqrt_check_subnormal
sqrt_exp_Inf:
    bne a5, a4, sqrt_exp_zero
    li a0, POS_INF
    jalr x0, ra, 0
sqrt_exp_zero:
    blt a5, x0, sqrt_return_POS_ZERO
    bne a5, x0, sqrt_final_return
sqrt_return_POS_ZERO:
    li a0, POS_ZERO
    jalr x0, ra, 0
sqrt_final_return:
    slli a0, a1, 15
    andi a5, a5, 0xFF
    slli a5, a5, 7
    or a0, a0, a5
    andi a6, a6, 0x7F
    or a0, a0, a6
    jalr x0, ra, 0
    .size   bf16_sqrt_asm, .-bf16_sqrt_asm
