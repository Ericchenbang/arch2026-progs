# op1, op2, op3 and q_mul: hand-written RV32I.
#
# uint32_t op1_asm(uint32_t a, uint32_t b, int *n)   a0, a1, a2 -> a0
# uint32_t op2_asm(uint32_t a, uint32_t b)           a0, a1 -> a0
# uint32_t op3_asm(uint32_t a, uint32_t b)           a0, a1 -> a0
# int32_t  q_mul_asm(int32_t a, int32_t b)           a0, a1 -> a0
#
# RV32I and Zicsr only: no mul, div, rem, no floating point, no compressed
# instructions. q_mul forms a 64-bit product in a register pair. Tests:
# tests/tfixed.c.

    .text

    .globl  op1_asm
    .type   op1_asm, @function
    .align  2
op1_asm:
    addi a3, x0, 0              # a3: value of n
op1_loop:
    beq a1, x0, op1_return
    and t0, a0, a1              # t0: a & b
    xor a0, a0, a1              # a = a ^ b
    slli a1, t0, 1              # b = t0 << 1
    addi a3, a3, 1
    jal x0, op1_loop
op1_return:
    sw a3, 0(a2)
    jalr x0, ra, 0
    .size   op1_asm, .-op1_asm

    .globl  op2_asm
    .type   op2_asm, @function
    .align  2
op2_asm:
    sub a0, a0, a1
    jalr x0, ra, 0
    .size   op2_asm, .-op2_asm

    .globl  op3_asm
    .type   op3_asm, @function
    .align  2
op3_asm:
    and t0, a0, a1
    andi t0, t0, 1              # t0: a & b & 1
    srli a0, a0, 1
    srli a1, a1, 1
    add a0, a0, a1 
    add a0, a0, t0
    jalr x0, ra, 0
    .size   op3_asm, .-op3_asm

    .globl  q_mul_asm
    .type   q_mul_asm, @function
    .align  2
q_mul_asm:
    addi sp, sp, -16
    sw ra, 12(sp)

    addi a2, x0, 0              # a2: sign
    addi a3, x0, -1             # a3: 0xFFFF_FFFF
check_a:
    bge a0, x0, check_b
neg_a:
    xor a0, a0, a3
    addi a0, a0, 1
    xori a2, a2, 1
check_b:
    bge a1, x0, seperate_low_high
neg_b:
    xor a1, a1, a3
    addi a1, a1, 1
    xori a2, a2, 1
seperate_low_high:
    srli a3, a3, 16             # a3: 0xFFFF
    and a4, a0, a3              # a4: a_low
    and a5, a1, a3              # a5: b_low
    srli a0, a0, 16
    and a6, a0, a3              # a6: a_high
    srli a1, a1, 16
    and a7, a1, a3              # a7: b_high

    addi a0, a4, 0
    addi a1, a5, 0
    addi a3, a6, 0
    jal ra, multiplication
    addi t2, t0, 0              # t2: result_low (a_low_times_b_low)
    addi t3, t1, 0              # t3: a_high_times_b_low
    
    addi a0, a4, 0
    addi a1, a7, 0
    addi a3, a6, 0          
    jal ra, multiplication      # t0: a_low_times_b_high
                                # t1: a_high_times_b_high
    
    #addi a3, t2, 0              # a3: result_low (a_low_times_b_low)
    #addi a5, t3, 0              # a5: a_high_times_b_low
    #addi a4, t0, 0              # a4: a_low_times_b_high
    #addi a6, t1, 0              # a6: result_high (a_high_times_b_high)

    slli t5, t3, 16             # t0: temp
    addi t6, t2, 0              # t1: old
    add t2, t2, t5
    srli t5, t3, 16
    add t1, t1, t5
    bgeu t2, t6, next_middle
    addi t1, t1, 1
next_middle:
    slli t5, t0, 16
    addi t6, t2, 0
    add t2, t2, t5
    srli t5, t0, 16
    add t1, t1, t5
    bgeu t2, t6, check_sign
    addi t1, t1, 1
check_sign:
    beq a2, x0, plus_1_19
    addi t5, x0, -1             # t5: 0xFFFF_FFFF
    xor t2, t2, t5
    xor t1, t1, t5
    addi t6, t2, 0              # t6: old
    addi t2, t2, 1
    bgeu t2, t6, plus_1_19
    addi t1, t1, 1
plus_1_19:
    addi t6, t2, 0              # t1: old
    li t5, 0x00080000
    add t2, t2, t5
    bgeu t2, t6, shift
    addi t1, t1, 1
shift:
    srli t2, t2, 20
    slli t1, t1, 12
    or a0, t1, t2
    lw ra, 12(sp)
    addi sp, sp, 16
    jalr x0, ra, 0

multiplication:     # input: a0, a1, a3; output: t0, t1;
    addi t0, x0, 0              # result
    addi t1, x0, 0
mul_while_loop:
    beq a1, x0, mul_return
    andi t6, a1, 1
    beq t6, x0, mul_next_digit
    add t0, t0, a0
    add t1, t1, a3
mul_next_digit: 
    slli a0, a0, 1
    slli a3, a3, 1
    srli a1, a1, 1
    jal x0, mul_while_loop
mul_return:
    jalr x0, ra, 0
    .size   q_mul_asm, .-q_mul_asm
